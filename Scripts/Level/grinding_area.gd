class_name grinding_area
extends Area3D

signal item_ground(points: float)
signal player_entered(player: CharacterBody3D)

@export var grind_sound: AudioStream = preload("res://Audio/SFX/grind.wav")
@export var grind_volume: float = 1.0
@export var enabled: bool = true
var grind_audio: WeakRef
var grind_playback_id: int = -1
var player_contact_pending: bool = false


func _ready() -> void:
	if not Blackboard.data_exists("score"):
		Blackboard.store_data("score", 0)
	monitoring = true
	if not body_entered.is_connected(grind):
		body_entered.connect(grind)


## Loose rigid bodies are items; static scenery and characters are left alone.
func grind(body: Node3D) -> bool:
	if not enabled or not is_instance_valid(body):
		return false
	if body is CharacterBody3D:
		if not player_contact_pending:
			player_contact_pending = true
			player_entered.emit(body)
		return false
	var rigid: RigidBody3D = _find_rigid_body(body)
	var pellet: mulch_pellet = rigid as mulch_pellet
	if not physics_items.is_processable(rigid) and not (physics_items.is_loose(pellet) and pellet.can_grind()):
		return false
	var item: Node3D = _find_item_root(rigid)
	# Several imported colliders may enter before deferred deletion is processed.
	if item.is_queued_for_deletion() or rigid.is_queued_for_deletion():
		return false
	var amount: float = 0.0
	if pellet != null:
		amount = maxf(0, pellet.stored_score)
	elif _is_scoring_item(body, item):
		var component: score_object = physics_items.score_component(item)
		amount = component.score if component != null else 1
	if pellet == null:
		Mulch.consume(item, amount)
	GrindCombo.record_item(amount)
	_play_grind_sound()
	WorldState.untrack(item)
	item.queue_free()
	item_ground.emit(amount)
	return true

func _play_grind_sound() -> void:
	var existing: audio_player = grind_audio.get_ref() as audio_player if grind_audio != null else null
	if is_instance_valid(existing) and existing.is_playback_active(grind_playback_id):
		return
	var audio: audio_player = Audio.play_global(grind_sound, grind_volume, 1.0, &"SFX")
	grind_audio = weakref(audio) if audio != null else null
	grind_playback_id = audio.playback_id if audio != null else -1

func set_enabled(value: bool) -> void:
	enabled = value
	set_deferred("monitoring", value)


func _find_rigid_body(body: Node) -> RigidBody3D:
	return physics_items.rigid_body(body)


## A wrapper marked grindable/score is destroyed with all its physics children.
## Unmarked loose bodies are destroyed individually; never infer the level as owner.
func _find_item_root(rigid: RigidBody3D) -> Node3D:
	return physics_items.item_root(rigid)


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
	# Compatibility helper; use the common imported-item resolver.
	return physics_items.score_component(node)
