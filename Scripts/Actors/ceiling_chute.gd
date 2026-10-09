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
