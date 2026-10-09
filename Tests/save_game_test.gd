extends Node
var failures: Array[String] = []
func check(ok: bool, text: String) -> void:
	if not ok:
		failures.append(text)
		push_error(text)
func tick() -> void:
	await get_tree().physics_frame
	await get_tree().process_frame
func _ready() -> void:
	run.call_deferred()
func run() -> void:
	SaveGame.save_path = "res://.godot/persistence_test.save"
	SaveGame.enabled = false
	SaveGame.saving_disabled = false
	DirAccess.remove_absolute(SaveGame.save_path)
	check(not SaveGame.load_now(), "Missing save starts a new game")
	var pool := object_pool.new()
	pool.pooled_scene = load("res://Scenes/audio_player.tscn")
	pool.reset_method = &"reset"
	pool.register_with_blackboard = true
	pool.blackboard_name = &"audio_pool"
	add_child(pool)
	Blackboard.store_data("spawned_items", [])
	Blackboard.store_data("score", 100)
	Blackboard.store_data("lever_pulls", 9)
	Blackboard.store_data("upgrade_levels", {&"fan_power": 2, &"store_basket": 3})
	Blackboard.store_data("found_notes", [{"id": "test-note", "title": "Saved", "body": "Remember"}])
	Blackboard.store_data("spawned_notes", ["test-note", "world-note"])
	Blackboard.store_data("custom_native", {"pose": Transform3D(Basis.from_euler(Vector3(.1,.2,.3)), Vector3(2,3,4)), "vector": Vector2(5,6), "colour": Color(.1,.2,.3), "packed": PackedStringArray(["a", "b"])})
	var inline := dialogue_sequence.new()
	var line := dialogue_line.new()
	line.text = "Inline saved resource"
	inline.lines = [line]
	Blackboard.store_data("custom_resource", inline)
	Blackboard.store_data("path_resource", load("res://Data/Dialogue/first_spawn.tres"))
	Flags.set_flag("exited room", true)
	Flags.set_flag("computer enabled", true)
	Flags.set_flag("arbitrary false flag", false)
	Flags.set_flag("dialogue first_spawn", true)
	var level: level_sequence = load("res://Scenes/testing_level.tscn").instantiate()
	level.spawn_animation_enabled = false
	add_child(level)
	await tick()
	level.player.process_mode = Node.PROCESS_MODE_DISABLED
	level.player.global_position = Vector3(7, 1, 8)
	var fan: Node3D = WorldState.spawn_item(load("res://Scenes/Actors/fan.tscn"), level, Transform3D(Basis.IDENTITY, Vector3(9, 2, 8)))
	fan.set("powered", false)
	fan.set("freeze", true)
	ScoreRewards.pending_points = 7
	ScoreRewards.current_interval = .32
	ScoreRewards.remaining = .21
	ScoreRewards.set_process(false)
	GrindCombo.item_count = 3
	GrindCombo.base_points = 4
	GrindCombo.remaining = 1.1
	GrindCombo.current_window = 2.2
	GrindCombo.set_process(false)
	check(SaveGame.save_now(), "Single-file save writes complete state")
	var saved_records: Array = Blackboard.read_data("spawned_items").duplicate(true)
	check(saved_records.size() == 1, "Snapshot captures live item")
	# Replacing the same file must also work on Windows.
	check(SaveGame.save_now(), "Saving again atomically replaces the same file")
	level.queue_free()
	await tick()
	Blackboard._data.clear()
	Flags._flags.clear()
	ScoreRewards.reset()
	GrindCombo.reset()
	check(SaveGame.load_now(), "State restores from disk before the level exists")
	check(Blackboard.read_data("score") == 100 and Blackboard.read_data("lever_pulls") == 9, "Score and progress restore")
	check(Flags.check_flag("computer enabled") and Flags.check_flag("exited room") and Flags.check_flag("dialogue first_spawn") and Flags._flags.has("arbitrary false flag") and not Flags.check_flag("arbitrary false flag"), "True and false flags restore")
	check(Blackboard.read_data("custom_native").pose.origin == Vector3(2,3,4) and Blackboard.read_data("custom_native").packed is PackedStringArray, "Native Godot values preserve types")
	var restored_resource: dialogue_sequence = Blackboard.read_data("custom_resource")
	check(restored_resource.lines.is_typed() and restored_resource.lines[0].text == "Inline saved resource", "Inline resources and typed resource arrays restore")
	check(Blackboard.read_data("path_resource") is dialogue_sequence and Blackboard.data_exists("audio_pool") and Blackboard.read_data("audio_pool") == null, "Resource paths restore; runtime handles retain their keys for re-registration")
	check(ScoreRewards.pending_points == 7 and is_equal_approx(ScoreRewards.remaining, .21) and GrindCombo.item_count == 3, "Unpaid rewards and active combo survive saving")
	Blackboard.store_data("audio_pool", pool)
	level = load("res://Scenes/testing_level.tscn").instantiate()
	level.spawn_animation_enabled = false
	add_child(level)
	level.player.process_mode = Node.PROCESS_MODE_DISABLED
	await tick()
	await tick()
	check(level.player.global_position.is_equal_approx(Vector3(7,1,8)), "Loaded player transform reaches the level")
	check(WorldState.items.size() == 1 and not WorldState._actor(str(saved_records[0].id)).get("powered"), "World item and power state restore")
	check(Progression.levels.get(&"fan_power") == 2 and Notes.has_note(&"test-note"), "Upgrades, purchases and journal restore")
	level.queue_free()
	await tick()
	var legacy: Dictionary = SaveGame._read_payload()
	legacy["version"] = 1
	legacy.erase("profile")
	legacy.erase("has_run")
	check(SaveGame._write_payload(legacy) and SaveGame.load_now() and Blackboard.read_data("score") == 100, "Legacy version-one run saves remain loadable")
	check(SaveGame.reset_save() and not FileAccess.file_exists(SaveGame.save_path), "Reset deletes the save")
	check(not SaveGame.save_now() and not FileAccess.file_exists(SaveGame.save_path), "Reset blocks every subsequent save, including teardown")
	for audio: audio_player in pool.active:
		audio.reset()
	await get_tree().create_timer(.1).timeout
	print("Single-file persistence, resources, world restoration and reset: ", "PASS" if failures.is_empty() else failures)
	get_tree().quit(0 if failures.is_empty() else 1)
