extends Node
var failures: Array[String] = []
func check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
		push_error(message)
func tick() -> void:
	await get_tree().physics_frame
	await get_tree().process_frame
func _ready() -> void:
	run.call_deferred()
func run() -> void:
	SaveGame.save_path = "res://.godot/title_options_test.save"
	SaveGame.enabled = false
	SaveGame.saving_disabled = false
	SaveGame.profile = {"mulch_coins": 12, "mulch_upgrades": {}, "settings": {}}
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SaveGame.save_path))
	Blackboard._data.clear()
	Flags._flags.clear()
	var title: Node3D = load("res://Scenes/UI/title_screen.tscn").instantiate()
	add_child(title)
	check(not title.rows.get_node("Continue").visible and title.has_node("Background"), "Fresh title hides Continue and reserves a 3D background root")
	title._options()
	var options: options_menu = title.options
	check(options.is_open and get_tree().paused and options.widgets.has("music"), "Title opens the shared options with all audio sliders")
	options._slider_changed(50, "master")
	options._slider_changed(20, "sfx")
	options._slider_changed(35, "vocals")
	options._slider_changed(45, "music")
	options._slider_changed(2, "sensitivity")
	options._toggle_changed(true, "invert_x")
	options._toggle_changed(true, "invert_y")
	check(is_equal_approx(AudioServer.get_bus_volume_linear(AudioServer.get_bus_index("Master")), .5) and is_equal_approx(AudioServer.get_bus_volume_linear(AudioServer.get_bus_index("Vocals")), .35) and is_equal_approx(AudioServer.get_bus_volume_linear(AudioServer.get_bus_index("Music")), .45), "Independent volume controls apply to their buses")
	options.close()
	check(not get_tree().paused and SaveGame.profile.settings.invert_x and SaveGame.profile.settings.sensitivity == 2 and not SaveGame.has_run_save(), "Settings persist without creating a Continue save")
	var body := Node3D.new()
	var head := Node3D.new()
	body.add_child(head)
	add_child(body)
	var look: Node = load("res://Scripts/Player/player_look_controller.gd").new()
	look.Head = head
	look.Body = body
	body.add_child(look)
	look.set_process(false)
	look.mouse_input = Vector2(10, 10)
	look.look(1)
	check(look.target_rotation.x > 1.5 and look.target_rotation.y > 1.5, "Sensitivity and both inversion axes affect mouse look")
	body.queue_free()
	Settings.set_value("invert_x", false)
	Settings.set_value("invert_y", false)
	Settings.set_value("sensitivity", 1.0)
	Blackboard.store_data("spawned_items", [])
	Blackboard.store_data("score", 123)
	var pool := object_pool.new()
	pool.pooled_scene = load("res://Scenes/audio_player.tscn")
	pool.reset_method = &"reset"
	pool.blackboard_name = &"audio_pool"
	pool.register_with_blackboard = true
	add_child(pool)
	var level: level_sequence = load("res://Scenes/testing_level.tscn").instantiate()
	level.spawn_animation_enabled = false
	add_child(level)
	await tick()
	level.player.process_mode = Node.PROCESS_MODE_DISABLED
	var room: start_room = level.room
	check(AudioServer.is_bus_mute(AudioServer.get_bus_index("SFX")), "Room gates world SFX before the door opens")
	Settings.set_value("sfx", .3)
	check(AudioServer.is_bus_mute(AudioServer.get_bus_index("SFX")) and is_equal_approx(AudioServer.get_bus_volume_linear(AudioServer.get_bus_index("RoomSFX")), .3), "Changing volume keeps world muted and room sounds adjustable")
	room.door.interact()
	check(not AudioServer.is_bus_mute(AudioServer.get_bus_index("SFX")) and is_equal_approx(AudioServer.get_bus_volume_linear(AudioServer.get_bus_index("SFX")), .3), "Opening restores the configured SFX limit rather than full volume")
	var pause: pause_menu = level.get_node("PauseMenu")
	pause.open()
	pause._options()
	check(pause.options is options_menu and pause.options.is_open and not pause.main.has_node("Reset"), "Pause uses the same options and no longer exposes a main-menu Reset")
	pause.options.close()
	check(get_tree().paused and pause.is_open, "Leaving options retains the pause menu's pause ownership")
	pause.close()
	check(SaveGame.save_now() and SaveGame.has_run_save(), "A real run enables Continue")
	var before: Dictionary = SaveGame._read_payload()
	Settings.set_value("music", .25)
	Settings.flush()
	check(SaveGame.has_run_save() and SaveGame._read_payload().blackboard == before.blackboard, "Settings writes at title preserve existing run data")
	level.queue_free()
	title.queue_free()
	await tick()
	check(SaveGame.new_game() and not SaveGame.has_run_save() and SaveGame.profile.mulch_coins == 12 and is_equal_approx(float(SaveGame.profile.settings.music), .25), "New Game keeps coins and settings while clearing run data")
	check(SaveGame.reset_save() and not FileAccess.file_exists(SaveGame.save_path), "Deletion resolves and removes the actual save file")
	Settings.set_value("sfx", .4)
	Settings.flush()
	check(not FileAccess.file_exists(SaveGame.save_path) and not SaveGame.save_now(), "Pending settings and teardown cannot recreate a deleted save")
	for audio: audio_player in pool.active:
		audio.reset()
	await get_tree().create_timer(.5).timeout
	print("Title, shared options, audio limits, inversion, profile/new-game and verified save deletion: ", "PASS" if failures.is_empty() else str(failures))
	get_tree().quit(0 if failures.is_empty() else 1)
