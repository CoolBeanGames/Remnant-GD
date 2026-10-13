extends Node

var failures: Array[String] = []
var capture_directory: String = ""
var level: level_sequence

func check(ok: bool, text: String) -> void:
	if not ok:
		failures.append(text)
		push_error(text)

func tick(count: int = 2) -> void:
	for i in count:
		await get_tree().physics_frame
		await get_tree().process_frame

func _ready() -> void:
	run.call_deferred()

func capture(entry_name: String) -> void:
	if capture_directory.is_empty():
		return
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(capture_directory)
	check(get_viewport().get_texture().get_image().save_png(capture_directory.path_join(entry_name + ".png")) == OK, "Saved actual engine " + entry_name)

func run() -> void:
	SaveGame.enabled = false
	SaveGame.saving_disabled = true
	var audio_pool := object_pool.new()
	audio_pool.pooled_scene = load("res://Scenes/audio_player.tscn")
	audio_pool.reset_method = &"reset"
	audio_pool.register_with_blackboard = true
	audio_pool.blackboard_name = &"audio_pool"
	add_child(audio_pool)
	Blackboard.store_data("spawned_items", [])
	for key in ["player_transform", "player_position", "player_rotation", "player_camera_rotation"]:
		Blackboard.remove_data(key)
	for key in ["exited room", "level enabled", "grinder enabled", "computer enabled"]:
		Flags.set_flag(key, true)
	var pool: item_spawn_pool = load("res://Data/Items/default_spawn_pool.tres")
	var chosen: Dictionary = {}
	seed(6842)
	for i in 9000:
		var path: String = pool.pick_item().resource_path
		chosen[path] = int(chosen.get(path, 0)) + 1
	check(chosen.size() == 9 and not chosen.has("res://Scenes/test_object.tscn"), "Nine real models spawn; test block never enters the production pool")
	for count: int in chosen.values():
		check(count > 850 and count < 1150, "Production random pool keeps all nine models equally weighted")
	level = load("res://Scenes/testing_level.tscn").instantiate()
	level.spawn_animation_enabled = false
	add_child(level)
	level.player.process_mode = Node.PROCESS_MODE_DISABLED
	level.player.disable_mode = CollisionObject3D.DISABLE_MODE_KEEP_ACTIVE
	Blackboard.store_data("player_input_blocked", false)
	await tick(5)
	var outputs: Array[RigidBody3D] = []
	level.chute.note_drop_chance = 0
	for scene in pool.items:
		var single := item_spawn_pool.new()
		single.items = [scene]
		level.chute.item_pool = single
		level.chute.spawn()
		var actor: Node3D = WorldState._actor(WorldState.items.keys().back())
		var body: RigidBody3D = WorldState._bodies(actor)[0]
		outputs.append(body)
		check(physics_items.score_component(actor).score == 1, "New chute art retains one base score")
		await tick(20)
	await tick(360)
	for body in outputs:
		check(is_instance_valid(body) and body.global_position.y > .005 and body.global_position.y < .45, "Each new model clears the actual chute and lands on solid floor")
		check(body.physics_material_override.friction == 1, "All new items switch to settled friction after leaving the chute")
	var handle: Node3D = level.manual_lever.get_node("Lever_Base/LeverHandle")
	var idle: Basis = handle.basis
	level.manual_lever.interact()
	level.manual_lever.anim.advance(.18)
	check(not handle.basis.is_equal_approx(idle), "Separated imported lever handle actually moves during a pull")
	level.manual_lever.anim.advance(1.5)
	await tick(70)
	check(handle.basis.is_equal_approx(idle), "Lever arm returns cleanly after its upgraded animation cycle")
	var door: start_room_door = level.get_node("doorway_animated")
	var leaf: Node3D = door.get_node("Model/DoorLeaf")
	var frame: Node3D = door.get_node("Model/DoorFrame")
	var frame_pose: Transform3D = frame.transform
	var camera: Camera3D = level.player.get_node("Camera3D")
	camera.global_position = door.to_global(Vector3(0, 1.7, 4))
	camera.look_at(door.to_global(Vector3(0, 1.7, 0)))
	await tick(5)
	await capture("engine_door_closed")
	door.interact()
	door.animation.advance(1.2)
	check(absf(leaf.rotation.y) > 1.5 and frame.transform.is_equal_approx(frame_pose), "Door leaf opens independently while its replacement frame stays fixed")
	await tick(5)
	await capture("engine_door_open")
	door.interact()
	door.animation.advance(1.2)
	check(is_zero_approx(leaf.rotation.y), "New wooden leaf closes without changing its UV or pivot")
	var portal: door_portal = level.get_node("DoorPortal")
	portal.purchase_required = false
	portal.activate(true)
	await tick(4)
	var room: Node3D = portal.room
	check(room != null and room.has_node("Art/BedroomBed") and not room.has_node("Art/BedroomDesk"), "The portal loads the expanded apartment with a separate bed and no office desk")
	var player: CharacterBody3D = level.player
	player.collision_mask = portal_space.ROOM_LAYER
	var movement: Node = player.get_node("Controllers/Player_Move_Controller")
	# Cross the new 1.2 m doorway using the real 1.8 m capsule, on the same floor.
	player.global_position = room.global_position + Vector3(7, .03, .575)
	player.rotation.y = -PI / 2
	player.velocity = Vector3.ZERO
	movement.reset_platform_motion()
	Input.action_press("forward")
	for i in 90:
		await get_tree().physics_frame
		movement._physics_process(1.0 / 60.0)
		await get_tree().process_frame
	Input.action_release("forward")
	check(player.global_position.x > room.global_position.x + 9 and player.global_position.y > -.03, "Real capsule walks through the bedroom opening onto its supported floor")
	player.velocity = Vector3.ZERO
	portal.set_process(false)
	camera.cull_mask = portal_space.ROOM_LAYER
	camera.global_position = room.global_position + Vector3(4.55, 1.65, 1.8)
	camera.look_at(room.global_position + Vector3(6.35, .65, -1.45))
	await tick(5)
	await capture("engine_bedroom")
	camera.global_position = room.global_position + Vector3(-2.15, 1.65, 2.65)
	camera.look_at(room.global_position + Vector3(1.8, 1.1, -1.3))
	await tick(5)
	await capture("engine_apartment")
	camera.cull_mask = 1
	camera.environment = null
	camera.global_position = level.computer.global_position + Vector3(-1.2, 1.8, 2)
	camera.look_at(level.computer.global_position + Vector3(0, 1.1, 0))
	await tick(5)
	await capture("engine_terminal")
	level.queue_free()
	await tick(3)
	for audio: audio_player in audio_pool.active.duplicate():
		audio.stop()
	# Real audio playback releases its mixer references asynchronously.
	Audio.begin_shutdown()
	await get_tree().create_timer(.12).timeout
	print("Trip models / nine chute paths / lever and door animation / capsule bedroom traversal: ", "PASS" if failures.is_empty() else str(failures))
	get_tree().quit(0 if failures.is_empty() else 1)
