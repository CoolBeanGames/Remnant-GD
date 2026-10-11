extends "res://addons/dev_toolkit/command.gd"

func execute(arguments: Array[String], context: DevToolsContext) -> String:
	if arguments.size() != 1 or not arguments[0].is_valid_int() or int(arguments[0]) < 0:
		return "Score must be a nonnegative integer."
	if context.adapter == null:
		return "Blackboard adapter unavailable."
	var error := context.adapter.set_blackboard("score", int(arguments[0]))
	return "Score = " + arguments[0] if error.is_empty() else error
