class_name world_view_session
extends RefCounted

var tree: SceneTree
var original_camera_rotation: Vector3
var camera: Camera3D
var pose: Transform3D
var camera_mask: int
var previous_mouse: Input.MouseMode
var previous_block: Variant
var had_block: bool
var previous_pause: bool
var active: bool = false
var hidden: Array[Dictionary] = []
var motion: Tween

func begin(view: Camera3D, pause_world: bool) -> void:
	camera = view
	tree = camera.get_tree()
	original_camera_rotation = camera.rotation
	Blackboard.store_data("world_view_session", self)
	pose = camera.global_transform
	camera_mask = camera.cull_mask
	previous_mouse = Input.mouse_mode
	had_block = Blackboard.data_exists("player_input_blocked")
	previous_block = Blackboard.read_data("player_input_blocked")
	previous_pause = camera.get_tree().paused
	Blackboard.store_data("player_input_blocked", true)
	if pause_world:
		camera.get_tree().paused = true
	var owner_node: Node = camera.get_parent()
	var pickup: player_pickup = owner_node.get_node_or_null("Controllers/Player_Pickup")
	if pickup != null:
		_hide(pickup.held_object)
		if pickup.placement != null:
			_hide(pickup.placement.preview)
		for ref in pickup.held_attachments:
			_hide(ref.get_ref())
		for state in pickup.extra_items:
			_hide(state.node.get_ref())
	for hud in tree.get_nodes_in_group("gameplay_hud"):
		_hide(hud)
	active = true

func _hide(node: Node) -> void:
	if not is_instance_valid(node) or not (node is Node3D or node is CanvasItem or node is CanvasLayer):
		return
	for state in hidden:
		if state.node.get_ref() == node:
			return
	hidden.append({"node": weakref(node), "visible": node.get("visible")})
	node.call("hide")

## Blend position and shortest-path rotation, preserving exact restoration state.
func move_camera(owner_node: Node, target: Transform3D, seconds: float, finished: Callable = Callable()) -> void:
	stop_motion()
	if not is_instance_valid(camera):
		return
	if seconds <= 0:
		camera.global_transform = target
		if finished.is_valid():
			finished.call()
		return
	var start: Transform3D = camera.global_transform
	motion = owner_node.create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	motion.tween_method(_blend_camera.bind(start, target), 0.0, 1.0, seconds)
	if finished.is_valid():
		motion.tween_callback(finished)

func _blend_camera(weight: float, start: Transform3D, target: Transform3D) -> void:
	if active and is_instance_valid(camera):
		camera.global_transform = start.interpolate_with(target, weight)

func stop_motion() -> void:
	if motion != null and motion.is_valid():
		motion.kill()
	motion = null

func is_moving() -> bool:
	return motion != null and motion.is_running()

func restore() -> void:
	if not active:
		return
	active = false
	stop_motion()
	if is_instance_valid(camera):
		camera.global_transform = pose
		camera.cull_mask = camera_mask
	if is_instance_valid(tree):
		tree.paused = previous_pause
	if Blackboard.read_data("world_view_session") == self:
		Blackboard.remove_data("world_view_session")
	for state in hidden:
		var node: Node = state.node.get_ref() as Node
		if is_instance_valid(node):
			node.set("visible", state.visible)
	hidden.clear()
	if had_block:
		Blackboard.store_data("player_input_blocked", previous_block)
	else:
		Blackboard.remove_data("player_input_blocked")
	Input.mouse_mode = previous_mouse
