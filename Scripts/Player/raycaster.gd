class_name raycaster
extends RayCast3D

@export_category("Raycast Settings")
@export var ray_distance: float = 3.0
@export var target_groups: Array[StringName] = []

@export_category("Debug")
@export var debug_enabled: bool = false

var looked_at: Node3D = null
var previous_target: Node3D = null


func _ready() -> void:
	target_position = Vector3(0.0, 0.0, -ray_distance)
	enabled = true
	collide_with_areas = true

	_debug("Ready. Distance: %s" % ray_distance)
	_debug("Target groups: %s" % str(target_groups))


func _physics_process(_delta: float) -> void:
	target_position = Vector3(0.0, 0.0, -ray_distance)

	# Overlapping enlarged targets must not hide the next reachable physical item.
	# Remove only temporary area exceptions; solid walls still stop the ray.
	var skipped: Array[CollisionObject3D] = []
	for attempt in 12:
		force_raycast_update()
		var collider: Object = get_collider()
		if collider is pickup_target and (not collider.can_target() or _pickup_occluded(collider)):
			add_exception(collider)
			skipped.append(collider)
		else:
			break
	_update_looked_at()
	for area in skipped:
		remove_exception(area)


func _update_looked_at() -> void:
	if not is_colliding():
		if is_instance_valid(looked_at):
			_debug("Stopped looking at: %s" % looked_at.get_path())

		_set_looked_at(null)
		return

	var collider: Object = get_collider()
	if collider is pickup_target:
		if not collider.can_target() or _pickup_occluded(collider):
			_set_looked_at(null)
			return

	if collider == null:
		_set_looked_at(null)
		return

	if debug_enabled and collider is Node:
		var collider_node: Node = collider as Node
		_debug("Ray hit collider: %s" % str(collider))
		_debug("Collider path: %s" % collider_node.get_path())
		_debug("Collider groups: %s" % str(collider_node.get_groups()))

	var target: Node3D = _find_grouped_parent(collider)

	if target == null:
		_debug("No matching grouped object found.")
		_set_looked_at(null)
		return

	_set_looked_at(target)

func _pickup_occluded(area: pickup_target) -> bool:
	var query := PhysicsRayQueryParameters3D.create(global_position, area.body.global_position, collision_mask)
	var exclusions: Array[RID] = [area.body.get_rid()]
	var parent: Node = get_parent()
	while parent != null:
		if parent is PhysicsBody3D:
			exclusions.append(parent.get_rid())
		parent = parent.get_parent()
	query.exclude = exclusions
	return not get_world_3d().direct_space_state.intersect_ray(query).is_empty()


func _find_grouped_parent(object: Object) -> Node3D:
	if not object is Node:
		return null

	var current: Node = object as Node

	while current != null:
		if current is Node3D:
			var current_3d: Node3D = current as Node3D

			if debug_enabled:
				_debug("Checking: %s | Groups: %s" % [current_3d.get_path(), str(current_3d.get_groups())])

			if _is_valid_target(current_3d):
				_debug(
					"Found valid target: %s" %
					current_3d.get_path()
				)

				return current_3d

		current = current.get_parent()

	return null


func _is_valid_target(target: Node3D) -> bool:
	if not interaction_allowed(target) or physics_items.prestige_locked(target):
		return false
	if target.is_in_group("prestige items"):
		return true
	for group: StringName in target_groups:
		if target.is_in_group(group):
			return true

	return false


func _set_looked_at(target: Node3D) -> void:
	if target == looked_at:
		return

	if is_instance_valid(looked_at):
		_debug(
			"Stopped looking at: %s" %
			looked_at.get_path()
		)

	previous_target = looked_at
	looked_at = target

	if is_instance_valid(looked_at):
		_debug(
			"Now looking at: %s" %
			looked_at.get_path()
		)

		_debug(
			"Target groups: %s" %
			str(looked_at.get_groups())
		)


func get_looked_at() -> Node3D:
	return looked_at if is_instance_valid(looked_at) and interaction_allowed(looked_at) and not physics_items.prestige_locked(looked_at) else null


func is_looking_at_something() -> bool:
	return get_looked_at() != null

static func interaction_allowed(target: Node) -> bool:
	while is_instance_valid(target):
		if not target.get_meta("interaction_enabled", true):
			return false
		target = target.get_parent()
	return true


func _debug(message: String) -> void:
	if debug_enabled:
		print("[Raycaster] ", message)
		DevTools.log_info(message, "raycaster")
