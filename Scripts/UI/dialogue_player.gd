class_name dialogue_player
extends CanvasLayer

signal sequence_started(sequence: dialogue_sequence)
signal sequence_finished(sequence: dialogue_sequence)
signal line_started(line: dialogue_line)
@export var voice_bus: StringName = &"Vocals"
@onready var label: Label = $Text
var queue: Array[dialogue_sequence] = []
var current: dialogue_sequence
var line_index: int = -1
var phase: String = ""
var characters: float = 0.0
var remaining: float = 0.0
var voice: WeakRef
var confirm_consumed: bool = false

func _ready() -> void:
	hide()
	Dialogue.bind(self)

func play(sequence: dialogue_sequence) -> bool:
	if sequence == null or sequence.lines.is_empty():
		return false
	if sequence.once and not sequence.id.is_empty():
		var key: String = "dialogue " + str(sequence.id)
		if Flags.check_flag(key):
			return false
		Flags.set_flag(key, true)
	queue.append(sequence)
	if current == null:
		_next_sequence()
	return true

func _next_sequence() -> void:
	if queue.is_empty():
		current = null
		phase = ""
		hide()
		return
	current = queue.pop_front()
	line_index = -1
	sequence_started.emit(current)
	_next_line()

func _next_line() -> void:
	_stop_voice()
	line_index += 1
	while line_index < current.lines.size() and current.lines[line_index] == null:
		line_index += 1
	if line_index >= current.lines.size():
		var finished: dialogue_sequence = current
		current = null
		sequence_finished.emit(finished)
		_next_sequence()
		return
	var line: dialogue_line = current.lines[line_index]
	label.text = line.text
	label.visible_characters = 0
	label.modulate.a = 1.0
	characters = 0.0
	phase = "typing"
	show()
	var audio: audio_player = Audio.play_global(line.voiceover, line.voice_volume, 1.0, voice_bus)
	voice = weakref(audio) if audio != null else null
	line_started.emit(line)

func _voice_playing() -> bool:
	var audio: audio_player = voice.get_ref() as audio_player if voice != null else null
	return is_instance_valid(audio) and is_instance_valid(audio.audio_global) and audio.audio_global.playing and current != null and audio.audio_global.stream == current.lines[line_index].voiceover

func _stop_voice() -> void:
	if _voice_playing():
		var audio: audio_player = voice.get_ref()
		audio.stop()
		audio.playback_finished.emit()
	voice = null

func _process(delta: float) -> void:
	if current == null:
		return
	var line: dialogue_line = current.lines[line_index]
	if phase == "typing":
		characters += delta * maxf(1, line.characters_per_second)
		label.visible_characters = int(characters)
		if characters >= label.get_total_character_count():
			label.visible_characters = -1
			phase = "holding"
			remaining = maxf(0, line.hold_seconds)
	elif phase == "holding":
		remaining -= delta
		if remaining <= 0 and (not line.wait_for_voice or not _voice_playing()):
			phase = "fading"
			remaining = maxf(.01, line.fade_seconds)
	elif phase == "fading":
		remaining -= delta
		label.modulate.a = clampf(remaining / maxf(.01, line.fade_seconds), 0, 1)
		if remaining <= 0:
			_next_line()

func cancel() -> void:
	_stop_voice()
	queue.clear()
	current = null
	phase = ""
	hide()

func _exit_tree() -> void:
	cancel()
	if Dialogue.view == self:
		Dialogue.view = null

func advance() -> void:
	if current != null:
		_next_line()

func _input(event: InputEvent) -> void:
	if IssueReporter.is_open or DebugInspector.is_open or DevConsole.is_open:
		return
	if current != null and event.is_action_pressed("confirm") and not event.is_echo():
		confirm_consumed = true
		advance()
		get_viewport().set_input_as_handled()

	elif confirm_consumed and event.is_action_released("confirm"):
		get_viewport().set_input_as_handled()
		_release_confirm()

func _release_confirm() -> void:
	await get_tree().create_timer(.05).timeout
	confirm_consumed = false

func blocks_confirm() -> bool:
	return current != null or confirm_consumed
