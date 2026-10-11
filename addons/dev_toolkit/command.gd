class_name DevConsoleCommand
extends Resource
## An editable command definition. Attach a script extending this class to add code.
@export var command: String = ""
@export var aliases: PackedStringArray = []
@export var usage: String = ""
@export_multiline var description: String = ""
@export var enabled: bool = true

## Arguments retain their quotes so handlers can distinguish JSON strings/numbers.
## The console matches the prefix before calling this trusted project script.
func execute(_arguments: Array[String], _context: DevToolsContext) -> String:
	return "Command has no execution script: " + command
