class_name DevFFmpegInstaller
extends Node
## Downloads a checked, private FFmpeg copy; never changes PATH or the OS install.

signal status_changed(message: String)
signal progress_changed(downloaded: int, total: int)
signal finished(path: String, error: String)

@export var archive_url: String = "https://www.gyan.dev/ffmpeg/builds/ffmpeg-release-essentials.zip"
@export var checksum_url: String = "https://www.gyan.dev/ffmpeg/builds/ffmpeg-release-essentials.zip.sha256"
@export var cache_directory: String = "user://dev_toolkit/ffmpeg"
@export var max_download_bytes: int = 256 * 1024 * 1024
@export var max_executable_bytes: int = 256 * 1024 * 1024
@export var request_timeout: float = 600.0
@export var probe_timeout: float = 10.0

var busy: bool = false
var status_text: String = ""
var _request: HTTPRequest
var _stage: String = ""
var _phase: String = ""
var _digest: String = ""
var _worker: Thread
var _mutex := Mutex.new()
var _cancelled: bool = false
var _worker_status: String = ""
var _config: Dictionary = {}
var _cached_path: String = ""
var _progress_bytes: int = -1

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

func platform_supported() -> bool:
	return OS.get_name() == "Windows" and OS.has_feature("x86_64")

func _safe_url(url: String) -> bool:
	# Loopback HTTP permits offline fixture tests and local development mirrors.
	return url.begins_with("https://") or url.begins_with("http://127.0.0.1:") or url.begins_with("http://localhost:")

func start_install() -> String:
	if busy:
		return "FFmpeg download is already in progress."
	if not is_inside_tree():
		return "FFmpeg installer must be added to the scene tree first."
	if not platform_supported():
		return "Automatic FFmpeg download supports Windows x86_64. Install FFmpeg on PATH or set ffmpeg_path on this platform."
	if not _safe_url(archive_url) or not _safe_url(checksum_url):
		return "FFmpeg archive and checksum URLs must use HTTPS."
	if cache_directory.is_empty() or max_download_bytes <= 0 or max_executable_bytes <= 0 or request_timeout <= 0 or probe_timeout <= 0:
		return "FFmpeg installer configuration is invalid."
	var root := ProjectSettings.globalize_path(cache_directory)
	var error := DirAccess.make_dir_recursive_absolute(root)
	if error != OK:
		return "Cannot create FFmpeg cache: " + error_string(error)
	_stage = root.path_join(".install-" + str(OS.get_process_id()) + "-" + str(Time.get_ticks_usec()))
	error = DirAccess.make_dir_absolute(_stage)
	if error != OK:
		_stage = ""
		return "Cannot create FFmpeg download folder: " + error_string(error)
	_config = {"root": root, "archive_url": archive_url, "checksum_url": checksum_url, "max_executable_bytes": max_executable_bytes, "probe_timeout": probe_timeout}
	_mutex.lock()
	_cancelled = false
	_worker_status = ""
	_mutex.unlock()
	busy = true
	_digest = ""
	_progress_bytes = -1
	_phase = "checksum"
	_set_status("Checking FFmpeg download checksum...")
	return _begin_request(checksum_url, "", 4096)

func _begin_request(url: String, destination: String, limit: int) -> String:
	_release_request()
	_request = HTTPRequest.new()
	_request.process_mode = Node.PROCESS_MODE_ALWAYS
	# Keep HTTP polling nonblocking: the native threaded cancel joins can stall
	# on partial response headers. Hashing/extraction/probes use our own worker.
	_request.use_threads = false
	_request.download_chunk_size = 65536
	_request.accept_gzip = false
	_request.timeout = request_timeout
	_request.body_size_limit = limit
	_request.download_file = destination
	add_child(_request)
	_request.request_completed.connect(_request_completed)
	var error := _request.request(url)
	if error != OK:
		var message := "Cannot start FFmpeg download: " + error_string(error)
		_finish("", message)
		return message
	return ""

func _request_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if not busy:
		return
	if result != HTTPRequest.RESULT_SUCCESS:
		_finish("", "FFmpeg download failed: " + _http_error(result))
		return
	if response_code != 200:
		_finish("", "FFmpeg download returned HTTP " + str(response_code) + ".")
		return
	if _phase == "checksum":
		_digest = _parse_checksum(body.get_string_from_utf8())
		if _digest.is_empty():
			_finish("", "FFmpeg provider returned an invalid SHA256 checksum.")
			return
		_phase = "archive"
		_set_status("Downloading FFmpeg...")
		_begin_request(_config.archive_url, _stage.path_join("archive.zip"), max_download_bytes)
	else:
		_release_request()
		_phase = "verify"
		_set_status("Verifying FFmpeg download...")
		_worker = Thread.new()
		var error := _worker.start(_verify_extract_probe)
		if error != OK:
			_worker = null
			_finish("", "Cannot start FFmpeg verification: " + error_string(error))

func _parse_checksum(value: String) -> String:
	var regex := RegEx.new()
	regex.compile("^([0-9a-fA-F]{64})(?:[ \\t]+[^\\r\\n]+)?$")
	var match := regex.search(value.strip_edges())
	return match.get_string(1).to_lower() if match != null else ""

func _http_error(result: int) -> String:
	match result:
		HTTPRequest.RESULT_CANT_CONNECT: return "could not connect."
		HTTPRequest.RESULT_CANT_RESOLVE: return "could not resolve the download server."
		HTTPRequest.RESULT_TLS_HANDSHAKE_ERROR: return "secure connection failed."
		HTTPRequest.RESULT_BODY_SIZE_LIMIT_EXCEEDED: return "download exceeds the configured size limit."
		HTTPRequest.RESULT_DOWNLOAD_FILE_CANT_OPEN: return "could not create the downloaded file."
		HTTPRequest.RESULT_DOWNLOAD_FILE_WRITE_ERROR: return "could not write the downloaded file."
		HTTPRequest.RESULT_TIMEOUT: return "download timed out. Try again."
		_: return "network request failed (" + str(result) + "). Try again."

func _set_status(message: String) -> void:
	status_text = message
	status_changed.emit(message)

func _post_worker_status(message: String) -> void:
	_mutex.lock()
	_worker_status = message
	_mutex.unlock()

func _was_cancelled() -> bool:
	_mutex.lock()
	var value := _cancelled
	_mutex.unlock()
	return value

func _process(_delta: float) -> void:
	if not busy:
		return
	if _request != null and _phase == "archive":
		var downloaded := _request.get_downloaded_bytes()
		if downloaded != _progress_bytes:
			_progress_bytes = downloaded
			progress_changed.emit(downloaded, _request.get_body_size())
	if _worker != null:
		_mutex.lock()
		var next_status := _worker_status
		_worker_status = ""
		_mutex.unlock()
		if not next_status.is_empty():
			_set_status(next_status)
		if not _worker.is_alive():
			var result: Dictionary = _worker.wait_to_finish()
			_worker = null
			if _was_cancelled():
				_finish("", "FFmpeg download cancelled.")
			elif not result.error.is_empty():
				_finish("", result.error)
			else:
				_publish(result)

func cancel() -> void:
	if not busy:
		return
	_mutex.lock()
	_cancelled = true
	_mutex.unlock()
	_release_request()
	if _worker != null:
		_set_status("Cancelling FFmpeg download...")
	else:
		_finish("", "FFmpeg download cancelled.")

func _release_request() -> void:
	if _request != null:
		_request.cancel_request()
		_request.queue_free()
		_request = null

func _verify_extract_probe() -> Dictionary:
	var archive := _stage.path_join("archive.zip")
	var digest := _hash_file(archive)
	if _was_cancelled():
		return {"error": "FFmpeg download cancelled."}
	if digest != _digest:
		return {"error": "FFmpeg checksum did not match. Nothing was installed; try again."}
	_post_worker_status("Extracting FFmpeg...")
	# Inspect central-directory sizes before ZIPReader allocates decompressed data.
	var index := _zip_index(archive)
	if not index.error.is_empty():
		return {"error": index.error}
	var candidates: Array[String] = []
	for entry: Dictionary in index.entries:
		if _is_executable_entry(entry.path):
			candidates.append(entry.path)
			if entry.size <= 0 or entry.size > int(_config.max_executable_bytes):
				return {"error": "FFmpeg executable exceeds the configured size limit."}
	if candidates.size() != 1:
		return {"error": "FFmpeg archive must contain exactly one bin/ffmpeg.exe."}
	var reader := ZIPReader.new()
	if reader.open(archive) != OK:
		return {"error": "FFmpeg download is not a readable ZIP archive."}
	var path := _stage.path_join("ffmpeg.exe")
	var bytes := reader.read_file(candidates[0])
	if bytes.is_empty() or bytes.size() > int(_config.max_executable_bytes):
		reader.close()
		return {"error": "Cannot extract FFmpeg executable."}
	var hash_context := HashingContext.new()
	hash_context.start(HashingContext.HASH_SHA256)
	hash_context.update(bytes)
	var executable_hash := hash_context.finish().hex_encode()
	var error := _write_file(path, bytes)
	bytes.clear()
	if not error.is_empty():
		reader.close()
		return {"error": error}
	var parent := candidates[0].trim_suffix("bin/ffmpeg.exe")
	for entry: Dictionary in index.entries:
		if entry.path.get_base_dir() != parent.trim_suffix("/"):
			continue
		var name: String = entry.path.get_file().to_lower()
		var destination := "LICENSE.txt" if name in ["license", "license.txt", "copying", "copying.txt"] else "README.txt" if name in ["readme", "readme.txt"] else ""
		if not destination.is_empty() and entry.size > 0 and entry.size <= 1024 * 1024:
			error = _write_file(_stage.path_join(destination), reader.read_file(entry.path))
			if not error.is_empty():
				reader.close()
				return {"error": error}
	reader.close()
	if _was_cancelled():
		return {"error": "FFmpeg download cancelled."}
	_post_worker_status("Checking FFmpeg recorder support...")
	error = _probe_executable(path)
	if not error.is_empty():
		return {"error": error}
	var manifest := {"schema": 1, "executable": "ffmpeg.exe", "archive_sha256": _digest, "executable_sha256": executable_hash, "archive_url": _config.archive_url, "checksum_url": _config.checksum_url, "provider": "Gyan.dev Windows release essentials (GPLv3)", "provider_page": "https://www.gyan.dev/ffmpeg/builds/", "source_page": "https://ffmpeg.org/download.html", "installed_at": Time.get_unix_time_from_system()}
	error = _write_file(_stage.path_join("install.json"), JSON.stringify(manifest, "\t").to_utf8_buffer())
	if not error.is_empty():
		return {"error": error}
	DirAccess.remove_absolute(archive)
	return {"error": "", "manifest": manifest}

func _hash_file(path: String) -> String:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return ""
	var hash_context := HashingContext.new()
	hash_context.start(HashingContext.HASH_SHA256)
	while file.get_position() < file.get_length():
		if _was_cancelled():
			file.close()
			return ""
		var bytes := file.get_buffer(1024 * 1024)
		if bytes.is_empty():
			file.close()
			return ""
		hash_context.update(bytes)
	file.close()
	return hash_context.finish().hex_encode()

func _is_executable_entry(path: String) -> bool:
	if path.contains("\\") or path.begins_with("/") or path.contains(":"):
		return false
	var parts := path.split("/")
	if parts.size() not in [2, 3] or "." in parts or ".." in parts:
		return false
	return parts[parts.size() - 2] == "bin" and parts[parts.size() - 1] == "ffmpeg.exe" and not parts[0].is_empty()

func _zip_index(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	var invalid := {"error": "FFmpeg download is not a supported ZIP archive.", "entries": []}
	if file == null or file.get_length() < 22:
		return invalid
	var length := file.get_length()
	var tail_start := maxi(0, length - 65557)
	file.seek(tail_start)
	var tail := file.get_buffer(length - tail_start)
	var end := -1
	for i in range(tail.size() - 22, -1, -1):
		if tail.decode_u32(i) == 0x06054b50 and i + 22 + tail.decode_u16(i + 20) == tail.size():
			end = i
			break
	if end < 0:
		return invalid
	var count := tail.decode_u16(end + 10)
	var central_size := tail.decode_u32(end + 12)
	var offset := tail.decode_u32(end + 16)
	if tail.decode_u16(end + 4) != 0 or tail.decode_u16(end + 6) != 0 or count == 65535 or central_size == 0xffffffff or offset == 0xffffffff or offset + central_size > tail_start + end:
		return invalid
	file.seek(offset)
	var entries: Array[Dictionary] = []
	for i in count:
		if file.get_position() + 46 > offset + central_size:
			return invalid
		var header := file.get_buffer(46)
		if header.size() != 46 or header.decode_u32(0) != 0x02014b50:
			return invalid
		var size := header.decode_u32(24)
		var name_length := header.decode_u16(28)
		var extra_length := header.decode_u16(30)
		var comment_length := header.decode_u16(32)
		if size == 0xffffffff or name_length == 0 or name_length > 4096 or file.get_position() + name_length + extra_length + comment_length > offset + central_size:
			return invalid
		var name := file.get_buffer(name_length).get_string_from_utf8()
		entries.append({"path": name, "size": size})
		file.seek(file.get_position() + extra_length + comment_length)
	file.close()
	return {"error": "", "entries": entries}

func _write_file(path: String, bytes: PackedByteArray) -> String:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return "Cannot write FFmpeg installation files: " + error_string(FileAccess.get_open_error())
	var success := file.store_buffer(bytes)
	file.close()
	return "" if success else "Cannot write FFmpeg installation files."

func _probe_executable(path: String) -> String:
	var version := _run_probe(path, ["-version"])
	if not version.error.is_empty():
		return version.error
	if not version.output.begins_with("ffmpeg version "):
		return "Downloaded executable did not identify itself as FFmpeg."
	var encoders := _run_probe(path, ["-hide_banner", "-encoders"])
	if not encoders.error.is_empty():
		return encoders.error
	if not "libx264rgb" in encoders.output:
		return "Downloaded FFmpeg does not support the recorder's libx264rgb encoder."
	return ""

func _run_probe(path: String, arguments: PackedStringArray) -> Dictionary:
	var process := OS.execute_with_pipe(path, arguments, false)
	if process.is_empty():
		return {"error": "Downloaded FFmpeg could not run on this computer.", "output": ""}
	var output := PackedByteArray()
	var deadline := Time.get_ticks_msec() + int(float(_config.probe_timeout) * 1000.0)
	var failure := ""
	while true:
		# Nonblocking reads avoid stalling the worker, including after pipe EOF.
		output.append_array(process.stdio.get_buffer(4096))
		process.stderr.get_buffer(4096)
		if _was_cancelled():
			failure = "FFmpeg download cancelled."
			break
		if output.size() > 1024 * 1024:
			failure = "FFmpeg verification produced too much output."
			break
		if not OS.is_process_running(process.pid):
			# Drain remaining stdout without querying a Windows pipe's length.
			while true:
				var remaining: PackedByteArray = process.stdio.get_buffer(4096)
				if remaining.is_empty():
					break
				output.append_array(remaining)
				if output.size() > 1024 * 1024:
					failure = "FFmpeg verification produced too much output."
					break
			break
		if Time.get_ticks_msec() >= deadline:
			failure = "FFmpeg verification timed out."
			break
		OS.delay_msec(10)
	if not failure.is_empty() and OS.is_process_running(process.pid):
		OS.kill(process.pid)
	elif failure.is_empty() and OS.get_process_exit_code(process.pid) != 0:
		failure = "Downloaded FFmpeg failed its recorder support check."
	process.stdio.close()
	process.stderr.close()
	return {"error": failure, "output": output.get_string_from_utf8()}

func _publish(_result: Dictionary) -> void:
	var destination: String = _config.root.path_join("build-" + _digest.substr(0, 16) + "-" + str(Time.get_ticks_usec()))
	var error := DirAccess.rename_absolute(_stage, destination)
	if error != OK:
		_finish("", "Cannot publish FFmpeg installation: " + error_string(error))
		return
	_stage = ""
	_cached_path = destination.path_join("ffmpeg.exe")
	_finish(_cached_path, "")

func cached_executable() -> String:
	if not platform_supported():
		return ""
	# Verify the binary on each lookup; same-second edits can retain its mtime.
	_cached_path = ""
	var root := ProjectSettings.globalize_path(cache_directory)
	var directory := DirAccess.open(root)
	if directory == null:
		return ""
	var builds: Array[Dictionary] = []
	for name in directory.get_directories():
		if not name.begins_with("build-"):
			continue
		var manifest_path := root.path_join(name).path_join("install.json")
		if not FileAccess.file_exists(manifest_path):
			continue
		var manifest: Variant = JSON.parse_string(FileAccess.get_file_as_string(manifest_path))
		if not manifest is Dictionary or manifest.get("schema") != 1 or manifest.get("executable") != "ffmpeg.exe":
			continue
		var expected: String = str(manifest.get("executable_sha256", ""))
		var installed_at: Variant = manifest.get("installed_at", 0.0)
		if _parse_checksum(expected).is_empty() or typeof(installed_at) not in [TYPE_FLOAT, TYPE_INT]:
			continue
		builds.append({"path": root.path_join(name).path_join("ffmpeg.exe"), "hash": expected, "time": float(installed_at)})
	builds.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.time > b.time)
	for build in builds:
		if FileAccess.file_exists(build.path) and FileAccess.get_sha256(build.path) == build.hash:
			_cached_path = build.path
			return _cached_path
	return ""

func _cleanup_stage() -> void:
	if _stage.is_empty():
		return
	# Only our fixed filenames are removed; no archive paths become disk paths.
	for name in ["archive.zip", "ffmpeg.exe", "LICENSE.txt", "README.txt", "install.json"]:
		if FileAccess.file_exists(_stage.path_join(name)):
			DirAccess.remove_absolute(_stage.path_join(name))
	DirAccess.remove_absolute(_stage)
	_stage = ""

func _finish(path: String, error: String) -> void:
	_release_request()
	_cleanup_stage()
	busy = false
	_phase = ""
	_set_status("FFmpeg is ready." if error.is_empty() else error)
	finished.emit(path, error)

func _exit_tree() -> void:
	_mutex.lock()
	_cancelled = true
	_mutex.unlock()
	_release_request()
	if _worker != null:
		_worker.wait_to_finish()
		_worker = null
	_cleanup_stage()
	busy = false
