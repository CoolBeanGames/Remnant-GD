extends Node
var failures: Array[String] = []
func check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
		push_error(message)
func _ready() -> void:
	run.call_deferred()
func run() -> void:
	var pool := object_pool.new()
	pool.pooled_scene = load("res://Scenes/audio_player.tscn")
	pool.reset_method = &"reset"
	pool.register_with_blackboard = true
	pool.blackboard_name = &"audio_pool"
	add_child(pool)
	for key in ["exited room", "level enabled", "grinder enabled", "computer enabled"]:
		Flags.set_flag(key, false)
	Blackboard.store_data("score", 0)
	Blackboard.store_data("lever_pulls", 0)
	Blackboard.store_data("spawned_items", [])
	var scene: PackedScene = load("res://Scenes/testing_level.tscn")
	var level: level_sequence = scene.instantiate()
	level.set("spawn_animation_enabled", false)
	add_child(level)
	level.set_process(false)
	level.player.process_mode = Node.PROCESS_MODE_DISABLED
	await get_tree().process_frame
	check(not level.manual_lever.enabled and not level.chute.enabled, "Chute starts locked")
	check(not level.grinder.enabled and not level.computer.enabled, "Later systems start locked")
	level._on_room_exit()
	level._process(2.9)
	check(not level.chute.enabled, "Exit delay is respected")
	level._process(.2)
	check(level.chute.enabled and level.manual_lever.enabled, "Exit unlocks chute")
	for i in range(4):
		level._on_lever_pulled()
	check(not level.grinder.enabled, "Four pulls do not unlock grinder")
	level._on_lever_pulled()
	check(level.grinder.enabled and Flags.check_flag("grinder enabled"), "Fifth pull unlocks grinder")
	Blackboard.store_data("score", 29)
	level._process(0)
	check(not level.computer.enabled, "Computer remains locked below 30")
	Blackboard.store_data("score", 30)
	level._process(0)
	check(level.computer.enabled and Flags.check_flag("computer enabled"), "30 score unlocks computer")
	var spawner: automatic_spawner = load("res://Scenes/Actors/automatic_spawner.tscn").instantiate()
	level.add_child(spawner)
	spawner.set_physics_process(false)
	spawner.place_on(level)
	spawner.remaining = .1
	var count: int = WorldState.items.size()
	spawner._physics_process(.2)
	check(WorldState.items.size() == count + 1, "Placed automatic spawner creates a tracked item")
	var actor: Node3D = WorldState._actor(WorldState.items.keys().back())
	check(physics_items.score_component(actor).score == 1, "New item has base score one")
	for body in WorldState._bodies(actor):
		body.freeze = true
		body.global_position = Vector3(3, -20, 4)
	WorldState._physics_process(.1)
	check(actor.is_queued_for_deletion(), "Fallen physical item is culled")
	check(Progression.score() == 30, "Culling awards no score")
	Blackboard.store_data("score", 500)
	SaveGame.profile["lifetime_score"] = 4500 # Offer discovery; balance still tests its real cost.
	check(Progression.purchase(Progression.entries[&"buy_automatic_spawner"], level, level.computer.delivery_point, level.player).is_empty(), "Buy the first spawner before unlocking its upgrades")
	var purchased_spawner: Node3D = level.get_child(level.get_child_count() - 1)
	WorldState.untrack(purchased_spawner)
	purchased_spawner.queue_free()
	Blackboard.store_data("score", 500)
	var upgrade: computer_entry = load("res://Data/Computer/spawner_speed.tres")
	check(Progression.purchase(upgrade, level, null, level.player).is_empty(), "Spawner upgrade can be bought")
	check(is_equal_approx(spawner.spawn_interval, 6.4), "Upgrade speeds an existing spawner up by 20 percent")
	WorldState.track(spawner)
	var survivor: Node3D = WorldState.spawn_item(load("res://Scenes/test_object.tscn"), level, Transform3D(Basis.IDENTITY, Vector3(4, 5, 6)))
	for body in WorldState._bodies(survivor):
		body.freeze = true
		body.global_position = Vector3(7, 8, 9)
	physics_items.score_component(survivor).score = 3
	var saved_pose := Transform3D(Basis(Vector3.UP, .6), Vector3(8, 2, 9))
	level.player.global_transform = saved_pose
	WorldState._physics_process(.1)
	check(Blackboard.read_data("player_transform").is_equal_approx(saved_pose), "Player pose is tracked")
	WorldState.capture()
	var saved: Array = Blackboard.read_data("spawned_items").duplicate(true)
	level.queue_free()
	await get_tree().process_frame
	Blackboard.store_data("spawned_items", saved)
	var resumed: level_sequence = scene.instantiate()
	resumed.set("spawn_animation_enabled", false)
	add_child(resumed)
	resumed.player.process_mode = Node.PROCESS_MODE_DISABLED
	await get_tree().process_frame
	check(resumed.player.global_transform.is_equal_approx(saved_pose), "Player exact pose restores")
	check(resumed.chute.enabled and resumed.grinder.enabled and resumed.computer.enabled, "Saved flags restore unlocked systems")
	check(WorldState.items.size() == saved.size(), "Saved item registry restores without duplicates")
	for id in WorldState.items:
		var restored: Node3D = WorldState._actor(id)
		if restored is automatic_spawner:
			check(restored.placed and restored.support.get_ref() == resumed, "Placed support restores")
			check(is_equal_approx(restored.spawn_interval, 6.4), "Saved spawner interval restores")
		else:
			check(WorldState._bodies(restored)[0].global_position.is_equal_approx(Vector3(7, 8, 9)), "Exact nested rigid-body position restores")
			check(physics_items.score_component(restored).score == 3, "Saved item value restores")
	resumed.queue_free()
	await get_tree().process_frame
	for audio: audio_player in pool.active:
		audio.reset()
	await get_tree().create_timer(.1).timeout
	print("level_progression_test: ", "PASS" if failures.is_empty() else failures)
	get_tree().quit(0 if failures.is_empty() else 1)


