class_name dialogue_trigger
extends Area3D

@export var sequence: dialogue_sequence
@export var on_player_entry: bool = true
@export var prompt_text: String = "Listen"

func _ready() -> void:
	body_entered.connect(_entered)
	if not on_player_entry:
		add_to_group("interact")
		collision_layer = 1
		add_child(object_prompts.new())

func _entered(body: Node3D) -> void:
	if on_player_entry and body is CharacterBody3D:
		trigger()

func trigger() -> bool:
	return Dialogue.play(sequence)

func interact() -> void:
	trigger()

func get_look_prompts() -> prompt_set:
	var prompts := prompt_set.new()
	var entry := prompt_entry.new()
	entry.text = prompt_text
	entry.action = &"confirm"
	prompts.entries.append(entry)
	return prompts
