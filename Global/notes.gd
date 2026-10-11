extends Node

signal note_read(note: Dictionary)
signal note_read_finished(note: Dictionary)
signal collection_changed

func all_notes() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var saved: Variant = Blackboard.read_data("found_notes")
	if saved is Array:
		for note in saved:
			if note is Dictionary and note.has("id"):
				result.append(note.duplicate(true))
	return result

func has_note(id: StringName) -> bool:
	# Existence checks do not need the journal's defensive deep-copy API.
	var saved: Variant = Blackboard.read_data("found_notes")
	if saved is Array:
		for note in saved:
			if note is Dictionary and str(note.get("id", "")) == str(id):
				return true
	return false

func has_spawned(id: StringName) -> bool:
	var saved: Variant = Blackboard.read_data("spawned_notes")
	return has_note(id) or (saved is Array and saved.has(str(id)))

func mark_spawned(id: StringName) -> void:
	if id == &"":
		return
	var ids: Array[String] = []
	var saved: Variant = Blackboard.read_data("spawned_notes")
	if saved is Array:
		for value in saved:
			if value is String or value is StringName:
				ids.append(str(value))
	if not ids.has(str(id)):
		ids.append(str(id))
	Blackboard.store_data("spawned_notes", ids)

func collect(note: note_definition) -> void:
	if note == null or note.id == &"":
		return
	mark_spawned(note.id)
	var saved: Array[Dictionary] = all_notes()
	if not has_note(note.id):
		saved.append(note.snapshot())
		Blackboard.store_data("found_notes", saved)
		collection_changed.emit()
	note_read.emit(note.snapshot())
	DevTools.log_info("Read note / %s" % note.id, "notes")

## Culling a lost world drop frees its slot; the journal always takes priority.
func release_spawned(id: StringName) -> void:
	if id.is_empty() or has_note(id):
		return
	var saved: Variant = Blackboard.read_data("spawned_notes")
	if saved is Array:
		var ids: Array = saved.duplicate()
		ids.erase(str(id))
		ids.erase(id)
		Blackboard.store_data("spawned_notes", ids)
