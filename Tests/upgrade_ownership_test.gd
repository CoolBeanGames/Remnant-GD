extends Node

@export var capture_directory: String = ""
var failures: Array[String] = []
var world: Node3D
var player: CharacterBody3D
var terminal: computer_terminal
var purchase_events: int = 0

func check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
		push_error(message)

func tick(count: int = 3) -> void:
	for i in count:
		await get_tree().physics_frame
		await get_tree().process_frame

func _ready() -> void:
	if DisplayServer.get_name() != "headless":
		DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS, true)
	run.call_deferred()

func on_purchase(_entry: computer_entry, _actor: Node3D) -> void:
	purchase_events += 1

func row_for(id: StringName) -> Control:
	for state in terminal.interface.rows:
		if state.entry.id == id:
			return state.row
	return null

func capture(entry_name: String) -> void:
	if capture_directory.is_empty() or DisplayServer.get_name() == "headless":
		return
	DirAccess.make_dir_recursive_absolute(capture_directory)
	await tick()
	await RenderingServer.frame_post_draw
	check(get_viewport().get_texture().get_image().save_png(capture_directory + "/" + entry_name + ".png") == OK, "Actual PC screenshot saved")

func run() -> void:
	SaveGame.enabled = false
	SaveGame.saving_disabled = false
	SaveGame.save_path = "user://upgrade_ownership_test.save"
	Blackboard._data.clear()
	Flags._flags.clear()
	SaveGame.profile = {"mulch_coins": 1000, "mulch_upgrades": {}, "settings": {}, "lifetime_score": 100000}
	Progression.entries.clear()
	Progression.levels.clear()
	Progression.restored_levels = true
	Blackboard.store_data("score", 100000)
	world = Node3D.new()
	add_child(world)
	Blackboard.store_data("game_root", world)
	player = load("res://Scenes/Player/player.tscn").instantiate()
	player.process_mode = Node.PROCESS_MODE_DISABLED
	world.add_child(player)
	player.get_node("Camera3D").make_current()
	terminal = load("res://Scenes/Computer/computer_terminal.tscn").instantiate()
	terminal.player = player
	terminal.focus_seconds = 0
	var delivery := Marker3D.new()
	delivery.position = Vector3(10, 8, 10)
	world.add_child(delivery)
	terminal.delivery_point = delivery
	world.add_child(terminal)
	Progression.purchased.connect(on_purchase)
	var gated: int = 0
	for entry: computer_entry in Progression.entries.values():
		if entry.required_purchase == &"":
			continue
		gated += 1
		check(not Progression.entry_visible(entry), "Unpurchased tool upgrade stays hidden despite high earnings: " + str(entry.id))
		check(Progression.purchase(entry, world, delivery, player).begins_with("Purchase "), "Direct purchase rejects unowned tool: " + str(entry.id))
		check(Progression.level(entry) == 0, "Rejected upgrade has no tier: " + str(entry.id))
	check(gated == 17 and Progression.score() == 100000 and Mulch.coins() == 1000 and purchase_events == 0, "All seventeen prerequisites reject without currency, delivery or purchase events")
	for id in [&"item_value", &"run_speed", &"jump", &"multi_grab", &"combo_max", &"lever_cooldown", &"lever_output"]:
		check(Progression.entry_visible(Progression.entries[id]), "Existing system upgrades need no store purchase: " + str(id))
	terminal.interact()
	await tick(8)
	check(not row_for(&"plate_bounce").visible and not row_for(&"fan_power").visible, "Actual Mechanics rows hide unowned tool offers")
	await capture("before_purchase")
	terminal.interface._buy(Progression.entries[&"buy_steel_plate"])
	check(row_for(&"plate_bounce").visible and row_for(&"plate_air_placement").visible and not row_for(&"fan_power").visible, "The first plate purchase immediately reveals only its own upgrades")
	await capture("after_plate_purchase")
	# Removing the delivered object does not remove the purchase history.
	var delivered: Node3D = world.get_child(world.get_child_count() - 1)
	delivered.queue_free()
	await tick()
	check(Progression.entry_visible(Progression.entries[&"plate_bounce"]), "Lost or ground tools retain their run upgrade access")
	for id in [&"buy_fan", &"buy_push_broom", &"buy_light", &"buy_automatic_spawner"]:
		check(terminal.buy(Progression.entries[id]).is_empty(), "Buy first tool: " + str(id))
		for entry: computer_entry in Progression.entries.values():
			if entry.required_purchase == id:
				check(Progression.entry_visible(entry), "First purchase reveals all matching regular/permanent offers: " + str(entry.id))
	# Tool ownership and lifetime discovery are independent requirements.
	var fan_power: computer_entry = Progression.entries[&"fan_power"]
	SaveGame.profile["lifetime_score"] = 500
	Blackboard.store_data("score", 0)
	check(not Progression.entry_visible(fan_power), "Purchased fan still waits for its 600 lifetime score threshold")
	SaveGame.profile["lifetime_score"] = 100000
	Blackboard.store_data("score", 90000)
	check(terminal.buy(fan_power).is_empty(), "Owned, discovered regular fan upgrade is purchasable")
	# The permanent installation qualifies without a current-run Store count.
	SaveGame.profile["mulcher_unlocked"] = true
	check(Progression.entry_visible(Progression.entries[&"mulcher_durability"]), "Persistent installed Mulcher grants regular upgrade access")
	Flags.set_flag("mulcher purchased", true)
	Flags.set_flag("mulch bin purchased", true)
	check(terminal.buy(Progression.entries[&"mulch_fan"]).is_empty(), "Owned fan allows its permanent currency upgrade")
	Progression.levels.erase(&"buy_fan")
	var coins_before: int = Mulch.coins()
	var events_before: int = purchase_events
	check(not Progression.entry_visible(fan_power) and not Progression.entry_visible(Progression.entries[&"mulch_fan"]), "Previously upgraded entries cannot bypass a missing base purchase")
	check(Mulch.buy_upgrade(Progression.entries[&"mulch_fan"], player) == "Purchase Fan first." and Mulch.coins() == coins_before and purchase_events == events_before, "Direct Mulch API cannot bypass the requirement or spend coins")
	Progression.levels[&"buy_fan"] = 1
	var missing := computer_entry.new()
	missing.required_purchase = &"missing_store_id"
	check(not Progression.entry_visible(missing) and Progression.purchase_requirement_error(missing) == "Required item purchase unavailable.", "Missing prerequisite fails closed")
	missing.required_purchase = &"run_speed"
	check(not Progression.entry_visible(missing), "A non-Store prerequisite is invalid")
	terminal.close_interface(true)
	check(SaveGame.save_now() and SaveGame.load_now(), "Real disk Continue restores purchase history")
	Progression.register_catalog(terminal.catalog)
	check(Progression.entry_visible(Progression.entries[&"plate_bounce"]) and Progression.entry_visible(fan_power), "Continue retains tool upgrade access without needing surviving props")
	check(SaveGame.new_game(), "New Game resets run purchases")
	Progression.register_catalog(terminal.catalog)
	check(Mulch.upgrade_level(&"mulch_fan") == 1 and not Progression.entry_visible(Progression.entries[&"mulch_fan"]) and not Progression.entry_visible(fan_power), "New Game retains paid permanent effects but hides further fan upgrades until another first purchase")
	check(Progression.entry_visible(Progression.entries[&"mulcher_durability"]), "Permanent Mulcher remains eligible across New Game")
	check(Progression.entry_visible(Progression.entries[&"buy_light"]), "Starter store tools remain available after reset")
	world.queue_free()
	await tick()
	SaveGame.reset_save()
	print("Upgrade ownership / catalog / real PC refresh / direct APIs / disk Continue / New Game: ", "PASS" if failures.is_empty() else str(failures))
	get_tree().quit(0 if failures.is_empty() else 1)
