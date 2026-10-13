extends Node
var failures: Array[String] = []
func _ready() -> void:
	run.call_deferred()
func check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
		push_error(message)
func tick(count: int = 3) -> void:
	for i in count:
		await get_tree().physics_frame
		await get_tree().process_frame
func run() -> void:
	SaveGame.save_path = "user://prestige_items_test.save"
	SaveGame.enabled = false
	SaveGame.saving_disabled = false
	SaveGame.reset_save()
	SaveGame.saving_disabled = false
	SaveGame.profile = {"mulch_coins": 499, "mulch_upgrades": {}, "settings": {}}
	Blackboard.store_data("score", 1234)
	Blackboard.store_data("spawned_items", [])
	Flags.set_flag("mulcher purchased", true)
	Flags.set_flag("mulch bin purchased", true)
	Progression.register_catalog(load("res://Data/Computer/default_catalog.tres"))
	var entry: computer_entry = Progression.entries[&"grind_additional_items"]
	var world := Node3D.new()
	add_child(world)
	Blackboard.store_data("game_root", world)
	var player: CharacterBody3D = load("res://Scenes/Player/player.tscn").instantiate()
	player.process_mode = Node.PROCESS_MODE_DISABLED
	world.add_child(player)
	var pickup: player_pickup = player.get_node("Controllers/Player_Pickup")
	var ray: raycaster = player.get_node("Camera3D/RayCast3D")
	# Tag the wrapper only: its existing collider must inherit the restriction.
	var actor: Node3D = load("res://Scenes/test_object.tscn").instantiate()
	actor.start_force = 0
	actor.add_to_group("prestige items")
	world.add_child(actor)
	var body: RigidBody3D = actor.get_node("RigidBody3D")
	var loader: rail_station = load("res://Scenes/Actors/rail_loader.tscn").instantiate()
	loader.position = Vector3(20,0,0)
	loader.freeze = true
	world.add_child(loader)
	body.global_position = loader.to_global(Vector3(0,.9,1.5))
	var car: rail_slider = load("res://Scenes/Actors/rail_slider.tscn").instantiate()
	car.position = Vector3(35,0,0)
	world.add_child(car)
	await tick(4)
	loader._capture_intake()
	check(loader.queue.is_empty() and not car.accept_cargo(body,car.global_transform), "Stations and carriage cargo cannot bypass the locked pickup permission")
	var grinder := grinding_area.new()
	grinder.grind_sound = null
	world.add_child(grinder)
	check(ProjectSettings.has_setting("global_group/prestige items"), "Prestige items exists as a named editor global group")
	check(not ray._is_valid_target(body) and not pickup.pickup_object(body), "Locked wrapper blocks targeting and scripted pickup of its child body")
	check(not physics_items.is_processable(body) and not grinder.grind(body) and not actor.is_queued_for_deletion(), "Locked prestige item cannot enter basket/multi-grab feedstock or reward grinding")
	var marker := Marker3D.new()
	world.add_child(marker)
	check(Progression.purchase(entry,world,marker,player) == "Not enough mulch coins." and not Mulch.prestige_items_unlocked(), "Expensive unlock requires 500 banked pellets")
	SaveGame.profile["mulch_coins"] = 501
	check(Progression.purchase(entry,world,marker,player).is_empty() and Mulch.coins() == 1 and Progression.score() == 1234, "Purchase spends pellets once without charging the run score")
	loader._capture_intake()
	check(loader.queue.size() == 1, "Existing queued-area object becomes eligible after the unlock")
	check(ray._is_valid_target(body) and pickup.pickup_object(body), "Existing item becomes targetable and pickable immediately")
	pickup.drop_object()
	check(Progression.purchase(entry,world,marker,player) == "Upgrade complete." and Mulch.coins() == 1, "One-time unlock cannot charge twice")
	check(grinder.grind(body) and not grinder.grind(body), "Unlocked prestige item grinds once through normal reward ownership")
	await tick()
	# The same normal single-file profile must restore this story prerequisite.
	SaveGame.profile["mulch_upgrades"] = {}
	SaveGame.load_profile()
	check(Mulch.prestige_items_unlocked(), "Unlock is recovered from the actual saved profile")
	check(SaveGame.new_game() and Mulch.prestige_items_unlocked() and Mulch.coins() == 1, "New Game retains the permanent true-ending prerequisite")
	Flags._flags.clear()
	check(Mulch.prestige_items_unlocked(), "Permission is profile-owned and independent of reset run flags")
	world.queue_free()
	await tick()
	SaveGame.reset_save()
	print("Prestige group / targeting / pickup / grinding / price / actual profile reload / New Game: ", "PASS" if failures.is_empty() else str(failures))
	get_tree().quit(0 if failures.is_empty() else 1)
