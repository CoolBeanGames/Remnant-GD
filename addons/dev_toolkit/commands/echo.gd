extends "res://addons/dev_toolkit/command.gd"
## Minimal example: arbitrary trusted GDScript receives arguments and toolkit context.
func execute(arguments: Array[String], context: DevToolsContext) -> String:
	var words := PackedStringArray()
	for argument in arguments:
		words.append(context.parse_name(argument))
	return " ".join(words)
