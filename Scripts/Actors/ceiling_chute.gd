class_name ceiling_chute
extends Node3D

@export var spawn_point: Node3D
@export var item_pool: item_spawn_pool = preload("res://Data/Items/default_spawn_pool.tres")
@export var enabled: bool = true
@export var item_exit_speed: float = 3.0
@export_category("Notes")
@export var notes_catalog: note_catalog = preload("res://Data/Notes/default_catalog.tres")
## Normal play defaults to 2%; override in the inspector.
@export_range(0.0, 1.0, 0.01) var note_drop_chance: float = 0.02
@export var note_scene: PackedScene = preload("res://Scenes/Actors/note_drop.tscn")
@export var note_exit_speed: float = 3.0

@export_category("Manual Batches")
@export_range(.05, 1, .01) var batch_spawn_spacing: float = .15
## Empty disables queue persistence for an additional independent chute.
@export var batch_save_key: String = "manual_spawn_queue"
var queued_spawns: int = 0
var batch_remaining: float = 0.0

func _ready() -> void:
	if not batch_save_key.is_empty():
		var saved: Variant = Blackboard.read_data(batch_save_key)
		if saved is int:
			queued_spawns = maxi(0, saved)
			batch_remaining = batch_spawn_spacing

## Each successful manual pull counts once, regardless of its individual drops.
func spawn_batch(count: int) -> void:
	if not enabled:
		return
	queued_spawns += clampi(count, 1, 16)
	_save_queue()
	if batch_remaining <= 0:
		_drain_batch()

func _physics_process(delta: float) -> void:
	if not enabled:
		return
	batch_remaining = maxf(0, batch_remaining - delta)
	if queued_spawns > 0 and batch_remaining <= 0:
		_drain_batch()

func _drain_batch() -> void:
	queued_spawns -= 1
	batch_remaining = maxf(.05, batch_spawn_spacing)
	_save_queue()
	spawn()

func _save_queue() -> void:
	if not batch_save_key.is_empty():
		Blackboard.store_data(batch_save_key, queued_spawns)


func spawn():
	if not enabled or not is_instance_valid(spawn_point):
		return
	var world: Node = Blackboard.read_data("game_root") as Node
	if world == null:
		world = get_parent()
	if note_scene != null and notes_catalog != null and randf() < note_drop_chance:
		var available: Array[note_definition] = notes_catalog.available()
		if not available.is_empty():
			var instance: Node = note_scene.instantiate()
			if instance is note_drop:
				var drop: note_drop = instance as note_drop
				drop.note = available.pick_random()
				world.add_child(drop)
				drop.global_transform = spawn_point.global_transform
				drop.linear_velocity = Vector3.DOWN * note_exit_speed
				WorldState.track(drop)
				return
			else:
				instance.free()
	var scene: PackedScene = item_pool.pick_item() if item_pool != null else null
	var actor: Node3D = WorldState.spawn_item(scene, world, spawn_point.global_transform, true)
	if actor != null:
		for body in WorldState._bodies(actor):
			body.linear_velocity = Vector3.DOWN * item_exit_speed
