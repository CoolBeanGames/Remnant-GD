@tool
class_name LexiconDatabase
extends Resource

@export var notes: LexiconCatalog
@export var dialog: LexiconCatalog
@export var flavor: LexiconCatalog

func find(kind: StringName, entry_id: StringName) -> Resource:
	var catalog: LexiconCatalog
	match kind:
		&"notes": catalog = notes
		&"dialog": catalog = dialog
		&"flavor": catalog = flavor
	return catalog.find(entry_id) if catalog != null else null
