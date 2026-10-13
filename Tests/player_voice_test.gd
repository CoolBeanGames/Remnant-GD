extends Node
var failures: Array[String] = []
var death_done: bool = false
func check(ok: bool, text: String) -> void:
	if not ok:
		failures.append(text)
		push_error(text)
func _ready() -> void:
	run.call_deferred()
func finish_death(wake: player_wake_up) -> void:
	await wake.fade_for_death()
	death_done = true
func run() -> void:
	var pool := object_pool.new()
	pool.pooled_scene = load("res://Scenes/audio_player.tscn")
	pool.reset_method = &"reset"
	pool.register_with_blackboard = true
	pool.blackboard_name = &"audio_pool"
	add_child(pool)
	var movement: Node = load("res://Scripts/Player/player_move_controller.gd").new()
	add_child(movement)
	movement.set_physics_process(false)
	movement._update_sprint_audio(4.9, true)
	check(pool.active.is_empty(), "Short sprints stay silent")
	movement._update_sprint_audio(.11, true)
	var breath: audio_player = pool.active.back()
	check(breath.audio_2d.stream == movement.heavy_breathing, "Five seconds of sprinting starts the heavy breath")
	var count: int = pool.active.size()
	movement._update_sprint_audio(10.0, true)
	check(pool.active.size() == count, "Heavy breathing never overlaps itself")
	movement._update_sprint_audio(1.0, false)
	check(movement.sprint_elapsed == 0, "Stopping resets continuous sprint time")
	movement.reset_audio()
	check(pool.active.is_empty(), "Respawn cleanup releases heavy breathing")
	for i in 6:
		var jump: audio_player = movement.play_jump_sound()
		check(movement.jump_sounds.has(jump.audio_2d.stream) and jump.audio_2d.bus == &"Vocals", "Jump selects an authored grunt on the room-audible bus")
		jump.stop()
		jump.playback_finished.emit()
	movement.jump_sounds.clear()
	check(movement.play_jump_sound() == null, "Optional jump sounds can be blank")
	Blackboard.store_data("spawned_items", [])
	Blackboard.store_data("player_input_blocked", false)
	var level: level_sequence = load("res://Scenes/testing_level.tscn").instantiate()
	level.spawn_animation_enabled = false
	add_child(level)
	await get_tree().process_frame
	var wake: player_wake_up = level.player.get_node("Controllers/Wake_Up")
	var look: Node = level.player.get_node("Controllers/Player_Look_Controller")
	wake.death_fade_seconds = .08
	var short_sound := AudioStreamWAV.new()
	short_sound.mix_rate = 8000
	short_sound.format = AudioStreamWAV.FORMAT_8_BITS
	var pcm := PackedByteArray()
	pcm.resize(8000)
	short_sound.data = pcm
	wake.death_sounds = [short_sound]
	finish_death(wake)
	check(Blackboard.read_data("player_input_blocked") == true and not look.is_processing(), "Death locks controls before fading")
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().create_timer(.12).timeout
	check(wake.black.color.a > .99 and not death_done, "Death reaches black and waits for the death voice")
	await get_tree().create_timer(1.1).timeout
	check(death_done and Blackboard.read_data("player_input_blocked") == false and look.is_processing(), "Finished death restores control ownership for waking")
	wake.effort_sounds = []
	wake.start()
	wake.set_process(false)
	wake._process(4.0)
	check(pool.active.size() >= 2, "Both rise stages dispatch their slide effects")
	# The left-to-right sweep now spans 2.9 seconds, rather than 0.9.
	wake._apply_pose(7.25)
	var left: float = wake.camera.rotation_degrees.y
	wake._apply_pose(8.25)
	check(absf(wake.camera.rotation_degrees.y - left) < 20, "Look-around sweep moves gradually over its first second")
	level.queue_free()
	movement.queue_free()
	await get_tree().process_frame
	for audio: audio_player in pool.active:
		audio.reset()
	await get_tree().create_timer(.1).timeout
	print("Sprint, jump, death fade, rise sounds and slower look-around: ", "PASS" if failures.is_empty() else str(failures))
	get_tree().quit(0 if failures.is_empty() else 1)
