extends Node
var failures: Array[String] = []
var test_root: String
var context: DevToolsContext

class RefusingModal extends Node:
	var is_open: bool = true
	func close() -> void:
		pass

func check(value: bool, message: String) -> void:
	if not value:
		failures.append(message)
		push_error(message)

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	run.call_deferred()

func logger_at(path: String, engine_capture: bool = false) -> DevDebugLog:
	var logger := DevDebugLog.new()
	logger.log_directory = path
	logger.export_directory = test_root.path_join("exports")
	logger.capture_engine_messages = engine_capture
	logger.max_entries = 20
	logger.max_segment_bytes = 4096
	context.add_child(logger)
	return logger

func run() -> void:
	var save_service := get_node_or_null("/root/SaveGame")
	if save_service != null:
		save_service.set("enabled", false)
		save_service.set("saving_disabled", true)
	test_root = "res://.godot/debug_log_test_" + str(OS.get_process_id()) + "_" + str(Time.get_ticks_usec())
	context = DevToolsContext.new()
	context.adapter = DevToolsAdapter.new()
	add_child(context)
	var original_pause := get_tree().paused
	var original_mouse := Input.mouse_mode
	var logger := logger_at(test_root.path_join("logs"), true)
	check(context.tool(&"logger") == logger, "Logger registers with a generic context")
	context.log_info("Portable breadcrumb", "test")
	context.log_warning("Test warning", "test")
	context.log_error("Test error", "test")
	print("Expected debug-log print capture probe")
	push_warning("Expected debug-log warning capture probe")
	push_error("Expected debug-log error capture probe")
	var thread := Thread.new()
	thread.start(func() -> void:
		print("Expected debug-log worker capture probe")
		logger.sink.append("INFO", "worker", "Thread-safe breadcrumb")
	)
	thread.wait_to_finish()
	var entries := logger.get_entries()
	check(entries.any(func(entry: Dictionary) -> bool: return entry.message.contains("print capture probe") and entry.channel == "engine"), "Print output is captured by the native Logger API")
	check(entries.any(func(entry: Dictionary) -> bool: return entry.message.contains("warning capture probe") and entry.severity == "WARNING"), "Engine warnings preserve severity")
	check(entries.any(func(entry: Dictionary) -> bool: return entry.message.contains("error capture probe") and entry.severity == "ERROR"), "Engine errors are captured")
	check(entries.any(func(entry: Dictionary) -> bool: return entry.channel == "worker"), "Worker logging reaches the ring safely")
	check(FileAccess.get_file_as_string(logger.session_directory.path_join("current.jsonl")).contains("Thread-safe breadcrumb"), "Breadcrumb is flushed before any frame or shutdown")
	var f5 := InputEventKey.new()
	f5.pressed = true
	f5.keycode = KEY_F5
	logger._input(f5)
	check(logger.is_open and get_tree().paused and context.active_modal == &"logger", "F5 viewer owns the generic modal")
	check(context.adapter.blackboard_snapshot().get("player_input_blocked", false), "Viewer locks player input through the adapter")
	logger.channel_filter.text = "worker"
	logger.refresh_view()
	check(logger.content.text.contains("Thread-safe breadcrumb") and not logger.content.text.contains("Portable breadcrumb"), "Channel/text filter updates the scrollable view")
	logger.channel_filter.text = ""
	logger.severity_filter.selected = 2
	logger.refresh_view()
	check(logger.content.text.contains("WARNING") and not logger.content.text.contains(" / INFO / "), "Severity filter excludes unrelated levels")
	logger.severity_filter.selected = 0
	logger.close()
	check(get_tree().paused == original_pause and Input.mouse_mode == original_mouse and not context.any_modal_open(), "Closing restores previous pause, mouse and modal ownership")
	check(not context.adapter.blackboard_snapshot().has("player_input_blocked"), "Closing removes a previously absent input lock")
	var reporter: CanvasLayer = load("res://addons/dev_toolkit/issue_reporter.gd").new()
	context.add_child(reporter)
	var screenshot := Image.create(16, 16, false, Image.FORMAT_RGB8)
	reporter.open_report(screenshot)
	logger._input(f5)
	check(reporter.is_open and not logger.is_open and context.active_modal == &"reporter", "F5 cannot displace a draft report")
	reporter.close_report()
	reporter.free()
	get_tree().paused = true
	context.adapter.set_blackboard("player_input_blocked", "existing")
	logger.open_log()
	logger.close()
	check(get_tree().paused and context.adapter.blackboard_snapshot().get("player_input_blocked") == "existing", "Viewer opened over a pause preserves preexisting state")
	get_tree().paused = original_pause
	context.adapter.values.erase("player_input_blocked")
	var refusing := RefusingModal.new()
	context.add_child(refusing)
	context.register_tool(&"custom", refusing)
	context.enter_modal(&"custom")
	var original_snapshot := context.modal_snapshot.duplicate(true)
	check(not context.enter_modal(&"logger") and context.active_modal == &"custom" and context.modal_snapshot == original_snapshot, "Refusing modal cannot lose original restoration state")
	refusing.free()
	check(context.enter_modal(&"logger"), "A freed modal releases ownership before the next tool opens")
	context.leave_modal(&"logger")
	check(get_tree().paused == original_pause, "Freed modal cleanup restores the original pause")
	# Use a dedicated root without the Remnant autoload to exercise deferred fallback resolution.
	var existing_context := get_tree().root.get_node_or_null("DevTools")
	if existing_context != null:
		existing_context.name = "HostDevToolsForTest"
	var tool_a := Node.new()
	var tool_b := Node.new()
	add_child(tool_a)
	add_child(tool_b)
	var pending_a := DevToolsContext.resolve(tool_a)
	var pending_b := DevToolsContext.resolve(tool_b)
	# These children have a parent context only if resolve walks up to this test root; it does not.
	check(pending_a == pending_b, "Standalone tools share one pending context before deferred insertion")
	await get_tree().process_frame
	check(get_tree().root.get_node_or_null("DevTools") == pending_a, "Deferred fallback context is installed once")
	pending_a.free()
	if existing_context != null:
		existing_context.name = "DevTools"
	for i in range(65):
		logger.info("Bounded entry " + str(i) + " " + "x".repeat(160), "bounds")
	entries = logger.get_entries()
	check(entries.size() == 20 and entries[0].message.begins_with("Bounded entry 45 ") and entries[-1].message.begins_with("Bounded entry 64 "), "Circular ring retains only the newest configured entries")
	check(FileAccess.file_exists(logger.session_directory.path_join("current.1.jsonl")), "Persistent segments rotate at the configured byte bound")
	for entry in entries:
		check(entry.message.length() <= 16000, "Messages have a memory bound")
	var zip_path := logger.export_logs()
	check(not zip_path.is_empty() and FileAccess.file_exists(zip_path), "Export writes a shareable diagnostic ZIP")
	if not zip_path.is_empty():
		var zip := ZIPReader.new()
		check(zip.open(zip_path) == OK, "Export is a readable ZIP")
		var files := zip.get_files()
		check("system.json" in files and "visible_entries.json" in files and "current.jsonl" in files and "current_session.json" in files, "Export includes system info, ring and persistent log")
		check(not Array(files).any(func(name: String) -> bool: return name.contains("save") or name.contains("blackboard")), "Export omits save files and Blackboard snapshots")
		var system: Variant = JSON.parse_string(zip.read_file("system.json").get_string_from_utf8())
		check(system is Dictionary and system.session == logger.session_id, "Export metadata matches the running session")
		zip.close()
	check(context.execute("log export").begins_with("Exported logs: "), "Resource-based console command exports logs")
	check(context.execute("log open") == "Debug log opened." and logger.is_open, "Resource-based console command opens the viewer")
	logger.close()
	var blocked_path := test_root.path_join("not_a_directory")
	var blocker := FileAccess.open(blocked_path, FileAccess.WRITE)
	blocker.store_string("blocked")
	blocker.close()
	check(logger.export_logs(blocked_path).is_empty() and not logger.last_export_error.is_empty(), "Export failures return a useful error and allow retry")
	check(not logger.export_logs().is_empty(), "Export can be retried after a path failure")
	if DisplayServer.get_name() != "headless":
		logger.channel_filter.text = ""
		logger.open_log()
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var rendered_image := get_viewport().get_texture().get_image()
		check(rendered_image != null and rendered_image.save_png(test_root.path_join("viewer.png")) == OK, "Rendered viewer screenshot is captured")
		logger.close()
	logger.shutdown(false)
	var first_session_directory := logger.session_directory
	logger.free()
	# Simulate an inactive prior process without actually crashing the test runner.
	var marker_path := first_session_directory.path_join("session.json")
	var marker: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(marker_path))
	marker.process_id = -1
	var marker_file := FileAccess.open(marker_path, FileAccess.WRITE)
	marker_file.store_string(JSON.stringify(marker))
	marker_file.close()
	var restored := logger_at(test_root.path_join("logs"))
	check(restored.previous_unclean and restored.previous_directory == first_session_directory, "Startup identifies an interrupted inactive session and preserves its logs")
	var live := logger_at(test_root.path_join("logs"))
	check(live.previous_directory != restored.session_directory, "Concurrent active sessions are not classified as crashes")
	live.shutdown()
	live.free()
	var recovered_zip := restored.export_logs()
	var recovered := ZIPReader.new()
	if recovered.open(recovered_zip) == OK:
		check("previous.jsonl" in recovered.get_files() and "previous_session.json" in recovered.get_files(), "Restart export includes the prior interrupted session")
		recovered.close()
	else:
		check(false, "Restart export is readable")
	restored.shutdown()
	check(JSON.parse_string(FileAccess.get_file_as_string(restored.session_directory.path_join("session.json"))).clean_exit, "Normal shutdown writes a clean session marker")
	restored.free()
	context.free()
	get_tree().paused = original_pause
	Input.mouse_mode = original_mouse
	print("Debug log capture, bounds, export, interrupted session and modal ownership: ", "PASS" if failures.is_empty() else failures)
	get_tree().quit(0 if failures.is_empty() else 1)
