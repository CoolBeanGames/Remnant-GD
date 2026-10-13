extends Node

var failures: Array[String] = []
var capture_directory: String = ""
var camera: Camera3D

func _ready() -> void:
	run.call_deferred()

func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error(message)

func tick(count: int = 3) -> void:
	for index in count:
		await get_tree().physics_frame
		await get_tree().process_frame

func capture(view_name: String) -> void:
	if capture_directory.is_empty() or DisplayServer.get_name() == "headless":
		return
	# This fixture moves the camera without crossing the aperture. Keep the real
	# player flashlight in the camera's destination space, as crossing would.
	var beam: SpotLight3D = camera.get_node("SpotLight3D")
	beam.set_powered(true)
	portal_space.apply_actor(beam, camera.cull_mask == portal_space.ROOM_LAYER)
	await tick(5)
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(capture_directory)
	get_viewport().get_texture().get_image().save_png(capture_directory.path_join(view_name + ".png"))

func travel(body: CharacterBody3D, target: Vector3) -> bool:
	for index in 200:
		await get_tree().physics_frame
		var offset: Vector3 = target - body.global_position
		offset.y = 0
		if offset.length() < .12:
			return true
		body.velocity = offset.normalized() * 3 + Vector3.DOWN
		body.move_and_slide()
	print("Blocked route / ", body.global_position, " -> ", target)
	for index in body.get_slide_collision_count():
		print("Route collider / ", body.get_slide_collision(index).get_collider().get_path())
	return false

func run() -> void:
	SaveGame.enabled = false
	SaveGame.saving_disabled = true
	Blackboard.store_data("spawned_items", [])
	Blackboard.store_data("score", 0)
	Blackboard.store_data("player_input_blocked", false)
	for flag_name in ["exited room", "level enabled", "grinder enabled", "computer enabled"]:
		Flags.set_flag(flag_name, true)
	var audio_pool := object_pool.new()
	audio_pool.pooled_scene = load("res://Scenes/audio_player.tscn")
	audio_pool.reset_method = &"reset"
	audio_pool.register_with_blackboard = true
	audio_pool.blackboard_name = &"audio_pool"
	add_child(audio_pool)
	scene_warmup.begin()
	for index in 1200:
		scene_warmup.poll()
		if scene_warmup.ready() or not scene_warmup.failed_path.is_empty():
			break
		await get_tree().process_frame
	check(scene_warmup.ready() and scene_warmup.scenes.size() == 4, "Workshop and all three memory resources finish preloading")
	check(get_tree().get_nodes_in_group("story-portal").is_empty(), "Resource preloading never activates a room or portal")
	var level: level_sequence = load("res://Scenes/testing_level.tscn").instantiate()
	level.spawn_animation_enabled = false
	add_child(level)
	level.player.process_mode = Node.PROCESS_MODE_DISABLED
	level.player.disable_mode = CollisionObject3D.DISABLE_MODE_KEEP_ACTIVE
	camera = level.player.get_node("Camera3D")
	await tick()
	var zoom: player_view_zoom = level.player.get_node("Controllers/Player_View_Zoom")
	Blackboard.store_data("player_input_blocked", false)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	var normal_fov: float = zoom.normal_fov
	Input.action_press("throw")
	zoom._process(.02)
	check(camera.fov < normal_fov and camera.fov > zoom.zoom_fov, "RMB starts a smooth FOV transition instead of snapping")
	for index in 60:
		zoom._process(1.0 / 60)
	check(camera.fov < zoom.zoom_fov + .1, "Held RMB reaches inspection zoom")
	Input.action_release("throw")
	zoom._process(.02)
	check(camera.fov < normal_fov and camera.fov > zoom.zoom_fov, "Released RMB smoothly returns")
	for index in 90:
		zoom._process(1.0 / 60)
	check(absf(camera.fov - normal_fov) < .02, "Zoom smoothly returns to the original FOV")
	var portal: door_portal = level.get_node("DoorPortal")
	portal.set_process(false)
	var walker := CharacterBody3D.new()
	walker.collision_layer = portal_space.ROOM_LAYER
	walker.collision_mask = portal_space.ROOM_LAYER
	var capsule := CapsuleShape3D.new()
	capsule.radius = .35
	capsule.height = 1.8
	var shape := CollisionShape3D.new()
	shape.shape = capsule
	shape.position.y = .9
	walker.add_child(shape)
	add_child(walker)
	for destination in [&"apartment", &"warehouse", &"hospital"]:
		if not portal.active:
			portal.activate(true)
		else:
			portal.select_destination(destination, true)
		await tick(8)
		var room: Node3D = portal.room
		camera.cull_mask = portal_space.ROOM_LAYER
		camera.environment = room.environment
		if destination == &"apartment":
			check(room.get_node_or_null("Art/BedroomDesk") == null, "Office desk is absent from the apartment")
			walker.global_position = room.global_position + Vector3(1.76, .03, 2.6)
			for point in [Vector3(1.76, .03, .575), Vector3(4.4, .03, .575), Vector3(9, .03, .575)]:
				check(await travel(walker, room.global_position + point), "Full player capsule crosses the living room and bedroom route")
			var shelf: book_sleeve_library = room.get_node("Art/Bookshelf")
			check(shelf.sleeves.size() == 25 and shelf.spine_nodes.size() == 25, "All 25 books have independent editable sleeves")
			var sample := book_sleeve.new()
			sample.title = "TEST TITLE"
			sample.author = "TEST AUTHOR"
			shelf.apply_sleeve(shelf.spine_nodes[0], sample)
			check(shelf.spine_nodes[0].get_node("SleeveTitle").text == "TEST TITLE\nTEST AUTHOR", "Authored title and author appear on an actual book spine")
			var spine: MeshInstance3D = shelf.spine_nodes[0]
			camera.global_position = spine.to_global(spine.mesh.get_aabb().get_center() + Vector3(0, 0, .5))
			camera.look_at(spine.to_global(spine.mesh.get_aabb().get_center()))
			await capture("editable_book_sleeve")
			camera.global_position = room.global_position + Vector3(4.4, 1.65, 2.5)
			camera.look_at(room.global_position + Vector3(4.5, 1.1, -1.2))
			await capture("apartment_routes")
			shelf.apply_sleeve(shelf.spine_nodes[0], shelf.sleeves[0])
			camera.global_position = room.global_position + Vector3(8.3, 1.65, .7)
			camera.look_at(room.global_position + Vector3(10.3, .65, -1.5))
			await capture("bedroom_clearance")
		elif destination == &"warehouse":
			check(room.get_node("Art/HydraulicPress 1").scale.x > 1.6, "Production machines use larger world scale")
			check(room.get_node("Art/OfficeDesk 1").scale.is_equal_approx(Vector3.ONE * 1.2), "Office desk is 20 percent larger")
			camera.global_position = room.global_position + Vector3(0, 1.7, -12)
			camera.look_at(room.global_position + Vector3(0, 1.5, -18))
			await capture("warehouse_closed_shutter")
			camera.global_position = room.global_position + Vector3(8.4, 5.85, -11.5)
			camera.look_at(room.global_position + Vector3(6.4, 5.1, -13.5))
			await capture("warehouse_office")
		else:
			var door: hinged_world_door = room.get_node("Art/Ward door 1")
			check(not door.is_open and door.prompts.prompts.entries[0].text == "Open Door", "Ward doors start closed with E interaction prompts")
			var query := PhysicsRayQueryParameters3D.create(room.global_position + Vector3(-.7, 1, 9.4), room.global_position + Vector3(-3.2, 1, 9.4), portal_space.ROOM_LAYER)
			query.exclude = [walker.get_rid()]
			check(not door.get_world_3d().direct_space_state.intersect_ray(query).is_empty(), "Closed ward leaf blocks the doorway in portal collision space")
			door.travel_seconds = .02
			door.interact()
			await tick(8)
			check(door.is_open and door.prompts.prompts.entries[0].text == "Close Door", "Opening changes the ward prompt to Close")
			walker.global_position = room.global_position + Vector3(-.7, .03, 9.4)
			check(await travel(walker, room.global_position + Vector3(-3, .03, 9.4)), "Player capsule walks through the opened ward")
			check(room.get_node("Art/StaffDoor") is hinged_world_door and room.get_node("Art/ClosedExitDoor").locked, "Staff door is interactive and far exit uses the fixed main-door model")
			var staff: hinged_world_door = room.get_node("Art/StaffDoor")
			query.from = room.global_position + Vector3(5.8, 1, .1)
			query.to = room.global_position + Vector3(5.8, 1, 3)
			var staff_hit: Dictionary = staff.get_world_3d().direct_space_state.intersect_ray(query)
			check(not staff_hit.is_empty() and staff.is_ancestor_of(staff_hit.collider), "The closed staff door occupies the actual architectural opening")
			staff.travel_seconds = .02
			staff.interact()
			await tick(8)
			walker.global_position = room.global_position + Vector3(5.8, .03, .1)
			check(await travel(walker, room.global_position + Vector3(5.8, .03, 3)), "Bench clearance and opened staff door admit the full capsule")
			camera.global_position = room.global_position + Vector3(-.4, 1.65, 7.8)
			camera.look_at(room.global_position + Vector3(-2.8, 1, 9.4))
			await capture("hospital_open_ward")
			camera.global_position = room.global_position + Vector3(5.8, 1.65, .4)
			camera.look_at(room.global_position + Vector3(5.8, 1, 1.7))
			await capture("hospital_staff_door")
			camera.global_position = room.global_position + Vector3(0, 1.65, -10)
			camera.look_at(room.global_position + Vector3(0, 1.5, -12.9))
			await capture("hospital_locked_exit")
	walker.queue_free()
	camera.cull_mask = 1
	camera.environment = null
	camera.global_position = Vector3(50, 1.65, 50)
	camera.rotation = Vector3.ZERO
	var contrast_surface := MeshInstance3D.new()
	var contrast_quad := QuadMesh.new()
	contrast_quad.size = Vector2(20, 20)
	var white := StandardMaterial3D.new()
	white.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	white.albedo_color = Color.WHITE
	contrast_quad.material = white
	contrast_surface.mesh = contrast_quad
	level.add_child(contrast_surface)
	contrast_surface.global_position = camera.global_position - camera.global_basis.z * 3
	GrindCombo.record_item(1)
	await capture("combo_text_contrast")
	contrast_surface.queue_free()
	var debris: grind_debris_pool = level.grinder.debris
	var floor_body := StaticBody3D.new()
	var floor_shape := BoxShape3D.new()
	floor_shape.size = Vector3(8, .2, 8)
	var floor_collision := CollisionShape3D.new()
	floor_collision.shape = floor_shape
	floor_body.add_child(floor_collision)
	level.add_child(floor_body)
	floor_body.global_position = Vector3(80, -.1, 80)
	debris.burst(Vector3(80, .2, 80))
	await tick()
	check(debris.pool.active.size() == 6, "Grinding dispatches a bounded physical debris burst")
	var chip: grind_debris = debris.pool.active[0] as grind_debris
	var serial: int = chip.get_instance_id()
	check(not physics_items.is_processable(chip) and chip.collision_layer == 0, "Debris cannot be ground, targeted or block player movement")
	await tick(70)
	check(chip.global_position.y >= -.02, "Real debris bodies collide with the floor instead of passing through")
	for index in 100:
		debris.burst(Vector3(80, .2, 80))
	await tick()
	check(debris.pool.active.size() <= 64, "Simultaneous grind events respect the pool capacity")
	await tick(120)
	check(debris.pool.active.is_empty() and debris.pool.available.size() <= 64, "Expired particles return to an inactive bounded pool")
	debris.burst(Vector3(80, .2, 80))
	await tick()
	check(debris.pool.available.any(func(node: Node) -> bool: return node.get_instance_id() == serial) or debris.pool.active.any(func(node: Node) -> bool: return node.get_instance_id() == serial), "Expired physical bodies are reused")
	level.queue_free()
	await tick()
	for audio: audio_player in audio_pool.active.duplicate():
		audio.stop()
	scene_warmup.release()
	Audio.begin_shutdown()
	await get_tree().create_timer(.12).timeout
	print("October 13 issues / resource preload / smooth zoom / book sleeves / real capsule routes / interactive doors / pooled debris: ", "PASS" if failures.is_empty() else str(failures))
	get_tree().quit(0 if failures.is_empty() else 1)
