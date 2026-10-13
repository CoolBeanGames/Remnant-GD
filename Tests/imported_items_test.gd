extends Node

var failures: Array[String] = []
var contacts: Dictionary = {}

func check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
		push_error(message)

func _ready() -> void:
	run.call_deferred()

func run() -> void:
	seed(2468)
	Blackboard.store_data("spawned_items", [])
	Blackboard.store_data("player_input_blocked", false)
	for key in ["player_transform", "player_position", "player_rotation", "player_camera_rotation"]:
		Blackboard.remove_data(key)
	var audio_pool := object_pool.new()
	audio_pool.pooled_scene = load("res://Scenes/audio_player.tscn")
	audio_pool.reset_method = &"reset"
	audio_pool.register_with_blackboard = true
	audio_pool.blackboard_name = &"audio_pool"
	add_child(audio_pool)
	var world := Node3D.new()
	add_child(world)
	world.add_child(load("res://Scenes/model_instances/game_stage_base.tscn").instantiate())
	var player: CharacterBody3D = load("res://Scenes/Player/player.tscn").instantiate()
	player.process_mode = Node.PROCESS_MODE_DISABLED
	world.add_child(player)
	player.position = Vector3(20, 1, 20)
	WorldState.begin(world, player)
	await get_tree().process_frame
	var pool: item_spawn_pool = load("res://Data/Items/default_spawn_pool.tres")
	var chosen: Dictionary = {}
	for i in 250:
		chosen[pool.pick_item().resource_path] = true
	var actors: Array[Node3D] = []
	var names: Array[String] = ["beer_bottle", "book", "syringe", "teddy_bear"]
	for i in names.size():
		var scene_path: String = "res://Scenes/Items/" + names[i] + ".tscn"
		check(chosen.has(scene_path), names[i] + " participates in random output")
		var actor: Node3D = WorldState.spawn_item(load(scene_path), world, Transform3D(Basis.IDENTITY, Vector3(-6 + i * 3, 1, 7)))
		actors.append(actor)
		var body: RigidBody3D = actor.get_node("RigidBody3D")
		body.linear_velocity = Vector3.DOWN * 20
		body.angular_velocity = Vector3.ZERO
		var id: String = names[i]
		body.body_entered.connect(func(_other: Node): contacts[id] = true)
	await get_tree().create_timer(1.5).timeout
	for i in names.size():
		var body: RigidBody3D = actors[i].get_node("RigidBody3D")
		check(contacts.has(names[i]) and body.global_position.y > .015, names[i] + " physically lands on the real floor")
		var collision_count_before: int = audio_pool.active.size()
		body.collide(world) # World has no collision group: wildcard still plays.
		check(audio_pool.active.size() == collision_count_before + 1, names[i] + " plays pooled audio for an untagged collision")
		var sound: audio_player = audio_pool.active.back()
		check(body.sound_matrix[0].sounds.has(sound.audio_3d.stream) and sound.audio_3d.bus == &"SFX", names[i] + " uses its custom bank on SFX")
	var pickup: player_pickup = player.get_node("Controllers/Player_Pickup")
	check(pickup.pickup_object(actors[0].get_node("RigidBody3D")), "Imported bottle uses normal pickup rules")
	pickup.drop_object()
	WorldState.capture()
	var saved: Array = Blackboard.read_data("spawned_items").duplicate(true)
	check(saved.size() == 4, "All new item types are registered for restoration")
	var grinder := grinding_area.new()
	grinder.grind_sound = null
	world.add_child(grinder)
	GrindCombo.reset()
	for actor in actors:
		check(grinder.grind(actor.get_node("RigidBody3D")), "Imported item is accepted by grinder")
	check(GrindCombo.base_points == 4, "Each imported item contributes one base point")
	GrindCombo.reset()
	await get_tree().process_frame
	Blackboard.store_data("spawned_items", saved)
	WorldState.begin(world, player)
	await get_tree().process_frame
	check(WorldState.items.size() == 4, "All four imported scenes restore from Blackboard")
	var restored_names: Dictionary = {}
	for id in WorldState.items:
		restored_names[WorldState._actor(id).scene_file_path.get_file().get_basename()] = true
	for entry_name in names:
		check(restored_names.has(entry_name), "Restoration retains " + entry_name + " identity")
	var fan: switchable_prop = load("res://Scenes/Actors/fan.tscn").instantiate()
	world.add_child(fan)
	fan.freeze = true
	fan.set_process(false)
	var pivot: Node3D = fan.get_node("Model/BladePivot")
	var original_basis: Basis = pivot.basis
	var original_position: Vector3 = pivot.position
	fan._process(.05)
	check(not pivot.basis.is_equal_approx(original_basis) and pivot.position == original_position, "Powered blades spin about a stationary hub")
	fan.set_powered(false)
	original_basis = pivot.basis
	fan._process(.2)
	check(pivot.basis.is_equal_approx(original_basis), "Switched-off fan stops blade rotation")
	var note: note_drop = load("res://Scenes/Actors/note_drop.tscn").instantiate()
	world.add_child(note)
	note.freeze = true
	var glass: StandardMaterial3D = note.get_node("Model/bottle").material_override
	var paper: StandardMaterial3D = note.get_node("Model/note").material_override
	check(glass.albedo_color.a < .5 and paper.transparency == BaseMaterial3D.TRANSPARENCY_DISABLED and glass.albedo_texture != paper.albedo_texture, "Bottle and visible paper have separate glass and opaque materials")
	var note_sound_count_before: int = audio_pool.active.size()
	note._on_collision(world)
	check(audio_pool.active.size() == note_sound_count_before + 1 and note.collision_sounds.sounds.has((audio_pool.active.back() as audio_player).audio_3d.stream), "Message bottle uses the glass collision bank")
	world.queue_free()
	await get_tree().process_frame
	# Every authored collider must pass through the actual chute, not only land
	# on an unobstructed floor in the smaller fixture above.
	Blackboard.store_data("spawned_items", [])
	for flag_name in ["exited room", "grinder enabled", "computer enabled"]:
		Flags.set_flag(flag_name, false)
	Flags.set_flag("level enabled", true)
	var level: level_sequence = load("res://Scenes/testing_level.tscn").instantiate()
	level.set("spawn_animation_enabled", false)
	add_child(level)
	level.player.process_mode = Node.PROCESS_MODE_DISABLED
	await get_tree().process_frame
	Blackboard.store_data("game_root", level)
	level.chute.note_drop_chance = 0.0
	var outputs: Array[RigidBody3D] = []
	for entry_name in names:
		var single := item_spawn_pool.new()
		single.items = [load("res://Scenes/Items/" + entry_name + ".tscn")]
		level.chute.item_pool = single
		level.chute.spawn()
		outputs.append(WorldState._bodies(WorldState._actor(WorldState.items.keys().back()))[0])
	await get_tree().create_timer(8.0).timeout
	for i in names.size():
		check(is_instance_valid(outputs[i]) and outputs[i].global_position.y > .001 and outputs[i].global_position.y < .3, names[i] + " exits the real chute and settles on the floor")
	level.queue_free()
	await get_tree().process_frame
	print("Imported items, collisions, score, restoration, blades and bottle materials: ", "PASS" if failures.is_empty() else str(failures))
	get_tree().quit(0 if failures.is_empty() else 1)
