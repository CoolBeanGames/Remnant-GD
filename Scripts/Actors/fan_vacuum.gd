class_name fan_vacuum
extends Node3D

## Fan attachment: moves existing bodies into a finite catch bag without changing
## their wrapper, score, note identity or WorldState registration.
@export var suction_force: float = 32.0
@export var reach: float = 2.8
@export var capture_distance: float = 0.42
@export_range(1, 20, 1) var capacity: int = 8
var contents: Array[Dictionary] = []
var released: Array[WeakRef] = []
@onready var fan: RigidBody3D = get_parent() as RigidBody3D
@onready var intake: Area3D = $Intake

func _physics_process(_delta: float) -> void:
	_follow_contents()
	for index in range(released.size() - 1, -1, -1):
		var body: RigidBody3D = released[index].get_ref() as RigidBody3D
		if not is_instance_valid(body):
			released.remove_at(index)
		elif to_local(body.global_position).y + physics_items.support_extent(body, -global_basis.y) < .3 or body.global_position.distance_to(global_position) > 1.6:
			body.remove_collision_exception_with(fan)
			released.remove_at(index)

func pull(_delta: float) -> void:
	if contents.size() >= capacity:
		return
	var mouth: Vector3 = to_global(Vector3(0, 1, -0.72))
	for node in intake.get_overlapping_bodies():
		var body: RigidBody3D = physics_items.rigid_body(node)
		if body == fan or not physics_items.is_processable(body) or _recently_released(body):
			continue
		var point: Vector3 = to_local(body.global_position)
		var distance: float = body.global_position.distance_to(mouth)
		# Force remains physical; heavy books must be brought closer than syringes.
		var effective_reach: float = reach / sqrt(maxf(1.0, body.mass))
		if point.z > -0.3 or distance > effective_reach:
			continue
		var query := PhysicsRayQueryParameters3D.create(mouth, body.global_position, intake.collision_mask)
		query.exclude = [fan.get_rid()]
		var obstruction: Dictionary = get_world_3d().direct_space_state.intersect_ray(query)
		if not obstruction.is_empty() and physics_items.rigid_body(obstruction.collider) != body:
			continue
		if distance < capture_distance and _fits(body):
			_capture(body)
			if contents.size() >= capacity:
				break
		else:
			body.sleeping = false
			body.apply_central_force((mouth - body.global_position).normalized() * suction_force)

func _fits(body: RigidBody3D) -> bool:
	for axis in [Vector3.RIGHT, Vector3.UP, Vector3.BACK]:
		if physics_items.support_extent(body, axis) > .4 or physics_items.support_extent(body, -axis) > .4:
			return false
	return true

func _recently_released(body: RigidBody3D) -> bool:
	for reference in released:
		if reference.get_ref() == body:
			return true
	return false

func _capture(body: RigidBody3D, pose: Transform3D = Transform3D.IDENTITY, mode: int = -1) -> void:
	if get_bodies().has(body):
		return
	var state: Dictionary = {"body": weakref(body), "mode": body.freeze_mode if mode < 0 else mode,
		"states": physics_items.collider_states(body)}
	if pose == Transform3D.IDENTITY:
		var slot: int = contents.size()
		pose.basis = global_basis.inverse() * body.global_basis
		pose.origin = Vector3((slot % 2 - .5) * .32, .48 + floorf(slot / 4.0) * .28, .65 + (floori(slot / 2.0) % 2) * .32)
	state.pose = pose
	contents.append(state)
	physics_items.set_collisions(state.states, false)
	body.freeze = true
	body.linear_velocity = Vector3.ZERO
	body.angular_velocity = Vector3.ZERO
	_follow_contents()

func _follow_contents() -> void:
	for index in range(contents.size() - 1, -1, -1):
		var state: Dictionary = contents[index]
		var body: RigidBody3D = state.body.get_ref() as RigidBody3D
		if not is_instance_valid(body) or body.is_queued_for_deletion():
			contents.remove_at(index)
			continue
		if not is_inside_tree() or not body.is_inside_tree():
			continue
		body.global_transform = global_transform * state.pose
		body.set_meta("carried_by_player", fan.get_meta("carried_by_player", false))

func get_bodies() -> Array[RigidBody3D]:
	var result: Array[RigidBody3D] = []
	for state in contents:
		var body: RigidBody3D = state.body.get_ref() as RigidBody3D
		if is_instance_valid(body) and not body.is_queued_for_deletion():
			result.append(body)
	return result

func empty() -> void:
	_follow_contents()
	for state in contents:
		var body: RigidBody3D = state.body.get_ref() as RigidBody3D
		if not is_instance_valid(body):
			continue
		body.add_collision_exception_with(fan)
		released.append(weakref(body))
		physics_items.set_collisions(state.states, true)
		body.freeze_mode = state.mode
		body.freeze = false
		body.remove_meta("carried_by_player")
		body.sleeping = false
		body.linear_velocity = Vector3.ZERO
		body.angular_velocity = Vector3.ZERO
	contents.clear()

func get_state() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for state in contents:
		var body: RigidBody3D = state.body.get_ref() as RigidBody3D
		if not is_instance_valid(body):
			continue
		var actor: Node3D = physics_items.item_root(body)
		result.append({"id": str(actor.get_meta("persistent_item_id", "")),
			"body_path": str(actor.get_path_to(body)), "pose": state.pose, "mode": state.mode})
	return result

func restore_state(records: Array, actor_resolver: Callable) -> void:
	for record in records:
		if not record is Dictionary:
			continue
		var actor: Node = actor_resolver.call(str(record.get("id", ""))) as Node
		if not is_instance_valid(actor):
			continue
		var body: RigidBody3D = actor.get_node_or_null(NodePath(record.get("body_path", "."))) as RigidBody3D
		if is_instance_valid(body) and not actor.is_in_group("machine-immune") and not body.is_in_group("machine-immune"):
			_capture(body, record.get("pose", Transform3D.IDENTITY), int(record.get("mode", 0)))

func portal_transform_contents(_pose_map: Transform3D, inside: bool) -> void:
	for content in contents:
		for state in content.states:
			state.layer = portal_space.remap_mask(state.layer, inside)
			state.mask = portal_space.remap_mask(state.mask, inside)

func _exit_tree() -> void:
	empty()
	for reference in released:
		var body: RigidBody3D = reference.get_ref() as RigidBody3D
		if is_instance_valid(body) and is_instance_valid(fan):
			body.remove_collision_exception_with(fan)
