extends "res://addons/dev_toolkit/command.gd"

func execute(arguments: Array[String], context: DevToolsContext) -> String:
	if arguments.size() not in [1, 2]:
		return "Use " + usage
	var key := context.parse_name(arguments[0])
	if key.is_empty():
		return "Flag name cannot be empty."
	var state := true
	if arguments.size() == 2:
		var requested := arguments[1].to_lower()
		if requested not in ["true", "false", "on", "off", "1", "0"]:
			return "Flag state must be true or false."
		state = requested in ["true", "on", "1"]
	if context.adapter == null:
		return "Flags adapter unavailable."
	var error := context.adapter.set_flag(key, state)
	return key + " = " + str(state) if error.is_empty() else error
