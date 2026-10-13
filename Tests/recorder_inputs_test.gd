extends Node
var failures: Array[String] = []
const Webcam = preload("res://addons/dev_toolkit/webcam_capture.gd")
func check(ok: bool, text: String) -> void:
	if not ok:
		failures.append(text)
		push_error(text)
func _ready() -> void:
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS, true)
	run.call_deferred()
func run() -> void:
	SaveGame.enabled = false
	SaveGame.saving_disabled = true
	var png := Image.create(48, 32, false, Image.FORMAT_RGB8).save_png_to_buffer()
	check(Webcam.png_size(png) == png.size() and Webcam.png_size(png.slice(0, png.size()-1)) == 0, "Camera parser preserves complete and fragmented PNG frames")
	check(Webcam.png_size(PackedByteArray([0,0,0,0,0,0,0,0])) == -1, "Camera parser rejects invalid streams")
	var color := ColorRect.new()
	color.color = Color(.1,.25,.35)
	color.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(color)
	var recorder := GameplayRecorder
	var camera := Webcam.new()
	camera.input_arguments = PackedStringArray(["-re", "-f", "lavfi", "-i", "testsrc=size=640x480:rate=15"])
	check(camera.start(recorder.find_ffmpeg()) == OK, "Actual FFmpeg camera transport starts")
	recorder.webcam = camera
	recorder.input_mode = true
	var deadline := Time.get_ticks_msec() + 10000
	while recorder.webcam_texture == null and Time.get_ticks_msec() < deadline:
		await get_tree().create_timer(.05).timeout
	check(recorder.webcam_texture != null and recorder.webcam_view.visible, "PNG camera pipe produces a live preview")
	check(is_equal_approx(recorder.webcam_view.size.x, get_viewport().get_visible_rect().size.x*.15) and is_equal_approx(recorder.webcam_view.size.y / recorder.webcam_view.size.x, .75), "Top-left preview occupies fifteen percent width without stretching 4:3 input")
	recorder.output_directory = "res://.godot/recorder_inputs_"+str(Time.get_ticks_usec())
	recorder.capture_fps = 20
	await RenderingServer.frame_post_draw
	recorder.start_recording()
	check(recorder.recording and recorder.mic_capture != null, "Recording installs an optional microphone capture")
	var mic_bus := AudioServer.get_bus_index(recorder.mic_bus)
	check(mic_bus > 0 and AudioServer.is_bus_mute(mic_bus), "Microphone routing is muted at speakers to prevent feedback")
	# Feed a known tone through the exact microphone capture/mix path. The
	# synthetic source does not claim to test a user's physical microphone.
	recorder.mic_player.stop()
	var tone := AudioStreamWAV.new()
	tone.mix_rate = 48000
	tone.format = AudioStreamWAV.FORMAT_16_BITS
	var data := PackedByteArray()
	data.resize(48000*2)
	for i in 48000:
		data.encode_s16(i*2, int(sin(TAU*440*i/48000.0)*6000))
	tone.data = data
	recorder.mic_player.stream = tone
	recorder.mic_player.play()
	await get_tree().create_timer(.7).timeout
	DirAccess.make_dir_recursive_absolute("res://Reports/IssueBatch/game")
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://Reports/IssueBatch/game/recorder.png")
	var event := InputEventKey.new()
	event.keycode = KEY_F7
	event.pressed = true
	recorder._input(event)
	check(not recorder.input_mode and recorder.webcam == null and recorder.mic_player == null and recorder.recording, "F7 stops camera/mic without interrupting the game recording")
	check(AudioServer.get_bus_index(recorder.mic_bus) == -1, "Input mode removes its own microphone bus")
	await get_tree().create_timer(.2).timeout
	recorder.stop_recording()
	deadline = Time.get_ticks_msec()+30000
	while recorder.finalizing and Time.get_ticks_msec()<deadline:
		await get_tree().create_timer(.05).timeout
	check(FileAccess.file_exists(recorder.last_path) and recorder.last_error.is_empty(), "Camera plus microphone recording finalizes without encoding errors")
	print("INPUT_RECORDING_PATH=",recorder.last_path)
	print("Recorder inputs / real PNG pipe / 4:3 preview / muted microphone mix / F7 cleanup: ", "PASS" if failures.is_empty() else str(failures))
	get_tree().quit(0 if failures.is_empty() else 1)
