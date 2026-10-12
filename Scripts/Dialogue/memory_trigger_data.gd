class_name memory_trigger_data
extends Resource

## An empty interaction flag makes this a look-only set piece.
@export var interaction_flag: String = ""
@export var prompt_text: String = "Inspect"
@export var interaction_dialogue: dialogue_sequence
@export var look_id: StringName
@export var look_dialogue: dialogue_sequence
@export_range(0.1, 5.0, 0.05) var look_delay: float = 0.8
