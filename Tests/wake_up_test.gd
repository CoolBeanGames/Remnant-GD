extends Node
var failures: Array[String] = []
var lines: Array[String] = []
func check(ok: bool, text: String) -> void:
	if not ok:
		failures.append(text)
		push_error(text)
func tick(count: int = 1) -> void:
	for i in count:
		await get_tree().physics_frame
		await get_tree().process_frame
func _ready() -> void:
	run.call_deferred()
func run() -> void:
	for key in ["exited room", "level enabled", "grinder enabled", "computer enabled", "dialogue first_spawn"]:
		Flags.set_flag(key, false)
	for key in ["player_transform", "player_position", "player_rotation", "player_camera_rotation", "respawn room active", "respawn_tallies"]:
		Blackboard.remove_data(key)
	Blackboard.store_data("spawned_items", [])
	Blackboard.store_data("score", 0)
	Blackboard.store_data("lever_pulls", 0)
	Blackboard.store_data("portal_inside", false)
	Blackboard.store_data("player_input_blocked", false)
	var pool := object_pool.new()
	pool.pooled_scene = load("res://Scenes/audio_player.tscn")
	pool.reset_method = &"reset"
	pool.register_with_blackboard = true
	pool.blackboard_name = &"audio_pool"
	add_child(pool)
	var level: level_sequence = load("res://Scenes/testing_level.tscn").instantiate()
	level.get_node("DoorPortal").purchase_required = false # Explicit free preview fixture.
	add_child(level)
	var wake: player_wake_up = level.player.get_node("Controllers/Wake_Up")
	var dialogue: dialogue_player = level.get_node("DialoguePlayer")
	dialogue.set_process(false)
	dialogue.line_started.connect(func(line: dialogue_line): lines.append(line.text))
	await tick()
	wake.set_process(false)
	check(wake.active and Blackboard.read_data("player_input_blocked") == true, "Initial spawn locks player control")
	check(wake.camera.position.y < .3 and absf(wake.camera.rotation.z) > 1.3, "Player starts lying close to the floor with a ninety-degree view")
	check(wake.camera.get_viewport().get_camera_3d() == wake.camera, "Wake and breathing use the active gameplay camera")
	check(wake.black.color.a > .95 and not level.player.get_node("Controllers/Player_Move_Controller").is_physics_processing(), "Initial fade is black and movement is suspended")
	check(Blackboard.read_data("respawn_tallies") == 1 and level.room.get_node("TallyMarks").count == 1, "First spawn creates one room tally")
	check(level.room.get_node("TallyMarks").global_position.x > level.player.global_position.x, "Tallies sit on the room's right wall")
	wake._process(1.0)
	check(wake.black.color.a < .2, "Vision fades in from black")
	wake._process(1.5)
	check(wake.camera.position.y > .6 and wake.camera.position.y < 1.4 and absf(wake.camera.rotation.z) > .1, "Getting up uses staged rising and body rotation")
	wake._process(3.7)
	check(absf(wake.camera.rotation.y) > .2 and Blackboard.read_data("player_input_blocked") == true, "Player looks around before control returns")
	wake._process(6.7)
	check(not wake.active and Blackboard.read_data("player_input_blocked") == false and wake.camera.transform.is_equal_approx(level.spawn_camera_pose), "Wake finishes at authored camera pose before handing over control")
	for i in 9:
		dialogue.advance()
	check(lines == ["what the hell?", "where am I?"], "First spawn plays the two editable sample lines")
	var breathing: camera_breathing = level.player.get_node("Controllers/Camera_Breathing")
	breathing.set_process(false)
	breathing._process(.5)
	check(breathing.is_physics_processing() == false and breathing.offset.length() > .005 and absf(breathing.roll_offset) > .0001, "Visible breathing bob and sway resume after waking")
	breathing.reset()
	var boundary: world_boundary = level.get_node("WorldBoundary")
	check(boundary.get_child_count() == 6, "Main world has six invisible boundary faces")
	for axis in 3:
		for direction in [-1, 1]:
			var vector := Vector3.ZERO
			vector[axis] = direction
			var query := PhysicsRayQueryParameters3D.create(boundary.global_position + vector * 490, boundary.global_position + vector * 510, 1)
			var hit: Dictionary = level.get_world_3d().direct_space_state.intersect_ray(query)
			check(not hit.is_empty() and hit.collider == boundary, "Boundary collides at five hundred metres in every direction")
	level.room._remove_room()
	await tick()
	check(level.get_node("DoorPortal").room.global_position.x >= 1500, "Portal destination is beyond the main-world boundary")
	lines.clear()
	level.respawn_player()
	wake.set_process(false)
	check(wake.active and Blackboard.read_data("respawn_tallies") == 2 and level.room.get_node("TallyMarks").count == 2, "Death rebuilds the room, adds a tally and restarts waking")
	wake._process(12.9)
	for i in 9:
		dialogue.advance()
	check(lines == ["I...", "I thought I died..."], "Respawn uses its own dialogue sequence")
	level.queue_free()
	await tick()
	level = load("res://Scenes/testing_level.tscn").instantiate()
	level.get_node("DoorPortal").purchase_required = false # Explicit free preview fixture.
	add_child(level)
	await tick()
	wake = level.player.get_node("Controllers/Wake_Up")
	wake.set_process(false)
	dialogue = level.get_node("DialoguePlayer")
	dialogue.set_process(false)
	check(wake.active and Blackboard.read_data("respawn_tallies") == 3 and level.room.get_node("TallyMarks").count == 3, "Loading again wakes in the room and adds the next persistent tally")
	wake._process(12.9)
	check(dialogue.current == null, "First-spawn dialogue does not replay on later loads")
	level.queue_free()
	await tick()
	for audio: audio_player in pool.active.duplicate():
		audio.stop()
	pool.queue_free()
	await tick(6)
	print("Wake cinematic, dialogue, breathing, tallies and boundary: ", "PASS" if failures.is_empty() else failures)
	get_tree().quit(0 if failures.is_empty() else 1)
