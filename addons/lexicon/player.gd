class_name LexiconPlayer
extends Node

signal line_started(line: Dictionary)
signal choices_requested(choices: Array[Dictionary])
signal content_finished(kind: StringName, entry_id: StringName)
signal note_requested(note: LexiconNote)
signal content_error(message: String)
signal playback_cancelled

@export var database: LexiconDatabase
var current: Resource
var kind: StringName
var current_line: Dictionary = {}
var flavor_index: int = 0

func _ready() -> void:
	add_to_group("lexicon_player")

func play(content_kind: StringName, entry_id: StringName) -> bool:
	if database == null:
		content_error.emit("No Lexicon database assigned.")
		return false
	var entry: Resource = database.find(content_kind, entry_id)
	if entry == null:
		content_error.emit("Missing Lexicon entry / %s / %s" % [content_kind, entry_id])
		return false
	cancel()
	kind = content_kind
	if entry is LexiconNote:
		note_requested.emit(entry)
		content_finished.emit(kind, entry_id)
		return true
	current = entry
	flavor_index = 0
	if current is LexiconConversation:
		_show(current.start_line)
	elif current is LexiconFlavor:
		_show_flavor()
	else:
		content_error.emit("Unsupported Lexicon resource.")
		cancel()
		return false
	return true

func advance() -> void:
	if current == null:
		return
	if current is LexiconFlavor:
		flavor_index += 1
		_show_flavor()
	elif not current_line.get("choices", []).is_empty():
		var choices: Array[Dictionary] = []
		for choice: Dictionary in current_line.choices:
			choices.append(choice.duplicate())
		choices_requested.emit(choices)
	else:
		_show(str(current_line.get("next", "")))

func choose(index: int) -> bool:
	if not current is LexiconConversation:
		return false
	var choices: Array = current_line.get("choices", [])
	if index < 0 or index >= choices.size():
		return false
	_show(str(choices[index].get("target", "")))
	return true

func cancel() -> void:
	current = null
	current_line = {}
	flavor_index = 0
	playback_cancelled.emit()

func _show(line_id: String) -> void:
	if line_id.is_empty():
		_finish()
		return
	current_line = (current as LexiconConversation).get_line(line_id)
	if current_line.is_empty():
		content_error.emit("Missing conversation line / " + line_id)
		cancel()
		return
	line_started.emit(current_line.duplicate(true))

func _show_flavor() -> void:
	var lines: Array[Dictionary] = (current as LexiconFlavor).lines
	if flavor_index >= lines.size():
		_finish()
	else:
		current_line = lines[flavor_index].duplicate(true)
		line_started.emit(current_line.duplicate(true))

func _finish() -> void:
	var entry_id: StringName = current.get("id")
	cancel()
	content_finished.emit(kind, entry_id)
