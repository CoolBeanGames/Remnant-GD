extends Node
var failures: Array[String] = []
func check(ok: bool, text: String) -> void:
	if not ok:
		failures.append(text)
		push_error(text)
func tick(count: int = 4) -> void:
	for i in count:
		await get_tree().physics_frame
		await get_tree().process_frame
func _ready() -> void:
	run.call_deferred()
func run() -> void:
	SaveGame.enabled = false
	SaveGame.saving_disabled = false
	SaveGame.save_path = "user://issue_batch_test.save"
	SaveGame.profile = {"mulch_coins": 0, "mulch_upgrades": {}, "settings": {}, "lifetime_score": 0}
	Blackboard._data.clear()
	Flags._flags.clear()
	Blackboard.store_data("score", 0)
	Progression.entries.clear()
	Progression.levels.clear()
	Progression.restored_levels = false
	Progression.register_catalog(load("res://Data/Computer/default_catalog.tres"))
	var memory: computer_entry = Progression.entries[&"memory_1"]
	Blackboard.store_data("score", 749)
	check(not Progression.entry_visible(memory), "Memory remains hidden below half its exact cost")
	Blackboard.store_data("score", 750)
	check(Progression.entry_visible(memory), "Memory appears at half its exact cost")
	Blackboard.store_data("score", 0)
	check(Progression.entry_visible(memory), "A revealed memory stays visible after spending")
	Progression.levels[memory.id] = 1
	check(not Progression.entry_visible(memory), "Purchased memory disappears from the display")
	var fan: computer_entry = Progression.entries[&"fan_power"]
	check(not Progression.entry_visible(fan), "Future offers are initially hidden")
	Progression.record_earned_score(100)
	check(Progression.entry_visible(fan) and Progression.lifetime_score() == 100, "Earnings reveal offers independently of spending")
	GrindCombo.reset()
	GrindCombo.set_process(false)
	for i in 40:
		GrindCombo.record_item(1)
	check(GrindCombo.multiplier() == 15, "Base combo has a configurable ceiling")
	Progression.levels[&"combo_max"] = 1
	Progression.levels[&"combo_increment"] = 1
	Progression.levels[&"combo_cooldown"] = 1
	Progression.apply_effects(GrindCombo, "combo")
	check(GrindCombo.maximum_multiplier == 20 and GrindCombo.multiplier_step == .75 and is_equal_approx(GrindCombo.window_decrease, .32), "Combo upgrades change cap, increment and decay independently")
	Progression.apply_effects(GrindCombo, "combo")
	check(GrindCombo.maximum_multiplier == 20, "Reapplying effects does not compound tiers")
	GrindCombo.reset()
	var world := Node3D.new()
	add_child(world)
	var floor_body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(20, .2, 20)
	shape.shape = box
	floor_body.add_child(shape)
	floor_body.position.y = -.1
	world.add_child(floor_body)
	var player: CharacterBody3D = load("res://Scenes/Player/player.tscn").instantiate()
	player.process_mode = Node.PROCESS_MODE_DISABLED
	player.disable_mode = CollisionObject3D.DISABLE_MODE_KEEP_ACTIVE
	world.add_child(player)
	WorldState.begin(world, player)
	var camera: Camera3D = player.get_node("Camera3D")
	check(is_equal_approx(camera.position.y, 1.65), "Player uses a human eye height")
	var pellet: mulch_pellet = WorldState.spawn_item(load("res://Scenes/Mulch/mulch_pellet.tscn"), world, Transform3D(Basis.IDENTITY, Vector3(0, .13, -1.4)))
	await tick(12)
	camera.look_at(pellet.global_position)
	var ray: raycaster = camera.get_node("RayCast3D")
	ray._physics_process(0)
	check(ray.get_looked_at() == pellet, "A floor pellet is recognized by the production ray")
	check(object_prompts.find_for(pellet).get_prompts().entries[0].text == "Pickup Mulch Pellet", "Pellet exposes its F prompt through the shared component")
	var pickup: player_pickup = player.get_node("Controllers/Player_Pickup")
	check(pickup.try_pickup() and pickup.held_object == pellet, "F pickup uses the actual pellet body")
	pickup.drop_object()
	for i in 10:
		var other: Node3D = WorldState.spawn_item(load("res://Scenes/Mulch/mulch_pellet.tscn"), world, Transform3D(Basis.IDENTITY, Vector3((i % 5 - 2) * .27, .13, -1.5 - floori(i / 5.0) * .27)))
		other.freeze = true
	await tick()
	camera.look_at(Vector3(0, .13, -1.7))
	ray._physics_process(0)
	check(ray.get_looked_at() is mulch_pellet, "Overlapping large targets do not make a pellet pile unpickable")
	Flags.set_flag("mulcher purchased", true)
	Mulch.bind_level(world)
	check(SaveGame.profile.get("mulcher_unlocked", false), "Installed Mulcher migrates into the permanent profile")
	check(SaveGame.save_now() and SaveGame.load_now(), "Run/profile can save and reload")
	check(SaveGame.profile.get("mulcher_unlocked", false) and Progression.lifetime_score() >= 100, "Permanent unlock and lifetime earnings survive loading")
	check(SaveGame.new_game(), "New Game clears the run successfully")
	check(Mulch.installed_unlock() and Progression.lifetime_score() >= 100, "New Game retains the Mulcher and lifetime earnings")
	var bin: computer_entry = load("res://Data/Mulch/buy_mulch_bin.tres")
	Progression.register_catalog(load("res://Data/Computer/default_catalog.tres"))
	Progression.levels[bin.id] = 1
	check(bin.single_purchase and Progression.purchase(bin, world, null, player) == "Already purchased.", "Bin cannot be purchased twice")
	world.queue_free()
	await tick()
	SaveGame.reset_save()
	print("October issue batch / offer discovery / combo / pellet physics pickup / profile: ", "PASS" if failures.is_empty() else failures)
	get_tree().quit(0 if failures.is_empty() else 1)
