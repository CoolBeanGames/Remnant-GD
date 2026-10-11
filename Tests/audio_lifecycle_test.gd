extends Node

var failures: Array[String] = []

func check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
		push_error(message)

func _ready() -> void:
	run.call_deferred()

func run() -> void:
	SaveGame.enabled = false
	var pool := object_pool.new()
	pool.pooled_scene = load("res://Scenes/audio_player.tscn")
	pool.reset_method = &"reset"
	pool.register_with_blackboard = true
	pool.blackboard_name = &"audio_pool"
	add_child(pool)
	var clip: AudioStream = load("res://Audio/SFX/grind.wav")
	var first: audio_player = Audio.play_global(clip)
	var first_id: int = first.playback_id
	first.stop(first_id)
	check(pool.active.is_empty() and pool.available == [first], "Cancelling a pooled clip releases it without manually emitting signals")
	first.stop(first_id)
	check(pool.available.size() == 1, "Repeated cancellation does not duplicate a pooled player")
	var second: audio_player = Audio.play_global(clip)
	check(second == first and second.playback_id != first_id, "Reused player gets a new playback ownership ID")
	second.stop(first_id)
	check(second.audio_global.playing and pool.active == [second], "A stale owner cannot stop a reused same-stream sound")
	second.stop(second.playback_id)

	var movement: Node = load("res://Scripts/Player/player_move_controller.gd").new()
	add_child(movement)
	movement.set_physics_process(false)
	movement.heavy_breathing = clip
	movement._update_sprint_audio(6.0, true)
	var breath: audio_player = pool.active.back()
	breath._on_audio_finished()
	var reused_breath: audio_player = Audio.play_global(clip)
	movement.reset_audio()
	check(reused_breath.audio_global.playing, "Respawn cleanup cannot cancel another owner's reused breathing clip")
	reused_breath.stop()
	movement.queue_free()

	var ui: dialogue_player = load("res://Scenes/UI/dialogue_player.tscn").instantiate()
	add_child(ui)
	ui.set_process(false)
	var line := dialogue_line.new()
	line.text = "Ownership test"
	line.voiceover = clip
	var sequence := dialogue_sequence.new()
	sequence.lines.append(line)
	ui.play(sequence)
	var voice: audio_player = pool.active.back()
	voice._on_audio_finished()
	var reused_voice: audio_player = Audio.play_global(clip)
	ui.cancel()
	check(reused_voice.audio_global.playing, "Skipping dialogue cannot cancel another owner's reused voice clip")
	reused_voice.stop()
	ui.queue_free()

	var local := AudioStreamPlayer3D.new()
	add_child(local)
	Audio.set_spatial_active(local, true)
	check(not local.playing, "Optional blank persistent sounds stay silent")
	local.stream = clip
	Audio.set_spatial_active(local, true)
	Audio.set_spatial_active(local, true)
	check(local.playing and pool.active.is_empty(), "Persistent spatial sources retain their local player without borrowing pooled slots")
	Audio.set_spatial_active(local, false)
	check(not local.playing, "Disabling a persistent spatial source stops it immediately")
	local.queue_free()

	var discarded: audio_player = pool.available.back()
	discarded.free()
	var replacement: audio_player = Audio.play_3d(clip, Vector3.ZERO)
	check(is_instance_valid(replacement) and replacement.audio_3d.playing, "Externally freed available nodes are replaced instead of returned")
	replacement.stop()

	var chute := ceiling_chute.new()
	chute.enabled = false
	add_child(chute)
	var handle: lever = load("res://Scenes/Actors/lever_assembly.tscn").instantiate()
	handle.chute = chute
	add_child(handle)
	handle.interact()
	check(pool.active.size() == 1 and (pool.active.back() as audio_player).audio_3d.stream == handle.pull_sound, "Lever pull plays while the handle is being pulled")
	handle.interact()
	check(pool.active.size() == 1, "Repeated interaction during a lever pull does not stack its sound")
	handle.anim.advance(handle.anim.current_animation_length)
	check(pool.active.size() == 2 and (pool.active.back() as audio_player).audio_3d.stream == handle.reset_sound, "Lever reset plays when the reset animation starts")
	for audio: audio_player in pool.active.duplicate():
		audio.stop()
	handle.queue_free()
	chute.queue_free()

	var prototype := Node.new()
	var scene := PackedScene.new()
	scene.pack(prototype)
	prototype.free()
	var old_scene: Node = SceneManager.load_scene(scene, &"audio_review_scene", &"audio_review_bundle", self)
	old_scene.queue_free()
	await get_tree().process_frame
	check(not SceneManager.scene_exists(&"audio_review_scene"), "Externally freed scenes no longer reserve access names")
	var new_scene: Node = SceneManager.load_scene(scene, &"audio_review_scene", &"audio_review_bundle", self)
	check(is_instance_valid(new_scene), "Scene access names can be reused after external teardown")
	SceneManager.unload_scene(&"audio_review_scene")
	await get_tree().process_frame
	# Let spatial playback commands and queued source nodes finish teardown
	# before shutting down the audio server in the headless fixture.
	pool.queue_free()
	await get_tree().process_frame
	await get_tree().physics_frame
	print("Audio cancellation, reuse ownership, spatial loops and scene lifecycle: ", "PASS" if failures.is_empty() else failures)
	get_tree().quit(0 if failures.is_empty() else 1)
