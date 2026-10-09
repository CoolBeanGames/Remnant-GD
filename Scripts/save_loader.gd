extends Node
@export var game_scene: PackedScene = preload("res://Scenes/Game.tscn")

func _ready() -> void:
	_load.call_deferred()

func _load() -> void:
	get_tree().paused = false
	SaveGame.load_now()
	SaveGame.enabled = true
	get_tree().change_scene_to_packed(game_scene)
