extends Node
var failures: Array[String] = []
func check(ok: bool, text: String) -> void:
	if not ok:
		failures.append(text)
		push_error(text)
func _ready() -> void:
	run.call_deferred()
func run() -> void:
	SaveGame.save_path = "res://.godot/loader_test.save"
	SaveGame.saving_disabled = false
	SaveGame.enabled = false
	Blackboard._data.clear()
	Flags._flags.clear()
	Blackboard.store_data("score", 321)
	Blackboard.store_data("spawned_items", [])
	Blackboard.store_data("respawn_tallies", 6)
	Flags.set_flag("computer enabled", true)
	Flags.set_flag("exited room", true)
	Flags.set_flag("dialogue first_spawn", true)
	check(SaveGame.save_now(), "Seed loader save")
	Blackboard._data.clear()
	Flags._flags.clear()
	# Keep the observer outside the changing current scene.
	get_tree().current_scene = null
	get_tree().change_scene_to_file("res://Scenes/save_loader.tscn")
	await get_tree().create_timer(.7).timeout
	check(get_tree().current_scene != null and get_tree().current_scene.name == "Game", "Intermediate loader enters the game")
	check(Blackboard.read_data("score") == 321 and Flags.check_flag("computer enabled"), "Saved data is present before level initialization")
	check(is_instance_valid(Blackboard.read_data("audio_pool")) and is_instance_valid(Blackboard.read_data("game_root")), "Game re-registers live service handles")
	check(Blackboard.read_data("respawn_tallies") == 7 and WorldState.tracking, "Loaded session wakes with the next wall tally")
	check(SaveGame.enabled, "Loader arms periodic and exit saves")
	Blackboard.store_data("score", 444)
	get_tree().change_scene_to_file("res://Scenes/save_loader.tscn")
	await get_tree().create_timer(.7).timeout
	check(Blackboard.read_data("score") == 444 and Blackboard.read_data("respawn_tallies") == 8, "Reload saves the old scene then restores through the intermediary")
	check(SaveGame.reset_save(), "Reset deletes the loader save")
	get_tree().current_scene.queue_free()
	await get_tree().process_frame
	check(not FileAccess.file_exists(SaveGame.save_path), "Level shutdown cannot resurrect a reset file")
	print("Startup loader, scene reload, live handles and reset teardown: ", "PASS" if failures.is_empty() else failures)
	get_tree().quit(0 if failures.is_empty() else 1)
