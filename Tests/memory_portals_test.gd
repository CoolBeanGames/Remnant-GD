extends Node

var failures: Array[String] = []
var level: level_sequence
var portal: door_portal
var player: CharacterBody3D
var movement: Node
var capture_directory: String = ""

func check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
		push_error(message)

func tick(count: int = 3) -> void:
	for i in count:
		await get_tree().physics_frame
		await get_tree().process_frame

func bind_level() -> void:
	level = load("res://Scenes/testing_level.tscn").instantiate()
	level.spawn_animation_enabled = false
	add_child(level)
	player = level.player
	player.process_mode = Node.PROCESS_MODE_DISABLED
	player.disable_mode = CollisionObject3D.DISABLE_MODE_KEEP_ACTIVE
	movement = player.get_node("Controllers/Player_Move_Controller")
	portal = level.get_node("DoorPortal")
	Blackboard.store_data("player_input_blocked", false)
	await tick(6)

func walk_through(frame: Node3D, finished: Callable) -> void:
	if not portal.door.is_open:
		portal.door.interact()
		portal.door.animation.advance(portal.door.animation.current_animation_length)
	player.global_transform = frame.global_transform * Transform3D(Basis.IDENTITY, Vector3(0, -portal.source_offset.y + .04, 1.1))
	player.velocity = Vector3.ZERO
	movement.reset_platform_motion()
	portal.previous_camera_position = portal.camera.global_position
	Input.action_press("forward")
	for i in 180:
		await get_tree().physics_frame
		movement._physics_process(1.0 / 60.0)
		await get_tree().process_frame
		if finished.call():
			break
	Input.action_release("forward")
	player.velocity = Vector3.ZERO

func capture(entry_name: String) -> void:
	if capture_directory.is_empty() or DisplayServer.get_name() == "headless":
		return
	player.get_node("Camera3D/RayCast3D")._physics_process(0.0)
	await tick()
	await RenderingServer.frame_post_draw
	check(get_viewport().get_texture().get_image().save_png(capture_directory + "/" + entry_name + ".png") == OK, "Actual return-door frame saved")

func _ready() -> void:
	if DisplayServer.get_name() != "headless":
		DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS, true)
	run.call_deferred()

func run() -> void:
	SaveGame.reset_save()
	SaveGame.saving_disabled = false
	SaveGame.enabled = false
	SaveGame.save_path = "user://memory_portals_test.save"
	Blackboard._data.clear()
	var pool := object_pool.new()
	pool.pooled_scene = load("res://Scenes/audio_player.tscn")
	pool.reset_method = &"reset"
	pool.register_with_blackboard = true
	pool.blackboard_name = &"audio_pool"
	add_child(pool)
	Flags._flags.clear()
	Progression.entries.clear()
	Progression.levels.clear()
	Progression.restored_levels = false
	Blackboard.store_data("score", 100000)
	Blackboard.store_data("spawned_items", [])
	Flags.set_flag("exited room", true)
	Flags.set_flag("computer enabled", true)
	await bind_level()
	check(not portal.active and portal.room == null, "Production level waits for a memory purchase")
	var entry: computer_entry = Progression.entries[&"memory_1"]
	check(level.computer.buy(entry).is_empty() and portal.active_destination_id == &"apartment", "Production terminal opens the apartment memory")
	check(portal.cycle_destination(), "F9 explicitly previews another destination during a paid memory")
	await tick(12)
	check(portal.active_destination_id == &"warehouse" and portal.debug_override and portal.memory_id == &"memory_1" and Blackboard.read_data("active_memory_id") == "memory_1", "F9 preview preserves purchased ownership")
	check(not Progression.memory_purchase_error(Progression.entries[&"memory_2"]).is_empty(), "Preview does not bypass the story purchase lock")
	check(SaveGame.save_now(), "Save an active F9 preview while a paid memory remains unfinished")
	level.queue_free()
	await tick()
	check(SaveGame.load_now(), "Continue loads F9 preview state")
	Blackboard.store_data("audio_pool", pool)
	await bind_level()
	check(portal.debug_override and portal.memory_id == &"memory_1" and portal.active_destination_id == &"warehouse", "Continue preserves preview and purchased memory separately")
	check(portal.select_destination(&"apartment", true), "Debug preview can return to the owned destination")
	await tick(12)
	check(not portal.debug_override, "Returning to the owned destination restores normal completion behavior")
	var malformed := portal_destination.new()
	malformed.id = &"invalid_preview"
	malformed.scene_path = "res://Tests/invalid_portal_destination.tscn"
	portal.destinations.append(malformed)
	check(portal.select_destination(malformed.id, true), "Valid resource path schedules preview validation")
	await tick(6)
	check(portal.active_destination_id == &"apartment" and not portal.debug_override and Blackboard.read_data("portal_debug_preview") == false, "Malformed preview cannot alter owned memory completion behavior")
	portal.destinations.erase(malformed)
	portal.door.interact()
	portal.door.animation.advance(portal.door.animation.current_animation_length)
	await walk_through(portal.source_frame, func() -> bool: return portal.inside)
	check(portal.inside and player.collision_mask == portal_space.ROOM_LAYER, "Real capsule movement enters the paid memory")
	var initial_room: WeakRef = weakref(portal.room)
	await walk_through(portal.destination_frame, func() -> bool: return not portal.inside)
	check(portal.active and not portal.inside and initial_room.get_ref() == portal.room, "Real capsule can leave an unfinished memory while its portal remains open")
	check(not Progression.memory_purchase_error(Progression.entries[&"memory_2"]).is_empty(), "An unfinished return still prevents another memory purchase")
	await walk_through(portal.source_frame, func() -> bool: return portal.inside)
	check(portal.inside, "Player reenters the retained unfinished memory")
	await capture("unfinished")
	var actor: Node3D = WorldState.spawn_item(load("res://Scenes/test_object.tscn"), level, Transform3D(Basis.IDENTITY, portal.destination_frame.to_global(Vector3(.7, -.4, 1))), false, true)
	var body: RigidBody3D = WorldState._bodies(actor)[0]
	body.freeze = true
	var actor_id: String = str(actor.get_meta("persistent_item_id"))
	var saved_pose: Transform3D = player.global_transform
	check(SaveGame.save_now(), "Save while inside the memory succeeds")
	level.queue_free()
	await tick()
	check(SaveGame.load_now(), "Continue reloads the run")
	Blackboard.store_data("audio_pool", pool)
	await bind_level()
	check(portal.active and portal.inside and portal.memory_id == &"memory_1" and portal.active_destination_id == &"apartment", "Continue restores the active memory and room")
	check(player.global_position.distance_to(saved_pose.origin) < .01 and player.collision_mask == portal_space.ROOM_LAYER, "Continue preserves the actual inside player position and collision space")
	actor = WorldState._actor(actor_id)
	check(is_instance_valid(actor) and actor.get_meta("portal_inside", false), "Continue restores original saved cargo into the memory space")
	await walk_through(portal.destination_frame, func() -> bool: return not portal.inside)
	check(portal.active and not portal.inside, "Continue keeps unfinished memories freely returnable")
	await walk_through(portal.source_frame, func() -> bool: return portal.inside)
	Flags.set_flag("memory 1 complete", true)
	await tick()
	check(portal.active and portal.inside, "Completing a memory does not erase it while occupied")
	var restored_door: portal_return_door = portal.room.find_children("*", "portal_return_door", true, false)[0]
	check(restored_door.get_look_prompts().entries[0].text != "Complete Memory to Return", "Completion restores normal return-door prompts")
	await capture("complete")
	if not portal.door.is_open:
		restored_door.interact()
		portal.door.animation.advance(portal.door.animation.current_animation_length)
	var old_room: WeakRef = weakref(portal.room)
	await walk_through(portal.destination_frame, func() -> bool: return not portal.active)
	await tick()
	check(not portal.active and not portal.inside and portal.room == null and old_room.get_ref() == null, "Walking back physically closes and frees the memory portal")
	check(player.collision_mask == 1 and portal.camera.cull_mask == portal.original_cull_mask, "Return restores the player's workshop render and collision masks")
	check(is_instance_valid(actor) and not actor.get_meta("portal_inside", false) and WorldState._bodies(actor)[0].collision_mask == 1, "Return evacuates saved cargo before releasing the room")
	check(not portal.door.is_open or portal.door.close_requested, "Return requests the normal animated door closure")
	check(Progression.memory_purchase_error(Progression.entries[&"memory_2"]).is_empty(), "Saved completion allows another memory purchase")
	level.queue_free()
	for voice in pool.active.duplicate():
		voice.stop()
	await tick(6)
	pool.queue_free()
	await tick()
	SaveGame.reset_save()
	print("Memory portals / production purchase / real walking / inside save-continue / unfinished return / reentry / completed exit / cargo: ", "PASS" if failures.is_empty() else str(failures))
	get_tree().quit(0 if failures.is_empty() else 1)
