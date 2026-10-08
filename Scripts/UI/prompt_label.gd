class_name prompt_label
extends Label


func set_prompt(entry: prompt_entry) -> void:
	text = entry.get_display_text()
