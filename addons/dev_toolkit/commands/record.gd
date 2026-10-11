extends "res://addons/dev_toolkit/command.gd"

func execute(arguments: Array[String], context: DevToolsContext) -> String:
	if arguments.size() != 1:
		return "Use " + usage
	var recorder := context.tool(&"recorder")
	if recorder == null:
		return "Gameplay recorder unavailable."
	match arguments[0].to_lower():
		"start":
			return recorder.start_recording()
		"stop":
			return recorder.stop_recording()
		"status":
			return recorder.status_text()
		"folder":
			if recorder.has_method("open_output_folder"):
				return recorder.open_output_folder()
			var directory: String = recorder.get("folder")
			if directory.is_empty():
				directory = ProjectSettings.globalize_path(str(recorder.get("output_directory")))
			var error := OS.shell_open(directory)
			return directory if error == OK else "Cannot open recording folder: " + error_string(error)
	return "Use " + usage
