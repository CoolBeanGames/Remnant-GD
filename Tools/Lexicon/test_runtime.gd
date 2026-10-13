extends SceneTree

## Run in an isolated project after exporting the browser fixture into it.
var passed: int = 0
var failures: int = 0
var lines_seen: Array[String] = []
var errors_seen: Array[String] = []
var notes_seen: Array[LexiconNote] = []

func _initialize() -> void:
	_run.call_deferred()

func check(value: bool, description: String) -> void:
	if value:
		passed += 1
		print("PASS / ", description)
	else:
		failures += 1
		print("FAIL / ", description)

func _run() -> void:
	var database := load("res://lexicon/lexicon_db.tres") as LexiconDatabase
	check(database != null, "Exported master resource loads in a project with no Remnant services")
	if database == null:
		quit(1)
		return
	check(database.notes.entries.size() == 1 and database.dialog.entries.size() == 1 and database.flavor.entries.size() == 1, "All three catalogs load")
	var note := database.find(&"notes", &"note_1") as LexiconNote
	check(note != null and note.image != null and note.text.contains("<script>literal text</script>"), "Image and literal typed transcript survive export")
	var conversation := database.find(&"dialog", &"conversation_1") as LexiconConversation
	check(conversation != null and conversation.get_line("line_1").get("audio") is AudioStream, "Voice clip imports as playable Godot audio")
	var editable := conversation.get_line("line_1")
	editable.choices[0].label = "Temporary change"
	check(conversation.get_line("line_1").choices[0].label == "Remember", "Runtime line copies do not edit the authored branch")
	var player := (load("res://addons/lexicon/player.tscn") as PackedScene).instantiate() as LexiconPlayer
	player.database = database
	var presenter := player.get_node("Presenter") as LexiconPresenter
	presenter.auto_advance = false
	root.add_child(player)
	await process_frame
	player.line_started.connect(func(line: Dictionary) -> void: lines_seen.append(str(line.text)))
	player.content_error.connect(func(message: String) -> void: errors_seen.append(message))
	player.note_requested.connect(func(value: LexiconNote) -> void: notes_seen.append(value))
	Input.mouse_mode = Input.MOUSE_MODE_HIDDEN
	var original_mouse_mode: Input.MouseMode = Input.mouse_mode
	check(player.play(&"dialog", &"conversation_1") and presenter.caption.text == "Do you remember?" and presenter.voice_pending, "Runtime starts at the authored line with voice")
	var skip := InputEventKey.new()
	skip.keycode = KEY_E
	skip.pressed = true
	Input.parse_input_event(skip)
	await process_frame
	check(presenter.choices.get_child_count() == 2 and not presenter.voice_pending and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE, "E skips voice and exposes usable branch buttons")
	check(not player.choose(99), "Invalid choice cannot advance")
	(presenter.choices.get_child(0) as Button).pressed.emit()
	check(lines_seen.back() == "I remember." and Input.mouse_mode == original_mouse_mode, "Button follows selected target and restores mouse mode")
	player.advance()
	check(player.current == null and presenter.caption.text.is_empty(), "End clears the presentation")
	player.play(&"notes", &"note_1")
	check(notes_seen.size() == 1 and presenter.note_window.visible and presenter.note_image.texture != null, "Draft note presentation displays image and text")
	presenter.close_note()
	check(not presenter.note_window.visible and Input.mouse_mode == original_mouse_mode, "Closing note restores prior mouse mode")
	player.play(&"flavor", &"flavor_1")
	check(lines_seen.back() == "It has gone cold." and not presenter.voice_pending, "Linear flavor supports no optional voice")
	player.cancel()
	check(not presenter.showing and presenter.caption.text.is_empty(), "External cancellation clears draft UI and audio")
	check(not player.play(&"dialog", &"missing") and errors_seen.size() == 1, "Missing content reports a signal without crashing")
	var linear := database.find(&"flavor", &"flavor_1") as LexiconFlavor
	linear.lines.append({"id": "line_2", "speaker": "", "text": "Second line"})
	player.play(&"flavor", &"flavor_1")
	player.advance()
	check(lines_seen.back() == "Second line", "Flavor plays in order without branch targets")
	player.advance()
	check(player.current == null, "Final flavor line ends")
	player.play(&"dialog", &"conversation_1")
	presenter.auto_advance = true
	presenter.characters_per_second = 10000
	presenter.hold_seconds = 0
	await create_timer(0.04).timeout
	check(presenter.choices.get_child_count() == 0 and presenter.voice_pending, "Auto advance waits for the voice to finish")
	await create_timer(0.3).timeout
	check(presenter.choices.get_child_count() == 2 and not presenter.voice_pending, "Voice completion then exposes choices")
	if "--capture-lexicon" in OS.get_cmdline_user_args():
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://lexicon_runtime_choices.png")
		player.play(&"notes", &"note_1")
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://lexicon_runtime_note.png")
		presenter.close_note()
		player.play(&"dialog", &"conversation_1")
	player.choose(1)
	check(player.current == null, "Choice can terminate a conversation")
	player.queue_free()
	await process_frame
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	print("Lexicon runtime / ", passed, " checks / ", failures, " failures")
	quit(0 if failures == 0 else 1)
