extends Node

var failures: Array[String] = []

func check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
		push_error(message)

func _ready() -> void:
	run.call_deferred()

func run() -> void:
	SaveGame.enabled = false
	SaveGame.saving_disabled = true
	SaveGame.save_path = "res://.godot/movie_encoder_test_" + str(Time.get_ticks_usec()) + ".save"
	var script: Script = load("res://Scripts/Debug/movie_encoder.gd")
	var encoder: RefCounted = script.new()
	var root_dir := ProjectSettings.globalize_path("res://.godot/movie_encoder_test_" + str(Time.get_ticks_usec()))
	DirAccess.make_dir_recursive_absolute(root_dir)
	var ffmpeg := OS.get_environment("REMNANT_FFMPEG")
	if ffmpeg.is_empty():
		var locations: Array = []
		OS.execute("where.exe" if OS.get_name() == "Windows" else "which", ["ffmpeg"], locations)
		ffmpeg = str(locations[0]).strip_edges().split("\n")[0].strip_edges() if not locations.is_empty() else ""
	var ffprobe := ffmpeg.get_base_dir().path_join("ffprobe.exe" if OS.get_name() == "Windows" else "ffprobe") if ffmpeg.is_absolute_path() else "ffprobe"
	var missing: RefCounted = script.new()
	check(missing.start(root_dir.path_join("missing_ffmpeg.exe"), root_dir.path_join("missing"), Vector2i(32, 24), 30, 48000) != OK, "Missing FFmpeg fails gracefully before recording")
	var start_error: Error = encoder.start(ffmpeg, root_dir, Vector2i(32, 24), 30, 48000)
	check(start_error == OK, "Installed FFmpeg starts a lossless recording")
	if start_error != OK:
		print("Gameplay recorder encoder: ", failures)
		get_tree().quit(1)
		return
	var expected_rgb := PackedByteArray()
	var expected_audio := PackedByteArray()
	var audio_position := 0
	var frame_count := 0
	for frame in range(8):
		var rgb := PackedByteArray()
		rgb.resize(32 * 24 * 3)
		for y in range(24):
			for x in range(32):
				var offset := (y * 32 + x) * 3
				rgb[offset] = (x * 7 + frame * 23) % 256
				rgb[offset + 1] = (y * 11 + frame * 19) % 256
				rgb[offset + 2] = (x * 3 + y * 5 + frame * 31) % 256
		var repeats := 1 + frame % 2
		var audio := PackedByteArray()
		audio.resize(1600 * repeats * 8)
		for sample in range(1600 * repeats):
			var phase := TAU * 440.0 * float(audio_position + sample) / 48000.0
			audio.encode_float(sample * 8, sin(phase) * .4)
			audio.encode_float(sample * 8 + 4, cos(phase) * .2)
		check(encoder.enqueue(rgb, repeats, audio), "Encoder accepts bounded RGB and audio packets")
		for repeat in range(repeats):
			expected_rgb.append_array(rgb)
		expected_audio.append_array(audio)
		audio_position += 1600 * repeats
		frame_count += repeats
	encoder.finish()
	var deadline := Time.get_ticks_msec() + 30000
	while encoder.thread.is_alive() and Time.get_ticks_msec() < deadline:
		await get_tree().create_timer(.01).timeout
	check(not encoder.thread.is_alive(), "Encoder completes without an indefinite pipe wait")
	if encoder.thread.is_alive():
		OS.kill(encoder.process.pid)
	encoder.thread.wait_to_finish()
	var result: Dictionary = encoder.result
	check(result.get("ok", false), "Lossless mux succeeds: " + str(result.get("error", "")))
	check(result.get("frames", 0) == frame_count and result.get("audio_samples", 0) == audio_position, "Encoder preserves submitted frame and stereo sample counts")
	var movie := str(result.get("path", ""))
	check(FileAccess.file_exists(movie), "Finished recording exists")
	if FileAccess.file_exists(movie):
		var output: Array = []
		var probe_exit := OS.execute(ffprobe, ["-v", "error", "-show_streams", "-of", "json", movie], output, true)
		check(probe_exit == 0, "FFprobe opens the finished recording")
		var metadata: Variant = JSON.parse_string(str(output[0])) if not output.is_empty() else null
		var video: Dictionary = {}
		var audio_stream: Dictionary = {}
		if metadata is Dictionary:
			for stream in metadata.get("streams", []):
				if stream.get("codec_type", "") == "video":
					video = stream
				if stream.get("codec_type", "") == "audio":
					audio_stream = stream
		check(video.get("codec_name", "") == "h264" and video.get("pix_fmt", "") == "gbrp" and video.get("width", 0) == 32 and video.get("height", 0) == 24 and video.get("r_frame_rate", "") == "30/1", "Video retains lossless RGB H.264, exact dimensions and frame rate")
		check(audio_stream.get("codec_name", "") == "pcm_f32le" and int(audio_stream.get("sample_rate", 0)) == 48000 and audio_stream.get("channels", 0) == 2, "Audio retains float PCM, stereo channels and mix rate")
		var decoded_video := root_dir.path_join("decoded.rgb")
		var decoded_audio := root_dir.path_join("decoded.f32")
		check(OS.execute(ffmpeg, ["-hide_banner", "-loglevel", "error", "-y", "-i", movie, "-map", "0:v:0", "-pix_fmt", "rgb24", "-f", "rawvideo", decoded_video]) == 0, "Lossless video decodes")
		check(OS.execute(ffmpeg, ["-hide_banner", "-loglevel", "error", "-y", "-i", movie, "-map", "0:a:0", "-c:a", "pcm_f32le", "-f", "f32le", decoded_audio]) == 0, "Uncompressed audio decodes")
		check(FileAccess.get_file_as_bytes(decoded_video) == expected_rgb, "Decoded RGB matches every submitted pixel exactly")
		check(FileAccess.get_file_as_bytes(decoded_audio) == expected_audio, "Decoded float PCM matches every submitted sound sample exactly")
		check(not FileAccess.file_exists(root_dir.path_join("video.mkv")) and not FileAccess.file_exists(root_dir.path_join("audio.f32")), "Successful finalization removes temporary streams")
	print("Gameplay recorder encoder, exact RGB/float PCM round-trip and missing dependency: ", "PASS" if failures.is_empty() else failures)
	get_tree().quit(0 if failures.is_empty() else 1)
