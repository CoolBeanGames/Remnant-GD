
class_name player_pickup
extends Node

signal object_picked_up(object: RigidBody3D)

@export_category("References")
@export var ray: raycaster
@export var hold_position: Node3D
@export var player_body: PhysicsBody3D
@export var placement: prop_placement

@export_category("Hold Settings")
@export var hold_position_speed: float = 16.0
@export var hold_rotation_speed: float = 16.0
@export_range(0.0, 1.0) var held_transparency: float = 0.35
@export_range(1, 12, 1) var grab_capacity: int = 1
@export var grab_radius: float = 1.2

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
var held_visual_state: Array[Dictionary] = []
var held_attachments: Array[WeakRef] = []
var extra_items: Array[Dictionary] = []


func _ready() -> void:
	_debug("Ready.")

	if ray == null:
		push_warning("PlayerPickup: Ray reference is missing.")

	if hold_position == null:
		push_warning("PlayerPickup: Hold position reference is missing.")

	if player_body == null:
		push_warning("PlayerPickup: Player Body reference is missing.")


func _process(delta: float) -> void:
	if Blackboard.read_data("player_input_blocked"):
		return
	if is_holding_object() and (Dialogue.view == null or not Dialogue.view.blocks_confirm()) and Input.is_action_just_released("confirm") and held_object.has_method("empty_contents"):
		held_object.empty_contents()
	elif is_holding_object() and (Dialogue.view == null or not Dialogue.view.blocks_confirm()) and Input.is_action_just_released("confirm") and held_object is switchable_prop and (placement == null or not placement.is_building()):
		held_object.interact()
	if held_object != null and not is_instance_valid(held_object):
		_debug("Held object was freed.")
		_restore_carry_state()
		held_object = null
		held_collision_state.clear()
		_reset_throw_charge()

	if Input.is_action_just_released("pickup"):
		if placement != null and placement.is_building():
			placement.cancel_building()
			return
		_debug("Pickup input released.")
		if is_holding_object():
			drop_object()
		else:
			try_pickup()

		return

	if is_holding_object() and (placement == null or not placement.is_building()):
		_handle_throw_input(delta)


func _unhandled_input(event: InputEvent) -> void:
	if Blackboard.read_data("player_input_blocked") or not is_holding_object() or not held_object is rotatable_item:
		return
	if placement != null and placement.is_building():
		return
	if event.is_action_pressed("rotate_axis"):
		held_object.cycle_rotation_axis()
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP or event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			held_object.rotate_held(1.0 if event.button_index == MOUSE_BUTTON_WHEEL_UP else -1.0)
			get_viewport().set_input_as_handled()


func _physics_process(delta: float) -> void:
	if not is_holding_object():
		return

	if hold_position == null:
		return

	_update_held_object(delta)
	for state in extra_items:
		var body: RigidBody3D = state.node.get_ref() as RigidBody3D
		if is_instance_valid(body):
			body.global_transform = held_object.global_transform * state.pose
	_refresh_carry_visuals()


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
	if target.has_method("read_note"):
		target.read_note()
		return true

	_debug("Target: %s" % str(target.get_path()))
	_debug("Groups: %s" % str(target.get_groups()))

	if not target.is_in_group("pick-up") and not target.is_in_group("prestige items"):
		_debug("FAILED: Object is not in group 'pick-up'.")
		return false

	if not target is RigidBody3D:
		_debug("FAILED: Object is not a RigidBody3D.")
		return false

	return pickup_object(target as RigidBody3D)


## Shared pickup entry point for loose props and scripted interactions.
func pickup_object(target: RigidBody3D) -> bool:
	if is_holding_object() or not is_instance_valid(target) or hold_position == null or physics_items.prestige_locked(target):
		return false
	var cargo_owner: Variant = target.get_meta("rail_cargo_owner") if target.has_meta("rail_cargo_owner") else null
	if cargo_owner is WeakRef:
		var carriage: Object = cargo_owner.get_ref()
		if is_instance_valid(carriage) and carriage.has_method("release_cargo_body"):
			carriage.release_cargo_body(target)
	held_object = target
	if target.has_method("on_picked_up"):
		target.on_picked_up()

	# Save original physics state.
	original_freeze = held_object.freeze
	original_freeze_mode = held_object.freeze_mode
	_disable_held_collisions(held_object)
	_set_carry_visuals(held_object)
	held_object.set_meta("carried_by_player", true)
	if held_object.has_method("get_carried_bodies"):
		for body in held_object.get_carried_bodies():
			_set_carry_visuals(body)
	for prop in get_tree().get_nodes_in_group("placed-prop"):
		if prop is rotatable_item and prop != held_object and _belongs_to_carry(prop):
			held_attachments.append(weakref(prop))
			prop.set_meta("carried_by_player", true)
			_disable_held_collisions(prop)
			_set_carry_visuals(prop)

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

	_collect_extra_items()
	object_picked_up.emit(held_object)
	_debug("PICKUP SUCCESS: %s" % held_object.name)

	return true


func _collect_extra_items() -> void:
	if grab_capacity <= 1 or held_object.is_in_group("machine-immune"):
		return
	var query := PhysicsShapeQueryParameters3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = maxf(0.01, grab_radius)
	query.shape = sphere
	query.transform.origin = held_object.global_position
	query.collision_mask = player_body.collision_mask
	query.exclude = [held_object.get_rid(), player_body.get_rid()]
	var hits := held_object.get_world_3d().direct_space_state.intersect_shape(query, 64)
	hits.sort_custom(func(a: Dictionary, b: Dictionary): return a.collider.global_position.distance_squared_to(held_object.global_position) < b.collider.global_position.distance_squared_to(held_object.global_position))
	var seen: Array[RID] = []
	for hit in hits:
		var body: RigidBody3D = physics_items.rigid_body(hit.collider)
		if not physics_items.is_processable(body) or seen.has(body.get_rid()):
			continue
		seen.append(body.get_rid())
		extra_items.append({"node": weakref(body), "freeze": body.freeze, "mode": body.freeze_mode, "pose": held_object.global_transform.affine_inverse() * body.global_transform})
		_disable_held_collisions(body)
		_set_carry_visuals(body, held_object)
		body.freeze_mode = RigidBody3D.FREEZE_MODE_KINEMATIC
		body.freeze = true
		body.linear_velocity = Vector3.ZERO
		body.angular_velocity = Vector3.ZERO
		body.set_meta("carried_by_player", true)
		if extra_items.size() >= grab_capacity - 1:
			break

func _release_extra_items(velocity: Vector3 = Vector3.ZERO) -> void:
	for state in extra_items:
		var body: RigidBody3D = state.node.get_ref() as RigidBody3D
		if is_instance_valid(body):
			body.freeze = state.freeze
			body.freeze_mode = state.mode
			body.linear_velocity = velocity
			body.sleeping = false
			body.remove_meta("carried_by_player")
	extra_items.clear()


## Move the complete carried assembly at once, preserving its local poses.
func teleport_held(pose_map: Transform3D, inside: bool) -> void:
	if not is_holding_object():
		return
	var actors: Array[Node3D] = [physics_items.item_root(held_object)]
	for state in extra_items:
		var body: RigidBody3D = state.node.get_ref() as RigidBody3D
		if is_instance_valid(body):
			var actor: Node3D = physics_items.item_root(body)
			if not actors.has(actor):
				actors.append(actor)
	for reference in held_attachments:
		var actor: Node3D = reference.get_ref() as Node3D
		if is_instance_valid(actor) and not actors.has(actor):
			actors.append(actor)
	var container_index: int = 0
	while container_index < actors.size():
		var container: Node3D = actors[container_index]
		if container.has_method("get_carried_bodies"):
			for body in container.get_carried_bodies():
				var actor: Node3D = physics_items.item_root(body)
				if is_instance_valid(actor) and not actors.has(actor):
					actors.append(actor)
		container_index += 1
	var poses: Array[Transform3D] = []
	for actor in actors:
		poses.append(actor.global_transform)
	for index in actors.size():
		actors[index].global_transform = pose_map * poses[index]
		portal_space.apply_actor(actors[index], inside)
	for state in held_collision_state:
		state.layer = portal_space.remap_mask(state.layer, inside)
		state.mask = portal_space.remap_mask(state.mask, inside)
	for actor in actors:
		if actor.has_method("portal_transform_contents"):
			actor.portal_transform_contents(pose_map, inside)
	if held_object.has_method("on_held_transform_updated"):
		held_object.on_held_transform_updated()
	_sync_attachments()


func _update_held_object(delta: float) -> void:
	_sync_attachments()
	if held_object.has_method("update_equipped_pose"):
		held_object.update_equipped_pose(player_body, hold_position, delta)
		_sync_attachments()
		return
	var position_weight: float = 1.0 - exp(
		-hold_position_speed * delta
	)

	var rotation_weight: float = 1.0 - exp(
		-hold_rotation_speed * delta
	)

	var target_position: Vector3 = hold_position.global_position
	if held_object.has_method("get_hold_offset"):
		target_position += hold_position.global_basis * held_object.get_hold_offset()

	var target_basis: Basis = hold_position.global_basis
	if held_object.has_method("get_hold_rotation"):
		target_basis *= held_object.get_hold_rotation()
	var target_rotation: Quaternion = target_basis.get_rotation_quaternion()

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
	if held_object is rotatable_item:
		new_rotation = target_rotation

	held_object.global_transform = Transform3D(
		Basis(new_rotation),
		new_position
	)
	if held_object.has_method("on_held_transform_updated"):
		held_object.on_held_transform_updated()
	_sync_attachments()


func _sync_attachments() -> void:
	# Keep parents before children so an attached fan follows its lamp immediately.
	var index: int = 0
	while index < held_attachments.size():
		var reference: WeakRef = held_attachments[index]
		var prop: rotatable_item = reference.get_ref() as rotatable_item
		if not is_instance_valid(prop):
			held_attachments.remove_at(index)
			continue
		if not prop.placed or not _belongs_to_carry(prop):
			prop.remove_meta("carried_by_player")
			for state_index in range(held_collision_state.size() - 1, -1, -1):
				var state: Dictionary = held_collision_state[state_index]
				var collider: CollisionObject3D = state.collider as CollisionObject3D
				if is_instance_valid(collider) and (collider == prop or prop.is_ancestor_of(collider)):
					collider.collision_layer = state.layer
					collider.collision_mask = state.mask
					held_collision_state.remove_at(state_index)
			held_attachments.remove_at(index)
			continue
		else:
			prop.sync_support_pose()
			if prop.has_method("on_held_transform_updated"):
				prop.on_held_transform_updated()
		index += 1


func _belongs_to_carry(prop: rotatable_item) -> bool:
	if prop.is_supported_by(held_object):
		return true
	if held_object.has_method("get_carried_bodies"):
		for body in held_object.get_carried_bodies():
			if prop.is_supported_by(body):
				return true
	return false


func _set_carry_visuals(node: Node, owner: Node = null) -> void:
	if owner == null:
		owner = node
	if node is GeometryInstance3D:
		for state in held_visual_state:
			if state.node.get_ref() == node:
				return
		held_visual_state.append({"node": weakref(node), "owner": weakref(owner), "transparency": node.transparency})
		node.transparency = 1.0 - (1.0 - node.transparency) * (1.0 - held_transparency)
	for child in node.get_children():
		_set_carry_visuals(child, owner)


func _refresh_carry_visuals() -> void:
	var owners: Dictionary = {held_object: true}
	for reference in held_attachments:
		var prop: Node = reference.get_ref()
		if is_instance_valid(prop):
			owners[prop] = true
	if held_object.has_method("get_carried_bodies"):
		for body in held_object.get_carried_bodies():
			owners[body] = true
			_set_carry_visuals(body)
	for index in range(held_visual_state.size() - 1, -1, -1):
		var state: Dictionary = held_visual_state[index]
		if not owners.has(state.owner.get_ref()):
			var visual: GeometryInstance3D = state.node.get_ref() as GeometryInstance3D
			if is_instance_valid(visual):
				visual.transparency = state.transparency
			held_visual_state.remove_at(index)


func _handle_throw_input(delta: float) -> void:
	if held_object.has_method("can_throw") and not held_object.can_throw():
		_reset_throw_charge()
		return
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
	if placement != null and placement.is_building():
		placement.cancel_building()
	if not is_holding_object():
		return

	var object_to_drop: RigidBody3D = held_object

	_debug("DROPPING: %s" % object_to_drop.name)

	_restore_object_physics(object_to_drop)
	if object_to_drop.has_method("on_released"):
		object_to_drop.on_released()

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
	if object_to_throw.has_method("can_throw") and not object_to_throw.can_throw():
		_reset_throw_charge()
		return

	_debug("THROWING: %s" % object_to_throw.name)
	_debug("Force: %.2f" % force)
	_release_extra_items(direction * force)

	_restore_object_physics(object_to_throw)

	object_to_throw.linear_velocity = direction * force
	if object_to_throw.has_method("on_released"):
		object_to_throw.on_released()

	held_object = null
	_reset_throw_charge()


func _restore_object_physics(object: RigidBody3D) -> void:
	object.remove_meta("carried_by_player")
	_restore_carry_state()
	object.freeze = original_freeze
	object.freeze_mode = original_freeze_mode
	object.sleeping = false
	if is_instance_valid(player_body):
		object.remove_collision_exception_with(player_body)
		player_body.remove_collision_exception_with(object)
	_debug("Object physics restored.")


func _restore_carry_state() -> void:
	_release_extra_items()
	for reference in held_attachments:
		var prop: rotatable_item = reference.get_ref() as rotatable_item
		if is_instance_valid(prop):
			prop.remove_meta("carried_by_player")
	held_attachments.clear()
	for state in held_visual_state:
		var visual: GeometryInstance3D = state.node.get_ref() as GeometryInstance3D
		if is_instance_valid(visual):
			visual.transparency = state.transparency
	held_visual_state.clear()
	for state in held_collision_state:
		var collider: Variant = state["collider"]
		if is_instance_valid(collider):
			collider.collision_layer = state["layer"]
			collider.collision_mask = state["mask"]
	held_collision_state.clear()


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

func _exit_tree() -> void:
	# Replacing/removing a player must not leave its surviving carried props frozen.
	if is_holding_object():
		drop_object()
	else:
		_restore_carry_state()
