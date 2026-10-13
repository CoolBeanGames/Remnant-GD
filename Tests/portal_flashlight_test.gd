extends Node

var failures: Array[String] = []
var level: level_sequence
var portal: door_portal
@export var capture_directory: String = ""

func check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
		push_error(message)

func tick(count: int = 12) -> void:
	for i in count:
		await get_tree().physics_frame
		await get_tree().process_frame

func key(code: Key) -> void:
	for pressed in [true, false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.physical_keycode = code
		event.pressed = pressed
		Input.parse_input_event(event)
		await tick(2)

func capture(entry_name: String) -> Image:
	await tick(18)
	await RenderingServer.frame_post_draw
	var result: Image = get_viewport().get_texture().get_image()
	if not capture_directory.is_empty():
		DirAccess.make_dir_recursive_absolute(capture_directory)
		check(result.save_png(capture_directory + "/" + entry_name + ".png") == OK, "Portal beam image saved")
	return result

func positive_light_delta(lit: Image, dark: Image) -> float:
	var result: float = 0
	for y in 32:
		for x in 48:
			var px: int = floori(float(x * lit.get_width()) / 48.0)
			var py: int = floori(float(y * lit.get_height()) / 32.0)
			result += maxf(0, lit.get_pixel(px, py).get_luminance() - dark.get_pixel(px, py).get_luminance())
	return result / (32 * 48)

func _ready() -> void:
	if DisplayServer.get_name() != "headless":
		DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS, true)
	run.call_deferred()

func run() -> void:
	SaveGame.enabled = false
	SaveGame.saving_disabled = true
	Blackboard._data.clear()
	Flags._flags.clear()
	SaveGame.profile = {"mulch_coins": 0, "mulch_upgrades": {}, "settings": {}}
	Blackboard.store_data("spawned_items", [])
	Flags.set_flag("exited room", true)
	var pool := object_pool.new()
	pool.pooled_scene = load("res://Scenes/audio_player.tscn")
	pool.reset_method = &"reset"
	pool.register_with_blackboard = true
	pool.blackboard_name = &"audio_pool"
	add_child(pool)
	level = load("res://Scenes/testing_level.tscn").instantiate()
	level.spawn_animation_enabled = false
	level.get_node("DoorPortal").purchase_required = false
	add_child(level)
	level.player.process_mode = Node.PROCESS_MODE_DISABLED
	await tick()
	portal = level.get_node("DoorPortal")
	portal.flashlight.process_mode = Node.PROCESS_MODE_ALWAYS
	portal.door.interact()
	portal.door.animation.advance(portal.door.animation.current_animation_length)
	portal.camera.global_position = portal.source_frame.to_global(Vector3(0, 0, 2.2))
	portal.camera.look_at(portal.source_frame.global_position)
	portal.previous_camera_position = portal.camera.global_position
	await tick()
	var map: Transform3D = portal.mapping(portal.source_frame, portal.destination_frame)
	check(portal.portal_flashlight.visible and portal.portal_flashlight.light_cull_mask == portal_space.ROOM_LAYER and portal.portal_flashlight.global_transform.is_equal_approx(map * portal.flashlight.global_transform), "Portal maps player beam and lighting space to distant room")
	if DisplayServer.get_name() != "headless":
		var lit: Image = await capture("portal_beam_on")
		await key(KEY_T)
		var dark: Image = await capture("portal_beam_off")
		var difference: float = positive_light_delta(lit, dark)
		print("Through-aperture rendered beam delta: ", difference)
		check(difference > .003, "Actual rendered flashlight illuminates through aperture")
		await key(KEY_T)
	else:
		await key(KEY_T)
		check(not portal.flashlight.visible and Blackboard.read_data("flashlight_powered") == false and not portal.portal_flashlight.visible, "Real T input switches source and mapped flashlight off")
		await key(KEY_T)
	var direct: Transform3D = map * portal.camera.global_transform
	portal.inside = true
	portal._set_player_space()
	portal.camera.global_transform = direct
	portal.previous_camera_position = portal.camera.global_position
	await tick()
	check(portal.flashlight.visible and portal.flashlight.light_cull_mask == portal_space.ROOM_LAYER, "Inside apartment keeps direct flashlight active")
	print("Direct beam state: ", portal.inside, " / ", portal.flashlight.visible, " / ", portal.flashlight.light_cull_mask, " / ", portal.active_destination_id)
	if DisplayServer.get_name() != "headless":
		var lit: Image = await capture("interior_beam_on")
		await key(KEY_T)
		var dark: Image = await capture("interior_beam_off")
		var difference: float = positive_light_delta(lit, dark)
		print("Direct-room rendered beam delta: ", difference)
		check(difference > .003, "Actual rendered direct beam remains useful after crossing")
		await key(KEY_T)
	portal.camera.global_position = portal.destination_frame.to_global(Vector3(0, 0, 2.2))
	portal.camera.look_at(portal.destination_frame.global_position)
	portal.previous_camera_position = portal.camera.global_position
	await tick()
	check(portal.portal_flashlight.visible and portal.portal_flashlight.light_cull_mask == 1, "Return aperture maps beam back to workshop")
	print("Return beam state: ", portal.inside, " / ", portal.portal_flashlight.visible, " / ", portal.portal_flashlight.light_cull_mask, " / ", portal.door.is_open)
	if DisplayServer.get_name() != "headless":
		await capture("return_beam")
	portal.suspended = true
	await tick()
	check(not portal.portal_flashlight.visible, "Suspended portal releases inactive beam")
	Blackboard.store_data("player_input_blocked", true)
	await key(KEY_T)
	check(portal.flashlight.powered, "Modal input lock prevents accidental flashlight toggles")
	WorldState.tracking = false
	level.queue_free()
	for voice in pool.active.duplicate():
		voice.stop()
	await tick()
	pool.queue_free()
	print("Portal flashlight / forward aperture / direct room / reverse space / suspension / cleanup: ", "PASS" if failures.is_empty() else str(failures))
	get_tree().quit(0 if failures.is_empty() else 1)
