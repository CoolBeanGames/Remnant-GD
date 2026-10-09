class_name switchable_prop
extends rotatable_item

@export var powered: bool = true
@export var toggle_name: String = "Prop"
signal power_changed(value: bool)

func _ready() -> void:
	super._ready()
	add_to_group("interact")
	set_powered(powered)

func interact() -> void:
	set_powered(not powered)
	WorldState.capture()

func set_powered(value: bool) -> void:
	powered = value
	_apply_power()
	power_changed.emit(value)

func _apply_power() -> void:
	pass

func get_look_prompts() -> prompt_set:
	var result := prompt_set.new()
	var provider: Node = get_node_or_null("Prompts")
	if provider != null and provider.prompts != null:
		result.entries.assign(provider.prompts.entries)
	var entry := prompt_entry.new()
	entry.text = ("Turn Off " if powered else "Turn On ") + toggle_name
	entry.action = &"confirm"
	result.entries.append(entry)
	return result
