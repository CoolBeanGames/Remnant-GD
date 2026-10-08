class_name prompt_entry
extends Resource

@export var text: String = ""
@export var action: StringName = &""
@export var key_first: bool = false
## Optional display override; empty uses the action's current InputMap binding.
@export var key_override: String = ""


func get_display_text() -> String:
	var key: String = key_override
	if key.is_empty():
		key = _get_action_key()
	if key.is_empty():
		return text
	return "[%s] %s" % [key, text] if key_first else "%s [%s]" % [text, key]


func _get_action_key() -> String:
	if action == &"" or not InputMap.has_action(action):
		return ""
	for event in InputMap.action_get_events(action):
		if event is InputEventKey:
			var keycode: int = event.physical_keycode if event.physical_keycode != 0 else event.keycode
			return OS.get_keycode_string(keycode)
		if event is InputEventMouseButton:
			match event.button_index:
				MOUSE_BUTTON_LEFT: return "LMB"
				MOUSE_BUTTON_RIGHT: return "RMB"
				MOUSE_BUTTON_MIDDLE: return "MMB"
			return "Mouse %s" % event.button_index
	return ""
