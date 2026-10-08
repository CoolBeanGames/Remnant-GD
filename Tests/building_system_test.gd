extends Node

var failures: Array[String] = []
var world: Node3D
var player: CharacterBody3D
var controller: player_building
var pickup: player_pickup
var camera: Camera3D
var aim: raycaster


func _ready() -> void:
	_run.call_deferred()


func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error(message)


func _tick() -> void:
	await get_tree().physics_frame
	await get_tree().process_frame


func _colliders(node: Node) -> Array[CollisionObject3D]:
	var colliders: Array[CollisionObject3D] = []
	if node is CollisionObject3D:
		colliders.append(node)
	for child in node.get_children():
		colliders.append_array(_colliders(child))
	return colliders


func _check_restored(states: Array[Dictionary]) -> void:
	for state in states:
		var collider: CollisionObject3D = state["collider"]
		check(collider.collision_layer == state["layer"] and collider.collision_mask == state["mask"], "Releasing an item must restore every collider's authored layer and mask.")


func _press_build() -> void:
	Input.action_press("build")
	controller._physics_process(0.0)
	Input.action_release("build")
	await _tick()


func _run() -> void:
	world = Node3D.new()
	world.position = Vector3(10, 0, 5)
	world.rotation.y = 0.3
	get_tree().root.add_child(world)
	Blackboard.store_data("game_root", world)
	var floor_body := StaticBody3D.new()
	floor_body.add_to_group("Floor")
	var floor_shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(40, 0.5, 40)
	floor_shape.shape = box
	floor_body.add_child(floor_shape)
	floor_body.position.y = -0.25
	world.add_child(floor_body)
	player = load("res://Scenes/Player/player.tscn").instantiate()
	player.process_mode = Node.PROCESS_MODE_DISABLED
	# Disable controller updates while keeping the character body in Jolt's space.
	player.disable_mode = CollisionObject3D.DISABLE_MODE_KEEP_ACTIVE
	for node in ["Camera3D/RayCast3D", "Controllers/Player_Pickup", "Controllers/Player_Interact"]:
		player.get_node(node).debug_enabled = false
	world.add_child(player)
	controller = player.get_node("Controllers/Player_Building")
	pickup = player.get_node("Controllers/Player_Pickup")
	camera = player.get_node("Camera3D")
	aim = player.get_node("Camera3D/RayCast3D")
	camera.rotation.x = deg_to_rad(-35)
	var package: packed_buildable = load("res://Scenes/Building/packed_light.tscn").instantiate()
	world.add_child(package)
	# Exercise a model with a nested static collider, as in the imported crate.
	var nested := StaticBody3D.new()
	nested.collision_layer = 5
	nested.collision_mask = 3
	var nested_shape := CollisionShape3D.new()
	var nested_box := BoxShape3D.new()
	nested_box.size = Vector3.ONE
	nested_shape.shape = nested_box
	nested.add_child(nested_shape)
	package.add_child(nested)
	var collider_states: Array[Dictionary] = []
	for collider in _colliders(package):
		collider_states.append({"collider": collider, "layer": collider.collision_layer, "mask": collider.collision_mask})
	check(pickup.pickup_object(package), "Package should be picked up through the existing pickup API.")
	for collider in _colliders(package):
		check(collider.collision_layer == 0 and collider.collision_mask == 0, "Every held crate collider must be disabled, including imported static bodies.")
	check(pickup.get_held_collision_rids().size() == collider_states.size(), "Placement exclusions must contain all held colliders.")
	# Put the crate inside the player and update character motion: it must not push.
	package.global_position = player.global_position + Vector3.UP
	var player_position: Vector3 = player.global_position
	await _tick()
	player.velocity = Vector3.ZERO
	player.move_and_slide()
	check(Vector2(player.global_position.x, player.global_position.z).distance_to(Vector2(player_position.x, player_position.z)) < 0.001, "A held crate overlapping the player must not push them horizontally.")
	# A crate centered directly on the aim ray must not become the placement surface.
	package.global_position = camera.global_position - camera.global_basis.z
	controller._sync_package()
	await _tick()
	check(package.visible and not controller.is_building(), "Picking up a crate must keep it visible without a ghost.")
	check(not controller.try_build(), "Carrying mode must not place a building directly.")
	await _press_build()
	check(not package.visible and controller.is_building(), "The first B press must hide the crate and start its ghost.")
	controller._update_preview()
	check(controller.placement_valid, "Floor placement should be valid.")
	check(is_equal_approx(controller.preview.get_node("Anchor").global_position.y, 0.01), "A crate in the aim ray must be ignored so the light snaps to the floor.")
	# Prove the hierarchy exclusions still work even before layer changes reach physics.
	for state in collider_states:
		state["collider"].collision_layer = state["layer"]
		state["collider"].collision_mask = state["mask"]
	await _tick()
	controller._update_preview()
	check(controller.placement_valid and is_equal_approx(controller.preview.get_node("Anchor").global_position.y, 0.01), "Root and descendant RIDs must be excluded independently of collision layers.")
	for collider in _colliders(package):
		collider.collision_layer = 0
		collider.collision_mask = 0
	# Dropping and throwing must restore the authored collision settings.
	pickup.drop_object()
	controller._sync_package()
	check(package.visible and not controller.is_building(), "Dropping during placement must restore crate visibility and clear the ghost.")
	_check_restored(collider_states)
	pickup.pickup_object(package)
	controller._sync_package()
	controller.start_building()
	pickup.throw_object()
	controller._sync_package()
	check(package.visible and not controller.is_building(), "Throwing during placement must restore crate visibility and clear the ghost.")
	_check_restored(collider_states)
	pickup.pickup_object(package)
	controller._sync_package()
	await _press_build()
	check(pickup.held_collision_state.size() == collider_states.size(), "Repeated pickup must not accumulate collider snapshots.")
	check(controller.preview.visible, "A held package should show a ghost.")
	check(Buildings.buildables.is_empty(), "Ghosts must never register as buildings.")
	for light in controller.preview.find_children("*", "Light3D", true, false):
		check(not light.visible, "Ghost lights must not illuminate the world.")
	check(controller.preview.collision_layer == 0, "Ghosts must not collide or block raycasts.")
	var wheel := InputEventMouseButton.new()
	wheel.button_index = MOUSE_BUTTON_WHEEL_UP
	wheel.pressed = true
	controller._unhandled_input(wheel)
	controller._update_preview()
	check(is_equal_approx(controller.rotation_angle, deg_to_rad(15)), "Wheel rotation should use the configured step.")
	var ghost_pose: Transform3D = controller.preview.global_transform
	check(is_equal_approx(controller.preview.get_node("Anchor").global_position.y, 0.01), "The anchor should snap to the floor with a small clearance.")
	# E remains interaction only and must not place while the ghost is active.
	Input.action_press("confirm")
	await get_tree().process_frame
	Input.action_release("confirm")
	player.get_node("Controllers/Player_Interact")._process(0.0)
	check(Buildings.buildables.is_empty() and pickup.is_holding_object(), "E must not place or consume a package.")
	await _press_build()
	check(Buildings.buildables.size() == 1, "The second B press should place exactly one building.")
	check(not pickup.is_holding_object(), "Building must consume the held package.")
	check(not is_instance_valid(controller.preview), "Building must clear its ghost.")
	if Buildings.buildables.is_empty():
		_finish()
		return
	var building: buildable = Buildings.buildables[0]
	check(building.global_transform.is_equal_approx(ghost_pose), "Placed transform must match the preview under a transformed parent.")
	for light in building.find_children("*", "Light3D", true, false):
		check(light.visible, "Placed lights must be active.")
	check(Blackboard.read_data("buildables").size() == 1, "Blackboard must contain the live building array.")
	var records := Buildings.get_save_data()
	check(records.size() == 1 and records[0]["definition"] == "res://Data/Building/light.tres", "Save records must identify the building recipe.")
	check(JSON.parse_string(JSON.stringify(records)) is Array, "Save records must contain JSON-compatible values.")
	await _tick()
	camera.look_at(building.global_position + Vector3(0, 0.7, 0))
	aim.force_raycast_update()
	aim._update_looked_at()
	check(aim.get_looked_at() == building, "The shared raycaster must target placed buildings.")
	Input.action_press("unbuild")
	await get_tree().process_frame
	Input.action_release("unbuild")
	controller._physics_process(0.0)
	check(pickup.held_object is packed_buildable, "Q should return the building directly to a held package.")
	check(Buildings.buildables.is_empty(), "Unbuilding must remove the building from the live registry immediately.")
	check(Blackboard.read_data("buildables").is_empty(), "Blackboard must reflect unbuilding.")
	await _tick()
	camera.rotation.x = deg_to_rad(-35)
	controller._sync_package()
	check(pickup.held_object.visible and not controller.is_building(), "Unbuilding must return to visible carrying mode without automatically starting a ghost.")
	await _press_build()
	controller._update_preview()
	check(controller.placement_valid, "An unpacked item should be buildable again.")
	# A solid obstacle at the candidate position must prevent placement.
	var obstacle := StaticBody3D.new()
	var obstacle_shape := CollisionShape3D.new()
	var obstacle_box := BoxShape3D.new()
	obstacle_box.size = Vector3(0.2, 0.8, 0.2)
	obstacle_shape.shape = obstacle_box
	obstacle.add_child(obstacle_shape)
	world.add_child(obstacle)
	obstacle.global_position = controller.preview.global_position + Vector3(0.2, 0.4, 0)
	await _tick()
	controller._update_preview()
	check(not controller.placement_valid, "Obstructed placement must be rejected.")
	await _press_build()
	check(controller.is_building() and Buildings.buildables.is_empty(), "Invalid B placement must retain the ghost and allow retrying.")
	check(pickup.is_holding_object(), "Invalid placement must retain the package.")
	obstacle.queue_free()
	await _tick()
	# Walls, steep surfaces, and missing hits should not permit placement.
	var recipe: buildable_definition = pickup.held_object.definition
	check(not recipe.accepts_surface(floor_body, Vector3.RIGHT), "Vertical surfaces must be rejected for the floor light.")
	var wrong_surface := StaticBody3D.new()
	check(not recipe.accepts_surface(wrong_surface, Vector3.UP), "Untagged surfaces must be rejected.")
	wrong_surface.free()
	# Repacking/rebuilding must keep one registry entry, then external frees remove it.
	controller._update_preview()
	check(controller.try_build(), "A repacked light should place successfully again.")
	check(Buildings.buildables.size() == 1, "Repeated building must not duplicate registry entries.")
	if not Buildings.buildables.is_empty():
		Buildings.buildables[0].queue_free()
	await _tick()
	check(Buildings.buildables.is_empty(), "Externally freed buildings must unregister themselves.")
	# Use a nonzero anchor and a different rotation axis to exercise the recipe settings.
	var off_center_scene := PackedScene.new()
	var off_center_light: buildable = recipe.building_scene.instantiate()
	off_center_light.get_node("Anchor").position = Vector3(0.2, 0, 0.1)
	check(off_center_scene.pack(off_center_light) == OK, "The anchor fixture should pack successfully.")
	off_center_light.free()
	var custom_recipe: buildable_definition = recipe.duplicate()
	custom_recipe.building_scene = off_center_scene
	custom_recipe.rotation_axis = Vector3.FORWARD
	custom_recipe.rotation_step_degrees = 30.0
	var custom_package: packed_buildable = recipe.packed_scene.instantiate()
	custom_package.definition = custom_recipe
	world.add_child(custom_package)
	pickup.pickup_object(custom_package)
	controller._sync_package()
	controller.start_building()
	controller._unhandled_input(wheel)
	controller._update_preview()
	var local_anchor: Vector3 = controller.preview.get_node("Anchor").global_position
	var expected_anchor: Vector3 = camera.global_position - camera.global_basis.z * (camera.global_position.y / camera.global_basis.z.y)
	expected_anchor.y += custom_recipe.surface_offset
	check(local_anchor.is_equal_approx(expected_anchor), "A nonzero anchor must stay at the aimed floor point after rotation.")
	check(controller.preview.global_basis.is_equal_approx(Basis(Vector3.FORWARD, deg_to_rad(30))), "Rotation must respect each recipe's configured axis and step.")
	camera.rotation.x = deg_to_rad(60)
	controller._update_preview()
	check(not controller.placement_valid and not controller.preview.visible, "Missing hits must hide the preview and invalidate placement.")
	pickup.drop_object()
	controller._sync_package()
	check(not is_instance_valid(controller.preview), "Dropping a package must remove the ghost.")
	check(custom_package.visible, "A dropped crate must be visible again.")
	pickup.pickup_object(custom_package)
	controller._sync_package()
	controller.start_building()
	pickup.throw_object()
	controller._sync_package()
	check(not controller.is_building(), "Throwing a package must remove the ghost.")
	# Ordinary objects still use the same pickup/throw path.
	var prop := RigidBody3D.new()
	world.add_child(prop)
	check(pickup.pickup_object(prop), "Ordinary rigid props must remain pickable.")
	controller._sync_package()
	check(not controller.is_building(), "Ordinary props must not enter building mode.")
	pickup.throw_object()
	check(not pickup.is_holding_object() and prop.linear_velocity.length() > 0, "Ordinary prop throwing must still work.")
	_finish()


func _finish() -> void:
	world.queue_free()
	await get_tree().process_frame
	if failures.is_empty():
		print("Building system integration checks passed.")
	else:
		print("Building system integration failures: ", failures)
	get_tree().quit(0 if failures.is_empty() else 1)
