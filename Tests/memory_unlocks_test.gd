extends Node

var failures: Array[String] = []
var portal: door_portal
var capture_directory: String = "res://Reports/MemoryUnlocks"

func check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
		push_error(message)

func tick(count: int = 3) -> void:
	for i in count:
		await get_tree().physics_frame
		await get_tree().process_frame

func capture(name: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	await tick()
	await RenderingServer.frame_post_draw
	check(get_viewport().get_texture().get_image().save_png(capture_directory + "/" + name + ".png") == OK, "Actual in-world display capture saved")

func _ready() -> void:
	run.call_deferred()

func run() -> void:
	if DisplayServer.get_name() != "headless":
		DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS, true)
	SaveGame.reset_save()
	SaveGame.saving_disabled = false
	SaveGame.enabled = false
	SaveGame.save_path = "user://memory_unlocks_test.save"
	Flags._flags.clear()
	Progression.levels.clear()
	Progression.entries.clear()
	Progression.restored_levels = false
	Blackboard.store_data("upgrade_levels", {})
	Blackboard.store_data("player_input_blocked", false)
	Blackboard.store_data("score", 76500)
	Blackboard.store_data("portal_inside", false)
	Blackboard.remove_data("active_memory_id")
	Blackboard.store_data("spawned_items", [])
	var world := Node3D.new()
	add_child(world)
	Blackboard.store_data("game_root", world)
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_energy = .8
	world.add_child(environment)
	var player: CharacterBody3D = load("res://Scenes/Player/player.tscn").instantiate()
	player.process_mode = Node.PROCESS_MODE_DISABLED
	world.add_child(player)
	WorldState.begin(world, player)
	var door: Node3D = load("res://Models/Door/source/doorway_animated.glb").instantiate()
	door.set_script(load("res://Scripts/Actors/start_room_door.gd"))
	door.position = Vector3(-20, 0, 0)
	world.add_child(door)
	portal = door_portal.new()
	portal.door = door as start_room_door
	portal.player = player
	portal.purchase_required = true
	portal.destinations.assign([load("res://Data/Portal/apartment.tres"), load("res://Data/Portal/warehouse.tres"), load("res://Data/Portal/hospital.tres")])
	world.add_child(portal)
	Flags.set_flag("exited room", true)
	await tick()
	check(not portal.active, "Removing the start room does not open an unpurchased memory")
	var terminal: computer_terminal = load("res://Scenes/Computer/computer_terminal.tscn").instantiate()
	terminal.player = player
	terminal.focus_seconds = 0
	terminal.return_seconds = 0
	world.add_child(terminal)
	await tick()
	terminal._open_interface()
	await tick()
	var ui: computer_ui = terminal.interface
	ui.tabs.current_tab = computer_entry.Tab.SELF
	await tick()
	ui.tabs.get_child(1).scroll_vertical = int(ui.tabs.get_child(1).get_v_scroll_bar().max_value)
	check(ui.tabs.get_child(1).get_node("List").get_child_count() == 6, "Self tab includes the three abilities and all memory purchases")
	await capture("available")
	var prices: Array[int] = [1500, 25000, 50000]
	for i in 3:
		var entry: computer_entry = Progression.entries[StringName("memory_%d" % (i + 1))]
		var flag_name: String = "memory %d unlocked" % (i + 1)
		var button: Button
		for state in ui.rows:
			if state.entry == entry:
				button = state.row.get_node("Buy")
		check(entry.cost(0) == prices[i] and entry.max_level == 1, "Memory %d has its exact one-time price" % (i + 1))
		Blackboard.store_data("score", prices[i] - 1)
		ui.refresh()
		check(button.disabled and terminal.buy(entry) == "Not enough score." and not Flags.check_flag(flag_name) and Progression.level(entry) == 0, "Insufficient score cannot buy or unlock Memory %d" % (i + 1))
		Blackboard.store_data("score", prices[i])
		ui.refresh()
		check(not button.disabled and button.text == "BUY / %d" % prices[i], "Affordable memory is offered through the actual display")
		button.pressed.emit()
		var saved_tiers: Dictionary = Blackboard.read_data("upgrade_levels")
		check(Progression.score() == 0 and Progression.level(entry) == 1 and saved_tiers.get(entry.id) == 1 and Flags.check_flag(flag_name), "Button spends exact score and records Memory %d flag and tier" % (i + 1))
		check(button.disabled and button.text == "OPEN PORTAL" and portal.active and portal.active_destination_id == entry.memory_destination, "Purchase opens its actual area and disables duplicate charges")
		check(terminal.buy(entry) == "Memory already open." and Progression.score() == 0, "Open memory cannot be charged twice")
		check(not portal.cycle_destination(), "F9 cannot switch an active paid memory")
		Blackboard.store_data("score", 100000)
		ui.refresh()
		if i == 0:
			await capture("active")
		if i < 2:
			var next_entry: computer_entry = Progression.entries[StringName("memory_%d" % (i + 2))]
			check(terminal.buy(next_entry) == "Complete %s first." % entry.title and Progression.score() == 100000, "An unfinished memory blocks another purchase even with enough score")
		terminal.close_interface(true)
		portal.teleport_player(portal.mapping(portal.source_frame, portal.destination_frame))
		check(portal.inside and player.collision_mask == portal_space.ROOM_LAYER, "Player enters the purchased memory space")
		var old_room: WeakRef = weakref(portal.room)
		var inside_pose: Transform3D = player.global_transform
		portal.teleport_player(portal.mapping(portal.destination_frame, portal.source_frame))
		await tick()
		check(portal.active and portal.inside and old_room.get_ref() == portal.room and player.global_transform == inside_pose and player.collision_mask == portal_space.ROOM_LAYER and Blackboard.read_data("active_memory_id") == str(entry.id), "An unfinished memory blocks direct return and retains its room, saved identity and player space")
		check(not Flags.check_flag(entry.completion_flag), "A blocked return does not invent story completion")
		check(terminal.buy(entry) == "Memory already open." and Progression.score() == 100000, "The unfinished open memory remains owned without another charge")
		Flags.set_flag(entry.completion_flag, true)
		check(Progression.pending_memory() == null and portal.active and portal.inside, "Explicit completion releases purchase lock while preserving the occupied room")
		portal.teleport_player(portal.mapping(portal.destination_frame, portal.source_frame))
		await tick()
		check(not portal.active and terminal.buy(entry) == "Upgrade complete.", "Completed memory closes on exit and cannot be purchased again")
		terminal._open_interface()
		await tick()
		ui.tabs.current_tab = computer_entry.Tab.SELF
		ui.tabs.get_child(1).scroll_vertical = int(ui.tabs.get_child(1).get_v_scroll_bar().max_value)
	await capture("unlocked")
	terminal.close_interface(true)
	SaveGame.profile["mulch_coins"] = 7
	check(SaveGame.save_now(), "Memory purchases write through the ordinary save file")
	Blackboard.store_data("upgrade_levels", {})
	Flags._flags.clear()
	check(SaveGame.load_now(), "Ordinary disk save reload succeeds")
	Progression.register_catalog(terminal.catalog)
	for i in 3:
		check(Flags.check_flag("memory %d unlocked" % (i + 1)) and Flags.check_flag("memory %d complete" % (i + 1)) and Progression.level(Progression.entries[StringName("memory_%d" % (i + 1))]) == 1, "Reload restores Memory %d flag and prevents repurchase" % (i + 1))
	Flags.remove_flag("memory 2 unlocked")
	Progression.register_catalog(terminal.catalog)
	check(Flags.check_flag("memory 2 unlocked"), "Saved purchased tier repairs a missing unlock flag when binding a catalog")
	check(SaveGame.new_game() and Mulch.coins() == 7, "New Game retains permanent currency")
	Progression.register_catalog(terminal.catalog)
	for i in 3:
		check(not Flags.check_flag("memory %d unlocked" % (i + 1)) and not Flags.check_flag("memory %d complete" % (i + 1)) and Progression.level(Progression.entries[StringName("memory_%d" % (i + 1))]) == 0, "New Game resets run-scoped Memory %d purchases" % (i + 1))
	world.queue_free()
	await tick()
	SaveGame.reset_save()
	print("Memory unlocks / display / exact score / real destinations / completion gate / blocked return / completed exit / save: ", "PASS" if failures.is_empty() else failures)
	get_tree().quit(0 if failures.is_empty() else 1)
