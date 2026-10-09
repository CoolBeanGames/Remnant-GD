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
	run.call_deferred()
func run() -> void:
	Blackboard.store_data("spawned_items", [])
	Blackboard.store_data("portal_inside", false)
	for key in ["player_transform", "player_position", "player_rotation", "player_camera_rotation"]:
		Blackboard.remove_data(key)
	for key in ["exited room", "level enabled", "grinder enabled", "computer enabled"]:
		Flags.set_flag(key, false)
	var pool := object_pool.new()
	pool.pooled_scene = load("res://Scenes/audio_player.tscn")
	pool.reset_method = &"reset"
	pool.register_with_blackboard = true
	pool.blackboard_name = &"audio_pool"
	add_child(pool)
	var level: level_sequence = load("res://Scenes/testing_level.tscn").instantiate()
	level.set("spawn_animation_enabled", false)
	add_child(level)
	var player: CharacterBody3D = level.player
	player.process_mode = Node.PROCESS_MODE_DISABLED
	player.disable_mode = CollisionObject3D.DISABLE_MODE_KEEP_ACTIVE
	var portal: door_portal = level.get_node("DoorPortal")
	await tick()
	check(not portal.active and portal.room == null, "Sky room does not exist before initial room removal")
	level.room._remove_room()
	await tick()
	check(portal.active and portal.room.global_position.is_equal_approx(Vector3(1600, 0, 0)), "Removing initial room activates the sky room")
	check(player.collision_mask == 1 and not portal.camera.cull_mask & portal_space.ROOM_LAYER, "Sky room is invisible and noncolliding from main space")
	var door: start_room_door = portal.door
	door.interact()
	door.animation.advance(door.animation.current_animation_length)
	player.global_position = door.global_position + Vector3(0, .02, -1)
	player.global_rotation = Vector3(0, PI, 0)
	portal.previous_camera_position = portal.camera.global_position
	portal._update_view()
	check(portal.source_surface.visible and not portal.return_surface.visible, "Only the entry view is drawn outside")
	var expected_view: Transform3D = portal.mapping(portal.source_frame, portal.destination_frame) * portal.camera.global_transform
	check(portal.portal_camera.global_transform.is_equal_approx(expected_view), "Portal camera matches player perspective through doorway")
	check(not portal.crosses_aperture(portal.source_frame, door.global_position + Vector3(3, 1, -1), door.global_position + Vector3(3, 1, 1)), "Walking around door does not cross portal")
	var basket: RigidBody3D = load("res://Scenes/Actors/basket.tscn").instantiate()
	level.add_child(basket)
	basket.global_position = door.global_position + Vector3(0, .05, -2)
	basket.freeze = true
	WorldState.track(basket)
	var actor: Node3D = WorldState.spawn_item(load("res://Scenes/test_object.tscn"), level, basket.global_transform)
	var contents: RigidBody3D = actor.get_node("RigidBody3D")
	contents.global_position = basket.global_position + Vector3(0, .5, 0)
	contents.linear_velocity = Vector3.ZERO
	var lamp: rotatable_item = load("res://Scenes/Actors/light.tscn").instantiate()
	level.add_child(lamp)
	lamp.global_position = basket.global_position + Vector3(.6, .2, 0)
	lamp.place_on(basket)
	WorldState.track(lamp)
	for i in 20:
		await tick()
	var pickup: player_pickup = player.get_node("Controllers/Player_Pickup")
	pickup.pickup_object(basket)
	check(basket.get_carried_bodies().has(contents), "Basket captures a real contained body for portal crossing")
	pickup._physics_process(1.0)
	var contents_pose: Transform3D = basket.global_transform.affine_inverse() * contents.global_transform
	player.velocity = Vector3(0, 0, 4)
	portal.previous_camera_position = portal.camera.global_position
	player.global_position.z = door.global_position.z + .3
	portal._physics_process(0)
	check(portal.inside and is_equal_approx(player.global_position.y, .02), "Walking through places player on sky-room floor")
	check(player.collision_mask == portal_space.ROOM_LAYER and portal.camera.cull_mask == portal_space.ROOM_LAYER, "Inside uses room rendering and physics")
	check(player.velocity.is_equal_approx(Vector3(0, 0, 4)), "Crossing preserves velocity")
	check(contents_pose.is_equal_approx(basket.global_transform.affine_inverse() * contents.global_transform), "Basket contents cross without scattering")
	check(lamp.get_meta("portal_inside", false) and lamp.collision_layer == 0, "Attached light travels while solid collisions stay disabled")
	check(portal.return_surface.visible and not portal.source_surface.visible, "Inside doorway shows the return view")
	pickup.drop_object()
	check(basket.collision_mask == portal_space.ROOM_LAYER and contents.collision_mask == portal_space.ROOM_LAYER, "Dropping basket and contents restores room collisions")
	check(lamp.collision_layer == portal_space.ROOM_LAYER, "Detached carry state restores attached light to room collision layer")
	var floor_query := PhysicsRayQueryParameters3D.create(Vector3(1600, 2, 2), Vector3(1600, -1, 2), portal_space.ROOM_LAYER)
	floor_query.exclude = [player.get_rid()]
	var hit: Dictionary = player.get_world_3d().direct_space_state.intersect_ray(floor_query)
	check(not hit.is_empty() and is_equal_approx(hit.position.y, 0), "Sky room has actual floor collision")
	var return_door: portal_return_door = portal.room.get_children().back() as portal_return_door
	return_door.interact()
	check(not door.is_open, "Return door controls the same original door")
	door.animation.advance(door.animation.current_animation_length)
	portal._update_view()
	check(not portal.return_surface.visible, "Closed door hides portal view")
	return_door.interact()
	door.animation.advance(door.animation.current_animation_length)
	player.global_position = Vector3(1600, .02, .3)
	portal.previous_camera_position = portal.camera.global_position
	player.velocity = Vector3(0, 0, -4)
	player.global_position.z = -.3
	portal._physics_process(0)
	check(not portal.inside and is_equal_approx(player.global_position.y, .02), "Walking back returns to workshop")
	check(player.collision_mask == 1 and player.velocity.is_equal_approx(Vector3(0, 0, -4)), "Return restores workshop physics and preserves velocity")
	# Exercise the real capsule against the open door, not only pose mapping.
	player.global_position = door.global_position + Vector3(0, .02, -1)
	portal.previous_camera_position = portal.camera.global_position
	var movement: Node = player.get_node("Controllers/Player_Move_Controller")
	Blackboard.store_data("player_input_blocked", false)
	Input.action_press("forward")
	for i in 100:
		await get_tree().physics_frame
		movement._physics_process(1.0 / 60.0)
		await get_tree().process_frame
		if portal.inside:
			break
	Input.action_release("forward")
	check(portal.inside, "Real character movement crosses the open door without collision obstruction")
	var thrown: Node3D = WorldState.spawn_item(load("res://Scenes/test_object.tscn"), level, Transform3D(Basis.IDENTITY, door.global_position + Vector3(0, 1, -.4)))
	var thrown_body: RigidBody3D = WorldState._bodies(thrown)[0]
	await tick()
	thrown_body.global_position = door.global_position + Vector3(0, 1, -1)
	thrown_body.linear_velocity = Vector3(0, 0, 4)
	for i in 40:
		await tick()
		if thrown.get_meta("portal_inside", false):
			break
	check(thrown.get_meta("portal_inside", false), "Loose thrown item crosses with real physics")
	var spawner: automatic_spawner = load("res://Scenes/Actors/automatic_spawner.tscn").instantiate()
	portal_space.apply_actor(spawner, true)
	level.add_child(spawner)
	spawner.global_position = Vector3(1602, 0, 4)
	spawner.place_on(hit.collider)
	spawner.required_flag = ""
	spawner.remaining = 0
	spawner._physics_process(.01)
	var spawned: Node3D = WorldState._actor(WorldState.items.keys().back())
	check(spawned.get_meta("portal_inside", false) and WorldState._bodies(spawned)[0].collision_mask == portal_space.ROOM_LAYER, "Spawner output inherits isolated room physics")
	spawner.queue_free()
	WorldState.capture()
	var saved: Array = Blackboard.read_data("spawned_items").duplicate(true)
	level.queue_free()
	await tick()
	Blackboard.store_data("spawned_items", saved)
	var resumed: level_sequence = load("res://Scenes/testing_level.tscn").instantiate()
	resumed.set("spawn_animation_enabled", false)
	add_child(resumed)
	resumed.player.process_mode = Node.PROCESS_MODE_DISABLED
	await tick()
	var resumed_portal: door_portal = resumed.get_node("DoorPortal")
	check(resumed_portal.active, "Saved room-removal flag recreates portal at startup")
	check(resumed_portal.inside and resumed.player.collision_mask == portal_space.ROOM_LAYER and resumed.player.global_position.x > 1599, "Startup restores player in the sky room with matching camera and physics")
	for id in WorldState.items:
		var restored: Node3D = WorldState._actor(id)
		check(restored.get_meta("portal_inside", false) and WorldState._bodies(restored)[0].collision_mask == portal_space.ROOM_LAYER, "Saved sky props restore in isolated room space")
	resumed.queue_free()
	await tick()
	print("Door portal activation, crossing, basket, return and restoration: ", "PASS" if failures.is_empty() else failures)
	get_tree().quit(0 if failures.is_empty() else 1)
