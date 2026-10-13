class_name lexicon_remnant_bridge
extends Node

## Assign the optional SDK presenter to use Remnant's pooled voice and held notes.
@export var presenter: LexiconPresenter

func _ready() -> void:
	if presenter != null:
		presenter.voice_handler = _voice
		presenter.note_handler = _note

func _voice(stream: AudioStream) -> Node:
	return audio_global.play_global(stream, 1, 1, &"Vocals")

func _note(source: LexiconNote) -> void:
	var note := note_definition.new()
	note.id = source.id
	note.title = source.title
	note.body = source.text
	note.page_texture = source.image
	Notes.collect(note)
