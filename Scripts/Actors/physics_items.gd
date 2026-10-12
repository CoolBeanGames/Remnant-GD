class_name physics_items
extends RefCounted

## Shared resolution for imported colliders and managed spawned-item wrappers.
static func rigid_body(node: Node) -> RigidBody3D:
	while is_instance_valid(node):
		if node is RigidBody3D:
			return node as RigidBody3D
		if node is CharacterBody3D:
			return null
		node = node.get_parent()
	return null


static func is_loose(body: RigidBody3D) -> bool:
	return is_instance_valid(body) and not body.is_queued_for_deletion() and not body.freeze


## Containers can remain physical without becoming machine feedstock.
static func is_processable(body: RigidBody3D) -> bool:
	if not is_loose(body) or not body.is_inside_tree():
		return false
	return not prestige_locked(body) and not body.is_in_group("machine-immune") and not item_root(body).is_in_group("machine-immune")


## Currency can join a multi-grab without making reusable tools feedstock.
static func is_multi_grabbable(body: RigidBody3D) -> bool:
	return is_processable(body) or (is_loose(body) and body is mulch_pellet and body.can_grind())


## A tag on either the rigid body or its item wrapper gates every pickup path.
static func prestige_locked(node: Node) -> bool:
	var world: Node = Blackboard.read_data("game_root") as Node
	while is_instance_valid(node) and node != world:
		if node.is_in_group("prestige items"):
			return not Mulch.prestige_items_unlocked()
		node = node.get_parent()
	return false


static func item_root(body: RigidBody3D) -> Node3D:
	var current: Node = body.get_parent()
	var world: Node = Blackboard.read_data("game_root") as Node
	while current is Node3D and current != world and current != body.get_tree().current_scene:
		if current is PhysicsBody3D:
			break
		if current.is_in_group("grindable") or current.is_in_group("score"):
			return current as Node3D
		current = current.get_parent()
	return body


static func score_component(node: Node) -> score_object:
	for child in node.get_children():
		if child is score_object:
			return child as score_object
	for child in node.get_children():
		var component: score_object = score_component(child)
		if component != null:
			return component
	return null


static func collider_states(node: Node) -> Array[Dictionary]:
	var states: Array[Dictionary] = []
	if node is CollisionObject3D:
		states.append({"node": weakref(node), "layer": node.collision_layer, "mask": node.collision_mask})
	for child in node.get_children():
		states.append_array(collider_states(child))
	return states


static func set_collisions(states: Array[Dictionary], enabled: bool) -> void:
	for state in states:
		var collider: CollisionObject3D = state.node.get_ref() as CollisionObject3D
		if is_instance_valid(collider):
			collider.collision_layer = state.layer if enabled else 0
			collider.collision_mask = state.mask if enabled else 0


## Distance from body origin to its lowest active collider along the given axis.
## Used by basket containment and spacing when releasing contents.
static func support_extent(body: RigidBody3D, axis: Vector3) -> float:
	axis = axis.normalized()
	var extent: float = 0.0
	for shape in body.find_children("*", "CollisionShape3D", true, false):
		if not shape.is_inside_tree() or shape.disabled or shape.shape == null or not shape.get_parent() is PhysicsBody3D or shape.get_parent().collision_layer == 0:
			continue
		var bounds: AABB = shape.shape.get_debug_mesh().get_aabb()
		var half: Vector3 = bounds.size * 0.5
		var basis: Basis = shape.global_basis
		var radius: float = absf(basis.x.dot(axis)) * half.x + absf(basis.y.dot(axis)) * half.y + absf(basis.z.dot(axis)) * half.z
		var center: Vector3 = shape.to_global(bounds.get_center()) - body.global_position
		extent = maxf(extent, radius - center.dot(axis))
	return maxf(extent, 0.125)


## Shared station/car snapshots resolve existing actors, never duplicate cargo.
static func cargo_records(entries: Array[Dictionary]) -> Array[Dictionary]:
	var records: Array[Dictionary] = []
	for entry in entries:
		var body: RigidBody3D = entry.body.get_ref() as RigidBody3D
		if not is_instance_valid(body):
			continue
		var actor: Node3D = item_root(body)
		var id: String = str(actor.get_meta("persistent_item_id", ""))
		if id.is_empty():
			continue
		var record: Dictionary = {"id": id, "path": str(actor.get_path_to(body)), "pose": entry.pose, "freeze": entry.freeze, "mode": entry.mode}
		if body.has_method("capture_current_contents"):
			record.contents = cargo_records(body.contents)
		records.append(record)
	return records


static func restore_basket_contents(basket: RigidBody3D, records: Array, resolve_actor: Callable) -> void:
	basket.on_released()
	basket.carried = true
	basket.last_carry_pose = basket.global_transform
	for record in records:
		if not record is Dictionary:
			continue
		var actor: Node3D = resolve_actor.call(str(record.get("id", ""))) as Node3D
		var body: RigidBody3D = actor.get_node_or_null(NodePath(record.get("path", ""))) as RigidBody3D if is_instance_valid(actor) else null
		if not is_instance_valid(body) or body.get_meta("carried_by_player", false) or body.has_meta("rail_cargo_owner"):
			continue
		var states: Array[Dictionary] = collider_states(body)
		basket.contents.append({"body": weakref(body), "pose": record.get("pose", Transform3D.IDENTITY),
			"freeze": record.get("freeze", false), "mode": record.get("mode", RigidBody3D.FREEZE_MODE_STATIC), "states": states})
		set_collisions(states, false)
		body.global_transform = basket.global_transform * record.get("pose", Transform3D.IDENTITY)
		body.freeze = true
		body.linear_velocity = Vector3.ZERO
		body.angular_velocity = Vector3.ZERO


## Exact solid bounds in a caller's space; sensors and pickup targets do not count.
static func solid_bounds(body: RigidBody3D, inverse_pose: Transform3D) -> AABB:
	var result := AABB()
	var first: bool = true
	for shape in body.find_children("*", "CollisionShape3D", true, false):
		if shape.disabled or shape.shape == null or not shape.get_parent() is PhysicsBody3D or shape.get_parent().collision_layer == 0:
			continue
		var bounds: AABB = shape.shape.get_debug_mesh().get_aabb()
		var pose: Transform3D = inverse_pose * shape.global_transform
		for corner in 8:
			var point: Vector3 = pose * bounds.get_endpoint(corner)
			if first:
				result = AABB(point, Vector3.ZERO)
				first = false
			else:
				result = result.expand(point)
	return result
