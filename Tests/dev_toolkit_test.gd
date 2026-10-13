extends Node
## Resource-command and default-adapter coverage, independent of Remnant state.
var failures: Array[String] = []

class TestCommand extends DevConsoleCommand:
	func execute(arguments: Array[String], context: DevToolsContext) -> String:
		if arguments.size() != 1:
			return "Usage: " + usage
		var value := context.parse_name(arguments[0])
		context.adapter.set_blackboard("custom command", value)
		return "CUSTOM = " + value

class PrefixCommand extends DevConsoleCommand:
	func execute(_arguments: Array[String], _context: DevToolsContext) -> String:
		return "PREFIX"

func check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
		push_error(message)

func _ready() -> void:
	run.call_deferred()

func run() -> void:
	# Keep the host's existing save untouched when run inside Remnant.
	var save_service := get_node_or_null("/root/SaveGame")
	if save_service != null:
		save_service.set("enabled", false)
		save_service.set("saving_disabled", true)
	var context: DevToolsContext = load("res://addons/dev_toolkit/dev_tools.tscn").instantiate()
	context.adapter = DevToolsAdapter.new()
	add_child(context)
	await get_tree().process_frame
	check(context.tool("reporter") != null and context.tool("inspector") != null and context.tool("console") != null and context.tool("recorder") != null, "Portable scene registers every tool")
	var custom := TestCommand.new()
	custom.command = "tool value"
	custom.aliases = PackedStringArray(["tv"])
	custom.usage = 'tool value "text"'
	custom.description = "Test command supplied by an external resource script"
	var prefix := PrefixCommand.new()
	prefix.command = "tool"
	var catalog := DevCommandCatalog.new()
	catalog.commands = [prefix, custom]
	context.command_catalog = catalog
	check(context.execute('ToOl VaLuE "some text"') == "CUSTOM = some text", "Longest case-insensitive resource prefix executes its script")
	check(context.adapter.blackboard_snapshot().get("custom command") == "some text", "Custom command receives and updates the host adapter")
	check(context.execute('tv "alias text"') == "CUSTOM = alias text", "Resource alias dispatches with preserved quoted arguments")
	check(context.execute("tool anything") == "PREFIX", "Shorter prefix remains available")
	check(context.execute("tool value").contains("Usage:"), "Handler reports missing-argument usage")
	check(context.execute("unknown command").to_lower().contains("unknown"), "Unknown commands report an error")
	custom.enabled = false
	check(context.execute('tv "disabled"').to_lower().contains("unknown"), "Disabled command alias cannot execute")
	check(context.adapter.blackboard_snapshot().get("custom command") == "alias text", "Disabled commands leave adapter state unchanged")
	custom.enabled = true
	check(context.help_text().contains(custom.usage), "Help derives usage from catalog resources")
	check(context.tokenize('tool value "unfinished').is_empty(), "Unmatched quoted command is rejected")
	context.command_catalog = load("res://addons/dev_toolkit/default_commands.tres")
	context.execute('set bb "typed" [1, true, {"name": "prop"}]')
	context.execute('set flag "standalone flag" false')
	context.execute('set score 42')
	check(context.adapter.blackboard_snapshot().get("typed")[2].name == "prop", "Default typed Blackboard command needs no game singleton")
	check(context.adapter.flags_snapshot().get("standalone flag", true) == false, "False flags survive the generic adapter")
	check(context.adapter.blackboard_snapshot().get("score") == 42, "Default score setter writes the host adapter")
	context.execute("set score -1")
	check(context.adapter.blackboard_snapshot().get("score") == 42, "Invalid score leaves state unchanged")
	check(context.execute("tp 1 2 3").to_lower().contains("player"), "Player-dependent commands explain a missing player")
	var node := Node.new()
	node.name = "FriendlyNodeName"
	context.add_child(node)
	check(context.format_value(node) == "FriendlyNodeName", "Inspector formats a node as its name")
	context.adapter.set_blackboard("reference", node)
	var inspector: Node = context.tool("inspector")
	inspector.open_inspector(KEY_F2)
	check(inspector.content.text.contains("FriendlyNodeName") and inspector.content.text.contains("typed"), "Portable Blackboard inspector renders adapter values")
	inspector.open_inspector(KEY_F3)
	check(inspector.content.text.contains("standalone flag") and inspector.content.text.contains("false"), "Portable flag inspector includes false values")
	var disk_path := "res://.godot/dev_toolkit_inspection.json"
	var disk := FileAccess.open(disk_path, FileAccess.WRITE)
	disk.store_string('{"stored test": 81, "detail": "actual file"}')
	disk.close()
	context.adapter.save_path = disk_path
	context.adapter.save_format = 1
	var original := FileAccess.get_file_as_string(disk_path)
	inspector.open_inspector(KEY_F4)
	check(inspector.content.text.contains("stored test") and inspector.content.text.contains("actual file"), "Portable save inspector reads the configured JSON file")
	check(FileAccess.get_file_as_string(disk_path) == original, "Save inspection leaves the file unchanged")
	inspector.close_inspector()
	var variant_path := "res://.godot/dev_toolkit_inspection.variant"
	var variant_file := FileAccess.open(variant_path, FileAccess.WRITE)
	variant_file.store_var({"stored test": 82}, false)
	variant_file.close()
	context.adapter.save_path = variant_path
	context.adapter.save_format = 0
	var snapshot := context.adapter.save_snapshot()
	check(snapshot.get("error", "missing").is_empty() and snapshot.data["stored test"] == 82, "Generic adapter also reads Variant saves")
	var reporter: Node = context.tool("reporter")
	var image := Image.create(32, 32, false, Image.FORMAT_RGB8)
	image.fill(Color(.15, .3, .45))
	reporter.report_directory = "res://.godot/dev_toolkit_reports"
	reporter.open_report(image)
	inspector.open_inspector(KEY_F2)
	check(reporter.is_open and not inspector.is_open, "Portable reporter protects its draft from inspector shortcuts")
	var report_path: String = reporter.save_report("Portable toolkit test report", image)
	check(not report_path.is_empty() and FileAccess.file_exists(report_path), "Portable reporter writes local report metadata")
	if not report_path.is_empty():
		var report: Variant = JSON.parse_string(FileAccess.get_file_as_string(report_path))
		check(report is Dictionary and report.description == "Portable toolkit test report", "Report retains the supplied text")
		check(FileAccess.file_exists(report_path.get_base_dir().path_join("screenshot.png")), "Portable reporter writes its sibling screenshot")
	reporter.close_report()
	var previous_pause := get_tree().paused
	var console: Node = context.tool("console")
	console.open_console()
	check(get_tree().paused and context.any_modal_open(), "Portable console acquires pause ownership")
	console.close_console()
	check(get_tree().paused == previous_pause and not context.any_modal_open(), "Portable console restores pause ownership")
	var recorder: Node = context.tool("recorder")
	recorder.auto_download_ffmpeg = false
	recorder.ffmpeg_path = "res://missing_test_encoder.exe"
	check(recorder.find_ffmpeg().is_empty(), "Portable recorder rejects an explicit missing encoder")
	var recording_result: String = recorder.start_recording()
	check(not recorder.recording and (recording_result.contains("FFmpeg") or recording_result.contains("rendered")), "Missing recording dependency produces an explanation without starting capture")
	context.queue_free()
	await get_tree().process_frame
	print("Portable toolkit resource dispatch and adapter integration: ", "PASS" if failures.is_empty() else str(failures))
	get_tree().quit(0 if failures.is_empty() else 1)
