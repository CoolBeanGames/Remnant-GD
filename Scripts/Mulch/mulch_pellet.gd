class_name mulch_pellet
extends RigidBody3D
@export var coin_value: int = 1
## Half of the input score assigned to this pellet; banking or grinding consumes it.
@export var stored_score: float = 0.0
var look_prompts: prompt_set
func _ready() -> void:
	WorldState.track(self)

func can_grind() -> bool:
	return not get_meta("banked", false) and not get_meta("carried_by_player", false)
func get_look_prompts() -> prompt_set:
	if look_prompts == null:
		look_prompts = prompt_set.new()
		var entry := prompt_entry.new()
		entry.text = "Pickup Mulch Pellet"
		entry.action = &"pickup"
		look_prompts.entries.append(entry)
	return look_prompts
