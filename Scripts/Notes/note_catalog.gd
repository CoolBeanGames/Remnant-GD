class_name note_catalog
extends Resource

@export var notes: Array[note_definition] = []

func available() -> Array[note_definition]:
	var result: Array[note_definition] = []
	for note in notes:
		if note != null and note.id != &"" and not Notes.has_spawned(note.id):
			result.append(note)
	return result
