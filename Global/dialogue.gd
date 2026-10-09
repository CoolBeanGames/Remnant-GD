extends Node

var view: dialogue_player
var pending: Array[dialogue_sequence] = []

func bind(player: dialogue_player) -> void:
	view = player
	for sequence in pending:
		view.play(sequence)
	pending.clear()

func play(sequence: dialogue_sequence) -> bool:
	if sequence == null:
		return false
	if is_instance_valid(view):
		return view.play(sequence)
	pending.append(sequence)
	return true

func say(text: String, voiceover: AudioStream = null, id: StringName = &"", once: bool = false) -> bool:
	var line := dialogue_line.new()
	line.text = text
	line.voiceover = voiceover
	var sequence := dialogue_sequence.new()
	sequence.id = id
	sequence.once = once
	sequence.lines.append(line)
	return play(sequence)

func cancel() -> void:
	pending.clear()
	if is_instance_valid(view):
		view.cancel()
