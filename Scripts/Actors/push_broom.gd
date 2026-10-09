extends RigidBody3D

@export var carry_prompts: prompt_set
@export var hold_distance: float = 1.5
@export var stroke_distance: float = 0.8
@export var push_acceleration: float = 52.5
@export var maximum_speed: float = 7.5
var held: bool = false
var stroke_time: float = 0.0
var direction: Vector3 = Vector3.FORWARD

func can_throw() -> bool:
	return false

func get_carry_prompts() -> prompt_set:
	return carry_prompts

func on_picked_up() -> void:
	held = true
	stroke_time = 0.0

func on_released() -> void:
	held = false
	stroke_time = 0.0
	$Sweep.collision_mask = 0

func _unhandled_input(event: InputEvent) -> void:
	if held and not Blackboard.read_data("player_input_blocked") and event.is_action_pressed("push"):
		push()
		get_viewport().set_input_as_handled()

func push() -> void:
	if held and stroke_time <= 0.0:
		stroke_time = .45

func update_equipped_pose(player: PhysicsBody3D, marker: Node3D, delta: float) -> void:
	direction = -marker.global_basis.z
	direction.y = 0
	direction = direction.normalized()
	if direction.is_zero_approx():
		direction = -player.global_basis.z
	var extension: float = 0.0
	if stroke_time > 0.0:
		var elapsed: float = .45 - stroke_time
		extension = elapsed / .18 if elapsed < .18 else 1.0 - (elapsed - .18) / .27
		stroke_time = maxf(0.0, stroke_time - delta)
	var point: Vector3 = player.global_position + direction * (hold_distance + clampf(extension, 0, 1) * stroke_distance)
	var query := PhysicsRayQueryParameters3D.create(point + Vector3.UP * 1.2, point - Vector3.UP * 2.0, player.collision_mask)
	query.exclude = [get_rid(), player.get_rid()]
	var hit: Dictionary = {}
	for i in 12:
		hit = get_world_3d().direct_space_state.intersect_ray(query)
		if hit.is_empty() or not hit.collider is RigidBody3D:
			break
		# Loose items under the head must not lift the broom off the floor.
		var excluded: Array[RID] = query.exclude
		excluded.append(hit.collider.get_rid())
		query.exclude = excluded
		hit = {}
	if not hit.is_empty():
		point.y = hit.position.y + .02
	global_transform = Transform3D(Basis.looking_at(direction, Vector3.UP), point)
	$Sweep.collision_mask = player.collision_mask

func _physics_process(delta: float) -> void:
	if not held or stroke_time < .27:
		return
	for collider in $Sweep.get_overlapping_bodies():
		var body: RigidBody3D = physics_items.rigid_body(collider)
		if body == self or not physics_items.is_processable(body):
			continue
		var increase: float = minf(maxf(0, maximum_speed - body.linear_velocity.dot(direction)), push_acceleration * delta)
		body.sleeping = false
		body.apply_central_impulse(direction * increase * body.mass)
