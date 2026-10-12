class_name rail_slider
extends rotatable_item

## A physical carriage, constrained to one straight rail. It has no motor.
@export_range(0.0, 8.0, 0.05) var travel_damping: float = 0.3
@export var deck_half_size: Vector2 = Vector2(.9, .9)
@export var deck_surface: float = 0.12
@export_range(0.01, 0.2, 0.01) var cargo_tolerance: float = 0.06
var slider_position: float = 0.0
var rail_basis: Basis = Basis.IDENTITY
var cargo: Array[Dictionary] = []
var cargo_scan_elapsed: float = 0.0
@onready var cargo_area: Area3D = get_node("CargoArea")


func can_place_on(host: Node3D) -> bool:
	return train_rail.from_collider(host) != null


func get_placement_pose(host: Node3D, hit_position: Vector3, _normal: Vector3, _rotation: Basis) -> Dictionary:
	var rail: train_rail = train_rail.from_collider(host)
	if rail == null:
		return {"valid": false}
	var position_on_rail: float = rail.to_local(hit_position).z
	return {"valid": true, "transform": rail.carriage_pose(position_on_rail), "host": rail}


func place_on(host: Node3D) -> void:
	var rail: train_rail = train_rail.from_collider(host)
	if rail == null:
		return
	slider_position = clampf(rail.to_local(global_position).z, -rail.end_limit(-1), rail.end_limit(1))
	rail_basis = rail.global_basis.inverse() * global_basis if get_meta("restoring", false) else Basis.IDENTITY
	global_transform = rail.carriage_pose(slider_position)
	global_basis = rail.global_basis * rail_basis
	super.place_on(rail)
	freeze = false
	can_sleep = false
	linear_damp = travel_damping
	angular_velocity = Vector3.ZERO
	sleeping = false


func mounted_rail() -> train_rail:
	return support.get_ref() as train_rail if placed and support != null else null


func apply_drive_impulse(impulse: Vector3) -> void:
	var rail: train_rail = mounted_rail()
	if rail == null or held or get_meta("carried_by_player", false):
		return
	var axis: Vector3 = rail.global_basis.z.normalized()
	sleeping = false
	apply_central_impulse(axis * impulse.dot(axis))


func _integrate_forces(state: PhysicsDirectBodyState3D) -> void:
	var rail: train_rail = mounted_rail()
	if rail == null or get_meta("carried_by_player", false):
		return
	var point: Vector3 = rail.to_local(state.transform.origin)
	var axis: Vector3 = rail.global_basis.z.normalized()
	var speed: float = state.linear_velocity.dot(axis)
	# Carry the whole deck/cargo orientation across reversed sections unchanged.
	# A large step may cross several short sections; traversal stays bounded.
	for hop in 32:
		var end: int = -1 if point.z < 0.0 else 1
		if absf(point.z) <= rail.rail_length * .5:
			break
		var connection: Dictionary = rail.connected_rail(end)
		if connection.is_empty():
			break
		var next: train_rail = connection.rail as train_rail
		if not is_instance_valid(next) or next.is_queued_for_deletion():
			break
		remove_collision_exception_with(rail)
		add_collision_exception_with(next)
		var world_basis: Basis = rail.global_basis * rail_basis
		var world_velocity: Vector3 = axis * speed
		rail_basis = next.global_basis.inverse() * world_basis
		support = weakref(next)
		rail = next
		point = rail.to_local(state.transform.origin)
		axis = rail.global_basis.z.normalized()
		speed = world_velocity.dot(axis)
	var lower: float = -rail.end_limit(-1)
	var upper: float = rail.end_limit(1)
	slider_position = clampf(point.z, lower, upper)
	if (slider_position <= lower and speed < 0) or (slider_position >= upper and speed > 0):
		speed = 0.0
	state.transform = rail.carriage_pose(slider_position)
	state.transform.basis = rail.global_basis * rail_basis
	state.linear_velocity = axis * speed
	state.angular_velocity = Vector3.ZERO
	support_pose = rail.global_transform.affine_inverse() * state.transform


func sync_support_pose() -> void:
	if not placed:
		return
	var rail: train_rail = mounted_rail()
	if not is_instance_valid(rail) or not rail.is_inside_tree() or rail.is_queued_for_deletion():
		_release_all_cargo()
		placed = false
		remove_from_group("placed-prop")
		support = null
		freeze = false
		can_sleep = true
		return
	global_transform = rail.carriage_pose(slider_position)
	global_basis = rail.global_basis * rail_basis
	support_pose = rail.global_transform.affine_inverse() * global_transform
	freeze = get_meta("carried_by_player", false)
	if freeze:
		linear_velocity = Vector3.ZERO
	_sync_cargo()


func _physics_process(delta: float) -> void:
	sync_support_pose()
	if not placed:
		return
	cargo_scan_elapsed += delta
	if cargo_scan_elapsed >= .1 and not get_meta("carried_by_player", false):
		cargo_scan_elapsed = 0.0
		_capture_resting_cargo()
	_sync_cargo()


func on_picked_up() -> void:
	_release_all_cargo()
	can_sleep = true
	super.on_picked_up()


func get_carried_bodies() -> Array[RigidBody3D]:
	var result: Array[RigidBody3D] = []
	for entry in cargo:
		var body: RigidBody3D = entry.body.get_ref() as RigidBody3D
		if not is_instance_valid(body):
			continue
		result.append(body)
		if body.has_method("get_carried_bodies"):
			for inner in body.get_carried_bodies():
				if not result.has(inner):
					result.append(inner)
	return result


func _capture_resting_cargo() -> void:
	if cargo_area == null:
		return
	cargo_area.collision_mask = int(get_meta("collision_space_mask", 1))
	var rail: train_rail = mounted_rail()
	for collider in cargo_area.get_overlapping_bodies():
		var body: RigidBody3D = physics_items.rigid_body(collider)
		if body == self or body == rail or not physics_items.is_loose(body) or physics_items.prestige_locked(body) or body.get_meta("carried_by_player", false) or body.has_meta("rail_cargo_owner"):
			continue
		var point: Vector3 = to_local(body.global_position)
		if absf(point.x) > deck_half_size.x or absf(point.z) > deck_half_size.y:
			continue
		var lowest: float = INF
		for shape in body.find_children("*", "CollisionShape3D", true, false):
			if shape.disabled or shape.shape == null or not shape.get_parent() is PhysicsBody3D or shape.get_parent().collision_layer == 0:
				continue
			var bounds: AABB = shape.shape.get_debug_mesh().get_aabb()
			var pose: Transform3D = global_transform.affine_inverse() * shape.global_transform
			for corner in 8:
				lowest = minf(lowest, (pose * bounds.get_endpoint(corner)).y)
		# Crossing above the deck is not enough: an object must actually rest on it.
		if absf(lowest - deck_surface) <= cargo_tolerance and absf(body.linear_velocity.dot(global_basis.y.normalized())) < .8:
			_capture_cargo_body(body)


func _capture_cargo_body(body: RigidBody3D, saved: Dictionary = {}) -> void:
	var entry: Dictionary = {"body": weakref(body), "pose": global_transform.affine_inverse() * body.global_transform,
		"freeze": body.freeze, "mode": body.freeze_mode, "states": physics_items.collider_states(body), "carry_collisions": false}
	if not saved.is_empty():
		entry.pose = saved.get("pose", entry.pose)
		entry.freeze = saved.get("freeze", false)
		entry.mode = saved.get("mode", RigidBody3D.FREEZE_MODE_STATIC)
	# Basket's existing carry implementation preserves its genuinely contained items.
	if body.has_method("contained_bodies") and body.has_method("on_picked_up"):
		body.on_picked_up()
	cargo.append(entry)
	body.set_meta("rail_cargo_owner", weakref(self))
	body.freeze = true
	body.linear_velocity = Vector3.ZERO
	body.angular_velocity = Vector3.ZERO


func _sync_cargo() -> void:
	for index in range(cargo.size() - 1, -1, -1):
		var entry: Dictionary = cargo[index]
		var body: RigidBody3D = entry.body.get_ref() as RigidBody3D
		if not is_instance_valid(body):
			cargo.remove_at(index)
			continue
		var carried: bool = get_meta("carried_by_player", false)
		if entry.carry_collisions != carried:
			physics_items.set_collisions(entry.states, not carried)
			entry.carry_collisions = carried
		body.global_transform = global_transform * entry.pose
		if body.has_method("capture_current_contents"):
			body.capture_current_contents()
		if body.has_method("on_held_transform_updated"):
			body.on_held_transform_updated()


func release_cargo_body(body: RigidBody3D) -> void:
	for index in range(cargo.size() - 1, -1, -1):
		var entry: Dictionary = cargo[index]
		if entry.body.get_ref() != body:
			continue
		physics_items.set_collisions(entry.states, true)
		if body.has_method("contained_bodies") and body.has_method("on_released"):
			body.on_released()
		body.remove_meta("rail_cargo_owner")
		body.freeze_mode = entry.mode
		body.freeze = entry.freeze
		body.linear_velocity = linear_velocity
		body.sleeping = false
		cargo.remove_at(index)


func portal_transform_contents(_pose_map: Transform3D, inside: bool) -> void:
	# The pickup traversal maps each actor and nested container exactly once.
	# Preserve the original masks that will be restored on a later release.
	for entry in cargo:
		for state in entry.states:
			state.layer = portal_space.remap_mask(state.layer, inside)
			state.mask = portal_space.remap_mask(state.mask, inside)


func _release_all_cargo() -> void:
	for entry in cargo.duplicate():
		var body: RigidBody3D = entry.body.get_ref() as RigidBody3D
		if is_instance_valid(body):
			release_cargo_body(body)
	cargo.clear()


func get_rail_state() -> Dictionary:
	return {"position": slider_position, "speed": linear_velocity.dot(mounted_rail().global_basis.z.normalized()) if mounted_rail() != null else 0.0, "basis": rail_basis, "cargo": physics_items.cargo_records(cargo)}


func restore_rail_state(state: Dictionary, resolve_actor: Callable = Callable()) -> void:
	var rail: train_rail = mounted_rail()
	if rail == null:
		return
	slider_position = clampf(float(state.get("position", slider_position)), -rail.end_limit(-1), rail.end_limit(1))
	rail_basis = state.get("basis", Basis.IDENTITY)
	sync_support_pose()
	linear_velocity = rail.global_basis.z.normalized() * float(state.get("speed", 0.0))
	if resolve_actor.is_valid():
		for entry in state.get("cargo", []):
			if not entry is Dictionary:
				continue
			var actor: Node3D = resolve_actor.call(str(entry.get("id", ""))) as Node3D
			var body: RigidBody3D = actor.get_node_or_null(NodePath(entry.get("path", ""))) as RigidBody3D if is_instance_valid(actor) else null
			if is_instance_valid(body) and not body.has_meta("rail_cargo_owner"):
				_capture_cargo_body(body, entry)
				if body.has_method("capture_current_contents"):
					_restore_basket_contents(body, entry.get("contents", []), resolve_actor)
	_sync_cargo()


func _restore_basket_contents(basket: RigidBody3D, records: Array, resolve_actor: Callable) -> void:
	basket.global_transform = global_transform * cargo.back().pose
	physics_items.restore_basket_contents(basket, records, resolve_actor)


func capture_current_cargo() -> void:
	_capture_resting_cargo()


## Stations use the existing cargo owner; item identity and nested contents stay intact.
func accept_cargo(body: RigidBody3D, pose: Transform3D) -> bool:
	if not is_instance_valid(body) or physics_items.prestige_locked(body) or body == self or body.has_meta("rail_cargo_owner") or body.get_meta("carried_by_player", false):
		return false
	_capture_cargo_body(body)
	cargo.back().pose = global_transform.affine_inverse() * pose
	_sync_cargo()
	return true


func eject_cargo(body: RigidBody3D, pose: Transform3D, velocity: Vector3) -> void:
	for entry in cargo:
		if entry.body.get_ref() != body:
			continue
		# Move a captured basket while it still owns its contents, then release.
		entry.pose = global_transform.affine_inverse() * pose
		_sync_cargo()
		var assembly: Array[RigidBody3D] = [body]
		if body.has_method("get_carried_bodies"):
			assembly.append_array(body.get_carried_bodies())
		release_cargo_body(body)
		for part in assembly:
			if is_instance_valid(part):
				part.linear_velocity = velocity
				part.angular_velocity = Vector3.ZERO
				part.sleeping = false
		return


## Conservative deck packing also checks built props and nearby scenery.
func cargo_loading_pose(body: RigidBody3D, ignored: Array[RID]) -> Dictionary:
	var axes: Basis = global_basis.orthonormalized()
	var solid: AABB = physics_items.solid_bounds(body, Transform3D(axes, body.global_position).affine_inverse())
	if not solid.has_volume():
		return {}
	var lower: Vector3 = -solid.position
	var upper: Vector3 = solid.end
	var shape := BoxShape3D.new()
	shape.size = lower + upper
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.collision_mask = int(get_meta("collision_space_mask", 1))
	query.exclude = ignored.duplicate()
	query.exclude.append(get_rid())
	query.exclude.append(body.get_rid())
	var rail: train_rail = mounted_rail()
	if rail != null:
		query.exclude.append(rail.get_rid())
	var space: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	var occupied: Array[AABB] = []
	for entry in cargo:
		var existing: RigidBody3D = entry.body.get_ref() as RigidBody3D
		if not is_instance_valid(existing):
			continue
		var bounds: AABB = physics_items.solid_bounds(existing, global_transform.affine_inverse())
		if bounds.has_volume():
			occupied.append(bounds)
	for height in [0.0, .45, .9, 1.35]:
		for x in [0.0, -.55, .55]:
			for z in [0.0, -.55, .55]:
				if x - lower.x < -deck_half_size.x or x + upper.x > deck_half_size.x or z - lower.z < -deck_half_size.y or z + upper.z > deck_half_size.y:
					continue
				var point := Vector3(x, deck_surface + lower.y + height + .015, z)
				var bounds := AABB(point - lower, lower + upper)
				var blocked: bool = false
				for other in occupied:
					if bounds.grow(.01).intersects(other):
						blocked = true
						break
				if blocked:
					continue
				query.transform = Transform3D(axes, to_global(point + (upper - lower) * .5))
				if space.intersect_shape(query, 1).is_empty():
					return {"pose": Transform3D(body.global_basis, to_global(point))}
	return {}


func _exit_tree() -> void:
	_release_all_cargo()
