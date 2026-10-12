extends Node

var portal: door_portal
var level: level_sequence

func _ready() -> void:
	run.call_deferred()

func frames(count: int = 12) -> void:
	for index in count:
		await get_tree().process_frame

func capture(name: String, position: Vector3, target: Vector3) -> void:
	portal.camera.global_position = position
	portal.camera.look_at(target)
	portal.previous_camera_position = position
	await frames(30)
	await RenderingServer.frame_post_draw
	var image: Image = get_viewport().get_texture().get_image()
	var error: Error = image.save_png("res://Reports/PortalEnvironments/" + name + ".png")
	assert(error == OK)
	print("Captured engine view: ", name)

func run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("Visual test requires a real renderer.")
		get_tree().quit(1)
		return
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS, true)
	SaveGame.enabled = false
	SaveGame.saving_disabled = true
	Blackboard.store_data("spawned_items", [])
	Blackboard.store_data("portal_inside", false)
	Blackboard.store_data("portal_destination_id", "apartment")
	for key in ["player_transform", "player_position", "player_rotation", "player_camera_rotation"]:
		Blackboard.remove_data(key)
	Flags.set_flag("exited room", true)
	var pool := object_pool.new()
	pool.pooled_scene = load("res://Scenes/audio_player.tscn")
	pool.reset_method = &"reset"
	pool.register_with_blackboard = true
	pool.blackboard_name = &"audio_pool"
	add_child(pool)
	level = load("res://Scenes/testing_level.tscn").instantiate()
	level.spawn_animation_enabled = false
	level.get_node("DoorPortal").purchase_required = false # Explicit free F9/physics test mode.
	add_child(level)
	level.player.process_mode = Node.PROCESS_MODE_DISABLED
	await frames(24)
	portal = level.get_node("DoorPortal")
	portal.door.interact()
	portal.door.animation.advance(portal.door.animation.current_animation_length)
	DirAccess.make_dir_recursive_absolute("res://Reports/PortalEnvironments")
	for id in [&"apartment", &"warehouse", &"hospital"]:
		if id != portal.active_destination_id:
			assert(portal.select_destination(id))
			await frames(12)
		portal.inside = false
		portal._set_player_space()
		var outside: Vector3 = portal.source_frame.to_global(Vector3(0, 0, 2.2))
		await capture(str(id) + "_portal", outside, portal.source_frame.global_position)
		var direct: Transform3D = portal.mapping(portal.source_frame, portal.destination_frame) * portal.camera.global_transform
		portal.inside = true
		portal._set_player_space()
		portal.camera.global_transform = direct
		await frames(30)
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("res://Reports/PortalEnvironments/" + str(id) + "_matched.png")
		if id == &"apartment":
			await capture("apartment_interior", Vector3(1602.9, 1.65, 2.3), Vector3(1598.7, 1.2, -.1))
		elif id == &"warehouse":
			await capture("warehouse_interior", Vector3(1608.5, 1.65, 13), Vector3(1600, 2.5, -4))
			await capture("warehouse_catwalk", Vector3(1609.5, 5.8, -3.5), Vector3(1609.5, 5.0, -13.0))
		else:
			await capture("hospital_interior", Vector3(1600, 1.65, 9.8), Vector3(1600, 1.6, -8))
			await capture("hospital_ward", Vector3(1596.6, 1.65, 9.0), Vector3(1592.8, 1.0, 9.0))
			await capture("hospital_station", Vector3(1600, 1.65, 3.9), Vector3(1605.4, 1.15, 3.8))
		portal.inside = false
		portal._set_player_space()
	WorldState.tracking = false
	level.queue_free()
	await frames(10)
	print("Portal destinations rendered views: PASS")
	get_tree().quit()
