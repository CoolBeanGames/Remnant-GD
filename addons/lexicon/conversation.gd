@tool
class_name LexiconConversation
extends Resource

@export var id: StringName
@export var title: String = "Untitled"
@export var start_line: String = ""
## Each line: id, speaker, text, audio (optional AudioStream), next, choices.
## Choices: label and target. Empty next/target ends the conversation.
@export var lines: Array[Dictionary] = []

func get_line(line_id: String) -> Dictionary:
	for line in lines:
		if str(line.get("id", "")) == line_id:
			return line.duplicate(true)
	return {}
