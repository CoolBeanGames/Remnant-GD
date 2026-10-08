class_name grinding_area
extends Area3D

@export var grind_sound: AudioStream = preload("res://Audio/SFX/grind.wav")
@export var grind_volume: float = 1.0


func _ready() -> void:
	if not Blackboard.data_exists("score"):
		Blackboard.store_data("score", 0)
	monitoring = true
	if not body_entered.is_connected(grind):
		body_entered.connect(grind)


## Loose rigid bodies are items; static scenery and characters are left alone.
func grind(body: Node3D) -> bool:
	if not is_instance_valid(body):
		return false
	var rigid: RigidBody3D = _find_rigid_body(body)
	if rigid == null:
		return false
	var item: Node3D = _find_item_root(rigid)
	# Several imported colliders may enter before deferred deletion is processed.
	if item.is_queued_for_deletion() or rigid.is_queued_for_deletion():
		return false
	if _is_scoring_item(body, item):
		var component: score_object = _find_score_object(item)
		var amount: int = component.score if component != null else 1
		ScoreRewards.enqueue(amount)
	Audio.play_global(grind_sound, grind_volume, 1.0, &"SFX")
	item.queue_free()
	return true


func _find_rigid_body(body: Node) -> RigidBody3D:
	var current: Node = body
	while is_instance_valid(current):
		if current is RigidBody3D:
			return current as RigidBody3D
		if current is CharacterBody3D:
			return null
		current = current.get_parent()
	return null


## A wrapper marked grindable/score is destroyed with all its physics children.
## Unmarked loose bodies are destroyed individually; never infer the level as owner.
func _find_item_root(rigid: RigidBody3D) -> Node3D:
	var item: Node3D = rigid
	var current: Node = rigid.get_parent()
	var world_root: Node = Blackboard.read_data("game_root") as Node
	while current is Node3D and current != world_root and current != get_tree().current_scene:
		if current is PhysicsBody3D:
			break
		if current.is_in_group("grindable") or current.is_in_group("score"):
			item = current as Node3D
			break
		current = current.get_parent()
	return item


func _is_scoring_item(body: Node, item: Node) -> bool:
	var current: Node = body
	while is_instance_valid(current):
		if current.is_in_group("score"):
			return true
		if current == item:
			break
		current = current.get_parent()
	return false


func _find_score_object(node: Node) -> score_object:
	# Prefer a direct child; also support components inside a collider/model wrapper.
	for child in node.get_children():
		if child is score_object:
			return child as score_object
	for child in node.get_children():
		var component: score_object = _find_score_object(child)
		if component != null:
			return component
	return null
