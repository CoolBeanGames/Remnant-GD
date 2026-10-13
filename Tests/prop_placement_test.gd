extends Node
var failures: Array[String] = []
func check(ok: bool, text: String) -> void:
	if not ok:
		failures.append(text)
		push_error(text)
func tick() -> void:
	await get_tree().physics_frame
	await get_tree().process_frame
func _ready() -> void:
	_run.call_deferred()
func _run() -> void:
	var world := Node3D.new()
	add_child(world)
	var floor_body := StaticBody3D.new()
	var collision := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(40, .2, 40)
	collision.shape = box
	floor_body.position.y = -.1
	floor_body.add_child(collision)
	world.add_child(floor_body)
	var player: CharacterBody3D = load("res://Scenes/Player/player.tscn").instantiate()
	player.process_mode = Node.PROCESS_MODE_DISABLED
	player.position = Vector3(12, 0, 12)
	world.add_child(player)
	var pickup: player_pickup = player.get_node("Controllers/Player_Pickup")
	var placement: prop_placement = player.get_node("Controllers/Prop_Placement")
	var camera: Camera3D = player.get_node("Camera3D")
	for id in ["fan", "light", "steel_plate"]:
		var prop: rotatable_item = load("res://Scenes/Actors/%s.tscn" % id).instantiate()
		prop.position = Vector3(10, 3, 0)
		world.add_child(prop)
		pickup.pickup_object(prop)
		prop.held_rotation = Basis.from_euler(Vector3(.3, .7, .2))
		for axis in 3:
			prop.rotation_axis = axis
			var before: Vector3 = prop.held_rotation[axis]
			prop.rotate_held(1)
			check(prop.held_rotation[axis].is_equal_approx(before), "Local-axis rotation must preserve its selected axis: " + id)
		var carried_angle := Basis.from_euler(Vector3(.7, .4, -.6))
		prop.held_rotation = carried_angle
		prop.rotation_axis = 2
		camera.global_position = Vector3(0, 3, 3)
		camera.look_at(Vector3.ZERO)
		await tick()
		check(placement.start_building() and placement.placement_valid and not prop.visible, "B must create a valid floor ghost: " + id)
		check(prop.held_rotation.is_equal_approx(Basis.IDENTITY) and prop.rotation_axis == 1, "Ghost starts from its bottom anchor and Y rotation axis: " + id)
		check(placement.preview.global_basis.y.is_equal_approx(Vector3.UP), "Bottom anchor aligns to the floor: " + id)
		prop.rotate_held(1)
		placement.cancel_building()
		check(prop.held_rotation.is_equal_approx(carried_angle) and prop.rotation_axis == 2, "Cancel restores the exact carried angle and rotation axis: " + id)
		check(prop.visible and pickup.held_object == prop, "F cancel restores the held prop.")
		placement.start_building()
		check(placement.try_build() and prop.placed and prop.freeze and not pickup.is_holding_object(), "Placement fixes the original prop to its support without a crate.")
		var pose: Transform3D = prop.global_transform
		floor_body.position.x += 1
		prop._physics_process(0)
		check(prop.global_position.is_equal_approx(pose.origin + Vector3.RIGHT), "Placed props follow moving supports.")
		pickup.ray.looked_at = prop
		var retrieve := InputEventKey.new()
		retrieve.physical_keycode = KEY_Q
		retrieve.pressed = false
		placement._unhandled_input(retrieve)
		check(pickup.held_object == prop and not prop.placed and not is_instance_valid(prop.support), "Q retrieves the placed prop without a crate.")
		pickup.drop_object()
		check(not prop.freeze, "Dropping a retrieved prop restores normal physics.")
		for surface in ["wall", "ceiling"]:
			var target := StaticBody3D.new()
			var target_collision := CollisionShape3D.new()
			var target_box := BoxShape3D.new()
			target_box.size = Vector3(6, 6, .2) if surface == "wall" else Vector3(6, .2, 6)
			target_collision.shape = target_box
			target.add_child(target_collision)
			target.position = Vector3(-10, 2, -.1) if surface == "wall" else Vector3(-10, 4, 0)
			world.add_child(target)
			pickup.pickup_object(prop)
			prop.held_rotation = Basis.IDENTITY
			camera.global_position = Vector3(-10, 2, 3) if surface == "wall" else Vector3(-10, 2, 0)
			camera.look_at(Vector3(-10, 2, 0) if surface == "wall" else Vector3(-10, 4, 0), Vector3.UP if surface == "wall" else Vector3.FORWARD)
			await tick()
			check(placement.start_building() and placement.placement_valid and placement.host == target, "Any-surface ghost must accept " + surface + " for " + id)
			check(placement.try_build(), "Any-surface placement must commit on " + surface)
			target.queue_free()
			await tick()
			prop._physics_process(0)
			check(not prop.placed and not prop.freeze, "Removed supports release prop physics.")
		prop.queue_free()
		await tick()
	print("Prop placement/local axes: ", "PASS" if failures.is_empty() else str(failures))
	world.queue_free()
	await tick()
	get_tree().quit(0 if failures.is_empty() else 1)
