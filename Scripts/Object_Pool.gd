class_name object_pool
extends Node


@export_category("Pool")
@export var pooled_scene: PackedScene
@export var initial_size: int = 0

@export_category("Reset")
@export var reset_method: StringName = &""

@export_category("Blackboard")
@export var register_with_blackboard: bool = false
@export var blackboard_name: StringName = &""


var available: Array[Node] = []
var active: Array[Node] = []


func _ready() -> void:
	if register_with_blackboard and blackboard_name != &"":
		Blackboard.store_data(blackboard_name, self)

	for i in initial_size:
		var object: Node = _create_object()

		if object != null:
			available.append(object)


func get_object() -> Node:
	var object: Node

	if available.is_empty():
		object = _create_object()
	else:
		object = available.pop_back()

	if object == null:
		return null

	active.append(object)

	return object


func release_object(object: Node) -> void:
	if object == null:
		return

	if not active.has(object):
		return

	active.erase(object)

	_reset_object(object)

	available.append(object)


func _create_object() -> Node:
	if pooled_scene == null:
		push_warning("Object pool has no pooled_scene assigned.")
		return null

	var object: Node = pooled_scene.instantiate()

	add_child(object)

	return object


func _reset_object(object: Node) -> void:
	if reset_method == &"":
		return

	if object.has_method(reset_method):
		object.call(reset_method)


func _exit_tree() -> void:
	if register_with_blackboard and Blackboard.read_data(blackboard_name) == self:
		Blackboard.remove_data(blackboard_name)
	available.clear()
	active.clear()
