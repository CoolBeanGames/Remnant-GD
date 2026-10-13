extends Node
var failures: Array[String] = []
func check(ok: bool, text: String) -> void:
	if not ok:
		failures.append(text)
		push_error(text)
func _ready() -> void:
	run.call_deferred()
func run() -> void:
	Flags.set_flag("dialogue test_intro", false)
	var pool := object_pool.new()
	pool.pooled_scene = load("res://Scenes/audio_player.tscn")
	pool.reset_method = &"reset"
	pool.register_with_blackboard = true
	pool.blackboard_name = &"audio_pool"
	add_child(pool)
	var ui: dialogue_player = load("res://Scenes/UI/dialogue_player.tscn").instantiate()
	add_child(ui)
	ui.set_process(false)
	var line := dialogue_line.new()
	line.text = "Hello."
	line.characters_per_second = 10
	line.hold_seconds = .2
	line.fade_seconds = .2
	var sequence := dialogue_sequence.new()
	sequence.id = &"test_intro"
	sequence.once = true
	sequence.lines = [line]
	check(Dialogue.play(sequence) and not Dialogue.play(sequence), "Persistent one-shot dialogue accepts only its first trigger")
	ui._process(.2)
	check(ui.label.visible_characters == 2 and ui.label.modulate.a == 1, "Dialogue types letter by letter")
	get_tree().paused = true
	ui.set_process(true)
	await get_tree().process_frame
	await get_tree().process_frame
	check(ui.label.visible_characters == 2, "Pause menu freezes dialogue progress")
	get_tree().paused = false
	ui.set_process(false)
	ui._process(1)
	ui._process(.3)
	ui._process(.1)
	check(is_equal_approx(ui.label.modulate.a, .5), "Completed text fades away")
	ui._process(.2)
	check(ui.current == null and not ui.visible, "Finished dialogue hides itself")
	line.voiceover = load("res://Audio/SFX/Lever/Lever_Pull.wav")
	sequence.once = false
	check(Dialogue.play(sequence), "Repeatable dialogue can play again")
	var audio: audio_player = pool.active.back()
	check(audio.audio_2d.stream == line.voiceover and audio.audio_2d.bus == ui.voice_bus, "Optional voice uses the pooled audio system")
	ui._process(1)
	ui._process(1)
	check(ui.phase == "holding", "Subtitle stays until its optional voice finishes")
	var next_line := dialogue_line.new()
	next_line.text = "Next line"
	sequence.lines.append(next_line)
	var skip := InputEventAction.new()
	skip.action = &"confirm"
	skip.pressed = true
	ui._input(skip)
	check(ui.line_index == 1 and ui.label.text == "Next line" and not audio.audio_2d.playing, "E skips to the next line and releases its old voice")
	Dialogue.cancel()
	check(not audio.audio_2d.playing and pool.active.is_empty() and ui.current == null, "Cancel stops and releases dialogue audio")
	var empty := dialogue_sequence.new()
	check(not Dialogue.play(empty), "Empty dialogue safely does nothing")
	check(Dialogue.say("A dynamic line"), "Dialogue.say supports direct scripted text")
	Dialogue.cancel()
	ui.queue_free()
	await get_tree().process_frame
	await get_tree().create_timer(.1).timeout
	print("Dialogue typing, fade, pause, voice, once and scripted triggers: ", "PASS" if failures.is_empty() else str(failures))
	get_tree().quit(0 if failures.is_empty() else 1)
