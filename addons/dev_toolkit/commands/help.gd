extends "res://addons/dev_toolkit/command.gd"

func execute(arguments: Array[String], context: DevToolsContext) -> String:
	if not arguments.is_empty():
		return "Use " + usage
	return context.help_text()
