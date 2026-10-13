extends Node
var failures: Array[String] = []

func check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
		push_error(message)

func _ready() -> void:
	_run.call_deferred()

func _run() -> void:
	Flags.remove_flag("exited room")
	var sfx: int = AudioServer.get_bus_index("SFX")
	var saved_volume: float = AudioServer.get_bus_volume_db(sfx)
	var saved_mute: bool = AudioServer.is_bus_mute(sfx)
	AudioServer.set_bus_volume_db(sfx, -7.0)
	AudioServer.set_bus_mute(sfx, false)
	var pool := object_pool.new()
	pool.pooled_scene = load("res://Scenes/audio_player.tscn")
	pool.reset_method = &"reset"
	pool.register_with_blackboard = true
	pool.blackboard_name = &"audio_pool"
	add_child(pool)
	var level: Node3D = load("res://Scenes/testing_level.tscn").instantiate()
	var room: start_room = level.get_node("CSGCombiner3D")
	room.auto_close_on_exit = false
	var door: start_room_door = level.get_node("doorway_animated")
	var left: AudioStream = load("res://Audio/SFX/Footsteps/Footstep_L1.wav")
	var right: AudioStream = load("res://Audio/SFX/Footsteps/Footstep_R1.wav")
	room.left_foot_sounds = [left]
	room.right_foot_sounds = [right]
	door.open_sound = load("res://Audio/SFX/Lever/Lever_Pull.wav")
	door.open_sound_bus = &"SFX"
	door.close_sound = load("res://Audio/SFX/Lever/Lever_Reset.wav")
	door.close_sound_bus = &"RoomSFX"
	level.set("spawn_animation_enabled", false)
	add_child(level)
	var player: CharacterBody3D = level.get_node("Player")
	player.process_mode = Node.PROCESS_MODE_DISABLED
	room.set_physics_process(false)
	var footsteps: footstep_audio = room.footsteps
	var light: light_flicker = room.get_node("OmniLight3D")
	light.set_process(false)
	light.random.seed = 123
	light.off_interval = Vector2(.05, .05)
	light.on_interval = Vector2(.03, .03)
	light.outage_count = Vector2i(2, 2)
	light.remaining = 0.0
	light._process(0.001)
	check(not light.powered and light.light_energy == 0, "Bad connection cuts room light fully off.")
	light._process(.05)
	check(light.powered and light.light_energy == light.original_energy, "Flicker restores the authored energy between outages.")
	light._process(.03)
	check(not light.powered and light.light_energy == 0, "Flicker includes repeated brief outages in each burst.")
	light._process(.05)
	check(light.powered and light.transitions_left == 0 and light.remaining > 1, "Burst ends lit with an irregular steady interval.")
	light.flicker_enabled = false
	light.light_energy = 0
	light._process(.01)
	check(light.light_energy == light.original_energy, "Disabling flicker restores the original light.")
	check(AudioServer.is_bus_mute(sfx) and AudioServer.get_bus_volume_db(sfx) == -80.0, "Start room silences SFX at startup.")
	check(footsteps.get_step_sounds(true) == [left] and footsteps.get_step_sounds(false) == [right], "Room selects its editable left/right footstep banks while inside.")
	footsteps.play_L()
	var step_bus: StringName = footsteps.bus if AudioServer.get_bus_index(footsteps.bus) >= 0 else &"Master"
	check(pool.active.size() == 1 and (pool.active[0] as audio_player).audio_3d.bus == step_bus and step_bus != &"SFX", "Room footsteps preserve the configured bus outside gated SFX.")
	var restored_before_sound: Array[bool] = []
	door.opened.connect(func(): restored_before_sound.append(not AudioServer.is_bus_mute(sfx) and AudioServer.get_bus_volume_db(sfx) == -7.0))
	door.interact()
	check(restored_before_sound == [true] and not room.sfx_gated, "First opening restores the original SFX volume before door sound playback.")
	check(pool.active.size() == 2, "Opening dispatches exactly one pooled sound.")
	var sound: audio_player = pool.active.back()
	check(sound.audio_3d.stream == door.open_sound and sound.audio_3d.bus == &"SFX" and sound.global_position.is_equal_approx(door.global_position), "Door sound uses the audio system, SFX bus and door position.")
	door.interact()
	check(pool.active.size() == 2, "Interacting again during animation does not duplicate the door sound.")
	player.global_position = Vector3(4.75, .3, 9)
	room._physics_process(.01)
	check(door.is_strange and door.prompt_component.prompts.entries[0].get_display_text() == "Close Strange Door [E]", "Leaving immediately renames the already open door, before room removal.")
	check(not Flags.check_flag("exited room"), "Door label changes without prematurely setting the room-removal flag.")
	room._update_footsteps()
	check(footsteps.get_step_sounds(true) == footsteps.left_foot_sounds, "Outside uses normal footsteps.")
	player.global_position = Vector3(4.75, .3, 18)
	room._update_footsteps()
	check(footsteps.get_step_sounds(false) == [right], "Reentering switches back to room footsteps.")
	room.left_foot_sounds = []
	room._update_footsteps()
	check(footsteps.get_step_sounds(true) == footsteps.left_foot_sounds, "Unassigned room sound banks safely fall back to normal footsteps.")
	door.animation.advance(door.animation.current_animation_length)
	var before_close: int = pool.active.size()
	door.interact()
	check(pool.active.size() == before_close, "Closing does not dispatch its sound before the animation finishes.")
	check(not door.is_open and not AudioServer.is_bus_mute(sfx) and AudioServer.get_bus_volume_db(sfx) == -7.0, "Closing never re-mutes SFX.")
	door.animation.advance(door.animation.current_animation_length)
	sound = pool.active.back()
	check(sound.audio_3d.stream == door.close_sound and sound.audio_3d.bus == &"RoomSFX" and sound.global_position.is_equal_approx(door.global_position), "Closing plays its own pooled positional sound on the configured bus.")
	check(door.prompt_component.prompts.entries[0].get_display_text() == "Open Strange Door [E]", "Closed strange door shows the correct open prompt.")
	var sound_count: int = pool.active.size()
	door._on_animation_finished(&"unrelated")
	check(pool.active.size() == sound_count, "Other animations do not dispatch closing audio.")
	room._remove_room()
	await get_tree().process_frame
	check(footsteps.sound_override_source == null and is_instance_valid(door), "Erasing the room clears only its footstep override and retains the door.")
	level.queue_free()
	await get_tree().process_frame
	# A level unloaded before opening must not leak its mute to other scenes.
	Flags.remove_flag("exited room")
	AudioServer.set_bus_mute(sfx, true)
	level = load("res://Scenes/testing_level.tscn").instantiate()
	level.set("spawn_animation_enabled", false)
	add_child(level)
	level.queue_free()
	await get_tree().process_frame
	check(AudioServer.get_bus_volume_db(sfx) == -7.0 and AudioServer.is_bus_mute(sfx), "Unloading restores both prior volume and prior mute preference.")
	Flags.set_flag("exited room", true)
	AudioServer.set_bus_mute(sfx, false)
	level = load("res://Scenes/testing_level.tscn").instantiate()
	level.set("spawn_animation_enabled", false)
	add_child(level)
	await get_tree().process_frame
	check(not AudioServer.is_bus_mute(sfx) and AudioServer.get_bus_volume_db(sfx) == -7.0, "An already exited room never gates SFX again.")
	door = level.get_node("doorway_animated")
	check(door.is_strange and door.prompt_component.prompts.entries[0].text == "Open Strange Door", "Saved exit flag restores the strange door label on load.")
	level.queue_free()
	await get_tree().process_frame
	for audio: audio_player in pool.active:
		audio.reset()
	await get_tree().create_timer(.1).timeout
	pool.queue_free()
	await get_tree().process_frame
	Blackboard.remove_data("audio_pool")
	Flags.remove_flag("exited room")
	AudioServer.set_bus_volume_db(sfx, saved_volume)
	AudioServer.set_bus_mute(sfx, saved_mute)
	print("Start room audio/footsteps/SFX gate: ", "PASS" if failures.is_empty() else str(failures))
	get_tree().quit(0 if failures.is_empty() else 1)
