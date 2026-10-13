extends Node

@export var capture_directory: String = ""
var failures: Array[String] = []
var grinder_entries: int = 0

func check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
		push_error(message)

func tick(count: int = 3) -> void:
	for i in count:
		await get_tree().physics_frame
		await get_tree().process_frame

func _ready() -> void:
	if DisplayServer.get_name() != "headless":
		DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS, true)
	run.call_deferred()

func capture(name: String) -> void:
	if capture_directory.is_empty() or DisplayServer.get_name() == "headless":
		return
	DirAccess.make_dir_recursive_absolute(capture_directory)
	await tick()
	await RenderingServer.frame_post_draw
	check(get_viewport().get_texture().get_image().save_png(capture_directory + "/" + name + ".png") == OK, "Rendered screenshot saved")

func check_fill(title: Node3D, size: Vector2i) -> void:
	var window := get_tree().root
	window.mode = Window.MODE_WINDOWED
	window.size = size
	await tick(8)
	await RenderingServer.frame_post_draw
	var logical: Vector2 = window.get_visible_rect().size
	var rendered: Vector2i = window.get_texture().get_image().get_size()
	check(rendered == window.size, "3D framebuffer fills the actual resized window")
	check(title.get_node("UI/Screen").size.is_equal_approx(logical), "Title UI fills the logical viewport")
	check(is_equal_approx(logical.x / logical.y, float(window.size.x) / window.size.y), "Expanded viewport matches window aspect without letterboxing")
	Settings.set_value("vsync", not bool(Settings.values.vsync))
	Settings.restore()
	check(window.mode == Window.MODE_WINDOWED, "Settings refresh preserves a manually resized window")

func _on_grinder_body(body: Node3D) -> void:
	if body is mulch_pellet:
		grinder_entries += 1

func run() -> void:
	if DisplayServer.get_name() != "headless":
		check(get_tree().root.mode == Window.MODE_MAXIMIZED, "Normal Play starts maximized")
	SaveGame.enabled = false
	SaveGame.saving_disabled = false
	SaveGame.save_path = "user://title_mulcher_test.save"
	SaveGame.profile = {"mulch_coins": 0, "mulch_upgrades": {}, "settings": {}, "lifetime_score": 100000}
	Blackboard._data.clear()
	Flags._flags.clear()
	Progression.entries.clear()
	Progression.levels.clear()
	Progression.restored_levels = false
	var title: Node3D = load("res://Scenes/UI/title_screen.tscn").instantiate()
	add_child(title)
	await tick()
	var machine: AudioStreamPlayer3D = title.machine_audio
	check(is_instance_valid(machine) and machine.playing and machine.bus == &"SFX", "Authored title grinder starts through SFX")
	check(is_equal_approx(machine.volume_db, -6) and title.get_node("Camera3D").current, "Designer audio gain and camera remain intact")
	machine.stop()
	machine.finished.emit()
	check(machine.playing, "Finished machine clip restarts for continuous ambience")
	title._options()
	check(get_tree().paused and machine.can_process() and machine.playing, "Grinder remains audible while Options pauses the scene")
	Settings.set_value("sfx", .25)
	check(is_equal_approx(AudioServer.get_bus_volume_linear(AudioServer.get_bus_index("SFX")), .25), "Title ambience respects the shared SFX volume")
	title.options.close()
	if DisplayServer.get_name() != "headless":
		await check_fill(title, Vector2i(1440, 900))
		await capture("title_wide")
		await check_fill(title, Vector2i(900, 900))
		await capture("title_square")
		Settings.set_value("window_mode", 1)
		check(get_tree().root.mode == Window.MODE_FULLSCREEN, "Saved display control can still enter fullscreen")
		Settings.restore()
		check(get_tree().root.mode == Window.MODE_FULLSCREEN, "Restoring saved fullscreen is respected")
		Settings.set_value("window_mode", 0)
		get_tree().root.size = Vector2i(1440, 900)
	# Optional ambience remains safe on reusable title variants.
	machine.stop()
	var stream: AudioStream = machine.stream
	machine.stream = null
	title._start_machine_audio()
	check(not machine.playing, "Blank optional title sound is silent")
	machine.stream = stream
	title.machine_audio = null
	title._start_machine_audio()
	title.machine_audio = machine
	title._start_machine_audio()
	remove_child(title)
	check(not machine.playing, "Leaving title stops its machine sound")
	title.free()
	Settings.set_value("sfx", 1.0)
	var pool := object_pool.new()
	pool.pooled_scene = load("res://Scenes/audio_player.tscn")
	pool.reset_method = &"reset"
	pool.blackboard_name = &"audio_pool"
	pool.register_with_blackboard = true
	add_child(pool)
	Blackboard.store_data("spawned_items", [])
	Blackboard.store_data("score", 100000)
	Flags.set_flag("exited room", true)
	Flags.set_flag("grinder enabled", true)
	Flags.set_flag("computer enabled", true)
	var level: level_sequence = load("res://Scenes/testing_level.tscn").instantiate()
	level.spawn_animation_enabled = false
	add_child(level)
	await tick()
	level.player.process_mode = Node.PROCESS_MODE_DISABLED
	check(level.computer.buy(Progression.entries[&"buy_mulcher"]).is_empty(), "Real Store purchase installs the moved Mulcher")
	var station: mulcher_station = Mulch.station
	var mount: Node3D = level.grinder.get_node("MulcherMount")
	check(station.global_transform.is_equal_approx(mount.global_transform), "Installation uses the exact designer mount")
	var shape: CollisionShape3D = station.get_node("CollisionShape3D")
	var clearance := PhysicsShapeQueryParameters3D.new()
	var box: BoxShape3D = shape.shape.duplicate()
	box.size -= Vector3.ONE * .02
	clearance.shape = box
	clearance.transform = shape.global_transform
	clearance.collision_mask = 1
	clearance.exclude = [station.get_rid()]
	check(station.get_world_3d().direct_space_state.intersect_shape(clearance).is_empty(), "Mounted machine has no solid penetration")
	var output: Node3D = station.get_node("Output")
	var intake: CollisionShape3D = level.grinder.get_node("CollisionShape3D")
	var half: Vector3 = (intake.shape as BoxShape3D).size * .5
	check(output.global_position.z < intake.global_position.z - half.z - .12 and station.pellet_launch_velocity().z < 0, "Outlet clears the actual intake and ejects away from it")
	# Marker rotation, rather than mesh scale, controls ejection.
	output.rotation.y = PI / 2
	check(station.pellet_launch_velocity().x < -2 and is_zero_approx(station.pellet_launch_velocity().z), "Rotating Output redirects pellet launch")
	output.rotation.y = 0
	var pellets: Array[Node3D] = []
	Mulch.pellet_produced.connect(func(pellet: Node3D): pellets.append(pellet))
	level.grinder.body_entered.connect(_on_grinder_body)
	Mulch.points = 2400
	Mulch.contributions.assign([{"points": 2400.0, "score": 120.0}])
	Mulch._emit_pellets()
	check(pellets.size() == 24 and Mulch.points == 0, "A real batch emits twenty-four physical pellets")
	await tick(300)
	for pellet in pellets:
		check(is_instance_valid(pellet) and pellet.global_position.y > .08 and pellet.global_position.y < .5 and pellet.global_position.z < -4.3, "Pellet settles safely on the floor outside the grinder")
	check(grinder_entries == 0, "No batch pellet ever enters the grinder sensor")
	var camera: Camera3D = level.player.get_node("Camera3D")
	camera.global_position = Vector3(-3, 5.5, -10)
	camera.look_at(Vector3(.3, .1, -4.3))
	var inspection := OmniLight3D.new()
	inspection.position = Vector3(0, 5, -5)
	inspection.omni_range = 12
	inspection.light_energy = 3
	level.add_child(inspection)
	await capture("mulcher_pellets")
	level.queue_free()
	await tick()
	for audio: audio_player in pool.active:
		audio.reset()
	SaveGame.reset_save()
	print("Title ambience / resized display / actual Mulcher clearance / 24 physical pellet landings: ", "PASS" if failures.is_empty() else failures)
	get_tree().quit(0 if failures.is_empty() else 1)
