extends Node

var failures: Array[String] = []
var world: Node3D
var anchor: StaticBody3D
var rails: Array[train_rail] = []
var slider: rail_slider


func check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
		push_error(message)


func tick(count: int = 2) -> void:
	for index in count:
		await get_tree().physics_frame
		await get_tree().process_frame


func _ready() -> void:
	_run.call_deferred()


func make_rail(pose: Transform3D, length: float = 3.0) -> train_rail:
	var rail: train_rail = load("res://Scenes/Actors/train_rail.tscn").instantiate()
	rail.rail_length = length
	world.add_child(rail)
	rail.global_transform = pose
	rail.place_on(anchor)
	return rail


func make_slider(rail: train_rail, position_on_rail: float = 0.0) -> rail_slider:
	var carriage: rail_slider = load("res://Scenes/Actors/rail_slider.tscn").instantiate()
	carriage.travel_damping = 0.0
	carriage.linear_damp_mode = RigidBody3D.DAMP_MODE_REPLACE
	world.add_child(carriage)
	carriage.global_transform = rail.carriage_pose(position_on_rail)
	carriage.place_on(rail)
	return carriage


func _run() -> void:
	world = Node3D.new()
	add_child(world)
	Blackboard.store_data("game_root", world)
	anchor = StaticBody3D.new()
	anchor.name = "RailAnchor"
	world.add_child(anchor)
	rails.append(make_rail(Transform3D(Basis.IDENTITY, Vector3(0, 4, 0))))
	await _check_building()
	# Third segment is reversed and longer: joining must preserve deck heading.
	rails.append(make_rail(Transform3D(Basis(Vector3.UP, PI), Vector3(0, 4, 6.5)), 4.0))
	await tick(4)
	check(rails[0].connected_rail(1).get("rail") == rails[1] and rails[1].connected_rail(1).get("rail") == rails[2], "Three placed sections must connect through matching endpoints.")
	check(rails[2].connected_rail(1).get("rail") == rails[1], "A reversed section must connect using its actual outward endpoint.")
	check(rails[0].get_node("BackStopCollision").disabled and rails[1].get_node("FrontStopCollision").disabled and rails[1].get_node("BackStopCollision").disabled and rails[2].get_node("BackStopCollision").disabled, "Every joined end must remove its physical stop.")
	check(not rails[0].get_node("FrontStopCollision").disabled and not rails[2].get_node("FrontStopCollision").disabled, "Outer ends retain their stops.")
	slider = make_slider(rails[0])
	var basket: RigidBody3D = load("res://Scenes/Actors/basket.tscn").instantiate()
	basket.set_meta("persistent_item_id", "chain-basket")
	world.add_child(basket)
	basket.global_position = slider.to_global(Vector3(0, .14, 0))
	await tick(30)
	check(slider.get_carried_bodies().has(basket), "A basket actually resting on the deck must be carried.")
	var fan: rotatable_item = load("res://Scenes/Actors/fan.tscn").instantiate()
	fan.powered = false
	fan.set_meta("persistent_item_id", "chain-fan")
	world.add_child(fan)
	fan.global_transform = slider.global_transform * Transform3D(Basis.IDENTITY, Vector3(1.2, .12, 0))
	fan.place_on(slider)
	var cargo_pose: Transform3D = slider.global_transform.affine_inverse() * basket.global_transform
	var deck_heading: Basis = slider.global_basis
	slider.apply_drive_impulse(Vector3(0, 0, 20))
	await tick(108)
	fan.sync_support_pose()
	check(slider.mounted_rail() == rails[2], "The physical carriage must cross both joins without stopping.")
	check(slider.global_basis.is_equal_approx(deck_heading), "Reversed track must not turn the carriage or its cargo around.")
	check(basket.global_transform.is_equal_approx(slider.global_transform * cargo_pose) and fan.global_transform.is_equal_approx(slider.global_transform * fan.support_pose), "Basket cargo and built fan follow seamlessly across rail transfers.")
	check(slider.get_collision_exceptions().has(rails[2]) and not slider.get_collision_exceptions().has(rails[0]) and not slider.get_collision_exceptions().has(rails[1]), "Rail transfer updates the support collision exception.")
	check(slider.linear_velocity.z > 3.5, "World travel speed keeps its direction on the reversed section.")
	_check_save(basket, fan)
	await tick(70)
	check(slider.mounted_rail() == rails[2] and absf(slider.global_position.z - 8.05) < .025 and absf(slider.linear_velocity.z) < .01, "Only the final unconnected end stops the carriage.")
	slider.apply_drive_impulse(Vector3(0, 0, -20))
	await tick(145)
	check(slider.mounted_rail() == rails[0] and slider.global_position.z < -1.0, "A carriage can travel back through the reversed join and both sections.")
	await tick(30)
	check(absf(slider.slider_position + rails[0].travel_limit()) < .025 and absf(slider.linear_velocity.z) < .01, "The other unconnected outer end also stops reverse travel.")
	# Removing a neighbour immediately breaks topology; exposed stops return.
	var middle_pose: Transform3D = rails[1].global_transform
	rails[1].on_picked_up()
	rails[1].freeze = true # The real pickup controller freezes a held section.
	await tick(4)
	check(rails[0].connected_rail(1).is_empty() and not rails[0].get_node("BackStopCollision").disabled, "Picking up one segment disconnects it and restores its neighbour's stop.")
	check(rails[2].connected_rail(1).is_empty() and rails[2].placed, "Picking up a rail does not pull an independent adjacent section along.")
	rails[1].held = false
	rails[1].global_transform = middle_pose
	rails[1].place_on(anchor)
	await tick(4)
	check(not rails[0].connected_rail(1).is_empty(), "Replacing the same section reconnects without saved link IDs.")
	portal_space.apply_actor(rails[1], true)
	await tick(4)
	check(rails[0].connected_rail(1).is_empty(), "Matching geometry in a different portal collision space cannot connect.")
	portal_space.apply_actor(rails[1], false)
	await tick(4)
	rails[1].queue_free()
	await tick(4)
	check(rails[0].connected_rail(1).is_empty() and not rails[0].get_node("BackStopCollision").disabled, "Deleting a middle section restores the remaining outer stops.")
	await _check_sloped_and_ambiguous()
	world.queue_free()
	await tick(4)
	print("Chained rail building, physics, cargo and restoration: ", "PASS" if failures.is_empty() else str(failures))
	get_tree().quit(0 if failures.is_empty() else 1)


func _check_building() -> void:
	var player: CharacterBody3D = load("res://Scenes/Player/player.tscn").instantiate()
	player.process_mode = Node.PROCESS_MODE_DISABLED
	player.position = Vector3(20, 3, 20)
	world.add_child(player)
	var pickup: player_pickup = player.get_node("Controllers/Player_Pickup")
	var placement: prop_placement = player.get_node("Controllers/Prop_Placement")
	var camera: Camera3D = player.get_node("Camera3D")
	var rail: train_rail = load("res://Scenes/Actors/train_rail.tscn").instantiate()
	rail.position = Vector3(12, 3, 12)
	world.add_child(rail)
	pickup.pickup_object(rail)
	camera.global_position = rails[0].to_global(Vector3(.28, 4, 1.3))
	camera.look_at(rails[0].to_global(Vector3(.28, .15, 1.3)), Vector3.FORWARD)
	await tick()
	check(placement.start_building() and placement.placement_valid, "B creates a valid endpoint-snapped rail ghost on a real rail collider.")
	check(placement.preview.global_transform.is_equal_approx(Transform3D(Basis.IDENTITY, Vector3(0, 4, 3))), "Rail ghost appends precisely at the rail endpoint and retains surface height.")
	check(placement.try_build() and rail.placed and rail.support.get_ref() == anchor, "Second B anchors the new rail independently onto the same scenery.")
	rails.append(rail)
	player.queue_free()
	await tick()
	check(rail.connected_rail(-1).get("rail") == rails[0], "A newly built rail becomes traversable on its matching endpoint.")
	var loose: train_rail = load("res://Scenes/Actors/train_rail.tscn").instantiate()
	world.add_child(loose)
	check(not loose.get_placement_pose(rails[0], rails[0].endpoint(1), Vector3.UP, Basis.IDENTITY).get("valid", true), "Appending onto an occupied endpoint is rejected.")
	check(loose.get_placement_pose(anchor, Vector3.ZERO, Vector3.UP, Basis.IDENTITY).is_empty(), "Ordinary surface rail building still uses the shared anchor placement.")
	loose.queue_free()
	await tick()


func _check_save(basket: RigidBody3D, fan: rotatable_item) -> void:
	var state: Dictionary = slider.get_rail_state()
	var saved_pose: Transform3D = slider.global_transform
	var fan_pose: Transform3D = fan.global_transform
	check(state.speed < 0 and not state.basis.is_equal_approx(Basis.IDENTITY), "Reversed section saves its local signed speed and retained heading.")
	# Same restoration order as WorldState: mount first, then resolve attachments,
	# then restore carriage/container state after every actor exists.
	slider.set_meta("restoring", true)
	slider.global_transform = saved_pose
	slider.place_on(rails[2])
	fan.global_transform = fan_pose
	fan.place_on(slider)
	slider.restore_rail_state(state)
	fan.sync_support_pose()
	check(slider.global_transform.is_equal_approx(saved_pose) and fan.global_transform.is_equal_approx(fan_pose), "Restoring a reversed-track carriage keeps attached fan position and heading.")
	check(slider.linear_velocity.z > 3.5 and slider.get_carried_bodies().has(basket), "Restoration preserves global travel direction and current cargo identity.")
	slider.remove_meta("restoring")


func _check_sloped_and_ambiguous() -> void:
	var basis: Basis = Basis(Vector3.UP, .7) * Basis(Vector3.RIGHT, -.15)
	var first: train_rail = make_rail(Transform3D(basis, Vector3(20, 8, 0)))
	var second: train_rail = make_rail(Transform3D(basis, first.to_global(Vector3(0, 0, 3))))
	var carriage: rail_slider = make_slider(first)
	await tick(4)
	check(first.connected_rail(1).get("rail") == second, "Rotated and sloped collinear rails join in their own coordinate frame.")
	carriage.apply_drive_impulse(basis.z * 30)
	await tick(65)
	check(carriage.mounted_rail() == second and absf(second.to_local(carriage.global_position).x) < .001 and absf(second.to_local(carriage.global_position).y - second.carriage_height) < .001, "Physical transfers on tilted rails retain the centreline and deck height.")
	var duplicate_actor: train_rail = make_rail(second.global_transform)
	await tick(4)
	check(first.connected_rail(1).is_empty() and not first.get_node("BackStopCollision").disabled, "An ambiguous overlapping branch is rejected rather than arbitrarily routing the carriage.")
	check(second.connected_rail(-1).is_empty() and duplicate_actor.connected_rail(-1).is_empty(), "Ambiguous endpoints cannot create one-sided joins.")
	duplicate_actor.queue_free()
	await tick(4)
	check(not first.connected_rail(1).is_empty(), "Removing an ambiguous duplicate restores the unique connection.")
