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

	_debug("Ready. Distance: %s" % ray_distance)
	_debug("Target groups: %s" % str(target_groups))


func _physics_process(_delta: float) -> void:
	target_position = Vector3(0.0, 0.0, -ray_distance)

	force_raycast_update()

	_update_looked_at()


func _update_looked_at() -> void:
	if not is_colliding():
		if is_instance_valid(looked_at):
			_debug("Stopped looking at: %s" % looked_at.get_path())

		_set_looked_at(null)
		return

	var collider: Object = get_collider()

	if collider == null:
		_set_looked_at(null)
		return

	_debug("Ray hit collider: %s" % str(collider))

	if collider is Node:
		var collider_node: Node = collider as Node

		_debug("Collider path: %s" % collider_node.get_path())
		_debug("Collider groups: %s" % str(collider_node.get_groups()))

	var target: Node3D = _find_grouped_parent(collider)

	if target == null:
		_debug("No matching grouped object found.")
		_set_looked_at(null)
		return

	_set_looked_at(target)


func _find_grouped_parent(object: Object) -> Node3D:
	if not object is Node:
		return null

	var current: Node = object as Node

	while current != null:
		if current is Node3D:
			var current_3d: Node3D = current as Node3D

			_debug(
				"Checking: %s | Groups: %s" %
				[
					current_3d.get_path(),
					str(current_3d.get_groups())
				]
			)

			if _is_valid_target(current_3d):
				_debug(
					"Found valid target: %s" %
					current_3d.get_path()
				)

				return current_3d

		current = current.get_parent()

	return null


func _is_valid_target(target: Node3D) -> bool:
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
	return looked_at


func is_looking_at_something() -> bool:
	return is_instance_valid(looked_at)


func _debug(message: String) -> void:
	if debug_enabled:
		print("[Raycaster] ", message)
