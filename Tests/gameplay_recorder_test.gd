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
	check(not GameplayRecorder.find_ffmpeg().is_empty(), "FFmpeg resolved on PATH")
	GameplayRecorder.output_directory = "res://.godot/recorder_test_" + str(Time.get_ticks_usec())
	if DisplayServer.get_name() == "headless":
		check(GameplayRecorder.start_recording().contains("rendered"), "Headless recording fails clearly")
		check(not GameplayRecorder.recording, "Failed start leaves recorder inactive")
	else:
		var color := ColorRect.new()
		color.color = Color(.15, .35, .6)
		color.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		add_child(color)
		var wav := AudioStreamWAV.new()
		wav.mix_rate = 48000
		wav.format = AudioStreamWAV.FORMAT_16_BITS
		var pcm := PackedByteArray()
		pcm.resize(48000 * 4)
		for i in 48000 * 2:
			var value := int(sin(TAU * 440 * float(i) / 48000) * 10000)
			pcm.encode_s16(i * 2, value)
		wav.data = pcm
		var tone := AudioStreamPlayer.new()
		tone.stream = wav
		add_child(tone)
		await get_tree().create_timer(.2).timeout
		await RenderingServer.frame_post_draw
		var effects := AudioServer.get_bus_effect_count(0)
		GameplayRecorder.start_recording()
		check(GameplayRecorder.recording, "Live recorder starts without restarting")
		tone.play()
		await get_tree().create_timer(.5).timeout
		get_tree().paused = true
		await get_tree().create_timer(.3).timeout
		get_tree().paused = false
		await get_tree().create_timer(.5).timeout
		GameplayRecorder.stop_recording()
		check(AudioServer.get_bus_effect_count(0) == effects, "Recording tap removed without changing existing effects")
		var deadline := Time.get_ticks_msec() + 30000
		while GameplayRecorder.finalizing and Time.get_ticks_msec() < deadline:
			await get_tree().create_timer(.05).timeout
		check(not GameplayRecorder.finalizing and FileAccess.file_exists(GameplayRecorder.last_path), "Capture finalizes playable audio/video")
		check(FileAccess.file_exists(GameplayRecorder.folder.path_join("recording.json")), "Timing/quality manifest is saved")
		check(GameplayRecorder.last_error.is_empty(), "Capture completes without overflow or encoder error")
		print("RECORDING_PATH=", GameplayRecorder.last_path)
		print("RECORDING_ERROR=", GameplayRecorder.last_error)
		tone.stop()
	print("Gameplay recorder availability, live A/V capture, pause and cleanup: ", "PASS" if failures.is_empty() else failures)
	get_tree().quit(0 if failures.is_empty() else 1)
