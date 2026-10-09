class_name prompt_display
extends HBoxContainer

@export_category("Player")
@export var ray: raycaster
@export var pickup: player_pickup
@export var placement: prop_placement
@export var placement_prompts: prompt_set

@export_category("Presentation")
@export var label_scene: PackedScene
@export var carrying_prompts: prompt_set

var labels: Array[prompt_label] = []
var displayed_texts: Array[String] = []


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	refresh()


func _process(_delta: float) -> void:
	refresh()


func get_current_prompts() -> prompt_set:
	if pickup != null and pickup.is_holding_object():
		if placement != null and placement.is_building():
			return placement_prompts
		if pickup.held_object.has_method("get_carry_prompts"):
			return pickup.held_object.get_carry_prompts()
		return carrying_prompts
	if ray == null or not ray.is_looking_at_something():
		return null
	var provider: object_prompts = object_prompts.find_for(ray.get_looked_at())
	return provider.get_prompts() if provider != null else null


func refresh() -> void:
	var selected: prompt_set = get_current_prompts()
	var entries: Array[prompt_entry] = []
	var texts: Array[String] = []
	if selected != null:
		for entry in selected.entries:
			if entry != null:
				entries.append(entry)
				texts.append(entry.get_display_text())
	if pickup != null and pickup.is_holding_object() and pickup.held_object is rotatable_item:
		if placement != null and placement.is_building() and pickup.held_object.air_placeable:
			var air_prompt := prompt_entry.new()
			air_prompt.text = "Lock In Air"
			air_prompt.action = &"place_in_air"
			air_prompt.key_first = true
			entries.append(air_prompt)
			texts.append(air_prompt.get_display_text())
		var axis_prompt := prompt_entry.new()
		axis_prompt.text = "Axis: " + pickup.held_object.get_rotation_axis_name()
		axis_prompt.action = &"rotate_axis"
		axis_prompt.key_first = true
		entries.append(axis_prompt)
		texts.append(axis_prompt.get_display_text())
	if pickup != null and pickup.is_holding_object() and pickup.held_object is switchable_prop and (placement == null or not placement.is_building()):
		var toggle_prompt := prompt_entry.new()
		toggle_prompt.text = "Turn Off" if pickup.held_object.powered else "Turn On"
		toggle_prompt.action = &"confirm"
		entries.append(toggle_prompt)
		texts.append(toggle_prompt.get_display_text())
	if Blackboard.read_data("player_input_blocked"):
		entries.clear()
		texts.clear()
	if texts == displayed_texts:
		visible = not texts.is_empty()
		return
	displayed_texts = texts
	while labels.size() > entries.size():
		var label: prompt_label = labels.pop_back()
		remove_child(label)
		label.queue_free()
	while labels.size() < entries.size():
		if label_scene == null:
			push_warning("Prompt display needs a prompt_label scene.")
			return
		var instance: Node = label_scene.instantiate()
		if not instance is prompt_label:
			instance.free()
			push_warning("Prompt label scenes must use prompt_label.gd.")
			return
		var label: prompt_label = instance as prompt_label
		add_child(label)
		labels.append(label)
	for i in entries.size():
		labels[i].set_prompt(entries[i])
	visible = not entries.is_empty()
