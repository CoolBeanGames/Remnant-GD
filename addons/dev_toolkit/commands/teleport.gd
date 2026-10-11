extends "res://addons/dev_toolkit/command.gd"

func execute(arguments: Array[String], context: DevToolsContext) -> String:
	if arguments.size() != 3:
		return "TP requires three finite coordinates."
	for token in arguments:
		if not token.is_valid_float() or not is_finite(float(token)):
			return "TP requires three finite coordinates."
	if context.adapter == null:
		return "Player adapter unavailable."
	var destination := Vector3(float(arguments[0]), float(arguments[1]), float(arguments[2]))
	var error := context.adapter.teleport(destination)
	return "Teleported to " + str(destination) if error.is_empty() else error
