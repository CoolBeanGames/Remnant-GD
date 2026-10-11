extends "res://addons/dev_toolkit/command.gd"

func execute(arguments: Array[String], context: DevToolsContext) -> String:
	if arguments.size() > 1:
		return "Use " + usage
	var logger := context.tool(&"logger")
	if logger == null:
		return "Debug logger unavailable."
	match "open" if arguments.is_empty() else arguments[0].to_lower():
		"open":
			logger.open_log()
			return "Debug log opened." if logger.is_open else "Debug log cannot replace the current menu."
		"export":
			var path: String = logger.export_logs()
			return "Exported logs: " + path if not path.is_empty() else logger.last_export_error
		"folder":
			return logger.open_export_folder()
	return "Use " + usage
