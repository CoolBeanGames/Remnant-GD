extends Node

var failures: Array[String] = []
var saved_count: int = 0
var failed_count: int = 0

func check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
		push_error(message)

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	run.call_deferred()

func run() -> void:
	var case_name: String = ""
	var save_path: String = ""
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("shutdown-case="):
			case_name = argument.trim_prefix("shutdown-case=")
		elif argument.begins_with("shutdown-save="):
			save_path = argument.trim_prefix("shutdown-save=")
	if not case_name.is_empty():
		await run_case(case_name, save_path)
		return
	SaveGame.enabled = false
	SaveGame.saving_disabled = true
	var root: String = ProjectSettings.globalize_path("res://")
	var directory: String = root.path_join(".godot/audio_shutdown_profiles/%d" % Time.get_ticks_usec())
	var previous_appdata: String = OS.get_environment("APPDATA")
	var had_appdata: bool = OS.has_environment("APPDATA")
	for mode in ["title", "paused", "saved", "reset", "retry"]:
		var profile: String = directory.path_join(mode)
		DirAccess.make_dir_recursive_absolute(profile)
		var saved_file: String = profile.path_join("shutdown.save")
		OS.set_environment("APPDATA", profile)
		var output: Array = []
		var result: int = OS.execute(OS.get_executable_path(), PackedStringArray(["--headless", "--path", root, "res://Tests/audio_shutdown_test.tscn", "--", "shutdown-case=" + mode, "shutdown-save=" + saved_file]), output, true)
		if had_appdata:
			OS.set_environment("APPDATA", previous_appdata)
		else:
			OS.unset_environment("APPDATA")
		var output_log: String = "\n".join(output)
		check(result == 0 and output_log.contains("Audio shutdown case PASS / " + mode), "Actual child Exit completed: " + mode)
		var unexpected: bool = false
		for line in output_log.split("\n"):
			if line.begins_with("ERROR:") or line.begins_with("SCRIPT ERROR:") or (line.begins_with("WARNING:") and not (mode == "retry" and line.begins_with("WARNING: Cannot write save:"))):
				unexpected = true
		check(not unexpected, "Child Exit released all audio without engine warnings: " + mode)
		if result != 0 or unexpected:
			print(output_log)
		if mode in ["saved", "retry"]:
			var file: FileAccess = FileAccess.open(saved_file, FileAccess.READ)
			var payload: Dictionary = file.get_var(false) if file != null else {}
			check(payload.get("blackboard", {}).get("shutdown_sentinel") == mode, "Exit preserved the run before teardown: " + mode)
		elif mode == "reset":
			check(not FileAccess.file_exists(saved_file) and not FileAccess.file_exists(saved_file + ".tmp"), "Reset remained deleted after complete child shutdown")
	print("Audio shutdown / paused title / saved run / reset / failed-save retry: ", "PASS" if failures.is_empty() else str(failures))
	get_tree().quit(0 if failures.is_empty() else 1)

func run_case(mode: String, path: String) -> void:
	SaveGame.save_path = path
	SaveGame.enabled = false
	SaveGame.saving_disabled = false
	var title: Node3D = load("res://Scenes/UI/title_screen.tscn").instantiate()
	add_child(title)
	var sources: Array[Node] = [AudioStreamPlayer.new(), AudioStreamPlayer2D.new(), AudioStreamPlayer3D.new()]
	var clip: AudioStream = load("res://Audio/SFX/machine_run.wav")
	for player in sources:
		player.process_mode = Node.PROCESS_MODE_ALWAYS
		player.set("stream", clip)
		add_child(player)
		player.call("play")
	for index in 4:
		await get_tree().physics_frame
		await get_tree().process_frame
	check(title.machine_audio.playing, "Title ambience remains audible before Exit")
	SaveGame.saved.connect(func(): saved_count += 1)
	SaveGame.save_failed.connect(func(_message: String): failed_count += 1)
	Settings.dirty_seconds = -1
	if mode == "paused":
		title._options()
		Engine.time_scale = .01
		check(get_tree().paused and title.machine_audio.playing, "Paused Options retains ambience before Exit")
	elif mode in ["saved", "reset", "retry"]:
		SaveGame.enabled = true
		Blackboard.store_data("shutdown_sentinel", mode)
	if mode == "retry":
		SaveGame.save_path = path.get_base_dir().path_join("missing/shutdown.save")
		SaveGame.exit_game()
		check(failed_count == 1 and not SaveGame.exit_started and not Audio.shutting_down and not get_tree().paused and title.machine_audio.playing, "Failed save leaves a live game and retryable Exit")
		SaveGame.save_path = path
	if mode == "reset":
		check(SaveGame.save_now(), "Reset case begins with a real saved run")
		SaveGame.reset_and_quit()
		SaveGame.reset_and_quit()
		check(saved_count == 1 and not FileAccess.file_exists(path), "Reset exit deletes once and performs no later save")
	else:
		SaveGame.exit_game()
		SaveGame.exit_game()
		check(saved_count == (1 if mode in ["saved", "retry"] else 0), "Duplicate Exit cannot save twice")
	check(SaveGame.exit_started and Audio.shutting_down and get_tree().paused, "Successful Exit pauses and starts shared audio shutdown")
	for player in sources:
		check(not player.get("playing") and player.get("stream") == null, "Shutdown stops and releases every player type")
	audio_global.set_spatial_active(sources[2] as AudioStreamPlayer3D, true)
	check(not sources[2].get("playing") and audio_global.play_global(clip) == null and audio_global.play_3d(clip, Vector3.ZERO) == null, "Shared helpers refuse new playback during shutdown")
	if not failures.is_empty():
		get_tree().quit(1)
		return
	print("Audio shutdown case PASS / " + mode)
