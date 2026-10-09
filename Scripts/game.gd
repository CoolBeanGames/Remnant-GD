extends Node

func _ready() -> void:
	SaveGame.start_session()
	SaveGame.restore_runtime(true)
	# Children have registered the pool before loading; disk runtime handles are null.
	Blackboard.store_data("audio_pool", $audio_pool)
	Blackboard.store_data("game_root",self)
	var level: Node = SceneManager.load_scene(load("res://Scenes/testing_level.tscn"),"test_level","stage")
	level.tree_exiting.connect(_save_before_reload)

func _save_before_reload() -> void:
	if SaveGame.enabled and not SaveGame.saving_disabled:
		SaveGame.save_now()

func _exit_tree() -> void:
	SceneManager.loaded_scenes.clear()
	SceneManager.loaded_bundles.clear()
