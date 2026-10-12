extends Node

var failures: Array[String] = []
var level: level_sequence
var emitted: Array[Node3D] = []
var automatic_pulls: int = 0
@export var capture_directory: String = ""

func check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
		push_error(message)

func tick(count: int = 4) -> void:
	for i in count:
		await get_tree().physics_frame
		await get_tree().process_frame

func capture(name: String) -> void:
	if capture_directory.is_empty() or DisplayServer.get_name() == "headless":
		return
	DirAccess.make_dir_recursive_absolute(capture_directory)
	await tick()
	await RenderingServer.frame_post_draw
	check(get_viewport().get_texture().get_image().save_png(capture_directory + "/" + name + ".png") == OK, "Rendered followup image saved")

func bind_level() -> void:
	level = load("res://Scenes/testing_level.tscn").instantiate()
	level.spawn_animation_enabled = false
	add_child(level)
	level.player.process_mode = Node.PROCESS_MODE_DISABLED
	await tick(8)

func _ready() -> void:
	if DisplayServer.get_name() != "headless":
		DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS, true)
	run.call_deferred()

func run() -> void:
	SaveGame.enabled = false
	SaveGame.saving_disabled = false
	SaveGame.save_path = "user://mulch_followup.save"
	SaveGame.profile = {"mulch_coins": 1000, "mulch_upgrades": {}, "settings": {}}
	Blackboard._data.clear()
	Flags._flags.clear()
	Progression.entries.clear()
	Progression.levels.clear()
	Progression.restored_levels = false
	Blackboard.store_data("score", 100000)
	Blackboard.store_data("spawned_items", [])
	Flags.set_flag("exited room", true)
	Flags.set_flag("level enabled", true)
	Flags.set_flag("grinder enabled", true)
	Flags.set_flag("computer enabled", true)
	Flags.set_flag("message computer enabled", true)
	var pool := object_pool.new()
	pool.pooled_scene = load("res://Scenes/audio_player.tscn")
	pool.reset_method = &"reset"
	pool.register_with_blackboard = true
	pool.blackboard_name = &"audio_pool"
	add_child(pool)
	await bind_level()
	GrindCombo.set_process(false)
	ScoreRewards.set_process(false)
	check(level.computer.buy(Progression.entries[&"buy_mulcher"]).is_empty(), "Install mulcher")
	check(level.computer.buy(Progression.entries[&"buy_mulch_bin"]).is_empty(), "Install fixed bin")
	var mount: Node3D = level.get_node("grinding_area/MulchBinMount")
	check(Mulch.bin.global_transform.is_equal_approx(mount.global_transform), "Bin aligns to editable grinder mount")
	var camera: Camera3D = level.player.get_node("Camera3D")
	var prompts: prompt_display = level.get_node("WorldPrompts")
	camera.global_position = Mulch.station.global_position + Vector3(0, .4, 2.0)
	camera.look_at(Mulch.station.global_position + Vector3(0, .4, 0))
	Mulch.damage = Mulch.maximum_damage
	Mulch._store()
	await tick()
	prompts.ray._physics_process(0)
	prompts.refresh()
	check(prompts.displayed_texts.has("Repair Mulcher / 100 Score [E]"), "Actual ray renders broken mulcher repair prompt")
	await capture("repair_prompt")
	Mulch.station.interact()
	check(Mulch.repair_remaining > 0, "Prompt target repairs the real machine")
	await capture("repairing")
	Mulch._process(Mulch.repair_seconds + 1)
	Mulch.points_per_pellet = 5
	Mulch.efficiency = 2
	Mulch.pellet_produced.connect(func(pellet: Node3D): emitted.append(pellet))
	var item: Node3D = load("res://Scenes/test_object.tscn").instantiate()
	item.position = Vector3(10, 3, 8)
	item.get_node("RigidBody3D").freeze = true
	level.add_child(item)
	Mulch.consume(item, 10)
	await tick()
	check(emitted.size() == 2 and is_equal_approx(emitted[0].stored_score, 2.5) and is_equal_approx(emitted[1].stored_score, 2.5), "Half score distributes proportionally across multiple pellets")
	GrindCombo.reset()
	var wear: float = Mulch.damage
	check(level.grinder.grind(emitted[0]) and not level.grinder.grind(emitted[0]), "A pellet grinds only once")
	check(is_equal_approx(GrindCombo.base_points, 2.5) and Mulch.damage == wear and is_zero_approx(Mulch.points), "Pellet pays stored score through combo without recycling points or wear")
	await tick()
	var saved_pellet: mulch_pellet = emitted[1]
	saved_pellet.freeze = true
	saved_pellet.global_position = Vector3(10, 2, 8)
	var saved_id: String = saved_pellet.get_meta("persistent_item_id")
	physics_items.score_component(item).mulch_value = 1
	Mulch.consume(item, 3)
	check(is_equal_approx(Mulch.points, 2) and is_equal_approx(Mulch.contributions[0].score, 1.5), "Partial pellet retains fractional contribution")
	WorldState.capture()
	# Simulate an old portable-bin save and duplicate installation records.
	var records: Array = Blackboard.read_data("spawned_items").duplicate(true)
	for record in records.duplicate(true):
		if record.scene == "res://Scenes/Mulch/mulch_bin.tscn":
			record.id = "legacy_duplicate_bin"
			record.transform = Transform3D(Basis.IDENTITY, Vector3(17, 4, 2))
			record.bodies = [{"path": NodePath("."), "transform": record.transform, "freeze": false}]
			records.append(record)
	Blackboard.store_data("spawned_items", records)
	check(SaveGame.save_now(), "Save fractional ledger and pellet score")
	# save_now captures live actors; inject the legacy records into the fixture file.
	var legacy_payload: Dictionary = SaveGame._read_payload()
	var legacy_blackboard: Dictionary = SaveGame._decode(legacy_payload.blackboard)
	legacy_blackboard.spawned_items = records
	legacy_payload.blackboard = SaveGame._encode(legacy_blackboard)
	check(SaveGame._write_payload(legacy_payload), "Write actual legacy portable/duplicate bin fixture")
	item.queue_free()
	level.queue_free()
	await tick()
	check(SaveGame.load_now(), "Reload followup save")
	Blackboard.store_data("audio_pool", pool)
	await bind_level()
	saved_pellet = WorldState._actor(saved_id)
	check(is_instance_valid(saved_pellet) and is_equal_approx(saved_pellet.stored_score, 2.5) and is_equal_approx(Mulch.contributions[0].score, 1.5), "Continue restores pellet score and contribution ledger")
	check(get_tree().get_nodes_in_group("mulch-bin").size() == 1 and Mulch.bin.global_transform.is_equal_approx(level.get_node("grinding_area/MulchBinMount").global_transform), "Legacy bin moves to fixed mount without duplicates")
	WorldState.capture()
	var restored_ids: Array[int] = []
	for id in WorldState.items:
		var restored_actor: Node3D = WorldState._actor(id)
		check(not restored_ids.has(restored_actor.get_instance_id()), "Restored ready-time registrants retain one saved identity")
		restored_ids.append(restored_actor.get_instance_id())
	var second: mulch_pellet = WorldState.spawn_item(load("res://Scenes/Mulch/mulch_pellet.tscn"), level, Transform3D(Basis.IDENTITY, Vector3(10.3, 2, 8)))
	var third: mulch_pellet = WorldState.spawn_item(load("res://Scenes/Mulch/mulch_pellet.tscn"), level, Transform3D(Basis.IDENTITY, Vector3(9.7, 2, 8)))
	await tick()
	var pickup: player_pickup = level.player.get_node("Controllers/Player_Pickup")
	pickup.grab_capacity = 3
	check(pickup.pickup_object(saved_pellet) and pickup.extra_items.size() == 2, "Real radius query multi-grabs three pellets")
	check(not Mulch.deposit(second) and not level.grinder.grind(third), "Held secondary pellets cannot be banked or ground")
	pickup.drop_object()
	check(not second.get_meta("carried_by_player", false) and second.collision_layer == 1, "Dropping restores secondary pellet ownership and collisions")
	var camera_after: Camera3D = level.player.get_node("Camera3D")
	camera_after.global_position = Mulch.station.global_position + Vector3(2.5, 1.4, 3.3)
	camera_after.look_at(Mulch.station.global_position + Vector3(1.0, .3, 0))
	await capture("fixed_installation")
	var coins: int = Mulch.coins()
	check(level.computer.buy(Progression.entries[&"mulch_collector"]).is_empty(), "Purchase collector with permanent currency")
	await tick()
	check(Mulch.coins() == coins - 25 + 3 and not is_instance_valid(saved_pellet), "Collector banks loose workshop pellets once")
	Mulch.points_per_pellet = 2
	item = load("res://Scenes/test_object.tscn").instantiate()
	item.position = Vector3(10, 3, 8)
	item.get_node("RigidBody3D").freeze = true
	level.add_child(item)
	coins = Mulch.coins()
	SaveGame.enabled = true
	Mulch.consume(item, 2)
	await tick()
	check(Mulch.coins() > coins and get_tree().get_nodes_in_group("mulch-pellet").is_empty(), "Collector automatically banks new machine output")
	var banked_save: Dictionary = SaveGame._decode(SaveGame._read_payload().blackboard)
	check(is_equal_approx(banked_save.mulch_points, Mulch.points) and banked_save.mulch_contributions == Mulch.contributions, "Automatic banking saves consumed ledger before currency to prevent replay on Continue")
	SaveGame.enabled = false
	var handle: lever = level.get_node("Lever_Assembly")
	var chute: ceiling_chute = handle.chute
	chute.note_drop_chance = 0
	chute.item_pool = item_spawn_pool.new()
	chute.item_pool.items = [load("res://Scenes/test_object.tscn")]
	check(level.computer.buy(Progression.entries[&"lever_output"]).is_empty(), "Regular output tier buys two items")
	check(level.computer.buy(Progression.entries[&"mulch_lever_output"]).is_empty() and is_equal_approx(handle.output_multiplier, 2), "Permanent lever multiplier applies on top of regular output")
	handle.pulled.connect(func(): automatic_pulls += 1)
	check(level.computer.buy(Progression.entries[&"mulch_automatic_lever"]).is_empty() and handle.automatic, "Upgrade automates existing lever")
	await get_tree().create_timer(2).timeout
	check(automatic_pulls == 1 and handle.pending_pull_items == 4, "Real automatic animation emits the multiplied four-item batch")
	handle.interact()
	var count: int = automatic_pulls
	await get_tree().create_timer(3).timeout
	check(automatic_pulls == count and handle.automation_paused and Blackboard.read_data("lever_auto_paused") == true, "E pauses automation and saves pause state")
	var world_prompts: prompt_display = level.get_node("WorldPrompts")
	camera_after.global_position = handle.global_position + Vector3(0, 1.2, 2.6)
	camera_after.look_at(handle.global_position + Vector3(0, .4, 0))
	await tick()
	world_prompts.ray._physics_process(0)
	world_prompts.refresh()
	check(world_prompts.displayed_texts.has("Resume Automatic Lever [E]"), "Automation uses dynamic in-world interaction prompt")
	await capture("automatic_lever")
	WorldState.tracking = false
	level.queue_free()
	await tick()
	SaveGame.reset_save()
	for voice in pool.active.duplicate():
		voice.stop()
	await tick(8)
	pool.queue_free()
	print("Mulch followup / repair ray / fractional score ledger / no recycling / legacy fixed bin / real multi-grab / collector / automatic multiplied lever: ", "PASS" if failures.is_empty() else failures)
	get_tree().quit(0 if failures.is_empty() else 1)
