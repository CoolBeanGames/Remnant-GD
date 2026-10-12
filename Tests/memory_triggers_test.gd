extends Node

var failures: Array[String] = []
var capture_directory: String = ""
var level: level_sequence
var portal: door_portal
var ray: raycaster
var player: CharacterBody3D
var camera: Camera3D

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

func bind_level() -> void:
	level = load("res://Scenes/testing_level.tscn").instantiate()
	level.spawn_animation_enabled = false
	add_child(level)
	player = level.player
	player.process_mode = Node.PROCESS_MODE_DISABLED
	player.disable_mode = CollisionObject3D.DISABLE_MODE_KEEP_ACTIVE
	camera = player.get_node("Camera3D")
	ray = camera.get_node("RayCast3D")
	ray.process_mode = Node.PROCESS_MODE_ALWAYS
	ray.add_exception(player)
	player.get_node("Controllers/Player_Interact").process_mode = Node.PROCESS_MODE_ALWAYS
	portal = level.get_node("DoorPortal")
	Blackboard.store_data("player_input_blocked", false)
	await tick(8)
	Dialogue.cancel()

func aim(target: memory_object) -> void:
	var point: Vector3 = target.to_global(Vector3(0, .12, 0))
	var aim_area: Node3D = target.get_node_or_null("StoryAim")
	if aim_area != null:
		point = aim_area.global_position
	else:
		var bounds := AABB()
		for mesh: MeshInstance3D in target.find_children("*", "MeshInstance3D", true, false):
			var local_bounds: AABB = (target.global_transform.affine_inverse() * mesh.global_transform) * mesh.get_aabb()
			bounds = local_bounds if bounds.size == Vector3.ZERO else bounds.merge(local_bounds)
		point = target.to_global(bounds.get_center())
	var found: bool = false
	var offsets: Array[Vector3] = [Vector3(0, .6, -2.5), Vector3(0, .6, 2.5), Vector3(-2.5, .6, 0), Vector3(2.5, .6, 0), Vector3(0, 1.5, .5)]
	if target.name == &"FamilyPhoto":
		offsets.push_front(Vector3(-2.0, .15, 0))
	for offset in offsets:
		player.global_position = point + offset - Vector3(0, 1.65, 0)
		camera.global_position = point + offset
		camera.look_at(point)
		await tick()
		ray._physics_process(0)
		if ray.get_looked_at() == target:
			found = true
			break
	check(found, "Actual ray reaches " + str(target.name))

func e_key() -> void:
	var event := InputEventKey.new()
	event.physical_keycode = KEY_E
	event.keycode = KEY_E
	event.pressed = true
	Input.parse_input_event(event)
	await tick()
	event.pressed = false
	Input.parse_input_event(event)
	await tick(5)

func finish_dialogue() -> void:
	Dialogue.cancel()
	if is_instance_valid(Dialogue.view):
		Dialogue.view.confirm_consumed = false
	await tick()

func capture(name: String) -> void:
	if capture_directory.is_empty() or DisplayServer.get_name() == "headless":
		return
	await tick()
	await RenderingServer.frame_post_draw
	check(get_viewport().get_texture().get_image().save_png(capture_directory + "/" + name + ".png") == OK, "Actual story frame saved")

func run() -> void:
	SaveGame.reset_save()
	SaveGame.enabled = false
	SaveGame.saving_disabled = true
	SaveGame.save_path = "user://memory_triggers_test.save"
	Flags._flags.clear()
	Blackboard._data.clear()
	Progression.entries.clear()
	Progression.levels.clear()
	Progression.restored_levels = false
	Flags.set_flag("exited room", true)
	Flags.set_flag("level enabled", true)
	Flags.set_flag("computer enabled", true)
	Flags.set_flag("message computer enabled", true)
	Blackboard.store_data("score", 100000)
	Blackboard.store_data("spawned_items", [])
	await bind_level()
	check(portal.open_memory(&"memory_1", &"apartment"), "Apartment opens through production portal")
	portal.teleport_player(portal.mapping(portal.source_frame, portal.destination_frame))
	await tick(8)
	var photo: memory_object = portal.room.get_node("Art/FamilyPhoto")
	await aim(photo)
	check(not Flags.check_flag(photo.story.interaction_flag), "Looking at required prop does not complete it")
	check(photo.get_look_prompts().entries[0].get_display_text().ends_with("[E]"), "World prompt resolves the current E binding")
	await capture("apartment_photo_prompt")
	await e_key()
	check(Flags.check_flag("memory 1 photo") and Dialogue.view.current == photo.story.interaction_dialogue, "Real E dispatch sets photo flag and starts editable dialogue")
	if not capture_directory.is_empty() and DisplayServer.get_name() != "headless":
		await get_tree().create_timer(1.8).timeout
	await capture("apartment_photo_dialogue")
	await finish_dialogue()
	await e_key()
	check(Dialogue.view.current == null, "Repeated E does not replay an acknowledged objective")
	var coffee: memory_object = portal.room.get_node("Art/CoffeePot")
	await aim(coffee)
	var flag_count: int = Flags._flags.size()
	get_tree().paused = true
	await get_tree().create_timer(1.0, true).timeout
	check(Dialogue.view.current == null, "Pause prevents look flavor")
	get_tree().paused = false
	Blackboard.store_data("player_input_blocked", true)
	await get_tree().create_timer(1.0).timeout
	check(Dialogue.view.current == null, "Wake/modal input ownership prevents look flavor")
	Blackboard.store_data("player_input_blocked", false)
	await get_tree().create_timer(1.0).timeout
	check(Dialogue.view.current == coffee.story.look_dialogue and coffee.get_look_prompts() == null, "Coffee plays on sustained real look without interaction prompt")
	check(Flags._flags.size() == flag_count, "Look flavor creates no flags")
	if not capture_directory.is_empty() and DisplayServer.get_name() != "headless":
		await get_tree().create_timer(1.6).timeout
	check(not Flags.check_flag("memory 1 phone") and not Flags.check_flag("memory 1 bills") and not Flags.check_flag("memory 1 complete"), "Flavor cannot contribute to completion")
	await capture("apartment_coffee_flavor")
	await finish_dialogue()
	var phone: memory_object = portal.room.get_node("Art/LandlinePhone")
	await aim(phone)
	await get_tree().create_timer(1.0).timeout
	check(Dialogue.view.current == phone.story.look_dialogue and not Flags.check_flag("memory 1 phone"), "Phone look flavor is separate from its required E objective")
	await finish_dialogue()
	await e_key()
	check(Flags.check_flag("memory 1 phone") and not Flags.check_flag("memory 1 complete"), "Second objective preserves unfinished memory")
	await finish_dialogue()
	var tv: memory_object = portal.room.get_node("Art/TV")
	await aim(tv)
	await get_tree().create_timer(1.0).timeout
	check(Dialogue.view.current == tv.story.look_dialogue and not tv.is_in_group("interact"), "TV is a look-only set piece")
	if not capture_directory.is_empty() and DisplayServer.get_name() != "headless":
		await get_tree().create_timer(1.6).timeout
	await capture("apartment_tv_flavor")
	await finish_dialogue()
	SaveGame.saving_disabled = false
	check(SaveGame.save_now(), "Partial objectives and flavor list checkpoint to disk")
	level.queue_free()
	await tick(6)
	check(SaveGame.load_now(), "Continue restores partial story progress")
	await bind_level()
	check(Flags.check_flag("memory 1 photo") and Flags.check_flag("memory 1 phone") and not Flags.check_flag("memory 1 complete"), "Reload does not invent missing objective")
	check(Blackboard.read_data("memory_flavor_seen").has("apartment_coffee"), "Flavor remains once per run after reload")
	coffee = portal.room.get_node("Art/CoffeePot")
	await aim(coffee)
	await get_tree().create_timer(1.0).timeout
	check(Dialogue.view.current == null, "Seen flavor does not replay after Continue")
	var bills: memory_object = portal.room.get_node("Art/PileOfMail")
	await aim(bills)
	await capture("apartment_bills_prompt")
	await e_key()
	check(Flags.check_flag("memory 1 bills") and Flags.check_flag("memory 1 complete") and portal.memory_complete(), "Third E completes apartment using exact existing portal flag")
	await finish_dialogue()
	check(bills.get_look_prompts() == null, "Completed objective removes its interaction prompt")
	var room_ref: WeakRef = weakref(portal.room)
	portal.teleport_player(portal.mapping(portal.destination_frame, portal.source_frame))
	await tick(10)
	check(not portal.active and room_ref.get_ref() == null, "Completed return closes and frees original memory through production lifecycle")
	for index in [2, 3]:
		var destination: StringName = &"warehouse" if index == 2 else &"hospital"
		check(portal.open_memory(StringName("memory_" + str(index)), destination), "Opens " + str(destination))
		portal.teleport_player(portal.mapping(portal.source_frame, portal.destination_frame))
		await tick(8)
		var objectives: Array[Node] = portal.room.find_children("*", "memory_object", true, false)
		check(objectives.size() == (5 if index == 2 else 4), "Authored required count matches " + str(destination))
		for i in objectives.size():
			var prop: memory_object = objectives[i]
			await aim(prop)
			check(not Flags.check_flag("memory %s complete" % index), "Incomplete until last E")
			if i == 0:
				await capture(str(destination) + "_prompt")
			await e_key()
			check(Flags.check_flag(prop.story.interaction_flag), "E records " + str(prop.name))
			await finish_dialogue()
		check(Flags.check_flag("memory %s complete" % index), "All objectives complete " + str(destination))
		portal.teleport_player(portal.mapping(portal.destination_frame, portal.source_frame))
		await tick(10)
	level.queue_free()
	await tick(6)
	SaveGame.new_game()
	check(not Flags.check_flag("memory 1 photo") and not Flags.check_flag("memory 3 complete") and Blackboard.read_data("memory_flavor_seen") == null, "New Game resets narrative run progress")
	SaveGame.reset_save()
	print("Memory triggers / actual look and E / flavor separation / 3-5-4 objectives / disk Continue / completed portal return / New Game: ", "PASS" if failures.is_empty() else failures)
	get_tree().quit(0 if failures.is_empty() else 1)
