
class_name player_pickup
extends Node

@export_category("References")
@export var ray: raycaster
@export var hold_position: Node3D
@export var player_body: PhysicsBody3D
@export var building: player_building

@export_category("Hold Settings")
@export var hold_position_speed: float = 16.0
@export var hold_rotation_speed: float = 16.0

@export_category("Throw Settings")
@export var minimum_throw_force: float = 3.0
@export var maximum_throw_force: float = 20.0
@export var charge_time: float = 2.0

@export_category("Debug")
@export var debug_enabled: bool = false

var held_object: RigidBody3D = null
var throw_charge: float = 0.0
var charging_throw: bool = false

var original_freeze: bool = false
var original_freeze_mode: RigidBody3D.FreezeMode = RigidBody3D.FREEZE_MODE_STATIC
## Imported models can contain extra bodies/areas below the held rigid body.
var held_collision_state: Array[Dictionary] = []


func _ready() -> void:
	_debug("Ready.")

	if ray == null:
		push_warning("PlayerPickup: Ray reference is missing.")

	if hold_position == null:
		push_warning("PlayerPickup: Hold position reference is missing.")

	if player_body == null:
		push_warning("PlayerPickup: Player Body reference is missing.")


func _process(delta: float) -> void:
	if held_object != null and not is_instance_valid(held_object):
		_debug("Held object was freed.")
		held_object = null
		held_collision_state.clear()
		_reset_throw_charge()

	if Input.is_action_just_released("pickup"):
		_debug("Pickup input released.")
		if building != null and building.is_building():
			building.cancel_building()
			return

		if is_holding_object():
			drop_object()
		else:
			try_pickup()

		return

	if is_holding_object() and (building == null or not building.is_building()):
		_handle_throw_input(delta)


func _physics_process(delta: float) -> void:
	if not is_holding_object():
		return

	if hold_position == null:
		return

	_update_held_object(delta)


func try_pickup() -> bool:
	_debug("Pickup attempt started.")

	if is_holding_object():
		_debug("FAILED: Already holding an object.")
		return false

	if ray == null or hold_position == null:
		_debug("FAILED: Missing required references.")
		return false

	if not ray.is_looking_at_something():
		_debug("FAILED: Raycaster has no valid target.")
		return false

	var target: Node3D = ray.get_looked_at()

	if not is_instance_valid(target):
		_debug("FAILED: Invalid target.")
		return false

	_debug("Target: %s" % str(target.get_path()))
	_debug("Groups: %s" % str(target.get_groups()))

	if not target.is_in_group("pick-up"):
		_debug("FAILED: Object is not in group 'pick-up'.")
		return false

	if not target is RigidBody3D:
		_debug("FAILED: Object is not a RigidBody3D.")
		return false

	return pickup_object(target as RigidBody3D)


## Also used to receive a package directly when a building is unbuilt.
func pickup_object(target: RigidBody3D) -> bool:
	if is_holding_object() or not is_instance_valid(target) or hold_position == null:
		return false
	held_object = target

	# Save original physics state.
	original_freeze = held_object.freeze
	original_freeze_mode = held_object.freeze_mode
	_disable_held_collisions(held_object)

	# Ignore collisions between the player and the held object.
	if player_body != null:
		held_object.add_collision_exception_with(player_body)
		player_body.add_collision_exception_with(held_object)
		_debug("Player/object collision exceptions added.")

	# Freeze physics while allowing smooth scripted movement.
	held_object.linear_velocity = Vector3.ZERO
	held_object.angular_velocity = Vector3.ZERO
	held_object.freeze_mode = RigidBody3D.FREEZE_MODE_KINEMATIC
	held_object.freeze = true

	_reset_throw_charge()

	_debug("PICKUP SUCCESS: %s" % held_object.name)

	return true


## Consume exactly the package that was placed and clear all holding/throw state.
func consume_held_object(expected: RigidBody3D) -> bool:
	if not is_holding_object() or held_object != expected:
		return false
	drop_object()
	expected.queue_free()
	return true


func _update_held_object(delta: float) -> void:
	var position_weight: float = 1.0 - exp(
		-hold_position_speed * delta
	)

	var rotation_weight: float = 1.0 - exp(
		-hold_rotation_speed * delta
	)

	var target_position: Vector3 = hold_position.global_position

	var target_rotation: Quaternion = (
		hold_position.global_transform.basis.get_rotation_quaternion()
	)

	var new_position: Vector3 = held_object.global_position.lerp(
		target_position,
		position_weight
	)

	var current_rotation: Quaternion = (
		held_object.global_transform.basis.get_rotation_quaternion()
	)

	var new_rotation: Quaternion = current_rotation.slerp(
		target_rotation,
		rotation_weight
	)

	held_object.global_transform = Transform3D(
		Basis(new_rotation),
		new_position
	)


func _handle_throw_input(delta: float) -> void:
	if Input.is_action_just_pressed("throw"):
		charging_throw = true
		throw_charge = 0.0
		_debug("Throw charging started.")

	if Input.is_action_pressed("throw"):
		if not charging_throw:
			charging_throw = true

		if charge_time > 0.0:
			throw_charge = minf(
				throw_charge + delta,
				charge_time
			)

	if charging_throw and Input.is_action_just_released("throw"):
		_debug("Throw released.")
		throw_object()


func drop_object() -> void:
	if not is_holding_object():
		return

	var object_to_drop: RigidBody3D = held_object

	_debug("DROPPING: %s" % object_to_drop.name)

	_restore_object_physics(object_to_drop)

	held_object = null
	_reset_throw_charge()


func throw_object() -> void:
	if not is_holding_object():
		return

	if hold_position == null:
		return

	var charge_ratio: float = 1.0

	if charge_time > 0.0:
		charge_ratio = clampf(
			throw_charge / charge_time,
			0.0,
			1.0
		)

	var force: float = lerpf(
		minimum_throw_force,
		maximum_throw_force,
		charge_ratio
	)

	var direction: Vector3 = (
		-hold_position.global_transform.basis.z
	).normalized()

	var object_to_throw: RigidBody3D = held_object

	_debug("THROWING: %s" % object_to_throw.name)
	_debug("Force: %.2f" % force)

	_restore_object_physics(object_to_throw)

	object_to_throw.linear_velocity = direction * force

	held_object = null
	_reset_throw_charge()


func _restore_object_physics(object: RigidBody3D) -> void:
	for state in held_collision_state:
		var collider: Variant = state["collider"]
		if is_instance_valid(collider):
			collider.collision_layer = state["layer"]
			collider.collision_mask = state["mask"]
	held_collision_state.clear()
	object.freeze = original_freeze
	object.freeze_mode = original_freeze_mode
	object.sleeping = false

	if player_body != null:
		object.remove_collision_exception_with(player_body)
		player_body.remove_collision_exception_with(object)

	_debug("Object physics restored.")


func _disable_held_collisions(node: Node) -> void:
	if node is CollisionObject3D:
		held_collision_state.append({
			"collider": node,
			"layer": node.collision_layer,
			"mask": node.collision_mask
		})
		# A held item is a visual carried object, including any imported colliders.
		node.collision_layer = 0
		node.collision_mask = 0
	for child in node.get_children():
		_disable_held_collisions(child)


## Physics queries must exclude the whole package, not just its root body.
func get_held_collision_rids() -> Array[RID]:
	var excluded: Array[RID] = []
	if not is_holding_object():
		return excluded
	for state in held_collision_state:
		var collider: Variant = state["collider"]
		if is_instance_valid(collider):
			excluded.append(collider.get_rid())
	return excluded


func _reset_throw_charge() -> void:
	throw_charge = 0.0
	charging_throw = false


func cancel_throw_charge() -> void:
	_reset_throw_charge()


func is_holding_object() -> bool:
	return is_instance_valid(held_object)


func _debug(message: String) -> void:
	if debug_enabled:
		print("[PlayerPickup] ", message)
