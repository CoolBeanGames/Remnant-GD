extends "res://addons/dev_toolkit/command.gd"

func execute(arguments: Array[String], context: DevToolsContext) -> String:
	if arguments.size() < 2:
		return "Use " + usage
	var key := context.parse_name(arguments[0])
	if key.is_empty():
		return "Blackboard key cannot be empty."
	var raw := " ".join(arguments.slice(1))
	var json := JSON.new()
	var value: Variant = raw
	if json.parse(raw) == OK:
		value = json.data
	if context.modal_lock_value(key, value):
		return key + " = " + context.format_value(value)
	if context.adapter == null:
		return "Blackboard adapter unavailable."
	var error := context.adapter.set_blackboard(key, value)
	return key + " = " + context.format_value(value) if error.is_empty() else error
