class_name note_definition
extends Resource

@export var id: StringName
@export var title: String = "Untitled note"
@export_multiline var body: String = ""

func snapshot() -> Dictionary:
	return {"id": str(id), "title": title, "body": body}
