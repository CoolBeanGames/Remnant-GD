extends Node

var failures: Array[String] = []

func check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
		push_error(message)

func tick(count: int = 2) -> void:
	for index in count:
		await get_tree().physics_frame
		await get_tree().process_frame

func _ready() -> void:
	run.call_deferred()

func run() -> void:
	SaveGame.save_path = "res://.godot/portal_assembly_test.save"
	SaveGame.enabled = false
	SaveGame.saving_disabled = true
	Blackboard.store_data("spawned_items", [])
	Blackboard.store_data("portal_inside", false)
	Flags.set_flag("exited room", true)
	var pool := object_pool.new()
	pool.pooled_scene = load("res://Scenes/audio_player.tscn")
	pool.reset_method = &"reset"
	pool.register_with_blackboard = true
	pool.blackboard_name = &"audio_pool"
	add_child(pool)
	var level: level_sequence = load("res://Scenes/testing_level.tscn").instantiate()
	level.spawn_animation_enabled = false
	level.get_node("DoorPortal").purchase_required = false # Explicit free F9/physics test mode.
	add_child(level)
	level.player.process_mode = Node.PROCESS_MODE_DISABLED
	await tick()
	var portal: door_portal = level.get_node("DoorPortal")
	var rail: train_rail = load("res://Scenes/Actors/train_rail.tscn").instantiate()
	rail.gravity_scale = 0
	level.add_child(rail)
	rail.global_position = Vector3(15, 3, 15)
	WorldState.track(rail, "assembly-rail")
	var slider: rail_slider = load("res://Scenes/Actors/rail_slider.tscn").instantiate()
	level.add_child(slider)
	slider.global_transform = rail.carriage_pose(0)
	slider.place_on(rail)
	WorldState.track(slider, "assembly-slider")
	var basket: RigidBody3D = load("res://Scenes/Actors/basket.tscn").instantiate()
	level.add_child(basket)
	basket.global_transform = slider.global_transform * Transform3D(Basis.IDENTITY, Vector3(0, .14, 0))
	WorldState.track(basket, "assembly-basket")
	slider._capture_cargo_body(basket)
	var item_actor: Node3D = WorldState.spawn_item(load("res://Scenes/test_object.tscn"), level, basket.global_transform)
	var body: RigidBody3D = WorldState._bodies(item_actor)[0]
	body.gravity_scale = 0
	body.global_position = basket.to_global(Vector3(0, .65, 0))
	body.linear_velocity = Vector3.ZERO
	var fan: rotatable_item = load("res://Scenes/Actors/fan.tscn").instantiate()
	fan.powered = false
	fan.vacuum_enabled = true
	level.add_child(fan)
	fan.global_transform = slider.global_transform * Transform3D(Basis.IDENTITY, Vector3(1.2, .12, 0))
	fan.place_on(slider)
	WorldState.track(fan, "assembly-fan")
	var bag_actor: Node3D = WorldState.spawn_item(load("res://Scenes/test_object.tscn"), level, fan.global_transform)
	var bag_body: RigidBody3D = WorldState._bodies(bag_actor)[0]
	bag_body.gravity_scale = 0
	fan.vacuum._capture(bag_body)
	await tick(8)
	check(basket.contents.size() == 1 and body.freeze, "Fixture captures a real item in the carriage basket")
	# A carriage can physically reach the doorway while its stationary rail
	# stays outside. It must not teleport independently and snap back later.
	var anchor := StaticBody3D.new()
	level.add_child(anchor)
	rail.place_on(anchor)
	if not portal.door.is_open:
		portal.door.interact()
		portal.door.animation.advance(portal.door.animation.current_animation_length)
	slider.global_position = portal.source_frame.to_global(Vector3(0, 0, -.03))
	portal.previous_bodies["assembly-slider"] = portal.source_frame.to_global(Vector3(0, 0, .03))
	portal._transfer_loose_items()
	check(not slider.get_meta("portal_inside", false) and slider.collision_layer == 1 and slider.mounted_rail() == rail, "An independently crossing mounted slider stays in its rail's physics space")
	check(not portal.previous_bodies.has("assembly-slider"), "Mounted children discard independent crossing history")
	slider.sync_support_pose()
	check(slider.global_transform.is_equal_approx(rail.carriage_pose(slider.slider_position)), "The mounted carriage remains aligned with its original rail")
	rail.on_picked_up()
	rail.on_released()
	rail.global_transform = portal.source_frame.global_transform * Transform3D(Basis.IDENTITY, Vector3(0, 0, -.03))
	slider.sync_support_pose()
	fan.sync_support_pose()
	fan.on_held_transform_updated()
	portal.previous_bodies["assembly-rail"] = portal.source_frame.to_global(Vector3(0, 0, .03))
	var pose_map: Transform3D = portal.mapping(portal.source_frame, portal.destination_frame)
	portal._transfer_loose_items()
	check(rail.get_meta("portal_inside", false), "A loose parent rail still crosses the active doorway with its complete assembly")
	await tick()
	check(rail.get_meta("portal_inside") and slider.get_meta("portal_inside") and basket.get_meta("portal_inside") and fan.get_meta("portal_inside"), "A loose rail transfers all attached and cargo actors")
	check(item_actor.get_meta("portal_inside") and bag_actor.get_meta("portal_inside"), "Nested basket items and attached fan-bag actors transfer too")
	slider.release_cargo_body(basket)
	fan.vacuum.empty()
	check(not body.freeze and body.collision_layer == portal_space.ROOM_LAYER and body.collision_mask == portal_space.ROOM_LAYER, "Releasing transferred basket contents restores portal physics")
	check(not bag_body.freeze and bag_body.collision_layer == portal_space.ROOM_LAYER and bag_body.collision_mask == portal_space.ROOM_LAYER, "Emptying an attached transferred fan restores portal physics")
	check(basket.collision_layer == portal_space.ROOM_LAYER, "Releasing carriage cargo restores portal physics")
	# Refill the same actors, return them outside, then carry the complete rail.
	body.global_position = basket.to_global(Vector3(0, .65, 0))
	body.linear_velocity = Vector3.ZERO
	slider._capture_cargo_body(basket)
	fan.vacuum._capture(bag_body)
	await tick(4)
	portal._transfer_assembly(rail, pose_map.affine_inverse(), false)
	var pickup: player_pickup = level.player.get_node("Controllers/Player_Pickup")
	check(pickup.pickup_object(rail), "The player can pick up the whole rail assembly")
	pickup._physics_process(.2)
	var basket_item_pose: Transform3D = rail.global_transform.affine_inverse() * body.global_transform
	var fan_item_pose: Transform3D = rail.global_transform.affine_inverse() * bag_body.global_transform
	pickup.teleport_held(pose_map, true)
	check(item_actor.get_meta("portal_inside") and bag_actor.get_meta("portal_inside"), "Held whole-rail crossing includes both nested container actors")
	var actual_basket_pose: Transform3D = rail.global_transform.affine_inverse() * body.global_transform
	check(actual_basket_pose.origin.distance_to(basket_item_pose.origin) < .001 and actual_basket_pose.basis.is_equal_approx(basket_item_pose.basis), "Held rail crossing preserves the basket item's local position")
	var actual_fan_pose: Transform3D = rail.global_transform.affine_inverse() * bag_body.global_transform
	# Remote rooms are beyond X1600; allow sub-millimetre float precision loss.
	check(actual_fan_pose.origin.distance_to(fan_item_pose.origin) < .001 and actual_fan_pose.basis.is_equal_approx(fan_item_pose.basis), "Held rail crossing preserves an attached fan bag's local position")
	pickup.drop_object()
	await tick()
	check(not slider.freeze and basket.collision_layer == portal_space.ROOM_LAYER and fan.collision_layer == portal_space.ROOM_LAYER, "Dropping the rail resumes the carriage and restores attachment/cargo collisions")
	slider.release_cargo_body(basket)
	fan.vacuum.empty()
	check(not body.freeze and body.collision_layer == portal_space.ROOM_LAYER and body.collision_mask == portal_space.ROOM_LAYER, "Held rail crossing remaps nested basket collision snapshots exactly once")
	check(not bag_body.freeze and bag_body.collision_layer == portal_space.ROOM_LAYER and bag_body.collision_mask == portal_space.ROOM_LAYER, "Held rail crossing remaps attached fan-bag snapshots exactly once")
	WorldState.tracking = false
	level.queue_free()
	await tick()
	for audio: audio_player in pool.active:
		audio.reset()
	# The real door produces two spatial clips. Give the audio mixer a turn to
	# release stopped playbacks before freeing the pool and exiting the fixture.
	await get_tree().create_timer(.15).timeout
	pool.queue_free()
	await get_tree().process_frame
	print("Portal loose rail, nested basket and attached vacuum assembly: ", "PASS" if failures.is_empty() else failures)
	get_tree().quit(0 if failures.is_empty() else 1)
