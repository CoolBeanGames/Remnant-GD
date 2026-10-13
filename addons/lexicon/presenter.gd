class_name LexiconPresenter
extends CanvasLayer

## Optional draft presentation. Hosts can use their own in-world UI and audio.
@export var player: LexiconPlayer
@export var characters_per_second: float = 28
@export var hold_seconds: float = 1
@export var auto_advance: bool = true
@export var advance_key: Key = KEY_E
@export var voice_bus: StringName = &"Vocals"
var voice_handler: Callable
var note_handler: Callable
var caption: Label
var speaker: Label
var choices: VBoxContainer
var note_window: PanelContainer
var note_text: RichTextLabel
var note_image: TextureRect
var fallback_voice: AudioStreamPlayer
var voice: Node
var voice_generation: int = 0
var voice_pending: bool = false
var voice_signal: StringName
var voice_callback: Callable
var characters: float = 0
var elapsed: float = 0
var showing: bool = false
var mouse_owned: bool = false
var previous_mouse_mode: Input.MouseMode = Input.MOUSE_MODE_VISIBLE

func _ready() -> void:
	if player == null:
		player = get_tree().get_first_node_in_group("lexicon_player") as LexiconPlayer
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	var rows := VBoxContainer.new()
	rows.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	rows.offset_left = 40
	rows.offset_right = -40
	rows.offset_top = -190
	root.add_child(rows)
	speaker = Label.new()
	rows.add_child(speaker)
	caption = Label.new()
	caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	caption.add_theme_font_size_override("font_size", 24)
	caption.add_theme_color_override("font_outline_color", Color.BLACK)
	caption.add_theme_constant_override("outline_size", 6)
	rows.add_child(caption)
	choices = VBoxContainer.new()
	rows.add_child(choices)
	note_window = PanelContainer.new()
	note_window.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	note_window.offset_left = 60
	note_window.offset_top = 50
	note_window.offset_right = -60
	note_window.offset_bottom = -50
	root.add_child(note_window)
	var note_rows := VBoxContainer.new()
	note_window.add_child(note_rows)
	note_image = TextureRect.new()
	note_image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	note_image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	note_image.custom_minimum_size.y = 240
	note_rows.add_child(note_image)
	note_text = RichTextLabel.new()
	note_text.bbcode_enabled = false
	note_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	note_rows.add_child(note_text)
	var close_button := Button.new()
	close_button.text = "Close note [Esc]"
	close_button.pressed.connect(close_note)
	note_rows.add_child(close_button)
	note_window.hide()
	fallback_voice = AudioStreamPlayer.new()
	fallback_voice.bus = voice_bus if AudioServer.get_bus_index(voice_bus) >= 0 else &"Master"
	add_child(fallback_voice)
	if player != null:
		player.line_started.connect(_line)
		player.choices_requested.connect(_choices)
		player.note_requested.connect(_note)
		player.content_finished.connect(_finished)
		player.playback_cancelled.connect(_cancelled)
	set_process(false)

func _line(line: Dictionary) -> void:
	_stop_voice()
	_clear_choices()
	_release_mouse()
	caption.text = str(line.get("text", ""))
	caption.visible_characters = 0
	caption.modulate.a = 1
	speaker.text = str(line.get("speaker", ""))
	characters = 0
	elapsed = 0
	showing = true
	var audio: AudioStream = line.get("audio") as AudioStream
	if audio != null:
		voice_pending = true
		if voice_handler.is_valid():
			voice = voice_handler.call(audio) as Node
		else:
			fallback_voice.stream = audio
			fallback_voice.play()
			voice = fallback_voice
		var completed: StringName = &"playback_finished" if is_instance_valid(voice) and voice.has_signal("playback_finished") else &"finished"
		if is_instance_valid(voice) and voice.has_signal(completed):
			voice_signal = completed
			voice_callback = _voice_finished.bind(voice_generation)
			voice.connect(voice_signal, voice_callback, CONNECT_ONE_SHOT)
		else:
			voice_pending = false
	set_process(true)

func _voice_finished(generation: int) -> void:
	if generation == voice_generation:
		voice_pending = false
		voice = null
		voice_callback = Callable()

func _process(delta: float) -> void:
	if not showing:
		return
	characters += delta * maxf(1, characters_per_second)
	caption.visible_characters = int(characters)
	if caption.visible_characters < caption.text.length():
		return
	elapsed += delta
	if auto_advance and elapsed >= hold_seconds and not voice_pending:
		showing = false
		player.advance()

func _unhandled_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	if note_window.visible and event.keycode == KEY_ESCAPE:
		close_note()
		get_viewport().set_input_as_handled()
	elif showing and (event.keycode == advance_key or event.physical_keycode == advance_key):
		_stop_voice()
		showing = false
		player.advance()
		get_viewport().set_input_as_handled()

func _choices(options: Array[Dictionary]) -> void:
	showing = false
	caption.visible_characters = -1
	_clear_choices()
	_claim_mouse()
	for index in options.size():
		var choice_button := Button.new()
		choice_button.text = str(options[index].get("label", ""))
		choice_button.pressed.connect(func() -> void: player.choose(index))
		choices.add_child(choice_button)

func _note(note: LexiconNote) -> void:
	if note_handler.is_valid():
		note_handler.call(note)
		return
	note_image.texture = note.image
	note_image.visible = note.image != null
	note_text.text = note.title + "\n\n" + note.text
	note_window.show()
	_claim_mouse()

func close_note() -> void:
	note_window.hide()
	_release_mouse()

func _cancelled() -> void:
	_finished(&"", &"")
	close_note()

func _finished(_kind: StringName, _entry_id: StringName) -> void:
	showing = false
	caption.text = ""
	speaker.text = ""
	_clear_choices()
	_stop_voice()
	if not note_window.visible:
		_release_mouse()
	set_process(false)

func _clear_choices() -> void:
	for child in choices.get_children():
		choices.remove_child(child)
		child.queue_free()

func _claim_mouse() -> void:
	if not mouse_owned:
		previous_mouse_mode = Input.mouse_mode
		mouse_owned = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _release_mouse() -> void:
	if mouse_owned:
		Input.mouse_mode = previous_mouse_mode
		mouse_owned = false

func _stop_voice() -> void:
	voice_generation += 1
	if is_instance_valid(voice) and voice_callback.is_valid() and voice.is_connected(voice_signal, voice_callback):
		voice.disconnect(voice_signal, voice_callback)
	if is_instance_valid(voice) and voice_pending and voice.has_method("stop"):
		voice.call("stop")
	voice = null
	voice_pending = false
	voice_callback = Callable()
	fallback_voice.stop()
	fallback_voice.stream = null

func _exit_tree() -> void:
	_release_mouse()
	if fallback_voice != null:
		_stop_voice()
