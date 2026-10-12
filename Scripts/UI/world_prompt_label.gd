class_name world_prompt_label
extends Label3D

## Edit Scenes/UI/world_prompt_label.tscn to style all in-world controls.
func set_prompt(entry: prompt_entry) -> void:
	text = entry.get_display_text() if entry != null else ""
