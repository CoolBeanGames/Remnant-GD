class_name mulch_pellet
extends RigidBody3D
@export var coin_value: int = 1
func _ready() -> void:
	WorldState.track(self)
func get_look_prompts() -> prompt_set:
	var result := prompt_set.new()
	var entry := prompt_entry.new()
	entry.text = "Pickup Mulch Pellet"
	entry.action = &"pickup"
	result.entries.append(entry)
	return result
