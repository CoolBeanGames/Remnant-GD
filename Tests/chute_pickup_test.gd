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
	run.call_deferred()
func run() -> void:
	for key in ["player_transform", "player_position", "player_rotation", "player_camera_rotation", "respawn room active"]:
		Blackboard.remove_data(key)
	for key in ["exited room", "level enabled", "grinder enabled", "computer enabled"]:
		Flags.set_flag(key, false)
	Blackboard.store_data("spawned_items", [])
	Blackboard.store_data("score", 0)
	Blackboard.store_data("lever_pulls", 0)
	var pool := object_pool.new()
	pool.pooled_scene = load("res://Scenes/audio_player.tscn")
	pool.reset_method = &"reset"
	pool.register_with_blackboard = true
	pool.blackboard_name = &"audio_pool"
	add_child(pool)
	var level: level_sequence = load("res://Scenes/testing_level.tscn").instantiate()
	level.set("spawn_animation_enabled", false)
	add_child(level)
	level.player.process_mode = Node.PROCESS_MODE_DISABLED
	var zone: chute_zone = level.get_node("ceiling_chute/ChuteZone")
	zone.set_physics_process(false)
	var actor: Node3D = WorldState.spawn_item(load("res://Scenes/Items/syringe.tscn"), level, Transform3D(Basis.IDENTITY, Vector3(10.18, 1, -2)))
	var body: RigidBody3D = actor.get_node("RigidBody3D")
	body.freeze = true
	var target: pickup_target = body.get_node("PickupTarget")
	check(target.collision_mask == 0 and target.get_node("Shape").shape.radius == .25, "Larger pickup sphere adds no physics collision")
	var physical: BoxShape3D = body.get_node("CollisionShape3D").shape
	check(physical.size.x < .21 and physical.size.y < .21 and physical.size.z < .07, "Replacement syringe physical collider stays compact and matches its diagonal model")
	var ray := raycaster.new()
	level.add_child(ray)
	ray.position = Vector3(10, 1, 0)
	ray.target_groups = [&"pick-up"]
	await tick()
	ray._physics_process(0)
	check(ray.get_collider() == target and ray.get_looked_at() == body, "Near-miss ray selects enlarged pickup target")
	var query := PhysicsRayQueryParameters3D.create(ray.global_position, ray.global_position + Vector3(0, 0, -3), 1)
	check(level.get_world_3d().direct_space_state.intersect_ray(query).is_empty(), "Same aim misses the original solid collider")
	var wall := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(.06, .5, .1)
	shape.shape = box
	wall.add_child(shape)
	level.add_child(wall)
	wall.position = Vector3(10.09, 1, -1)
	await tick()
	ray._physics_process(0)
	check(ray.get_looked_at() == null, "Pickup padding cannot target an item hidden behind scenery")
	wall.queue_free()
	await tick()
	var pickup: player_pickup = level.player.get_node("Controllers/Player_Pickup")
	pickup.pickup_object(body)
	check(target.collision_layer == 0 and not target.can_target(), "Holding disables padded target with the rest of collisions")
	pickup.drop_object()
	check(target.collision_layer == 1, "Dropping restores padded target")
	zone.entered(body)
	check(is_equal_approx(body.physics_material_override.friction, .35), "Chute uses low friction for flow")
	zone._physics_process(29)
	check(not actor.is_queued_for_deletion(), "Item survives the first twenty-nine seconds inside chute")
	zone.left(body)
	check(body.physics_material_override.friction == 1 and body.linear_damp == 2, "Leaving chute increases friction and damping")
	WorldState.capture()
	var records: Array = Blackboard.read_data("spawned_items")
	check(records[0].bodies[0].chute_settled and records[0].bodies[0].friction == 1, "Settled physics values are stored with item transform")
	zone.entered(body)
	body.set_meta("carried_by_player", true)
	zone._physics_process(31)
	check(not actor.is_queued_for_deletion() and zone.occupants.is_empty(), "Picked-up items are released from timeout")
	body.set_meta("carried_by_player", false)
	zone.entered(body)
	zone._physics_process(31)
	check(actor.is_queued_for_deletion() and not WorldState.items.has(actor.get_meta("persistent_item_id")), "Stuck item is removed from world and Blackboard registry at timeout")
	check(Blackboard.read_data("score") == 0, "Chute cleanup does not award score")
	await tick()
	level.queue_free()
	await tick()
	print("Chute cleanup, friction, pickup padding and occlusion: ", "PASS" if failures.is_empty() else str(failures))
	get_tree().quit(0 if failures.is_empty() else 1)
