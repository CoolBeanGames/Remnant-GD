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
	_run.call_deferred()

func _run() -> void:
	var pool := object_pool.new()
	pool.pooled_scene = load("res://Scenes/audio_player.tscn")
	pool.reset_method = &"reset"
	pool.register_with_blackboard = true
	pool.blackboard_name = &"audio_pool"
	add_child(pool)
	Flags.remove_flag("exited room")
	var level: Node3D = load("res://Scenes/testing_level.tscn").instantiate()
	level.set("spawn_animation_enabled", false)
	add_child(level)
	var room: start_room = level.get_node("CSGCombiner3D")
	var door: start_room_door = level.get_node("doorway_animated")
	var player: CharacterBody3D = level.get_node("Player")
	player.process_mode = Node.PROCESS_MODE_DISABLED
	room.set_physics_process(false)
	var camera: Camera3D = player.get_node("Camera3D")
	var ray: raycaster = camera.get_node("RayCast3D")
	await tick()
	await tick()
	check(room.use_collision, "Start room has solid walls and floor.")
	check(door.prompt_component.prompts.entries[0].get_display_text() == "Open Door [E]", "Door uses reusable E interaction prompt.")
	camera.global_position = Vector3(4.75, 1.6, 14)
	camera.look_at(Vector3(4.75, 1.6, 11.9))
	ray.force_raycast_update()
	ray._update_looked_at()
	check(ray.get_looked_at() == door, "Existing interaction ray resolves the door through its mesh collision.")
	var closed_hit := room._ray(Vector3(4.75, 1.6, 14), Vector3(4.75, 1.6, 10))
	check(not closed_hit.is_empty() and door.is_ancestor_of(closed_hit.collider), "Closed door blocks the passage.")
	door.interact()
	check(door.is_open and room.exit_armed, "E opens the door and arms room exit tracking.")
	check(door.prompt_component.prompts.entries[0].text == "Close Door", "Door prompt updates when opened.")
	door.animation.advance(door.animation.current_animation_length)
	await tick()
	await tick()
	var open_hit := room._ray(Vector3(4.75, 1.6, 14), Vector3(4.75, 1.6, 10))
	check(open_hit.is_empty(), "Door animation moves physical collision clear of the CSG doorway cutout.")
	room._physics_process(1)
	check(not room.erased and not Flags.check_flag("exited room"), "Looking away inside cannot erase the room.")
	player.global_position = Vector3(4.75, .3, 9)
	camera.global_position = Vector3(4.75, 1.6, 9)
	camera.look_at(Vector3(4.75, 1.6, 16))
	await tick()
	check(room.is_room_visible(), "Visible room or door remains detectable from outside.")
	room._physics_process(1)
	check(not room.erased, "Room remains while the exited player looks back.")
	camera.look_at(Vector3(4.75, 1.6, 0))
	await tick()
	check(not room.is_room_visible(), "Room and door are unseen when the player turns away.")
	room._physics_process(.3)
	await tick()
	check(not is_instance_valid(room) and Flags.check_flag("exited room"), "Room is removed and exited room flag is set together.")
	check(is_instance_valid(door) and door.is_inside_tree(), "Door remains after the room is removed.")
	level.queue_free()
	await tick()
	# Darkness must count even while the room is inside the view frustum.
	Flags.remove_flag("exited room")
	level = load("res://Scenes/testing_level.tscn").instantiate()
	level.set("spawn_animation_enabled", false)
	add_child(level)
	room = level.get_node("CSGCombiner3D")
	door = level.get_node("doorway_animated")
	player = level.get_node("Player")
	player.process_mode = Node.PROCESS_MODE_DISABLED
	room.set_physics_process(false)
	camera = player.get_node("Camera3D")
	player.global_position = Vector3(4.75, .3, 9)
	camera.global_position = Vector3(4.75, 1.6, 9)
	camera.look_at(Vector3(4.75, 1.6, 16))
	for light in level.find_children("*", "Light3D", true, false):
		light.hide()
	var environment: Environment = level.get_node("WorldEnvironment").environment.duplicate()
	environment.ambient_light_color = Color.BLACK
	environment.ambient_light_energy = 0
	camera.environment = environment
	await tick()
	await tick()
	check(not room.is_room_visible(), "Unlit room can become unseen despite remaining in view.")
	room.exit_armed = true
	room._physics_process(.3)
	await tick()
	check(not is_instance_valid(room) and is_instance_valid(door), "Darkness removes only the room.")
	level.queue_free()
	await tick()
	# Existing saved flag prevents recreating the room, while keeping the door.
	level = load("res://Scenes/testing_level.tscn").instantiate()
	level.set("spawn_animation_enabled", false)
	add_child(level)
	await tick()
	check(not level.has_node("CSGCombiner3D") and level.has_node("doorway_animated"), "Previously exited room respects the flag on load and retains the door.")
	level.queue_free()
	await tick()
	Flags.remove_flag("exited room")
	for audio: audio_player in pool.active:
		audio.reset()
	await get_tree().create_timer(.1).timeout
	print("Start room door/visibility/flags: ", "PASS" if failures.is_empty() else str(failures))
	get_tree().quit(0 if failures.is_empty() else 1)
