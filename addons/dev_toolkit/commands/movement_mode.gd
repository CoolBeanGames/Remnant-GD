extends "res://addons/dev_toolkit/command.gd"
## Multiple resources can share this script while choosing independent modes.
@export_enum("fly", "noclip") var mode: String = "fly"

func execute(arguments: Array[String], context: DevToolsContext) -> String:
	if arguments.size() > 1:
		return "Use " + usage
	var requested := arguments[0].to_lower() if not arguments.is_empty() else ""
	if not requested.is_empty() and requested not in ["on", "off", "true", "false", "1", "0"]:
		return "Use " + usage
	if context.adapter == null:
		return "Player adapter unavailable."
	return context.adapter.set_movement_mode(mode, requested)
