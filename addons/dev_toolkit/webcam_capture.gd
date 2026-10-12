extends RefCounted
## Optional Windows camera input; blocking device IO never runs on the game thread.
var thread := Thread.new()
var mutex := Mutex.new()
var ending: bool = false
var process: Dictionary = {}
var latest_png := PackedByteArray()
var error: String = ""
var executable: String
var device_name: String = ""
var input_arguments: PackedStringArray = []

func start(path: String) -> Error:
	if thread.is_started():
		return ERR_ALREADY_IN_USE
	executable = path
	ending = false
	error = ""
	return thread.start(_work)

func take_frame() -> PackedByteArray:
	mutex.lock()
	var frame := latest_png
	latest_png = PackedByteArray()
	mutex.unlock()
	return frame

func stop() -> void:
	mutex.lock()
	ending = true
	var pid: int = int(process.get("pid", -1))
	mutex.unlock()
	if pid > 0 and OS.is_process_running(pid):
		OS.kill(pid)
	if thread.is_started():
		thread.wait_to_finish()
	process.clear()
	latest_png = PackedByteArray()

func _stopped() -> bool:
	mutex.lock()
	var stopped := ending
	mutex.unlock()
	return stopped

static func png_size(bytes: PackedByteArray) -> int:
	if bytes.size() < 8:
		return 0
	if bytes.slice(0, 8) != PackedByteArray([137, 80, 78, 71, 13, 10, 26, 10]):
		return -1
	var offset := 8
	while offset + 12 <= bytes.size():
		var length: int = (int(bytes[offset]) << 24) | (int(bytes[offset + 1]) << 16) | (int(bytes[offset + 2]) << 8) | int(bytes[offset + 3])
		if length > 16777216:
			return -1
		if offset + length + 12 > bytes.size():
			return 0
		if bytes.slice(offset + 4, offset + 8).get_string_from_ascii() == "IEND":
			return offset + length + 12
		offset += length + 12
	return 0

func _work() -> void:
	var args := input_arguments
	if args.is_empty():
		var output: Array = []
		OS.execute(executable, ["-hide_banner", "-list_devices", "true", "-f", "dshow", "-i", "dummy"], output, true)
		var pattern := RegEx.new()
		pattern.compile('"([^"\\r\\n]+)" \\(video\\)')
		var match := pattern.search("\n".join(output))
		if match == null:
			error = "No default webcam found. Check Windows camera access or close other camera apps."
			return
		device_name = match.get_string(1)
		args = PackedStringArray(["-f", "dshow", "-rtbufsize", "64M", "-i", "video=" + device_name])
	if _stopped():
		return
	var command := PackedStringArray(["-hide_banner", "-loglevel", "error", "-nostats"])
	command.append_array(args)
	command.append_array(["-an", "-vf", "scale='min(1280,iw)':-2", "-r", "30", "-c:v", "png", "-threads", "1", "-f", "image2pipe", "pipe:1"])
	mutex.lock()
	process = OS.execute_with_pipe(executable, command, true)
	mutex.unlock()
	if process.is_empty():
		error = "Cannot open webcam capture."
		return
	var buffer := PackedByteArray()
	while not _stopped():
		var incoming: PackedByteArray = process.stdio.get_buffer(4096)
		if incoming.is_empty():
			if not _stopped():
				error = "Webcam unavailable or disconnected. Check Windows camera permissions."
			break
		buffer.append_array(incoming)
		var length := png_size(buffer)
		while length > 0:
			mutex.lock()
			latest_png = buffer.slice(0, length)
			mutex.unlock()
			buffer = buffer.slice(length)
			length = png_size(buffer)
		if length < 0 or buffer.size() > 16777216:
			error = "Invalid webcam stream."
			break
	process.stdio.close()
	process.stderr.close()
	if OS.is_process_running(process.pid):
		OS.kill(process.pid)
