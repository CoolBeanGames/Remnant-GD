extends Node
## Offline transfer/integrity/cache coverage using an in-process loopback server.
var failures: Array[String] = []
var server := TCPServer.new()
var clients: Array[Dictionary] = []
var routes: Dictionary = {}
var requests: Dictionary = {}
var base_url: String
var fixture_root: String

class FixtureInstaller extends DevFFmpegInstaller:
	var reject_probe: bool = false
	func platform_supported() -> bool:
		return true
	func _probe_executable(path: String) -> String:
		if reject_probe:
			return "Fixture rejected executable"
		return "Fixture executable missing" if not FileAccess.file_exists(path) else ""

class UnsupportedInstaller extends DevFFmpegInstaller:
	func platform_supported() -> bool:
		return false

class RecorderFixtureInstaller extends Node:
	signal status_changed(message: String)
	signal progress_changed(downloaded: int, total: int)
	signal finished(path: String, error: String)
	var cache_path: String = ""
	var busy: bool = false
	var starts: int = 0
	func cached_executable() -> String:
		return cache_path
	func start_install() -> String:
		starts += 1
		busy = true
		status_changed.emit("Fixture download")
		progress_changed.emit(25, 100)
		return ""
	func cancel() -> void:
		busy = false
		finished.emit("", "Cancelled")
	func complete(path: String, error: String) -> void:
		busy = false
		cache_path = path if error.is_empty() else ""
		finished.emit(path, error)

func check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
		push_error(message)

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	run.call_deferred()

func _process(_delta: float) -> void:
	while server.is_connection_available():
		clients.append({"peer": server.take_connection(), "request": PackedByteArray(), "response": PackedByteArray(), "sent": 0, "header_size": 0, "next_send": 0, "slow": false, "slow_headers": false})
	for i in range(clients.size() - 1, -1, -1):
		var client: Dictionary = clients[i]
		var peer: StreamPeerTCP = client.peer
		peer.poll()
		if peer.get_status() != StreamPeerTCP.STATUS_CONNECTED:
			clients.remove_at(i)
			continue
		var available := peer.get_available_bytes()
		if available > 0:
			var data := peer.get_data(available)
			if data[0] == OK:
				client.request.append_array(data[1])
		if client.response.is_empty() and client.request.get_string_from_utf8().contains("\r\n\r\n"):
			var path: String = client.request.get_string_from_utf8().get_slice("\r\n", 0).get_slice(" ", 1)
			requests[path] = int(requests.get(path, 0)) + 1
			var route: Dictionary = routes.get(path, {"status": 404, "body": "missing".to_utf8_buffer()})
			var body: PackedByteArray = route.body
			var status := int(route.get("status", 200))
			var header := "HTTP/1.1 %d %s\r\nContent-Length: %d\r\nConnection: close\r\n\r\n" % [status, "OK" if status == 200 else "Failure", body.size()]
			client.response = header.to_utf8_buffer()
			client.header_size = client.response.size()
			client.response.append_array(body)
			client.slow = bool(route.get("slow", false))
			client.slow_headers = bool(route.get("slow_headers", false))
		if not client.response.is_empty() and Time.get_ticks_msec() >= int(client.next_send):
			var remaining: int = client.response.size() - client.sent
			var amount := mini(remaining, 16 if client.slow else 65536)
			# This route throttles the body; a separate route tests cancellation
			# while response headers are still arriving.
			if client.slow and not client.slow_headers and client.sent < client.header_size:
				amount = client.header_size - client.sent
			var sent := peer.put_partial_data(client.response.slice(client.sent, client.sent + amount))
			if sent[0] == OK:
				client.sent += int(sent[1])
			client.next_send = Time.get_ticks_msec() + (50 if client.slow else 0)
			if client.sent >= client.response.size():
				peer.disconnect_from_host()
				clients.remove_at(i)

func archive(name: String, paths: Array[String]) -> PackedByteArray:
	var file_path := fixture_root.path_join(name + ".zip")
	var packer := ZIPPacker.new()
	check(packer.open(file_path) == OK, "Fixture ZIP can be written")
	var payload := PackedByteArray()
	payload.resize(2048)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7723
	for i in payload.size():
		payload[i] = rng.randi_range(0, 255)
	for path in paths:
		packer.start_file(path)
		packer.write_file(payload)
		packer.close_file()
	packer.close()
	return FileAccess.get_file_as_bytes(file_path)

func digest(bytes: PackedByteArray) -> String:
	var hashing := HashingContext.new()
	hashing.start(HashingContext.HASH_SHA256)
	hashing.update(bytes)
	return hashing.finish().hex_encode()

func add_archive(route: String, bytes: PackedByteArray, expected_digest: String = "", slow: bool = false) -> void:
	routes[route + ".zip"] = {"body": bytes, "slow": slow}
	routes[route + ".sha256"] = {"body": (digest(bytes) if expected_digest.is_empty() else expected_digest).to_utf8_buffer()}

func installer(name: String, route: String) -> FixtureInstaller:
	var item := FixtureInstaller.new()
	item.cache_directory = fixture_root.path_join(name)
	item.archive_url = base_url + route + ".zip"
	item.checksum_url = base_url + route + ".sha256"
	item.request_timeout = 3.0
	add_child(item)
	return item

func finish(item: DevFFmpegInstaller, start: bool = true) -> Dictionary:
	var result: Dictionary = {"called": false, "path": "", "error": ""}
	var handler := func(path: String, error: String) -> void:
		result.called = true
		result.path = path
		result.error = error
	item.finished.connect(handler)
	if start:
		var error := item.start_install()
		if not error.is_empty():
			result.error = error
	var deadline := Time.get_ticks_msec() + 12000
	while item.busy and Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
	if item.busy:
		check(false, "Installer completes without an indefinite wait")
		item.cancel()
		while item.busy:
			await get_tree().process_frame
	item.finished.disconnect(handler)
	return result

func local_ffmpeg() -> String:
	var executable := OS.get_environment("REMNANT_FFMPEG")
	if not executable.is_empty():
		return executable
	var binary := "ffmpeg.exe" if OS.get_name() == "Windows" else "ffmpeg"
	for directory in OS.get_environment("PATH").split(";" if OS.get_name() == "Windows" else ":"):
		var candidate := directory.strip_edges().trim_prefix('"').trim_suffix('"').path_join(binary)
		if FileAccess.file_exists(candidate):
			return candidate
	return ""

func real_probe() -> void:
	var executable := local_ffmpeg()
	if executable.is_empty():
		print("FFmpeg installed-process probe skipped: no local encoder fixture.")
		return
	var item := DevFFmpegInstaller.new()
	item._config = {"probe_timeout": 10.0}
	add_child(item)
	var worker := Thread.new()
	check(worker.start(item._probe_executable.bind(executable)) == OK, "Real executable verification starts in a worker")
	while worker.is_alive():
		await get_tree().process_frame
	var error: String = worker.wait_to_finish()
	check(error.is_empty(), "Real FFmpeg version and libx264rgb probe succeeds: " + error)
	item.queue_free()

func recorder_integration() -> void:
	if DisplayServer.get_name() == "headless":
		return
	var previous_path := OS.get_environment("PATH")
	var executable := local_ffmpeg()
	if executable.is_empty():
		print("FFmpeg rendered auto-resume check skipped: no local encoder fixture.")
		return
	var context := DevToolsContext.new()
	context.adapter = DevToolsAdapter.new()
	add_child(context)
	var recorder: Node = load("res://addons/dev_toolkit/gameplay_recorder.gd").new()
	context.add_child(recorder)
	var setup := RecorderFixtureInstaller.new()
	recorder.add_child(setup)
	recorder.ffmpeg_installer = setup
	recorder.output_directory = fixture_root.path_join("recordings")
	recorder.capture_fps = 15
	OS.set_environment("PATH", "")
	var audio_effects := AudioServer.get_bus_effect_count(0)
	var start: String = recorder.start_recording()
	check(start.contains("Setting up") and recorder.pending_recording and not recorder.recording, "Missing FFmpeg begins setup before starting capture")
	check(AudioServer.get_bus_effect_count(0) == audio_effects and recorder.notice.text.contains("25%"), "Pending setup shows progress without adding an audio tap")
	recorder.start_recording()
	check(setup.starts == 1, "Repeated start requests do not duplicate the download")
	check(recorder.stop_recording().to_lower().contains("cancel") and not recorder.pending_recording and not setup.busy, "Stopping during setup cancels the transfer")
	setup.complete(executable, "")
	check(not recorder.recording, "A late completion after cancellation cannot start recording")
	setup.cache_path = ""
	recorder.start_recording()
	setup.complete("", "Fixture offline failure")
	check(not recorder.pending_recording and not recorder.recording and recorder.last_error.contains("offline failure"), "Failed setup leaves capture inactive with a useful error")
	var before := setup.starts
	recorder.auto_download_ffmpeg = false
	recorder.start_recording()
	check(setup.starts == before and not recorder.pending_recording, "Disabled automatic setup makes no request")
	recorder.auto_download_ffmpeg = true
	recorder.ffmpeg_path = fixture_root.path_join("missing-override.exe")
	recorder.start_recording()
	check(setup.starts == before and not recorder.pending_recording, "A missing explicit path is reported without overriding the user's configuration")
	recorder.ffmpeg_path = ""
	recorder.start_recording()
	setup.complete(executable, "")
	check(recorder.recording and not recorder.pending_recording, "Successful setup automatically resumes the requested recording")
	await get_tree().create_timer(.3).timeout
	recorder.stop_recording()
	var deadline := Time.get_ticks_msec() + 30000
	while recorder.finalizing and Time.get_ticks_msec() < deadline:
		await get_tree().create_timer(.02).timeout
	check(not recorder.finalizing and FileAccess.file_exists(recorder.last_path), "Automatically resumed recording finalizes a playable file")
	check(AudioServer.get_bus_effect_count(0) == audio_effects, "Automatic setup and capture restore the existing audio effects")
	before = setup.starts
	recorder.start_recording()
	check(recorder.recording and setup.starts == before, "The next recording uses the cached executable without setup")
	await get_tree().create_timer(.1).timeout
	recorder.stop_recording()
	while recorder.finalizing and Time.get_ticks_msec() < deadline:
		await get_tree().create_timer(.02).timeout
	OS.set_environment("PATH", previous_path)
	context.queue_free()
	await get_tree().process_frame

func run() -> void:
	var save_service := get_node_or_null("/root/SaveGame")
	if save_service != null:
		save_service.set("enabled", false)
		save_service.set("saving_disabled", true)
	fixture_root = ProjectSettings.globalize_path("res://.godot/ffmpeg_installer_test_" + str(Time.get_ticks_usec()))
	check(DirAccess.make_dir_recursive_absolute(fixture_root) == OK, "Fixture directory is writable")
	check(server.listen(0, "127.0.0.1") == OK, "Loopback fixture server starts")
	base_url = "http://127.0.0.1:" + str(server.get_local_port())
	var valid := archive("valid", ["ffmpeg-test/bin/ffmpeg.exe", "ffmpeg-test/LICENSE"])
	add_archive("/valid", valid)
	var item := installer("success", "/valid")
	var statuses: Array[String] = []
	var progress: Array[Vector2i] = []
	item.status_changed.connect(func(message: String) -> void: statuses.append(message))
	item.progress_changed.connect(func(downloaded: int, total: int) -> void: progress.append(Vector2i(downloaded, total)))
	var result: Dictionary = await finish(item)
	check(result.called and result.error.is_empty() and FileAccess.file_exists(result.path), "Verified ZIP installs an executable in the private cache")
	check(not statuses.is_empty(), "Installer reports status while preparing the dependency")
	check(item.cached_executable() == result.path, "Installed cache is discoverable without system PATH changes")
	check(str(result.path).begins_with(fixture_root), "Binary is extracted within the configured cache")
	var before := requests.duplicate()
	var installed_path: String = result.path
	var cache_reader := FixtureInstaller.new()
	cache_reader.cache_directory = item.cache_directory
	check(cache_reader.cached_executable() == installed_path and requests == before, "A fresh cache reader reuses the verified binary without downloading")
	cache_reader.free()
	check(FileAccess.file_exists(installed_path.get_base_dir().path_join("LICENSE.txt")), "Installation preserves the provider license beside the executable")
	add_archive("/failed-reinstall", valid, "0".repeat(64))
	item.archive_url = base_url + "/failed-reinstall.zip"
	item.checksum_url = base_url + "/failed-reinstall.sha256"
	result = await finish(item)
	check(not result.error.is_empty() and item.cached_executable() == installed_path, "A failed replacement preserves the previous verified cache")
	var corrupt := FileAccess.open(installed_path, FileAccess.WRITE)
	corrupt.store_string("damaged cache")
	corrupt.close()
	cache_reader = FixtureInstaller.new()
	cache_reader.cache_directory = item.cache_directory
	check(cache_reader.cached_executable().is_empty(), "A fresh cache reader rejects a binary whose checksum changed")
	cache_reader.free()
	item.queue_free()
	add_archive("/named", valid, digest(valid) + "  ffmpeg.zip\n")
	item = installer("named-checksum", "/named")
	result = await finish(item)
	check(result.error.is_empty(), "Provider checksum with its filename is supported")
	item.queue_free()
	add_archive("/wrong", valid, "0".repeat(64))
	item = installer("digest-failure", "/wrong")
	result = await finish(item)
	check(not result.error.is_empty() and item.cached_executable().is_empty(), "Digest mismatch cannot install a binary")
	item.archive_url = base_url + "/valid.zip"
	item.checksum_url = base_url + "/valid.sha256"
	result = await finish(item)
	check(result.error.is_empty() and not item.cached_executable().is_empty(), "Integrity failure leaves the installer retryable")
	item.queue_free()
	add_archive("/invalid", "not a zip archive".to_utf8_buffer())
	item = installer("invalid-zip", "/invalid")
	result = await finish(item)
	check(not result.error.is_empty() and item.cached_executable().is_empty(), "A matching digest does not make an invalid archive installable")
	item.queue_free()
	add_archive("/missing", archive("no_binary", ["ffmpeg-test/README"]))
	item = installer("no-executable", "/missing")
	result = await finish(item)
	check(not result.error.is_empty() and item.cached_executable().is_empty(), "An archive without the expected executable fails clearly")
	item.queue_free()
	add_archive("/ambiguous", archive("ambiguous", ["first/bin/ffmpeg.exe", "second/bin/ffmpeg.exe"]))
	item = installer("ambiguous-archive", "/ambiguous")
	result = await finish(item)
	check(not result.error.is_empty() and item.cached_executable().is_empty(), "An archive with multiple executable candidates is rejected")
	item.queue_free()
	add_archive("/unsafe", archive("unsafe", ["../escape/bin/ffmpeg.exe"]))
	item = installer("unsafe-archive", "/unsafe")
	result = await finish(item)
	check(not result.error.is_empty() and not FileAccess.file_exists(fixture_root.path_join("escape/bin/ffmpeg.exe")), "Traversal paths cannot escape the cache during extraction")
	item.queue_free()
	routes["/http.sha256"] = {"status": 503, "body": "unavailable".to_utf8_buffer()}
	item = installer("http-failure", "/http")
	result = await finish(item)
	check(not result.error.is_empty() and item.cached_executable().is_empty(), "HTTP failure is reported without producing a cache")
	item.queue_free()
	item = installer("probe-failure", "/valid")
	item.reject_probe = true
	result = await finish(item)
	check(not result.error.is_empty() and item.cached_executable().is_empty(), "Downloaded binaries must pass the executable validation hook")
	item.queue_free()
	item = installer("oversized", "/valid")
	item.max_download_bytes = 256
	result = await finish(item)
	check(not result.error.is_empty() and item.cached_executable().is_empty(), "Oversized archives are rejected by the configured download limit")
	item.queue_free()
	item = installer("oversized-executable", "/valid")
	item.max_executable_bytes = 512
	result = await finish(item)
	check(not result.error.is_empty() and item.cached_executable().is_empty(), "Executable decompression size is checked before extraction")
	item.queue_free()
	add_archive("/slow", valid, "", true)
	item = installer("cancelled", "/slow")
	check(item.start_install().is_empty(), "Slow installation can start asynchronously")
	await get_tree().create_timer(.2).timeout
	check(item.busy, "Download keeps the scene responsive while transfer is pending")
	item.cancel()
	result = await finish(item, false)
	check(not item.busy and item.cached_executable().is_empty(), "Cancelling a pending transfer installs no binary")
	item.archive_url = base_url + "/valid.zip"
	item.checksum_url = base_url + "/valid.sha256"
	result = await finish(item)
	check(result.error.is_empty(), "Cancelled transfers can be retried successfully")
	item.queue_free()
	add_archive("/slowheaders", valid, "", true)
	routes["/slowheaders.zip"].slow_headers = true
	item = installer("cancelled-headers", "/slowheaders")
	check(item.start_install().is_empty(), "A transfer with stalled headers starts asynchronously")
	await get_tree().create_timer(.1).timeout
	check(item.busy, "Partial response headers leave a cancellable pending request")
	item.cancel()
	result = await finish(item, false)
	check(not item.busy and item.cached_executable().is_empty(), "Cancelling while headers are incomplete cannot stall the main thread")
	item.queue_free()
	var unsupported := UnsupportedInstaller.new()
	unsupported.cache_directory = fixture_root.path_join("unsupported")
	add_child(unsupported)
	var unsupported_error := unsupported.start_install()
	check(not unsupported_error.is_empty() and not unsupported.busy, "Unsupported platforms fail before making a request")
	unsupported.queue_free()
	await real_probe()
	await recorder_integration()
	server.stop()
	for client in clients:
		client.peer.disconnect_from_host()
	clients.clear()
	await get_tree().process_frame
	print("FFmpeg installer offline transfer, integrity, cache, cancellation and retry: ", "PASS" if failures.is_empty() else failures)
	get_tree().quit(0 if failures.is_empty() else 1)
