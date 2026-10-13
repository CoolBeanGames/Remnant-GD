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
	Blackboard.store_data("found_notes", [])
	Blackboard.store_data("spawned_items", [])
	Blackboard.store_data("score", 0)
	Blackboard.store_data("lever_pulls", 0)
	Flags.set_flag("level enabled", true)
	Flags.set_flag("grinder enabled", false)
	Flags.set_flag("computer enabled", false)
	var level: level_sequence = load("res://Scenes/testing_level.tscn").instantiate()
	level.set("spawn_animation_enabled", false)
	add_child(level)
	level.player.process_mode = Node.PROCESS_MODE_DISABLED
	level.player.disable_mode = CollisionObject3D.DISABLE_MODE_KEEP_ACTIVE
	await get_tree().process_frame
	var pc_light: Light3D = level.get_node("ceiling_chute/LevelLight2")
	check(pc_light.light_energy == 0 and not level.computer.enabled, "Actual PC-area spotlight stays off at initial unlock")
	Blackboard.store_data("score", 30)
	level._process(0)
	check(pc_light.light_energy > 0 and level.computer.enabled, "PC spotlight unlocks only at 30 points")
	var fan: switchable_prop = load("res://Scenes/Actors/fan.tscn").instantiate()
	level.add_child(fan)
	fan.freeze = true
	WorldState.track(fan)
	check(not fan.has_node("Arrow10"), "Fan model has no facing arrow")
	fan.interact()
	check(not fan.powered and fan.get_node("Wind").collision_mask == 0 and not fan.get_node("Airflow").emitting, "Switching off fan stops wind and particles")
	check(fan.get_look_prompts().entries.back().text == "Turn On Fan", "Toggle prompt changes with power")
	fan.interact()
	check(fan.powered and fan.get_node("Wind").collision_mask == 1, "Switching on restores fan wind")
	var lamp: switchable_prop = load("res://Scenes/Actors/light.tscn").instantiate()
	level.add_child(lamp)
	lamp.freeze = true
	lamp.interact()
	check(not lamp.get_node("OmniLight3D").visible, "Work light turns off")
	lamp.interact()
	check(lamp.get_node("OmniLight3D").visible, "Work light turns back on")
	var pickup: player_pickup = level.player.get_node("Controllers/Player_Pickup")
	var placement: prop_placement = level.player.get_node("Controllers/Prop_Placement")
	pickup.pickup_object(fan)
	placement.start_building()
	check(placement.preview.has_node("BuildDirection"), "Facing arrow exists in build ghost")
	placement.cancel_building()
	check(not fan.has_node("BuildDirection"), "Cancel never attaches arrow to real prop")
	pickup.drop_object()
	fan.freeze = true
	level.chute.note_drop_chance = 1.0
	level.chute.spawn()
	var drop: note_drop
	for id in WorldState.items:
		var actor: Node3D = WorldState._actor(id)
		if actor is note_drop:
			drop = actor
	check(drop != null and drop.note != null and drop.linear_velocity.y < 0, "Chute drops authored note with downward exit velocity")
	await get_tree().create_timer(7.0).timeout
	check(is_instance_valid(drop), "Chute note remains in world after landing instead of falling through floor")
	if not is_instance_valid(drop):
		get_tree().quit(1)
		return
	check(drop.global_position.y > .02 and drop.global_position.y < .3, "Note passes through chute and settles above floor")
	var definition: note_definition = drop.note
	pickup.ray.looked_at = drop
	check(pickup.try_pickup() and not pickup.is_holding_object(), "F collects and reads instead of carrying note")
	await get_tree().process_frame
	var menu: pause_menu = level.get_node("PauseMenu")
	var reader: note_reader = level.get_node("NoteReader")
	check(reader.is_open and not menu.is_open and get_tree().paused, "Collecting holds a physical note while the world pauses")
	check(Notes.has_note(definition.id) and Notes.all_notes().size() == 1, "Note saved once to Blackboard")
	check(reader.current_note.body == definition.body and reader.holder != null, "Physical reader retains authored content")
	reader.close()
	await get_tree().create_timer(reader.lower_seconds + .06).timeout
	check(not get_tree().paused and not Blackboard.read_data("player_input_blocked"), "Continue restores play and input")
	Notes.collect(definition)
	await get_tree().process_frame
	check(Notes.all_notes().size() == 1, "Duplicate pickups do not duplicate journal entries")
	reader.close()
	await get_tree().create_timer(reader.lower_seconds + .06).timeout
	var escape := InputEventKey.new()
	escape.physical_keycode = KEY_ESCAPE
	escape.pressed = true
	menu._input(escape)
	check(menu.is_open and get_tree().paused, "Escape opens pause menu")
	menu.show_notes()
	check(menu.list.item_count == 1, "Pause journal lists collected note titles")
	menu._select_note(0)
	check(reader.is_open and not menu.is_open and reader.from_journal, "Journal selection opens the physical note")
	reader.close()
	await get_tree().create_timer(reader.lower_seconds + .06).timeout
	check(menu.is_open and menu.journal.visible, "Putting the paper away returns to the paused journal")
	menu._input(escape)
	check(menu.main.visible and menu.is_open, "Escape goes back from journal")
	menu._input(escape)
	check(not menu.is_open and not get_tree().paused, "Escape resumes from pause menu")
	check(not level.chute.notes_catalog.available().has(definition), "Found notes leave the drop pool")
	fan.set_powered(false)
	level.chute.spawn()
	WorldState.capture()
	var records: Array = Blackboard.read_data("spawned_items").duplicate(true)
	level.queue_free()
	await get_tree().process_frame
	Blackboard.store_data("spawned_items", records)
	var restored: level_sequence = load("res://Scenes/testing_level.tscn").instantiate()
	restored.set("spawn_animation_enabled", false)
	add_child(restored)
	restored.player.process_mode = Node.PROCESS_MODE_DISABLED
	await get_tree().process_frame
	var restored_note: bool = false
	var restored_fan: bool = false
	for id in WorldState.items:
		var actor: Node3D = WorldState._actor(id)
		if actor is note_drop:
			restored_note = actor.note != null
		elif actor is switchable_prop:
			restored_fan = not actor.powered
	check(restored_note and restored_fan, "Uncollected note content and fan power restore")
	check(Notes.all_notes().size() == 1, "Found-note journal survives level restart")
	restored.queue_free()
	await get_tree().process_frame
	for audio: audio_player in pool.active:
		audio.reset()
	await get_tree().create_timer(.1).timeout
	print("Notes, pause menu, toggles and PC light: ", "PASS" if failures.is_empty() else str(failures))
	get_tree().quit(0 if failures.is_empty() else 1)
