extends Node
var failures: Array[String] = []
var shown: Array[String] = []
func check(ok: bool, text: String) -> void:
	if not ok:
		failures.append(text)
		push_error(text)
func tick() -> void:
	await get_tree().physics_frame
	await get_tree().process_frame
func _ready() -> void:
	run.call_deferred()
func run() -> void:
	for key in ["exited room", "level enabled", "grinder enabled", "computer enabled", "grinder used", "message grinder death", "message first note", "message computer enabled"]:
		Flags.set_flag(key, false)
	for key in ["player_transform", "player_position", "player_rotation", "player_camera_rotation", "respawn room active", "grinder_idle_seconds"]:
		Blackboard.remove_data(key)
	Blackboard.store_data("spawned_items", [])
	Blackboard.store_data("lever_pulls", 0)
	Blackboard.store_data("score", 0)
	Blackboard.store_data("portal_inside", false)
	GrindCombo.reset()
	ScoreRewards.reset()
	var pool := object_pool.new()
	pool.pooled_scene = load("res://Scenes/audio_player.tscn")
	pool.reset_method = &"reset"
	pool.register_with_blackboard = true
	pool.blackboard_name = &"audio_pool"
	add_child(pool)
	var level: level_sequence = load("res://Scenes/testing_level.tscn").instantiate()
	level.set("spawn_animation_enabled", false)
	add_child(level)
	level.player.process_mode = Node.PROCESS_MODE_DISABLED
	level.player.disable_mode = CollisionObject3D.DISABLE_MODE_KEEP_ACTIVE
	level.set_process(false)
	var messages: word_message = level.get_node("WordMessage")
	messages.set_process(false)
	messages.word_shown.connect(func(word: String, _key: StringName): shown.append(word))
	var guidance: world_guidance = level.get_node("WorldGuidance")
	guidance.set_process(false)
	await tick()
	check(level.room_template != null, "Authored concrete room cached before removal")
	check(is_equal_approx(level.chute.note_drop_chance, .02), "Notes use a two-percent default")
	check(level.computer.get_node("Model").scale.x > 2.1, "Computer retains the larger authored model size")
	var door: start_room_door = level.get_node("doorway_animated")
	door.interact()
	door.animation.advance(door.animation.current_animation_length)
	level.room.set_physics_process(false)
	level.player.global_position = Vector3(4.75, .1, 10.5)
	level.room._physics_process(.01)
	check(not door.is_open and door.is_strange, "First room exit automatically closes the strange door")
	level.room._remove_room()
	await tick()
	var portal: door_portal = level.get_node("DoorPortal")
	check(portal.active and portal.room.global_position.y == 0, "Portal destination shares workshop height")
	Flags.set_flag("grinder enabled", true)
	guidance._process(29.9)
	check(messages.current.is_empty(), "Grinder reminder waits thirty seconds")
	guidance._process(.2)
	check(shown == ["CHEW"], "Reminder displays one large word at a time")
	messages._process(1)
	messages._process(1)
	check(shown == ["CHEW", "IT", "UP"], "Reminder splits all three words automatically")
	messages._process(1)
	messages._process(2)
	check(shown.back() == "CHEW", "Unused grinder reminder repeats")
	var first: Node3D = WorldState.spawn_item(load("res://Scenes/Items/book.tscn"), level, Transform3D(Basis.IDENTITY, Vector3(10, 1, 0)))
	var second: Node3D = WorldState.spawn_item(load("res://Scenes/Items/teddy_bear.tscn"), level, Transform3D(Basis.IDENTITY, Vector3(12, 1, 0)))
	level.grinder.grind(first.get_node("RigidBody3D"))
	level.grinder.grind(second.get_node("RigidBody3D"))
	var grind_players: int = 0
	for audio: audio_player in pool.active:
		if audio.audio_global.playing and audio.audio_global.stream == level.grinder.grind_sound:
			grind_players += 1
	check(grind_players == 1 and GrindCombo.item_count == 2, "Batch grinding plays one sound and counts every item")
	check(messages.current.is_empty() and not guidance.grinder_waiting, "Grinding cancels the reminder immediately")
	await tick()
	var note: Dictionary = {"id": "test", "title": "TEST", "body": "Test text"}
	var reader: note_reader = level.get_node("NoteReader")
	reader.open_note(note)
	check(not Flags.check_flag("message first note"), "Reading does not trigger warning until reader closes")
	reader.close()
	await get_tree().create_timer(reader.lower_seconds + .06).timeout
	check(shown.back() == "DO" and Flags.check_flag("message first note"), "First finished note starts DO NOT LISTEN")
	for i in 3:
		messages._process(1)
	var count: int = shown.size()
	Notes.note_read_finished.emit(note)
	check(shown.size() == count, "Note warning is only shown once")
	Blackboard.store_data("score", 30)
	level._check_thresholds()
	check(messages.current.key == &"message computer enabled" and shown.back() == "YOU", "Computer unlock starts YOU DESERVE THIS")
	for i in 3:
		messages._process(1)
	var survivor: Node3D = WorldState.spawn_item(load("res://Scenes/Items/book.tscn"), level, Transform3D(Basis.IDENTITY, Vector3(20, 1, 0)))
	var survivor_id: String = survivor.get_meta("persistent_item_id", "")
	level.player.global_position = Vector3(0, .1, 0)
	level.player.velocity = Vector3(5, -10, 2)
	level.grinder.grind(level.player)
	await tick()
	check(level.player.transform.is_equal_approx(level.spawn_pose) and level.player.velocity == Vector3.ZERO, "Grinder respawns player at authored room transform with no momentum")
	check(is_instance_valid(level.room) and not level.room.erased and level.room.interior != null, "Respawn reconstructs concrete room with valid interior")
	await tick()
	var floor_query := PhysicsRayQueryParameters3D.create(level.player.global_position + Vector3.UP, level.player.global_position - Vector3.UP, 1)
	floor_query.exclude = [level.player.get_rid()]
	var room_floor: Dictionary = level.get_world_3d().direct_space_state.intersect_ray(floor_query)
	check(not room_floor.is_empty() and room_floor.collider == level.room, "Respawn room has real concrete floor collision")
	check(portal.suspended and not portal.source_surface.visible, "Concrete respawn suspends portal until room disappears again")
	check(is_instance_valid(survivor) and WorldState.items.has(survivor_id), "Respawn preserves world items and progression")
	check(messages.current.key == &"message grinder death" and shown.back() == "DONT.", "First grinder death starts the one-time warning")
	for i in 3:
		messages._process(1)
	count = shown.size()
	level.grinder.grind(level.player)
	await tick()
	check(shown.size() == count, "Later grinder deaths respawn silently")
	WorldState.capture()
	level.queue_free()
	await tick()
	level = load("res://Scenes/testing_level.tscn").instantiate()
	level.set("spawn_animation_enabled", false)
	add_child(level)
	level.player.process_mode = Node.PROCESS_MODE_DISABLED
	await tick()
	portal = level.get_node("DoorPortal")
	check(is_instance_valid(level.room) and not level.room.erased and portal.suspended, "Startup restores a saved concrete respawn room with portal suspended")
	check(not level.room.sfx_gated and Flags.check_flag("message grinder death"), "Restoring respawn preserves warning history and active SFX")
	level.room._remove_room()
	await tick()
	check(not portal.suspended and Blackboard.read_data("respawn room active") == false, "Erasing respawn room restores portal")
	level.queue_free()
	await tick()
	for audio: audio_player in pool.active:
		audio.reset()
	await get_tree().create_timer(.1).timeout
	print("World messages, grinder sound, door and concrete respawn: ", "PASS" if failures.is_empty() else failures)
	get_tree().quit(0 if failures.is_empty() else 1)
