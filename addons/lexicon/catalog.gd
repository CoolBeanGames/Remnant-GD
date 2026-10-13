@tool
class_name LexiconCatalog
extends Resource

@export var entries: Array[Resource] = []

func find(entry_id: StringName) -> Resource:
	for entry in entries:
		if entry != null and entry.get("id") == entry_id:
			return entry
	return null
