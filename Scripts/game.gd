extends Node

func _ready() -> void:
	Blackboard.store_data("game_root",self)
	SceneManager.load_scene(load("res://Scenes/testing_level.tscn"),"test_level","stage")
