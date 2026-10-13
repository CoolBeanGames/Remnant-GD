extends Node
var failures: Array[String] = []
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
	var pool := object_pool.new()
	pool.pooled_scene = load("res://Scenes/audio_player.tscn")
	pool.reset_method = &"reset"
	pool.register_with_blackboard = true
	pool.blackboard_name = &"audio_pool"
	add_child(pool)
	var clip: AudioStream = load("res://Audio/SFX/grind.wav")
	for i in 25:
		audio_global.play_collision(clip, Vector3.ZERO)
	check(pool.active.size() == 10, "Collision playback never exceeds ten simultaneous clips")
	audio_global.play_3d(clip, Vector3.ZERO)
	audio_global.play_global(clip)
	check(pool.active.size() == 12, "Collision cap leaves important spatial/global sounds unrestricted")
	var stopped: audio_player = pool.active[0]
	stopped.stop()
	stopped.playback_finished.emit()
	audio_global.play_collision(clip, Vector3.ZERO)
	check(pool.active.size() == 12 and stopped.get_meta("audio_category") == &"collision", "Completed collision frees a reusable sound slot")
	for audio: audio_player in pool.active.duplicate():
		audio.stop()
		audio.playback_finished.emit()
	for key in ["player_transform", "player_position", "player_rotation", "player_camera_rotation", "respawn room active"]:
		Blackboard.remove_data(key)
	for key in ["exited room", "level enabled", "grinder enabled", "computer enabled"]:
		Flags.set_flag(key, false)
	Blackboard.store_data("spawned_items", [])
	Blackboard.store_data("spawned_notes", [])
	Blackboard.store_data("found_notes", [])
	Blackboard.store_data("score", 100000)
	Blackboard.store_data("lever_pulls", 0)
	Progression.levels = {}
	Progression.restored_levels = true
	var level: level_sequence = load("res://Scenes/testing_level.tscn").instantiate()
	level.spawn_animation_enabled = false
	add_child(level)
	level.player.process_mode = Node.PROCESS_MODE_DISABLED
	level.get_node("WorldGuidance").set_process(false)
	await tick()
	var basket: computer_entry = Progression.entries[&"buy_basket"]
	check(basket.cost(0) == 30 and basket.cost(1) == 54 and basket.cost(2) == 98, "Repeated basket prices rise exponentially")
	var value: computer_entry = Progression.entries[&"item_value"]
	check(value.cost(0) == 50 and value.cost(1) == 175 and value.cost(2) == 613, "Value upgrade costs use the stronger progression curve")
	var light: computer_entry = Progression.entries[&"buy_light"]
	check(light.cost(0) == 10 and light.cost(10) == 10, "Lights keep their fixed price")
	var before: int = Progression.score()
	check(level.computer.buy(basket) == "" and level.computer.buy(basket) == "", "Repeat basket deliveries succeed")
	check(Progression.score() == before - 84 and Progression.level(basket) == 2 and Blackboard.read_data("upgrade_levels")[basket.id] == 2, "Purchases deduct the increasing price and persist purchase count")
	var saved: Dictionary = Progression.levels.duplicate()
	Progression.levels.clear()
	Progression.restored_levels = false
	Progression.register_catalog(level.computer.catalog)
	check(Progression.level(basket) == 2 and basket.cost(Progression.level(basket)) == 98, "Saved purchase counts restore the next price")
	Progression.levels = saved
	var masses: Array[float] = []
	for entry_name in ["syringe", "teddy_bear", "book"]:
		var actor: Node3D = load("res://Scenes/Items/" + entry_name + ".tscn").instantiate()
		masses.append(actor.get_node("RigidBody3D").mass)
		actor.free()
	check(masses[0] < masses[1] and masses[1] < masses[2], "Syringes are lighter than teddy bears, which are lighter than books")
	var scene: PackedScene = load("res://Scenes/Actors/note_drop.tscn")
	var outputs: Array[note_drop] = []
	for i in 12:
		var note := note_definition.new()
		note.id = StringName("flow_" + str(i))
		var drop: note_drop = scene.instantiate()
		drop.note = note
		level.add_child(drop)
		drop.global_transform = level.chute.spawn_point.global_transform
		drop.linear_velocity = Vector3.DOWN * 3
		WorldState.track(drop)
		outputs.append(drop)
		await get_tree().create_timer(.12).timeout
	await get_tree().create_timer(8).timeout
	for drop in outputs:
		check(is_instance_valid(drop) and drop.global_position.y < .3 and drop.global_position.y > .01, "Message bottle clears the real chute and lands on the floor")
	var definition: note_definition = level.chute.notes_catalog.notes[0]
	var lost: note_drop = scene.instantiate()
	lost.note = definition
	level.add_child(lost)
	lost.global_position = Vector3(30, -20, 0)
	WorldState.track(lost)
	check(Notes.has_spawned(definition.id), "World note reserves its pool slot")
	WorldState._physics_process(0)
	check(not Notes.has_spawned(definition.id) and level.chute.notes_catalog.available().has(definition), "Falling below the level returns an uncollected note to its pool")
	await tick()
	var stuck: note_drop = scene.instantiate()
	stuck.note = definition
	level.add_child(stuck)
	stuck.global_transform = level.chute.spawn_point.global_transform
	stuck.freeze = true
	WorldState.track(stuck)
	await tick()
	var zone: chute_zone = level.get_node("ceiling_chute/ChuteZone")
	zone.entered(stuck)
	zone._physics_process(31)
	check(stuck.is_queued_for_deletion() and not Notes.has_spawned(definition.id), "Thirty-second chute cleanup recycles a lost note")
	await tick()
	Notes.collect(definition)
	Notes.release_spawned(definition.id)
	check(Notes.has_note(definition.id) and Notes.has_spawned(definition.id), "Collected notes are never returned to the spawn pool")
	level.queue_free()
	await tick()
	for audio: audio_player in pool.active:
		audio.reset()
	await get_tree().create_timer(.1).timeout
	print("Real note flow, recycling, collision cap, prices and masses: ", "PASS" if failures.is_empty() else str(failures))
	get_tree().quit(0 if failures.is_empty() else 1)
