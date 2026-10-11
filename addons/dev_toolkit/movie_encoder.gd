extends RefCounted
## Blocking encoder IO lives exclusively on a worker; queue is bounded.
var thread := Thread.new()
var mutex := Mutex.new()
var semaphore := Semaphore.new()
var queue: Array[Dictionary] = []
var ending: bool = false
var result: Dictionary = {}
var ffmpeg: String
var folder: String
var size: Vector2i
var fps: int
var mix_rate: int
var process: Dictionary
var max_queue: int = 8
var started: bool = false

func start(executable: String, directory: String, dimensions: Vector2i, rate: int, audio_rate: int) -> Error:
	if started:
		return ERR_ALREADY_IN_USE
	ffmpeg = executable
	folder = directory
	size = dimensions
	fps = rate
	mix_rate = audio_rate
	if not FileAccess.file_exists(ffmpeg) or size.x <= 0 or size.y <= 0 or fps <= 0 or mix_rate <= 0:
		return ERR_INVALID_PARAMETER
	var error := DirAccess.make_dir_recursive_absolute(folder)
	if error != OK:
		return error
	process = OS.execute_with_pipe(ffmpeg, ["-hide_banner", "-loglevel", "error", "-nostats", "-y", "-f", "rawvideo", "-pixel_format", "rgb24", "-video_size", str(size.x) + "x" + str(size.y), "-framerate", str(fps), "-i", "pipe:0", "-an", "-c:v", "libx264rgb", "-crf", "0", "-preset", "ultrafast", "-tune", "zerolatency", "-pix_fmt", "rgb24", "-threads", "2", folder.path_join("video.mkv")], true)
	if process.is_empty():
		return ERR_CANT_FORK
	error = thread.start(_work)
	if error != OK:
		process.stdio.close()
		OS.kill(process.pid)
	started = error == OK
	return error

func enqueue(rgb: PackedByteArray, repeats: int, audio: PackedByteArray) -> bool:
	if not started or repeats < 0 or (repeats > 0 and rgb.size() != size.x * size.y * 3) or audio.size() % 8 != 0:
		return false
	mutex.lock()
	if ending or not thread.is_alive() or queue.size() >= max_queue:
		mutex.unlock()
		return false
	queue.append({"rgb": rgb, "repeats": repeats, "audio": audio})
	mutex.unlock()
	semaphore.post()
	return true

func finish() -> void:
	mutex.lock()
	ending = true
	mutex.unlock()
	semaphore.post()

func _drain_errors() -> String:
	var stderr: FileAccess = process.stderr
	var count := stderr.get_length()
	return stderr.get_buffer(count).get_string_from_utf8() if count > 0 else ""

func _work() -> void:
	var audio := FileAccess.open(folder.path_join("audio.f32"), FileAccess.WRITE)
	var pipe: FileAccess = process.stdio
	var frames := 0
	var audio_samples := 0
	var error := ""
	if audio == null:
		error = "Cannot create audio file."
	while error.is_empty():
		semaphore.wait()
		mutex.lock()
		var packet: Dictionary = queue.pop_front() if not queue.is_empty() else {}
		var done := ending and queue.is_empty() and packet.is_empty()
		mutex.unlock()
		if done:
			break
		if packet.is_empty():
			continue
		if not audio.store_buffer(packet.audio):
			error = "Audio write failed."
			break
		audio_samples += int(packet.audio.size() / 8)
		for i in packet.repeats:
			if not pipe.store_buffer(packet.rgb):
				error = "Video encoder stopped accepting frames."
				break
			frames += 1
		error += _drain_errors()
	pipe.close()
	if audio != null:
		audio.close()
	var deadline := Time.get_ticks_msec() + 60000
	while OS.is_process_running(process.pid) and Time.get_ticks_msec() < deadline:
		OS.delay_msec(10)
	if OS.is_process_running(process.pid):
		OS.kill(process.pid)
		error += "Encoder did not finish within 60 seconds."
	else:
		if OS.get_process_exit_code(process.pid) != 0:
			error += "Encoder exited with an error."
	process.stderr.close()
	var final_path := folder.path_join("recording.mkv")
	if frames == 0:
		error += "No frames were recorded."
	if error.is_empty():
		# Copy video, preserve floating-point mix, and pad/trim the tail to its duration.
		var logs: Array = []
		var exit_code := OS.execute(ffmpeg, ["-hide_banner", "-loglevel", "error", "-nostats", "-y", "-i", folder.path_join("video.mkv"), "-f", "f32le", "-ar", str(mix_rate), "-ac", "2", "-i", folder.path_join("audio.f32"), "-map", "0:v:0", "-map", "1:a:0", "-c:v", "copy", "-c:a", "pcm_f32le", "-af", "apad", "-t", str(float(frames) / fps), final_path], logs, true)
		if exit_code != 0:
			error = "Finalizing audio/video failed: " + "\n".join(logs)
		else:
			DirAccess.remove_absolute(folder.path_join("video.mkv"))
			DirAccess.remove_absolute(folder.path_join("audio.f32"))
	result = {"ok": error.is_empty(), "path": final_path, "error": error, "frames": frames, "audio_samples": audio_samples}
