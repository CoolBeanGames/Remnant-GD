class_name LexiconTrigger
extends Node

@export var player: LexiconPlayer
@export_enum("notes", "dialog", "flavor") var content_kind: String = "dialog"
@export var entry_id: StringName

func trigger() -> bool:
	if player == null:
		player = get_tree().get_first_node_in_group("lexicon_player") as LexiconPlayer
	return player.play(StringName(content_kind), entry_id) if player != null else false

func interact() -> void:
	trigger()
