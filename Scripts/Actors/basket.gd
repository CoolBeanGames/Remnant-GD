extends RigidBody3D

@export var carry_prompts: prompt_set
@export var containment_tolerance: float = 0.025
var contents: Array[Dictionary] = []
var carried: bool = false
var last_carry_pose: Transform3D
var falling_contents: Array[WeakRef] = []


func _ready() -> void:
	add_to_group("machine-immune")


func get_carry_prompts() -> prompt_set:
	return carry_prompts


func get_carried_bodies() -> Array[RigidBody3D]:
	var bodies: Array[RigidBody3D] = []
	for state in contents:
		var body: RigidBody3D = state.body.get_ref() as RigidBody3D
		if is_instance_valid(body):
			bodies.append(body)
	return bodies


func get_hold_offset() -> Vector3:
	return Vector3(0, -0.35, -0.65)


func contained_bodies() -> Array[RigidBody3D]:
	var result: Array[RigidBody3D] = []
	for node in $Contents.get_overlapping_bodies():
		var body: RigidBody3D = physics_items.rigid_body(node)
		if body == self or not physics_items.is_processable(body) or result.has(body):
			continue
		var exiting_bottom: bool = false
		for reference in falling_contents:
			if reference.get_ref() == body:
				exiting_bottom = true
				break
		if exiting_bottom:
			continue
		var point: Vector3 = to_local(body.global_position)
		var inside: bool = true
		for i in 3:
			var axis: Vector3 = global_basis[i].normalized()
			var lower: float = [-0.7, 0.15, -0.6][i]
			var upper: float = [0.7, 1.1, 0.6][i]
			if point[i] - physics_items.support_extent(body, axis) < lower - containment_tolerance or point[i] + physics_items.support_extent(body, -axis) > upper + containment_tolerance:
				inside = false
		if inside:
			result.append(body)
	return result


func on_picked_up() -> void:
	carried = true
	last_carry_pose = global_transform
	capture_current_contents()


## Also used by a mounted rail carriage as new objects enter its basket.
func capture_current_contents() -> void:
	for body in contained_bodies():
		var already_carried: bool = false
		for state in contents:
			if state.body.get_ref() == body:
				already_carried = true
				break
		if already_carried:
			continue
		var states: Array[Dictionary] = physics_items.collider_states(body)
		contents.append({"body": weakref(body), "pose": global_transform.affine_inverse() * body.global_transform,
			"freeze": body.freeze, "mode": body.freeze_mode, "states": states})
		physics_items.set_collisions(states, false)
		body.freeze = true
		body.linear_velocity = Vector3.ZERO
		body.angular_velocity = Vector3.ZERO


func _physics_process(_delta: float) -> void:
	on_held_transform_updated()
	for index in range(falling_contents.size() - 1, -1, -1):
		var reference: WeakRef = falling_contents[index]
		var body: RigidBody3D = reference.get_ref() as RigidBody3D
		if not is_instance_valid(body):
			falling_contents.remove_at(index)
			continue
		var point: Vector3 = to_local(body.global_position)
		if point.y + physics_items.support_extent(body, -global_basis.y) < 0.0 or absf(point.x) > 1.0 or absf(point.z) > .9:
			body.remove_collision_exception_with(self)
			falling_contents.remove_at(index)


## Follow immediately after pickup moves the basket, regardless of scene order.
func on_held_transform_updated() -> void:
	if not carried:
		return
	var previous_inverse: Transform3D = last_carry_pose.affine_inverse()
	for index in range(contents.size() - 1, -1, -1):
		var state: Dictionary = contents[index]
		var body: RigidBody3D = state.body.get_ref() as RigidBody3D
		if not is_instance_valid(body):
			contents.remove_at(index)
			continue
		if is_instance_valid(body) and body.is_inside_tree():
			var point: Vector3 = previous_inverse * body.global_position
			if absf(point.x) > 0.7 or absf(point.z) > 0.6 or point.y < 0.15 or point.y > 1.1:
				_restore(state, linear_velocity)
				contents.remove_at(index)
				continue
			body.global_transform = global_transform * state.pose
	last_carry_pose = global_transform


func on_released() -> void:
	on_held_transform_updated()
	carried = false
	for state in contents:
		_restore(state, linear_velocity)
	contents.clear()


func portal_transform_contents(pose_map: Transform3D, inside: bool) -> void:
	last_carry_pose = pose_map * last_carry_pose
	for content in contents:
		for state in content.states:
			state.layer = portal_space.remap_mask(state.layer, inside)
			state.mask = portal_space.remap_mask(state.mask, inside)


func _restore(state: Dictionary, velocity: Vector3) -> void:
	var body: RigidBody3D = state.body.get_ref() as RigidBody3D
	if not is_instance_valid(body):
		return
	physics_items.set_collisions(state.states, true)
	body.freeze_mode = state.mode
	body.freeze = state.freeze
	body.sleeping = false
	body.linear_velocity = velocity


func interact() -> void:
	empty_contents()


func empty_contents() -> void:
	on_held_transform_updated()
	if not carried:
		for body in contained_bodies():
			contents.append({"body": weakref(body), "freeze": body.freeze, "mode": body.freeze_mode,
				"states": physics_items.collider_states(body)})
	for i in contents.size():
		var state: Dictionary = contents[i]
		var body: RigidBody3D = state.body.get_ref() as RigidBody3D
		if is_instance_valid(body):
			body.add_collision_exception_with(self)
			falling_contents.append(weakref(body))
		_restore(state, Vector3.ZERO)
		if is_instance_valid(body) and body.is_inside_tree():
			body.angular_velocity = Vector3.ZERO
	contents.clear()


func _exit_tree() -> void:
	on_released()
	for reference in falling_contents:
		var body: RigidBody3D = reference.get_ref() as RigidBody3D
		if is_instance_valid(body):
			body.remove_collision_exception_with(self)
