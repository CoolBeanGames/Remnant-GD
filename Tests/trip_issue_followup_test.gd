extends Node

var failures: Array[String] = []
var capture_directory: String = "res://.godot/trip_issue_views"
var camera: Camera3D

func _ready() -> void:
	run.call_deferred()

func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error(message)

func tick(count: int = 4) -> void:
	for index in count:
		await get_tree().physics_frame
		await get_tree().process_frame

func capture(view_name: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	await tick()
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(capture_directory))
	get_viewport().get_texture().get_image().save_png(capture_directory.path_join(view_name + ".png"))

func f9() -> void:
	var event := InputEventKey.new()
	event.physical_keycode = KEY_F9
	event.keycode = KEY_F9
	event.pressed = true
	Input.parse_input_event(event)

func run() -> void:
	SaveGame.enabled = false
	SaveGame.saving_disabled = true
	Blackboard.store_data("spawned_items", [])
	Blackboard.store_data("player_input_blocked", false)
	Blackboard.remove_data("active_memory_id")
	Blackboard.remove_data("portal_debug_preview")
	Blackboard.remove_data("respawn room active")
	for flag_name in ["exited room", "level enabled", "grinder enabled", "computer enabled", "mulcher purchased", "mulch bin purchased"]:
		Flags.set_flag(flag_name, false)
	SaveGame.profile["mulcher_unlocked"] = false
	var pool := object_pool.new()
	pool.pooled_scene = load("res://Scenes/audio_player.tscn")
	pool.reset_method = &"reset"
	pool.register_with_blackboard = true
	pool.blackboard_name = &"audio_pool"
	add_child(pool)
	var level: level_sequence = load("res://Scenes/testing_level.tscn").instantiate()
	level.spawn_animation_enabled = false
	add_child(level)
	level.player.process_mode = Node.PROCESS_MODE_DISABLED
	level.player.disable_mode = CollisionObject3D.DISABLE_MODE_KEEP_ACTIVE
	camera = level.player.get_node("Camera3D")
	await tick()
	var portal: door_portal = level.get_node("DoorPortal")
	f9()
	await tick()
	check(not portal.active and not portal.queued_debug_preview, "F9 preserves the first room's visibility gate")
	level.room._remove_room()
	await tick()
	check(not portal.active, "Production memories remain purchase gated without an F9 request")
	f9()
	await tick(12)
	check(portal.active and portal.active_destination_id == &"apartment" and portal.debug_override, "Actual F9 input opens the production apartment preview after room removal")
	f9()
	await tick(12)
	check(portal.active_destination_id == &"warehouse", "Actual F9 input cycles to the warehouse")
	level._restore_respawn_room()
	Blackboard.store_data("player_input_blocked", false)
	f9()
	await tick()
	check(portal.suspended and portal.queued_debug_preview and portal.active_destination_id == &"warehouse", "A visible respawn room queues one preview request without exposing the memory")
	level.room.exit_armed = true
	level.room.unseen_delay = .01
	level.room.visibility_check_interval = .01
	level.player.global_position = Vector3(5, .01, 7)
	camera.global_position = Vector3(5, 1.7, 7)
	camera.look_at(Vector3(5, 1.7, 0))
	await tick(25)
	check(not portal.suspended and not portal.queued_debug_preview and portal.active_destination_id == &"hospital", "Turning away removes the concrete room and automatically fulfills the queued F9 request")
	var door: start_room_door = level.get_node("doorway_animated")
	var leaf: Node3D = door.find_child("DoorLeaf", true, false)
	var frame: Node3D = door.find_child("DoorFrame", true, false)
	var hinge: Vector3 = leaf.global_position
	var frame_pose: Transform3D = frame.global_transform
	door.animation.play("0_idle_closed")
	door.animation.advance(.001)
	door.animation.stop(true)
	camera.global_position = door.global_position + Vector3(0, 1.8, -4)
	camera.look_at(door.global_position + Vector3(0, 1.7, 0))
	var inspection := OmniLight3D.new()
	inspection.omni_range = 12
	inspection.light_energy = 2
	level.add_child(inspection)
	inspection.global_position = camera.global_position + Vector3(0, 1, 0)
	await capture("door_closed")
	door.animation.play(door.open_animation)
	door.animation.advance(1.2)
	door.animation.stop(true)
	check(leaf.global_position.is_equal_approx(hinge) and frame.global_transform.is_equal_approx(frame_pose), "Opening keeps the real hinge and fixed frame stationary")
	check(leaf.position.x > 0 and leaf.to_global(Vector3(-1.74, 0, 0)).distance_to(hinge) > 1.73, "The leaf hinges opposite its left-side handle without changing its width")
	await capture("door_open")
	var lever_actor: Node3D = level.get_node("Lever_Assembly")
	var handle: Node3D = lever_actor.get_node("Lever_Base/LeverHandle")
	var socket: Vector3 = handle.global_position
	var base: Node3D = lever_actor.get_node("Lever_Base/LeverBase")
	var base_pose: Transform3D = base.global_transform
	var animation: AnimationPlayer = lever_actor.get_node("AnimationPlayer")
	camera.global_position = lever_actor.to_global(Vector3(-2, 1.7, 3))
	camera.look_at(lever_actor.to_global(Vector3(0, .9, 0)))
	inspection.global_position = camera.global_position + Vector3(0, 2, 0)
	await capture("lever_idle")
	animation.play("pull")
	animation.advance(.28)
	animation.stop(true)
	check(handle.global_position.is_equal_approx(socket) and base.global_transform.is_equal_approx(base_pose), "The pulled shaft rotates about its housing axle while the base stays fixed")
	await capture("lever_pulled")
	var terminal: computer_terminal = level.computer
	terminal.set_enabled(true)
	camera.global_position = terminal.global_position + Vector3(0, 1.6, 2)
	camera.look_at(terminal.screen.global_position)
	inspection.global_position = camera.global_position + Vector3(0, 1, 0)
	await capture("terminal_idle")
	var original_pose: Transform3D = camera.global_transform
	var original_fov: float = camera.fov
	terminal.focus_seconds = .05
	terminal.return_seconds = .05
	terminal._open_interface()
	for index in 120:
		await get_tree().process_frame
		if not terminal.session.is_moving():
			break
	var size: Vector2 = (terminal.screen.mesh as QuadMesh).size
	var top_left: Vector2 = camera.unproject_position(terminal.screen.to_global(Vector3(-size.x * .5, size.y * .5, 0)))
	var bottom_right: Vector2 = camera.unproject_position(terminal.screen.to_global(Vector3(size.x * .5, -size.y * .5, 0)))
	var viewport_size: Vector2 = get_viewport().get_visible_rect().size
	var fraction: Vector2 = (bottom_right - top_left) / viewport_size
	print("Screen coverage / ", fraction, " / viewport ", viewport_size, " / fov ", camera.fov)
	check(maxf(fraction.x, fraction.y) > .85 and maxf(fraction.x, fraction.y) < .92, "The focused physical screen occupies most of the limiting viewport dimension")
	check(top_left.x > 0 and top_left.y > 0 and bottom_right.x < viewport_size.x and bottom_right.y < viewport_size.y, "The complete interactive screen fits inside the window")
	var mapped: Vector2 = terminal.screen_pointer(camera.unproject_position(terminal.screen.global_position))
	check(mapped.distance_to(Vector2(terminal.display_resolution) * .5) < .1, "Window mouse rays map onto the real display center after zoom")
	await capture("terminal_focused")
	terminal.close_interface()
	for index in 120:
		await get_tree().process_frame
		if terminal.session == null:
			break
	check(camera.global_transform.is_equal_approx(original_pose) and is_equal_approx(camera.fov, original_fov), "Disconnect restores the exact gameplay pose and field of view")
	check(Mulch.install() and Mulch.install_bin(), "Both production machines install")
	await tick()
	var machine: mulcher_station = Mulch.station
	var bin_node: mulch_bin = level.get_node("MulchBin")
	var query := PhysicsShapeQueryParameters3D.new()
	var collision: CollisionShape3D = machine.get_node("CollisionShape3D")
	query.shape = collision.shape
	query.transform = collision.global_transform
	query.collision_mask = 1
	query.exclude = [machine.get_rid()]
	check(not machine.get_world_3d().direct_space_state.intersect_shape(query).any(func(hit: Dictionary) -> bool: return hit.collider == bin_node), "The installed bin has no solid overlap with the Mulcher")
	camera.global_position = Vector3(4, 3, -9)
	camera.look_at(Vector3(1.2, .5, -4.8))
	inspection.global_position = camera.global_position + Vector3(0, 2, 0)
	await capture("mulcher_bin")
	level.queue_free()
	await tick()
	for audio: audio_player in pool.active.duplicate():
		audio.stop()
	print("Trip F1 fixes / real F9 / respawn visibility / pivots / physical display / zoom / bin clearance: ", "PASS" if failures.is_empty() else str(failures))
	get_tree().quit(0 if failures.is_empty() else 1)
