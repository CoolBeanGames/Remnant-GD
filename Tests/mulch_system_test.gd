extends Node
var failures: Array[String] = []
func check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
		push_error(message)
func tick() -> void:
	await get_tree().physics_frame
	await get_tree().process_frame
func _ready() -> void:
	run.call_deferred()
func run() -> void:
	SaveGame.save_path = "res://.godot/mulch_system_test.save"
	SaveGame.enabled = false
	SaveGame.saving_disabled = false
	SaveGame.profile = {"mulch_coins": 0, "mulch_upgrades": {}, "settings": {}}
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SaveGame.save_path))
	Blackboard._data.clear()
	Flags._flags.clear()
	Progression.entries.clear()
	Progression.levels.clear()
	Progression.restored_levels = false
	var pool := object_pool.new()
	pool.pooled_scene = load("res://Scenes/audio_player.tscn")
	pool.reset_method = &"reset"
	pool.blackboard_name = &"audio_pool"
	pool.register_with_blackboard = true
	add_child(pool)
	Blackboard.store_data("spawned_items", [])
	Blackboard.store_data("score", 100000)
	Flags.set_flag("computer enabled", true)
	Flags.set_flag("grinder enabled", true)
	var level: level_sequence = load("res://Scenes/testing_level.tscn").instantiate()
	level.spawn_animation_enabled = false
	add_child(level)
	await tick()
	level.player.process_mode = Node.PROCESS_MODE_DISABLED
	GrindCombo.set_process(false)
	ScoreRewards.set_process(false)
	var pc: computer_terminal = level.computer
	check(not Mulch.tab_unlocked(), "Mulch tab starts locked")
	check(pc.buy(Progression.entries[&"buy_mulcher"]).is_empty() and is_instance_valid(Mulch.station), "Store purchase installs mulcher directly onto grinder")
	check(Mulch.station.get_node("DamageGrid").text.count("\n") == 10, "Damage grid has ten actual rows")
	var before: int = Progression.score()
	check(not pc.buy(Progression.entries[&"buy_mulcher"]).is_empty() and Progression.score() == before, "Installed machine cannot be purchased twice")
	check(not Mulch.tab_unlocked(), "One purchase does not unlock Mulch")
	check(pc.buy(Progression.entries[&"buy_mulch_bin"]).is_empty() and Mulch.tab_unlocked(), "Bin delivery unlocks the fourth tab")
	var ui: computer_ui = load("res://Scenes/UI/computer_ui.tscn").instantiate()
	add_child(ui)
	ui.open(pc)
	check(not ui.tabs.is_tab_hidden(3) and ui.tabs.get_child(3).get_node("List").get_child_count() == 12, "Unlocked computer shows modular mulch upgrades")
	ui.close()
	var pellets: Array[Node3D] = []
	Mulch.pellet_produced.connect(func(pellet: Node3D): pellets.append(pellet))
	for i in 20:
		var actor: Node3D = WorldState.spawn_item(load("res://Scenes/test_object.tscn"), level, Transform3D(Basis.IDENTITY, Vector3(10, 3, 8)))
		check(level.grinder.grind(actor.get_node("RigidBody3D")), "Normal item grinds")
	await tick()
	check(pellets.size() == 1 and is_zero_approx(Mulch.points) and Mulch.damage == 20 and Mulch.coins() == 0, "One hundred points creates a physical pellet without banking currency")
	check(is_equal_approx(pellets[0].stored_score, 10.0), "Pellet stores half the twenty items' score")
	check(Mulch.deposit(pellets[0]) and not Mulch.deposit(pellets[0]) and Mulch.coins() == 1, "Each deposited pellet banks exactly one permanent coin")
	await tick()
	Mulch.damage = Mulch.maximum_damage
	var item: Node3D = load("res://Scenes/test_object.tscn").instantiate()
	level.add_child(item)
	var points_before: float = Mulch.points
	Mulch.consume(item)
	check(Mulch.points == points_before, "Broken mulcher stops producing while normal grinder remains usable")
	before = Progression.score()
	var first_repair_cost: int = Mulch.repair_cost()
	check(Mulch.repair().is_empty() and Progression.score() == before - first_repair_cost and Mulch.repair_remaining > 0, "Repair charges score and takes time")
	check(Mulch.repair() == "Repair already in progress.", "Repeated repair cannot charge twice")
	Mulch._process(Mulch.repair_seconds + .1)
	check(Mulch.damage == 0 and Mulch.repair_cost() > first_repair_cost and Mulch.repairs == 1, "Repair clears damage and raises next repair price")
	check(pc.buy(Progression.entries[&"mulcher_durability"]).is_empty() and Mulch.maximum_damage == 150, "Regular score buys bonus durability immediately")
	check(pc.buy(Progression.entries[&"mulcher_efficiency"]).is_empty() and is_equal_approx(Mulch.efficiency, 1.25), "Regular score buys efficiency")
	SaveGame.profile["mulch_coins"] = 50
	var movement: Node = level.player.get_node("Controllers/Player_Move_Controller")
	var speed: float = movement.move_speed
	check(pc.buy(Progression.entries[&"run_speed"]).is_empty(), "Regular speed upgrade applies")
	var upgraded_speed: float = movement.move_speed
	check(pc.buy(Progression.entries[&"mulch_speed"]).is_empty() and is_equal_approx(movement.move_speed, upgraded_speed * 2), "Permanent speed stacks on top of regular speed")
	var coins_before: int = Mulch.coins()
	check(pc.buy(Progression.entries[&"mulch_durability_meta"]).is_empty() and Mulch.maximum_damage == 300 and Mulch.coins() < coins_before, "Mulch upgrades use coins and stack durability")
	# Exercise the real deposit area with a falling pellet.
	var bin: mulch_bin = Mulch.bin
	var physical: mulch_pellet = WorldState.spawn_item(load("res://Scenes/Mulch/mulch_pellet.tscn"), level, Transform3D(Basis.IDENTITY, bin.global_position + Vector3(0, 1.0, 0)))
	coins_before = Mulch.coins()
	await get_tree().create_timer(.5).timeout
	check(not is_instance_valid(physical) and Mulch.coins() == coins_before + 1, "Bin's physical sensor deposits pellets")
	check(bin is StaticBody3D and not bin.is_in_group("pick-up") and bin.get_node("Deposit").collision_mask == 1, "Installed bin stays solid and cannot be picked up")
	check(SaveGame.save_now(), "Mulcher wear/repair/progress save")
	var coins_saved: int = Mulch.coins()
	ui.queue_free()
	level.queue_free()
	await tick()
	check(SaveGame.new_game() and not SaveGame.has_run_save(), "New Game removes old run while preserving profile-only data")
	check(Mulch.coins() == coins_saved and Mulch.upgrade_level(&"mulch_speed") == 1 and not Flags.check_flag("mulcher purchased") and Mulch.damage == 0, "Coins and permanent upgrades survive; run ownership and wear reset")
	Blackboard.store_data("audio_pool", pool)
	level = load("res://Scenes/testing_level.tscn").instantiate()
	level.spawn_animation_enabled = false
	add_child(level)
	await tick()
	check(is_equal_approx(level.player.get_node("Controllers/Player_Move_Controller").move_speed, speed * 2), "Permanent bonus carries into a fresh run without regular tiers")
	level.queue_free()
	await tick()
	SaveGame.reset_save()
	for audio: audio_player in pool.active:
		audio.reset()
	await get_tree().create_timer(.1).timeout
	print("Mulcher installation, pellets, bank, damage/repairs, stacked upgrades and new-run persistence: ", "PASS" if failures.is_empty() else str(failures))
	get_tree().quit(0 if failures.is_empty() else 1)
