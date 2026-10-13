extends Node

@export var capture_directory: String = ""
var failures: Array[String] = []
var world: Node3D
var floor_body: StaticBody3D
var player: CharacterBody3D
var pickup: player_pickup
var placement: prop_placement
var camera: Camera3D
var display_camera: Camera3D
var target: steel_plate
var joined: Array[steel_plate] = []


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


func make_plate(pose: Transform3D) -> steel_plate:
	var plate: steel_plate = WorldState.spawn_item(load("res://Scenes/Actors/steel_plate.tscn"), world, pose)
	return plate


func aim(edge: Vector3) -> void:
	var point: Vector3 = target.to_global(edge * 1.04 + Vector3(0, 0, .06))
	camera.global_position = point + target.global_basis.z * 4.0
	camera.look_at(point, target.global_basis.y)


func press_build() -> void:
	var key := InputEventKey.new()
	key.physical_keycode = KEY_B
	key.pressed = true
	placement._unhandled_input(key)


func capture(entry_name: String) -> void:
	if capture_directory.is_empty() or DisplayServer.get_name() == "headless":
		return
	DirAccess.make_dir_recursive_absolute(capture_directory)
	display_camera.global_position = target.global_position + Vector3(6.0, 3.0, 12.0)
	display_camera.look_at(target.global_position)
	display_camera.make_current()
	await tick()
	await RenderingServer.frame_post_draw
	check(get_viewport().get_texture().get_image().save_png(capture_directory + "/" + entry_name + ".png") == OK, "Rendered plate image saved")
	camera.make_current()


func capture_store() -> void:
	if capture_directory.is_empty() or DisplayServer.get_name() == "headless":
		return
	Progression.entries.clear()
	Progression.levels.clear()
	Progression.restored_levels = true
	SaveGame.profile["lifetime_score"] = 30
	Blackboard.store_data("score", 30)
	var terminal: computer_terminal = load("res://Scenes/Computer/computer_terminal.tscn").instantiate()
	terminal.player = player
	terminal.position = Vector3(10, 0, 0)
	terminal.focus_seconds = 0
	world.add_child(terminal)
	terminal.interact()
	await tick(8)
	var ui: computer_ui = terminal.interface
	ui.tabs.current_tab = computer_entry.Tab.STORE
	var visible_titles: Array[String] = []
	for row in ui.tabs.get_child(computer_entry.Tab.STORE).get_node("List").get_children():
		if row.visible:
			visible_titles.append(row.get_node("Text/Title").text)
	check(visible_titles == ["LIGHT", "STEEL PLATE", "PUSH BROOM"], "At the computer's initial 30-score unlock only the three starter tools appear")
	await tick()
	await RenderingServer.frame_post_draw
	check(get_viewport().get_texture().get_image().save_png(capture_directory + "/starter_store.png") == OK, "Actual in-world Store image saved")
	terminal.close_interface(true)
	terminal.queue_free()
	await tick()


func run() -> void:
	SaveGame.enabled = false
	SaveGame.saving_disabled = false
	SaveGame.save_path = "user://plate_edges_test.save"
	Blackboard._data.clear()
	Blackboard.store_data("spawned_items", [])
	world = Node3D.new()
	add_child(world)
	Blackboard.store_data("game_root", world)
	floor_body = StaticBody3D.new()
	floor_body.name = "PlateFloor"
	world.add_child(floor_body)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(40, .2, 40)
	shape.shape = box
	floor_body.position.y = -.1
	floor_body.add_child(shape)
	var floor_mesh := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = box.size
	floor_mesh.mesh = mesh
	var floor_material := StandardMaterial3D.new()
	floor_material.albedo_color = Color(.12, .14, .15)
	floor_material.roughness = .9
	floor_mesh.material_override = floor_material
	floor_body.add_child(floor_mesh)
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color(.055, .06, .075)
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color(.65, .7, .8)
	environment.environment.ambient_light_energy = .8
	world.add_child(environment)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-40, -35, 0)
	sun.light_energy = 1.8
	sun.shadow_enabled = true
	world.add_child(sun)
	display_camera = Camera3D.new()
	world.add_child(display_camera)
	player = load("res://Scenes/Player/player.tscn").instantiate()
	player.process_mode = Node.PROCESS_MODE_DISABLED
	player.disable_mode = CollisionObject3D.DISABLE_MODE_KEEP_ACTIVE
	player.position = Vector3(15, 0, 15)
	world.add_child(player)
	pickup = player.get_node("Controllers/Player_Pickup")
	placement = player.get_node("Controllers/Prop_Placement")
	camera = player.get_node("Camera3D")
	camera.make_current()
	WorldState.begin(world, player)
	await tick()
	target = make_plate(Transform3D(Basis.IDENTITY, Vector3(0, 4, 0)))
	target.place_on(floor_body)
	for edge in steel_plate.EDGES:
		var plate: steel_plate = make_plate(Transform3D(Basis.IDENTITY, Vector3(12, 3, 0)))
		check(pickup.pickup_object(plate), "Pick up a real plate for edge " + str(edge))
		aim(edge)
		await tick()
		press_build()
		check(placement.is_building() and placement.placement_valid and placement.host == target, "Production ray/ghost snaps to edge " + str(edge))
		var expected: Vector3 = target.global_position + edge * (2.4 + target.edge_gap)
		check(placement.preview.global_position.is_equal_approx(expected) and placement.preview.global_basis.is_equal_approx(target.global_basis), "Joined sheets align edge-to-edge without overlap")
		press_build()
		check(plate.placed and plate.freeze and plate.support.get_ref() == target and not pickup.is_holding_object(), "Second B commits the original plate to the host")
		joined.append(plate)
	await capture("four_edges")
	await capture_store()
	var incoming: steel_plate = make_plate(Transform3D(Basis.IDENTITY, Vector3(12, 3, 0)))
	pickup.pickup_object(incoming)
	aim(Vector3.RIGHT)
	await tick()
	check(placement.start_building() and not placement.placement_valid and not placement.try_build(), "An occupied edge rejects a second overlapping sheet")
	placement.cancel_building()
	pickup.drop_object()
	incoming.queue_free()
	await tick()
	var old_pose: Transform3D = target.global_transform
	check(pickup.pickup_object(target) and joined.all(func(p: steel_plate) -> bool: return p.collision_layer == 0 and p.get_meta("carried_by_player", false)), "Picking up the host carries all four joins with collisions off")
	pickup._physics_process(1.0 / 60.0)
	check(joined.all(func(p: steel_plate) -> bool: return p.global_transform.is_equal_approx(target.global_transform * p.support_pose)), "Whole plate assembly follows its carried host")
	pickup.drop_object()
	target.global_transform = old_pose
	target.place_on(floor_body)
	for plate in joined:
		plate.sync_support_pose()
	check(joined.all(func(p: steel_plate) -> bool: return p.collision_layer == 1 and p.placed), "Dropping restores solid joined plates")
	WorldState.capture()
	check(SaveGame.save_now() and SaveGame.load_now(), "Plate joins pass through the real disk save")
	var records: Array = Blackboard.read_data("spawned_items").duplicate(true)
	var parent_id: String = target.get_meta("persistent_item_id")
	var child_ids: Array[String] = []
	for plate in joined:
		child_ids.append(plate.get_meta("persistent_item_id"))
		plate.queue_free()
	target.queue_free()
	await tick()
	WorldState.items.clear()
	WorldState.body_cache.clear()
	WorldState._restore(records)
	await tick()
	target = WorldState._actor(parent_id) as steel_plate
	joined.clear()
	for id in child_ids:
		var plate: steel_plate = WorldState._actor(id)
		joined.append(plate)
		check(plate.placed and plate.support.get_ref() == target and plate.global_transform.is_equal_approx(target.global_transform * plate.support_pose), "Continue restores each original edge connection")
	# Free the right edge, then use real wheel events to hinge its replacement.
	joined[0].queue_free()
	await tick()
	incoming = make_plate(Transform3D(Basis.IDENTITY, Vector3(12, 3, 0)))
	pickup.pickup_object(incoming)
	aim(Vector3.RIGHT)
	await tick()
	placement.start_building()
	var wheel := InputEventMouseButton.new()
	wheel.button_index = MOUSE_BUTTON_WHEEL_UP
	wheel.pressed = true
	for i in 3:
		placement._unhandled_input(wheel)
	check(placement.placement_valid and placement.preview.global_basis.is_equal_approx(target.global_basis * Basis(Vector3.UP, deg_to_rad(45))), "Wheel folds a side join by 45 degrees on its clean local axis")
	await capture("hinged_ghost")
	check(placement.try_build(), "The folded edge builds without colliding with its host")
	await capture("hinged_edge")
	# Collider dimensions/transforms and arbitrary host poses govern the join.
	var own_pose: Transform3D = target.global_transform
	target.global_transform = Transform3D(Basis.from_euler(Vector3(.2, .6, .1)), Vector3(-6, 6, 0))
	for edge in steel_plate.EDGES:
		var hit: Vector3 = target.to_global(edge * 1.04 + Vector3(0, 0, .06))
		var custom: Dictionary = incoming.get_placement_pose(target, hit, target.global_basis.z, Basis.IDENTITY)
		check(custom.get("valid", false) and (custom.transform as Transform3D).origin.is_equal_approx(target.to_global(edge * (2.4 + target.edge_gap))), "All four edges work on a translated and tilted host")
	check(incoming.get_placement_pose(target, target.to_global(Vector3(0, 0, .06)), target.global_basis.z, Basis.IDENTITY).is_empty(), "Centre aiming preserves ordinary surface anchoring")
	check(not target.get_placement_pose(incoming, incoming.to_global(Vector3(1.1, 0, .06)), Vector3.BACK, Basis.IDENTITY).get("valid", false), "Placement cannot create a circular support chain")
	for edge in [Vector3.RIGHT, Vector3.UP]:
		var axis: Vector3 = Vector3.UP if edge.x != 0 else Vector3.RIGHT
		for degrees in [45.0, 90.0]:
			var custom: Dictionary = incoming.get_placement_pose(target, target.to_global(edge * 1.04 + Vector3(0, 0, .06)), target.global_basis.z, Basis(axis, deg_to_rad(degrees)))
			check(custom.get("valid", false), "Side and top edges accept both 45 and 90 degree hinges")
	var twisted: Dictionary = incoming.get_placement_pose(target, target.to_global(Vector3(0, 1.04, .06)), target.global_basis.z, Basis(Vector3.UP, deg_to_rad(15)))
	check(not twisted.get("valid", false), "A twisted sheet cannot falsely claim a full aligned edge")
	var resized := BoxShape3D.new()
	resized.size = Vector3(1.6, 1.8, .12)
	incoming.plate_collision.shape = resized
	incoming.plate_collision.position = Vector3(.2, .1, 0)
	var resized_pose: Dictionary = incoming.get_placement_pose(target, target.to_global(Vector3(1.04, 0, .06)), target.global_basis.z, Basis.IDENTITY)
	var expected_center: Vector3 = target.to_global(Vector3(1.2 + .8 + target.edge_gap - .2, -.1, 0))
	check(resized_pose.get("valid", false) and (resized_pose.transform as Transform3D).origin.is_equal_approx(expected_center), "Snap follows resized collision geometry and an offset collider")
	target.global_transform = own_pose
	pickup.ray.looked_at = incoming
	var retrieve := InputEventKey.new()
	retrieve.physical_keycode = KEY_Q
	retrieve.pressed = false
	placement._unhandled_input(retrieve)
	check(pickup.held_object == incoming and not incoming.placed and target.placed, "Q detaches just the chosen plate through the normal retrieval system")
	pickup.drop_object()
	check(not incoming.freeze and incoming.collision_layer == 1, "Dropping the retrieved plate restores its normal physics")
	target.queue_free()
	await tick()
	for index in range(1, joined.size()):
		check(not joined[index].placed and not joined[index].freeze, "Deleting a host releases the remaining edge attachments")
	WorldState.tracking = false
	world.queue_free()
	await tick()
	SaveGame.reset_save()
	print("Plate edges / production B and wheel / occupancy / carry / disk restore / tilted host: ", "PASS" if failures.is_empty() else str(failures))
	get_tree().quit(0 if failures.is_empty() else 1)
