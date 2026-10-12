extends CanvasLayer
## Native-resolution lossless game capture, mixed game audio, no simulation changes.
const Encoder = preload("movie_encoder.gd")
const FFmpegInstaller = preload("ffmpeg_installer.gd")
const WebcamCapture = preload("webcam_capture.gd")
@export var tools_context: NodePath
@export var toggle_key: Key = KEY_F6
@export var input_mode_key: Key = KEY_F7
@export_range(.05, .5, .01) var webcam_width_fraction: float = .15
@export_range(0, 2, .05) var microphone_gain: float = 1.0
@export var enabled: bool = true
var context: DevToolsContext
signal recording_started(folder: String)
signal recording_finished(path: String)
signal recording_failed(message: String)
@export var output_directory: String = "res://.recordings"
@export var ffmpeg_path: String = ""
@export var auto_download_ffmpeg: bool = true
@export var ffmpeg_cache_directory: String = "user://dev_toolkit/ffmpeg"
@export_range(1, 120) var capture_fps: int = 60
var recording: bool = false
var finalizing: bool = false
var pending_recording: bool = false
var pending_for_inputs: bool = false
var ffmpeg_installer: Node
var last_path: String = ""
var last_error: String = ""
var folder: String = ""
var encoder: RefCounted
var audio_capture: AudioEffectCapture
var master_bus: int = -1
var start_usec: int = 0
var frame_count: int = 0
var repeated_frames: int = 0
var session_fps: int = 60
var session_mix_rate: int = 48000
var dimensions: Vector2i
var last_rgb: PackedByteArray
var notice: Label
var notice_seconds: float = 0.0
var input_mode: bool = false
var webcam: RefCounted
var webcam_view: TextureRect
var webcam_texture: ImageTexture
var mic_player: AudioStreamPlayer
var mic_capture: AudioEffectCapture
var mic_bus: StringName
var mic_frames := PackedVector2Array()
var mic_frames_used: int = 0
var recording_used_inputs: bool = false

func _ready() -> void:
	context = DevToolsContext.resolve(self, tools_context)
	context.register_tool(&"recorder", self)
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 110
	notice = Label.new()
	notice.position = Vector2(16, 16)
	notice.add_theme_color_override("font_color", Color.WHITE)
	notice.add_theme_color_override("font_shadow_color", Color.BLACK)
	notice.add_theme_constant_override("shadow_offset_x", 2)
	notice.add_theme_constant_override("shadow_offset_y", 2)
	add_child(notice)
	webcam_view = TextureRect.new()
	webcam_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	webcam_view.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	webcam_view.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT
	webcam_view.hide()
	add_child(webcam_view)
	RenderingServer.frame_post_draw.connect(_capture_frame)

func _input(event: InputEvent) -> void:
	if not enabled or context.tool_open(&"reporter") or context.tool_open(&"console") or not event is InputEventKey or not event.pressed or event.echo:
		return
	if event.keycode == input_mode_key or event.physical_keycode == input_mode_key:
		get_viewport().set_input_as_handled()
		set_input_mode(not input_mode)
	elif event.keycode == toggle_key or event.physical_keycode == toggle_key:
		get_viewport().set_input_as_handled()
		if recording or pending_recording:
			stop_recording()
		else:
			start_recording()

func find_ffmpeg() -> String:
	if not ffmpeg_path.is_empty():
		return ffmpeg_path if FileAccess.file_exists(ffmpeg_path) else ""
	var binary := "ffmpeg.exe" if OS.get_name() == "Windows" else "ffmpeg"
	var separator := ";" if OS.get_name() == "Windows" else ":"
	for directory in OS.get_environment("PATH").split(separator):
		var path := directory.strip_edges().trim_prefix('"').trim_suffix('"').path_join(binary)
		if FileAccess.file_exists(path):
			return path
	if ffmpeg_installer != null:
		return ffmpeg_installer.cached_executable()
	var cache_reader := FFmpegInstaller.new()
	cache_reader.cache_directory = ffmpeg_cache_directory
	var cached: String = cache_reader.cached_executable()
	cache_reader.free()
	return cached

func _get_ffmpeg_installer() -> Node:
	if ffmpeg_installer == null:
		ffmpeg_installer = FFmpegInstaller.new()
		ffmpeg_installer.cache_directory = ffmpeg_cache_directory
		add_child(ffmpeg_installer)
	if not ffmpeg_installer.finished.is_connected(_ffmpeg_installed):
		ffmpeg_installer.finished.connect(_ffmpeg_installed)
		ffmpeg_installer.status_changed.connect(_ffmpeg_setup_status)
		ffmpeg_installer.progress_changed.connect(_ffmpeg_setup_progress)
	return ffmpeg_installer

func _ffmpeg_setup_status(message: String) -> void:
	if pending_recording:
		_notice(message + " / " + OS.get_keycode_string(input_mode_key if pending_for_inputs else toggle_key) + " TO CANCEL", 0)

func _ffmpeg_setup_progress(downloaded: int, total: int) -> void:
	var amount := "%.1f MB" % (float(downloaded) / 1048576.0)
	if total > 0:
		amount = "%d%%" % clampi(int(float(downloaded) * 100.0 / total), 0, 100)
	_ffmpeg_setup_status("DOWNLOADING FFMPEG / " + amount)

func _ffmpeg_installed(_path: String, error: String) -> void:
	if not pending_recording:
		return
	pending_recording = false
	if not error.is_empty():
		_fail("FFmpeg setup failed: " + error)
		return
	context.log_info("Verified FFmpeg setup completed", "recorder")
	if pending_for_inputs:
		pending_for_inputs = false
		set_input_mode(input_mode)
	else:
		start_recording()

func _download_ffmpeg(record_after: bool = true) -> String:
	if not auto_download_ffmpeg or not ffmpeg_path.is_empty():
		return _fail("FFmpeg not found. Set a valid ffmpeg_path or enable automatic download with that override empty.")
	pending_recording = true
	pending_for_inputs = not record_after
	last_error = ""
	context.log_info("Starting automatic FFmpeg setup", "recorder")
	var installer := _get_ffmpeg_installer()
	var error: String = installer.start_install()
	if not error.is_empty():
		if pending_recording:
			pending_recording = false
			return _fail(error)
		return last_error if not last_error.is_empty() else error
	return "Setting up FFmpeg; " + ("camera input" if pending_for_inputs else "recording") + " will start when ready. " + OS.get_keycode_string(input_mode_key if pending_for_inputs else toggle_key) + " to cancel."

func set_input_mode(value: bool) -> String:
	input_mode = value
	context.log_info("Webcam/microphone mode " + ("enabled" if value else "disabled"), "recorder")
	if not value:
		if pending_recording and pending_for_inputs:
			stop_recording()
		_stop_webcam()
		_stop_microphone()
		_notice("WEBCAM + MIC OFF / F7", 4)
		return "Webcam and microphone disabled."
	if OS.get_name() != "Windows" or DisplayServer.get_name() == "headless":
		input_mode = false
		return _fail("Webcam mode currently requires a rendered Windows game.")
	var executable := find_ffmpeg()
	if executable.is_empty():
		return _download_ffmpeg(false)
	_start_webcam(executable)
	if recording:
		_start_microphone()
	_notice("WEBCAM + MIC ON / F7 OFF / F6 RECORD", 6)
	return "Default webcam enabled. Default microphone joins the next recording."

func _start_webcam(executable: String) -> void:
	if webcam != null:
		return
	webcam = WebcamCapture.new()
	if webcam.start(executable) != OK:
		webcam = null
		_fail("Could not start webcam input.")

func _stop_webcam() -> void:
	if webcam != null:
		webcam.stop()
		webcam = null
	webcam_view.hide()
	notice.position.y = 16
	webcam_view.texture = null
	webcam_texture = null

func _start_microphone() -> void:
	if mic_player != null:
		return
	if not ProjectSettings.get_setting("audio/driver/enable_input", false):
		_notice("MIC INPUT DISABLED / ENABLE audio/driver/enable_input AND RESTART", 10)
		return
	# Capture before a private muted fader: no speaker feedback or game gain.
	mic_bus = StringName("DevRecorderMic_" + str(get_instance_id()))
	AudioServer.add_bus()
	var index := AudioServer.bus_count - 1
	AudioServer.set_bus_name(index, mic_bus)
	AudioServer.set_bus_mute(index, true)
	mic_capture = AudioEffectCapture.new()
	mic_capture.buffer_length = 2.0
	AudioServer.add_bus_effect(index, mic_capture)
	mic_player = AudioStreamPlayer.new()
	mic_player.stream = AudioStreamMicrophone.new()
	mic_player.bus = mic_bus
	add_child(mic_player)
	mic_player.play()
	mic_frames = PackedVector2Array()
	mic_frames_used = 0
	recording_used_inputs = true

func _stop_microphone() -> void:
	if mic_player != null:
		mic_player.stop()
		mic_player.queue_free()
		mic_player = null
	var index := AudioServer.get_bus_index(mic_bus)
	if index >= 0:
		AudioServer.remove_bus(index)
	mic_capture = null
	mic_frames = PackedVector2Array()
	mic_frames_used = 0

func _mix_microphone(samples: PackedVector2Array) -> PackedVector2Array:
	if mic_capture == null:
		return samples
	mic_frames.append_array(mic_capture.get_buffer(mic_capture.get_frames_available()))
	for i in samples.size():
		if mic_frames_used < mic_frames.size():
			samples[i] += mic_frames[mic_frames_used] * microphone_gain
			mic_frames_used += 1
	if mic_frames.size() - mic_frames_used > int(AudioServer.get_mix_rate()) * 2:
		mic_frames = mic_frames.slice(mic_frames.size() - int(AudioServer.get_mix_rate()))
		mic_frames_used = 0
	if mic_frames_used > 4096:
		mic_frames = mic_frames.slice(mic_frames_used)
		mic_frames_used = 0
	return samples

func _output_root() -> String:
	var directory := output_directory
	if directory.begins_with("res://") and not OS.has_feature("editor"):
		directory = "user://recordings"
	return ProjectSettings.globalize_path(directory)

func open_output_folder() -> String:
	var directory := folder if not folder.is_empty() else _output_root()
	var error := DirAccess.make_dir_recursive_absolute(directory)
	if error != OK:
		return "Cannot create recording folder: " + error_string(error)
	error = OS.shell_open(directory)
	return directory if error == OK else "Cannot open recording folder: " + error_string(error)

func start_recording() -> String:
	if pending_recording:
		return "FFmpeg setup is already in progress. " + OS.get_keycode_string(toggle_key) + " or record stop to cancel."
	if recording:
		return "Already recording."
	if finalizing:
		return "Still finalizing the previous recording."
	if DisplayServer.get_name() == "headless" or OS.has_feature("movie"):
		return _fail("Recording needs a normal rendered game window.")
	var executable := find_ffmpeg()
	if executable.is_empty():
		return _download_ffmpeg()
	dimensions = get_viewport().get_texture().get_image().get_size()
	folder = _output_root().path_join(Time.get_datetime_string_from_system().replace(":", "-") + "-" + str(Time.get_ticks_usec()))
	session_fps = capture_fps
	session_mix_rate = int(AudioServer.get_mix_rate())
	encoder = Encoder.new()
	var error: Error = encoder.start(executable, folder, dimensions, session_fps, session_mix_rate)
	if error != OK:
		encoder = null
		return _fail("Cannot start recorder: " + error_string(error))
	master_bus = AudioServer.get_bus_index("Master")
	audio_capture = AudioEffectCapture.new()
	audio_capture.buffer_length = 2.0
	AudioServer.add_bus_effect(master_bus, audio_capture)
	audio_capture.clear_buffer()
	recording_used_inputs = false
	if input_mode:
		_start_webcam(executable)
		_start_microphone()
	start_usec = Time.get_ticks_usec()
	frame_count = 0
	repeated_frames = 0
	last_rgb = PackedByteArray()
	last_error = ""
	recording = true
	context.log_info("Recording started: " + str(dimensions) + ", " + str(session_fps) + " FPS", "recorder")
	_notice("REC / " + OS.get_keycode_string(toggle_key) + " TO STOP", 0)
	recording_started.emit(folder)
	return "Recording at native resolution " + str(dimensions) + ", " + str(session_fps) + " FPS. " + OS.get_keycode_string(toggle_key) + " to finish."

func _audio_bytes() -> PackedByteArray:
	if audio_capture == null:
		return PackedByteArray()
	var available := audio_capture.get_frames_available()
	if available == 0:
		return PackedByteArray()
	var samples := audio_capture.get_buffer(available)
	# Master effects precede its fader; child buses already have their gains.
	var gain := 0.0 if AudioServer.is_bus_mute(master_bus) else AudioServer.get_bus_volume_linear(master_bus)
	if not is_equal_approx(gain, 1.0):
		for i in samples.size():
			samples[i] *= gain
	return _mix_microphone(samples).to_byte_array()

func _capture_frame() -> void:
	if not recording:
		return
	if not encoder.thread.is_alive():
		stop_recording("Encoder stopped unexpectedly.")
		return
	if audio_capture.get_discarded_frames() > 0:
		stop_recording("Audio capture overflowed. Reduce capture FPS or resolution.")
		return
	var audio := _audio_bytes()
	var expected := int(float(Time.get_ticks_usec() - start_usec) * session_fps / 1000000.0) + 1
	var repeats := expected - frame_count
	if repeats <= 0:
		if not audio.is_empty() and not encoder.enqueue(PackedByteArray(), 0, audio):
			stop_recording("Encoder queue filled. Reduce capture FPS or resolution.")
		return
	var image := get_viewport().get_texture().get_image()
	if image.get_size() != dimensions:
		stop_recording("Window resolution changed; recording ended at its original size.")
		return
	image.convert(Image.FORMAT_RGB8)
	var rgb := image.get_data()
	# Keep wall-clock timing under load by repeating the preceding frame.
	if repeats > 1 and not last_rgb.is_empty():
		if not encoder.enqueue(last_rgb, repeats - 1, PackedByteArray()):
			stop_recording("Encoder queue filled. Reduce capture FPS or resolution.")
			return
		repeated_frames += repeats - 1
		frame_count += repeats - 1
		repeats = 1
	if not encoder.enqueue(rgb, repeats, audio):
		stop_recording("Encoder queue filled. Reduce capture FPS or resolution.")
		return
	frame_count += repeats
	last_rgb = rgb

func stop_recording(reason: String = "") -> String:
	if pending_recording:
		pending_recording = false
		ffmpeg_installer.cancel()
		context.log_info("FFmpeg setup cancelled", "recorder")
		_notice("FFMPEG DOWNLOAD CANCELLED", 8)
		return "FFmpeg download cancelled."
	if not recording:
		return "Finalizing recording." if finalizing else "No recording is active."
	var audio := _audio_bytes()
	if not audio.is_empty() and not encoder.enqueue(PackedByteArray(), 0, audio) and reason.is_empty():
		reason = "Final audio buffer could not be queued."
	recording = false
	finalizing = true
	context.log_info("Recording stopped; finalizing" + (" / " + reason if not reason.is_empty() else ""), "recorder")
	last_error = reason
	_remove_audio_tap()
	_stop_microphone()
	encoder.finish()
	_notice("FINALIZING RECORDING...", 0)
	return "Finalizing recording in " + folder

func _remove_audio_tap() -> void:
	if audio_capture == null:
		return
	for i in range(AudioServer.get_bus_effect_count(master_bus) - 1, -1, -1):
		if AudioServer.get_bus_effect(master_bus, i) == audio_capture:
			AudioServer.remove_bus_effect(master_bus, i)
			break
	audio_capture = null

func _process(delta: float) -> void:
	if webcam != null:
		var png: PackedByteArray = webcam.take_frame()
		if not png.is_empty():
			var frame := Image.new()
			if frame.load_png_from_buffer(png) == OK:
				if webcam_texture == null or webcam_texture.get_size() != Vector2(frame.get_size()):
					webcam_texture = ImageTexture.create_from_image(frame)
				else:
					webcam_texture.update(frame)
				webcam_view.texture = webcam_texture
				webcam_view.show()
		if webcam_texture != null:
			var width := get_viewport().get_visible_rect().size.x * webcam_width_fraction
			webcam_view.size = Vector2(width, width * webcam_texture.get_height() / float(webcam_texture.get_width()))
			notice.position.y = webcam_view.size.y + 8
		if not webcam.thread.is_alive():
			var camera_error: String = webcam.error
			_stop_webcam()
			if not camera_error.is_empty():
				_notice(camera_error + " / MIC STILL AVAILABLE", 10)
				context.log_warning(camera_error, "recorder")
	if finalizing and encoder != null and not encoder.thread.is_alive():
		_finish_result()
	if notice_seconds > 0:
		notice_seconds -= delta
		if notice_seconds <= 0:
			notice.text = ""

func _finish_result() -> void:
	encoder.thread.wait_to_finish()
	var result: Dictionary = encoder.result
	finalizing = false
	encoder = null
	if result.ok:
		last_path = result.path
		context.log_info("Recording saved: " + last_path + " / " + str(result.frames) + " frames", "recorder")
		var manifest := FileAccess.open(folder.path_join("recording.json"), FileAccess.WRITE)
		if manifest != null:
			manifest.store_string(JSON.stringify({"file": "recording.mkv", "width": dimensions.x, "height": dimensions.y, "fps": session_fps, "frames": result.frames, "duration": float(result.frames) / session_fps, "repeated_frames": repeated_frames, "audio_mix_rate": session_mix_rate, "audio_samples": result.audio_samples, "video_codec": "h264_rgb_lossless", "audio_codec": "pcm_f32le", "warning": last_error, "webcam_mic_used": recording_used_inputs, "webcam_width_fraction": webcam_width_fraction}, "\t"))
			manifest.close()
		var message := "RECORDING SAVED / " + last_path
		if repeated_frames > 0:
			message += " / repeated frames: " + str(repeated_frames)
		if not last_error.is_empty():
			message += " / " + last_error
			recording_failed.emit(last_error)
		_notice(message, 12)
		recording_finished.emit(last_path)
	else:
		_fail((last_error + " / " if not last_error.is_empty() else "") + result.error)

func _notice(message: String, seconds: float) -> void:
	notice.text = message
	notice_seconds = seconds

func _fail(message: String) -> String:
	last_error = message
	if context != null:
		context.log_error(message, "recorder")
	_notice(message, 12)
	recording_failed.emit(message)
	return message

func status_text() -> String:
	if pending_recording:
		return "FFmpeg setup: " + str(ffmpeg_installer.status_text)
	if recording:
		return "Recording: " + folder
	if finalizing:
		return "Finalizing: " + folder
	return "Last recording: " + last_path + (" / " + last_error if not last_error.is_empty() else "")

func _exit_tree() -> void:
	if pending_recording:
		pending_recording = false
		ffmpeg_installer.cancel()
	if recording:
		stop_recording()
	_stop_webcam()
	_stop_microphone()
	if finalizing and encoder != null:
		_finish_result()
