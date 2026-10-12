extends Node
var failures: Array[String] = []
var capture_directory: String = "res://Reports/WorldPrompts"
var level: level_sequence
func settle() -> void:
	var end: int = Time.get_ticks_msec() + 3000
	while Time.get_ticks_msec() < end:
		var pc: computer_terminal = level.computer
		var reader: note_reader = level.get_node("NoteReader")
		var pc_moving: bool = pc.session != null and (pc.session.is_moving() or pc.closing)
		var paper_moving: bool = reader.paper_motion != null and reader.paper_motion.is_running()
		if not pc_moving and not paper_moving and not reader.closing:
			await frames()
			return
		await get_tree().process_frame
	check(false, "World view motion finishes within its expected duration")
func _ready() -> void:
	run.call_deferred()
func check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
		push_error(message)
func frames(count: int = 3) -> void:
	for index in count:
		await get_tree().process_frame
func key(code: Key) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.keycode = code
	event.pressed = true
	Input.parse_input_event(event)
	await frames()
	event.pressed = false
	Input.parse_input_event(event)
	await frames()
func capture(name: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	var image: Image = get_viewport().get_texture().get_image()
	check(image.save_png(capture_directory + "/" + name + ".png") == OK, "Actual rendered capture saves")
func click_control(terminal: computer_terminal, control: Control) -> void:
	var uv: Vector2 = control.get_global_rect().get_center() / Vector2(terminal.display_viewport.size)
	var quad_size: Vector2 = (terminal.screen.mesh as QuadMesh).size
	var local := Vector3((uv.x - .5) * quad_size.x, (.5 - uv.y) * quad_size.y, 0)
	var position: Vector2 = terminal.session.camera.unproject_position(terminal.screen.to_global(local))

	check(terminal.screen_pointer(position).is_equal_approx(control.get_global_rect().get_center()), "Perspective input maps actual quad to viewport pixels")
	var native_position: Vector2 = position * Vector2(get_window().size) / get_viewport().get_visible_rect().size
	var move := InputEventMouseMotion.new()
	move.position = native_position
	move.global_position = native_position
	Input.parse_input_event(move)
	await frames()
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.position = native_position
	event.global_position = native_position
	event.pressed = true
	Input.parse_input_event(event)
	await frames()
	event.pressed = false
	Input.parse_input_event(event)
	await frames()
func run() -> void:
	SaveGame.enabled = false
	SaveGame.saving_disabled = true
	Blackboard.store_data("score", 10000)
	Blackboard.store_data("player_input_blocked", false)
	Blackboard.store_data("spawned_items", [])
	Blackboard.store_data("found_notes", [])
	Flags.set_flag("exited room", true)
	Flags.set_flag("level enabled", true)
	Flags.set_flag("computer enabled", true)
	Flags.set_flag("message computer enabled", true)
	var pool := object_pool.new()
	pool.pooled_scene = load("res://Scenes/audio_player.tscn")
	pool.reset_method = &"reset"
	pool.register_with_blackboard = true
	pool.blackboard_name = &"audio_pool"
	add_child(pool)
	level = load("res://Scenes/testing_level.tscn").instantiate()
	level.spawn_animation_enabled = false
	add_child(level)
	level.player.process_mode = Node.PROCESS_MODE_DISABLED
	await frames(12)
	var camera: Camera3D = level.player.get_node("Camera3D")
	var terminal: computer_terminal = level.computer
	var original_pose: Transform3D = camera.global_transform
	var original_rotation: Vector3 = camera.rotation
	for name in ["CenterContainer", "WorldPrompts", "ComboDisplay", "PortalStatus"]:
		check(level.get_node_or_null(name) != null, "Essential gameplay feedback restored: " + name)
	check(level.get_node("DialoguePlayer").show_text and level.get_node("WordMessage").show_text, "Story text retained")
	var crosshair: Control = level.get_node("CenterContainer")
	var prompts: prompt_display = level.get_node("WorldPrompts")
	var ray: raycaster = prompts.ray
	var lever: Node3D = level.get_node("Lever_Assembly/lever_body")
	camera.global_position = lever.global_position + Vector3(0, 1.2, 2.6)
	camera.look_at(lever.global_position + Vector3(0, .4, 0))
	await frames(4)
	ray._physics_process(0)
	prompts.refresh()
	check(crosshair.visible and prompts.displayed_texts.has("Pull Lever [E]"), "Actual ray contact renders lever prompt and crosshair")
	await capture("gameplay_prompts")
	var feedback_pose: Transform3D = camera.global_transform
	camera.global_transform = original_pose
	ray._set_looked_at(null)
	terminal.interact()
	await frames(2)
	await get_tree().create_timer(terminal.focus_seconds * .35).timeout
	await capture("terminal_approach")
	await settle()
	for hud in get_tree().get_nodes_in_group("gameplay_hud"):
		check(not hud.get("visible"), "Gameplay HUD hidden during physical PC use: " + hud.name)
	check(terminal.interface is Control and terminal.interface.get_parent() == terminal.display_viewport, "Catalog UI is a viewport control on the PC")
	check(terminal.screen_material.albedo_texture == terminal.display_viewport.get_texture(), "PC uses the actual rendered UI texture")
	check(Blackboard.read_data("player_input_blocked") == true and not get_tree().paused, "PC blocks movement without stopping workshop production")
	WorldState._physics_process(0)
	check(Blackboard.read_data("player_camera_rotation").is_equal_approx(original_rotation), "Autosave records gameplay look instead of terminal focus pose")
	await capture("terminal_mechanics")
	# Genuine screen-coordinate tab and purchase clicks, not direct purchase calls.
	terminal.interface.tabs.current_tab = 2
	await frames(12)
	var buy: Button = terminal.interface.tabs.get_child(2).get_node("List").get_child(2).get_node("Buy")
	var score: int = Progression.score()
	await click_control(terminal, buy)
	check(Progression.score() < score, "Real 3D mouse click purchases a catalog delivery")
	await capture("terminal_store")
	await key(KEY_ESCAPE)
	await capture("terminal_return")
	await settle()
	check(terminal.session == null and camera.global_transform.is_equal_approx(original_pose), "Escape restores exact original camera")
	check(terminal.display_viewport.render_target_update_mode == SubViewport.UPDATE_DISABLED and not Blackboard.read_data("player_input_blocked"), "Closed PC stops rendering and releases input")
	check(crosshair.visible, "Crosshair returns after PC disconnect")
	var held_fan: rotatable_item = load("res://Scenes/Actors/fan.tscn").instantiate()
	level.add_child(held_fan)
	var held_pickup: player_pickup = level.player.get_node("Controllers/Player_Pickup")
	camera.global_transform = feedback_pose
	held_pickup.pickup_object(held_fan)
	held_pickup._update_held_object(1.0)
	prompts.refresh()
	check(prompts.displayed_texts.has("[B] Build") and prompts.displayed_texts.has("[F] Drop"), "Carry prompts restored on held fan")
	await capture("carry_prompts")
	var placement: prop_placement = prompts.placement
	check(placement.start_building(), "Fan starts ghost placement")
	prompts.refresh()
	check(prompts.displayed_texts.has("[B] Place") and prompts.displayed_texts.has("[F] Cancel"), "Ghost placement renders place/cancel prompts")
	await capture("build_prompts")
	placement.cancel_building()
	held_pickup.drop_object()
	held_fan.queue_free()
	camera.global_transform = original_pose
	var reader: note_reader = level.get_node("NoteReader")
	var definition: note_definition = load("res://Data/Notes/door.tres")
	# A found bottle becomes readable paper and remains a unique saved journal entry.
	Notes.collect(definition)
	await frames(2)
	await get_tree().create_timer(reader.raise_seconds * .35).timeout
	await capture("physical_note_rise")
	await settle()
	for hud in get_tree().get_nodes_in_group("gameplay_hud"):
		check(not hud.get("visible"), "Gameplay HUD hidden while reading: " + hud.name)
	check(reader.is_open and reader.holder.get_parent() == camera and get_tree().paused, "Pickup creates lit paper held in front of the real camera")
	check(reader.holder.get_node("ReadingLight").light_cull_mask == note_reader.READING_LAYER, "Reading light affects the paper only")
	check(not level.get_node("PauseMenu").is_open and not reader.transcript.visible, "Physical reading has no pause or transcript overlay")
	await capture("physical_note")
	await key(KEY_N)
	check(reader.typed and reader.transcript.visible and not reader.holder.visible and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE, "N brings up the typed transcript with scrollable content")
	await capture("typed_note")
	await key(KEY_N)
	check(not reader.typed and reader.holder.visible, "N closes transcript and restores the physical paper")
	await key(KEY_ESCAPE)
	await capture("physical_note_lower")
	await settle()
	check(not reader.is_open and not get_tree().paused and not Blackboard.read_data("player_input_blocked") and crosshair.visible, "Putting away restores gameplay ownership and crosshair")
	await key(KEY_N)
	check(reader.is_open and reader.typed, "N outside a reading session reopens the latest collected transcript")
	reader.close()
	await settle()
	var menu: pause_menu = level.get_node("PauseMenu")
	menu.open()
	menu.show_notes()
	check(menu.list.item_count == 1, "Pause menu lists saved note titles")
	menu._select_note(0)
	await frames(15)
	await settle()
	check(reader.is_open and reader.from_journal and not menu.is_open, "Pause selection hands off to the in-world paper")
	await capture("journal_paper")
	reader.close()
	await settle()
	check(menu.is_open and menu.journal.visible and get_tree().paused, "Reader close returns to the same paused journal")
	menu.close()
	var encoded: Variant = SaveGame._encode(Notes.all_notes())
	var decoded: Array = SaveGame._decode(encoded)
	check(decoded[0].definition_path == definition.resource_path and decoded[0].body == definition.body, "Physical note authoring reference and transcript survive the save codec")
	# Closing while a diagnostic modal owns input must preserve its original session.
	reader.open_note(definition.snapshot())
	var before_light: int = level.get_node("ceiling_chute/LevelLight2").light_cull_mask
	check(before_light & note_reader.READING_LAYER == 0, "World lights cannot wash out paper")
	reader.close()
	await settle()
	check(level.get_node("ceiling_chute/LevelLight2").light_cull_mask & note_reader.READING_LAYER != 0, "World lighting mask restored after reading")
	# Carried cargo is hidden for reading, then restored without dropping it.
	var carried_basket: RigidBody3D = load("res://Scenes/Actors/basket.tscn").instantiate()
	level.add_child(carried_basket)
	var pickup: player_pickup = level.player.get_node("Controllers/Player_Pickup")
	pickup.pickup_object(carried_basket)
	reader.open_note(definition.snapshot())
	check(not carried_basket.visible and carried_basket.freeze and pickup.held_object == carried_basket, "Paper reading preserves the held basket while hiding its model")
	reader.close()
	await settle()
	check(carried_basket.visible and carried_basket.freeze and pickup.held_object == carried_basket, "Closing paper restores the same held basket and physics state")
	pickup.drop_object()
	# Optional artist-made geometry and page texture survive actual resource/save paths.
	var artist_root := Node3D.new()
	var mesh := MeshInstance3D.new()
	mesh.name = "AuthoredFace"
	mesh.mesh = QuadMesh.new()
	artist_root.add_child(mesh)
	mesh.owner = artist_root
	var packed := PackedScene.new()
	packed.pack(artist_root)
	ResourceSaver.save(packed, "user://reading_art.tscn")
	artist_root.free()
	var authored := note_definition.new()
	authored.id = &"art_fixture"
	authored.body = "Artist note transcript"
	authored.reading_scene = load("user://reading_art.tscn")
	ResourceSaver.save(authored, "user://reading_definition.tres")
	authored = load("user://reading_definition.tres")
	reader.open_note(authored.snapshot())
	check(reader.holder.get_child(0).has_node("AuthoredFace") and reader.holder.get_child(0).get_node("AuthoredFace").layers == note_reader.READING_LAYER, "Saved custom note scene is instantiated on the isolated reading layer")
	reader.close()
	await settle()
	# Legacy journals with no asset fields still print readable paper.
	reader.open_note({"id": "legacy", "title": "OLD JOURNAL", "body": "Legacy content"})
	check(reader.page_viewport != null and reader.print_text.text.contains("Legacy content"), "Existing save journals need no migration")
	reader.close()
	await settle()
	# Tear down an open PC while its camera is removed first.
	terminal.interact()
	await frames(4)
	level.queue_free()
	await frames(6)
	check(not get_tree().paused and not Blackboard.read_data("player_input_blocked") and Blackboard.read_data("world_view_session") == null, "Scene unload releases the viewing session without a stale lock")
	for audio: audio_player in pool.active:
		audio.reset()
	# Allow the audio mixer to release cancelled WAV playback before quitting.
	await get_tree().create_timer(.12).timeout
	print("World interfaces / physical notes / 3D mouse / journal / save / cleanup: ", "PASS" if failures.is_empty() else failures)
	get_tree().quit(0 if failures.is_empty() else 1)
