@tool
class_name LexiconFlavor
extends Resource

@export var id: StringName
@export var title: String = "Untitled"
## Ordered speaker/text/audio dictionaries. No branching.
@export var lines: Array[Dictionary] = []
