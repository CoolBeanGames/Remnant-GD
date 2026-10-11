class_name DevDebugLog
extends CanvasLayer
## F5 log viewer, durable session breadcrumbs and a shareable diagnostic ZIP.
signal logs_exported(path: String)
@export var tools_context: NodePath
@export var toggle_key: Key = KEY_F5
@export var enabled: bool = true
@export var capture_engine_messages: bool = true
@export_dir var log_directory: String = "user://debug_logs"
@export_dir var export_directory: String = "user://debug_logs/exports"
@export_range(20, 10000, 1) var max_entries: int = 2000
@export_range(4096, 8388608, 4096) var max_segment_bytes: int = 2097152
@export_range(1, 8, 1) var archive_segments: int = 2
@export_range(2, 20, 1) var retained_sessions: int = 8
var context: DevToolsContext
var is_open: bool = false
var sink: DevLogSink
var session_id: String = ""
var previous_session: Dictionary = {}
var previous_unclean: bool = false
var session_directory: String = ""
var previous_directory: String = ""
var last_export_error: String = ""
var content: TextEdit
var status: Label
var severity_filter: OptionButton
var channel_filter: LineEdit
var follow_tail: CheckButton
var _registered: bool = false
var _closed: bool = false
var _last_sequence: int = -1
var _refresh_elapsed: float = 0.0
var _started_at: String = ""
var _operation_status: String = ""

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 95
	context = DevToolsContext.resolve(self, tools_context)
	context.register_tool(&"logger", self)
	_build_ui()
	_start_session()
	hide()
	set_process(false)

func _start_session() -> void:
	_started_at = Time.get_datetime_string_from_system()
	session_id = _started_at.replace(":", "-") + "-" + str(OS.get_process_id()) + "-" + str(Time.get_ticks_usec())
	var root_directory := log_directory.path_join("sessions")
	session_directory = root_directory.path_join(session_id)
	var directory_error := DirAccess.make_dir_recursive_absolute(session_directory)
	var inactive_sessions := _inactive_sessions(root_directory)
	# Prefer an unexported interrupted session over a newer clean one, until it is exported.
	for entry in inactive_sessions:
		if previous_directory.is_empty():
			previous_session = entry.marker
			previous_directory = entry.directory
		if not bool(entry.marker.get("clean_exit", false)) and not bool(entry.marker.get("diagnostics_exported", false)):
			previous_session = entry.marker
			previous_directory = entry.directory
			break
	previous_unclean = not previous_session.is_empty() and not bool(previous_session.get("clean_exit", false))
	_prune_sessions(inactive_sessions)
	_write_marker(false)
	sink = DevLogSink.new()
	sink.configure(session_directory.path_join("current.jsonl"), session_id, max_entries, max_segment_bytes, archive_segments)
	if capture_engine_messages:
		OS.add_logger(sink)
		_registered = true
	info("Session started: " + str(ProjectSettings.get_setting("application/config/name", "Godot Project")) + " / Godot " + str(Engine.get_version_info().get("string", "")), "session")
	if directory_error != OK:
		warning("Persistent log directory unavailable: " + error_string(directory_error), "session")
	if previous_unclean:
		warning("Previous session did not record a clean exit. Its logs are available in EXPORT LOGS.", "session")

func _inactive_sessions(root_directory: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var directory := DirAccess.open(root_directory)
	if directory == null:
		return result
	var names := directory.get_directories()
	names.sort()
	names.reverse()
	for folder in names:
		var path := root_directory.path_join(folder)
		if path == session_directory:
			continue
		var marker_path := path.path_join("session.json")
		if not FileAccess.file_exists(marker_path):
			continue
		var marker: Variant = JSON.parse_string(FileAccess.get_file_as_string(marker_path))
		if not marker is Dictionary or not marker.has("id"):
			continue
		var pid := int(marker.get("process_id", -1))
		if not bool(marker.get("clean_exit", false)) and pid > 0 and OS.is_process_running(pid):
			continue
		result.append({"directory": path, "marker": marker})
	return result

func _prune_sessions(sessions: Array[Dictionary]) -> void:
	for i in range(maxi(retained_sessions - 1, 0), sessions.size()):
		var path: String = sessions[i].directory
		if path == previous_directory:
			continue
		# Delete only toolkit-owned names; unexpected files are retained.
		for segment in range(9):
			var filename := "current.jsonl" if segment == 0 else "current." + str(segment) + ".jsonl"
			if FileAccess.file_exists(path.path_join(filename)):
				DirAccess.remove_absolute(path.path_join(filename))
		DirAccess.remove_absolute(path.path_join("session.json"))
		DirAccess.remove_absolute(path)

func info(message: String, channel: String = "game") -> void:
	if sink != null:
		sink.append("INFO", channel, message)
func warning(message: String, channel: String = "game") -> void:
	if sink != null:
		sink.append("WARNING", channel, message)
func error(message: String, channel: String = "game") -> void:
	if sink != null:
		sink.append("ERROR", channel, message)
func get_entries() -> Array[Dictionary]:
	return sink.snapshot() if sink != null else []

func _build_ui() -> void:
	var screen := ColorRect.new()
	screen.color = Color(0.025, 0.025, 0.025, .97)
	screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(screen)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 24)
	screen.add_child(margin)
	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation", 10)
	margin.add_child(rows)
	var title := Label.new()
	title.text = "DEBUG LOG / " + OS.get_keycode_string(toggle_key)
	title.add_theme_font_size_override("font_size", 25)
	rows.add_child(title)
	var hint := Label.new()
	hint.text = "LIVE EVENTS + ENGINE MESSAGES / ESC CLOSE / LOGS ARE SAVED AS THEY HAPPEN"
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	rows.add_child(hint)
	var filters := HBoxContainer.new()
	rows.add_child(filters)
	severity_filter = OptionButton.new()
	for severity in ["ALL LEVELS", "INFO", "WARNING", "ERROR"]:
		severity_filter.add_item(severity)
	severity_filter.item_selected.connect(func(_index: int) -> void: refresh_view())
	filters.add_child(severity_filter)
	channel_filter = LineEdit.new()
	channel_filter.placeholder_text = "FILTER CHANNEL OR TEXT"
	channel_filter.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	channel_filter.text_changed.connect(func(_text: String) -> void: refresh_view())
	filters.add_child(channel_filter)
	follow_tail = CheckButton.new()
	follow_tail.text = "FOLLOW"
	follow_tail.button_pressed = true
	filters.add_child(follow_tail)
	content = TextEdit.new()
	content.editable = false
	content.add_theme_color_override("font_readonly_color", Color(.88, .88, .88))
	content.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	rows.add_child(content)
	status = Label.new()
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	rows.add_child(status)
	var buttons := HBoxContainer.new()
	rows.add_child(buttons)
	var export_button := Button.new()
	export_button.text = "EXPORT LOGS"
	export_button.pressed.connect(_export_pressed)
	buttons.add_child(export_button)
	var folder_button := Button.new()
	folder_button.text = "OPEN EXPORT FOLDER"
	folder_button.pressed.connect(_open_export_folder)
	buttons.add_child(folder_button)
	var close_button := Button.new()
	close_button.text = "CLOSE [ESC]"
	close_button.pressed.connect(close)
	buttons.add_child(close_button)

func _input(event: InputEvent) -> void:
	if not enabled or not event is InputEventKey or not event.pressed or event.echo or context.tool_open(&"reporter"):
		return
	var key: int = event.keycode if event.keycode != 0 else event.physical_keycode
	if key == toggle_key:
		get_viewport().set_input_as_handled()
		if is_open:
			close()
		else:
			open_log()
	elif is_open and key == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		close()

func open_log() -> void:
	if is_open or not context.enter_modal(&"logger"):
		return
	is_open = true
	show()
	set_process(true)
	refresh_view()
	channel_filter.grab_focus()
func close() -> void:
	if not is_open:
		return
	is_open = false
	hide()
	set_process(false)
	context.leave_modal(&"logger")
func _process(delta: float) -> void:
	if not is_open or sink == null:
		return
	_refresh_elapsed += delta
	if _refresh_elapsed >= .2:
		_refresh_elapsed = 0
		if sink.sequence() != _last_sequence:
			refresh_view()
func refresh_view() -> void:
	if sink == null:
		return
	# Capture the revision before reading; worker messages arriving during rendering
	# must still cause the next refresh instead of being marked as already displayed.
	_last_sequence = sink.sequence()
	var filter_text := channel_filter.text.strip_edges().to_lower()
	var severity := "" if severity_filter.selected == 0 else severity_filter.get_item_text(severity_filter.selected)
	var lines: PackedStringArray = []
	var entries := get_entries()
	for entry in entries:
		if not severity.is_empty() and entry.severity != severity:
			continue
		if not filter_text.is_empty() and not (str(entry.channel) + " " + str(entry.message)).to_lower().contains(filter_text):
			continue
		var line := "[" + str(entry.time).get_slice("T", 1) + "] " + str(entry.severity) + " / " + str(entry.channel) + " / " + str(entry.message)
		if entry.has("details"):
			var details: Dictionary = entry.details
			line += "\n  " + str(details.get("file", "")) + ":" + str(details.get("line", "")) + " " + str(details.get("function", ""))
		lines.append(line)
	var old_scroll := content.scroll_vertical
	content.text = "\n".join(lines)
	if follow_tail.button_pressed:
		content.set_caret_line(maxi(content.get_line_count() - 1, 0))
		content.set_caret_column(content.get_line(content.get_caret_line()).length())
	else:
		content.scroll_vertical = old_scroll
	status.text = str(lines.size()) + " SHOWN / " + str(entries.size()) + " IN MEMORY / " + ProjectSettings.globalize_path(log_directory)
	if previous_unclean:
		status.text += " / PREVIOUS SESSION EXITED UNEXPECTEDLY"
	if not sink.storage_error().is_empty():
		status.text += " / " + sink.storage_error()
	if not _operation_status.is_empty():
		status.text += "\n" + _operation_status

func export_logs(destination_directory: String = "") -> String:
	last_export_error = ""
	var target_directory := export_directory if destination_directory.is_empty() else destination_directory
	var mkdir_error := DirAccess.make_dir_recursive_absolute(target_directory)
	if mkdir_error != OK:
		last_export_error = "Cannot create export folder: " + error_string(mkdir_error)
		return ""
	info("Diagnostic log export requested.", "debug")
	if sink != null:
		sink.flush()
	var path := target_directory.path_join("debug-" + session_id + "-" + str(Time.get_ticks_usec()) + ".zip")
	var writer := ZIPPacker.new()
	var open_error := writer.open(path)
	if open_error != OK:
		last_export_error = "Cannot open export ZIP: " + error_string(open_error)
		return ""
	var pack_error := _pack_bytes(writer, "system.json", JSON.stringify(_system_info(), "\t").to_utf8_buffer())
	if pack_error == OK:
		pack_error = _pack_bytes(writer, "visible_entries.json", JSON.stringify(get_entries(), "\t").to_utf8_buffer())
	var included: PackedStringArray = []
	var sources: Dictionary = {}
	for prefix in ["current", "previous"]:
		var source_directory := session_directory if prefix == "current" else previous_directory
		if source_directory.is_empty():
			continue
		for i in range(archive_segments + 1):
			var filename: String = prefix + (".jsonl" if i == 0 else "." + str(i) + ".jsonl")
			sources[filename] = source_directory.path_join("current" + (".jsonl" if i == 0 else "." + str(i) + ".jsonl"))
		sources[prefix + "_session.json"] = source_directory.path_join("session.json")
	var engine_path := str(ProjectSettings.get_setting("debug/file_logging/log_path", "user://logs/godot.log"))
	if bool(ProjectSettings.get_setting("debug/file_logging/enable_file_logging", true)):
		sources["engine/godot.log"] = engine_path
		var directory := DirAccess.open(engine_path.get_base_dir())
		if directory != null:
			var old_logs: PackedStringArray = []
			for filename in directory.get_files():
				if filename.begins_with(engine_path.get_file().get_basename()) and filename != engine_path.get_file() and filename.ends_with(".log"):
					old_logs.append(filename)
			old_logs.sort()
			old_logs.reverse()
			for i in mini(old_logs.size(), 2):
				sources["engine/" + old_logs[i]] = engine_path.get_base_dir().path_join(old_logs[i])
	for filename: String in sources:
		if pack_error != OK:
			break
		var source := FileAccess.open(sources[filename], FileAccess.READ) if FileAccess.file_exists(sources[filename]) else null
		if source == null:
			continue
		# Keep even unusually large host engine logs bounded. Retain their most recent bytes.
		var read_size := mini(source.get_length(), 8388608)
		source.seek(source.get_length() - read_size)
		pack_error = _pack_bytes(writer, filename, source.get_buffer(read_size))
		source.close()
		included.append(filename)
	if pack_error == OK:
		pack_error = _pack_bytes(writer, "README.txt", ("Diagnostic logs from " + str(ProjectSettings.get_setting("application/config/name", "Godot Project")) + ".\nCurrent and previous session breadcrumbs, engine output, and system information.\nA missing clean_exit can indicate a crash, forced termination, or interrupted shutdown; it is not a diagnosis.\nLogs flush as events occur. An abrupt crash cannot run the export command; restart and export to include the previous session.\nNo save-file or Blackboard snapshot is included. Engine messages can contain file paths or text printed by game scripts; review before sharing.\nIncluded log files: " + ", ".join(included) + "\n").to_utf8_buffer())
	var close_error := writer.close()
	if pack_error != OK or close_error != OK:
		last_export_error = "Log export failed: " + error_string(pack_error if pack_error != OK else close_error)
		DirAccess.remove_absolute(path)
		error(last_export_error, "debug")
		return ""
	var absolute_path := ProjectSettings.globalize_path(path)
	if not previous_directory.is_empty():
		previous_session["diagnostics_exported"] = true
		_write_json(previous_directory.path_join("session.json"), previous_session)
	info("Diagnostic logs exported: " + absolute_path, "debug")
	logs_exported.emit(absolute_path)
	return absolute_path

func _pack_bytes(writer: ZIPPacker, name: String, data: PackedByteArray) -> Error:
	var result := writer.start_file(name)
	if result == OK:
		result = writer.write_file(data)
		var finish_error := writer.close_file()
		if result == OK:
			result = finish_error
	return result
func _system_info() -> Dictionary:
	var scene := get_tree().current_scene
	return {"application": ProjectSettings.get_setting("application/config/name", ""), "session": session_id, "previous_unclean_exit": previous_unclean, "previous_session": previous_session, "exported_at": Time.get_datetime_string_from_system(), "engine": Engine.get_version_info(), "os": OS.get_name(), "os_version": OS.get_version(), "processor": OS.get_processor_name(), "processors": OS.get_processor_count(), "renderer": RenderingServer.get_current_rendering_method(), "rendering_driver": RenderingServer.get_current_rendering_driver_name(), "video_adapter": RenderingServer.get_video_adapter_name(), "scene": scene.scene_file_path if scene != null else "", "fps": Engine.get_frames_per_second(), "nodes": Performance.get_monitor(Performance.OBJECT_NODE_COUNT), "log_storage_error": sink.storage_error() if sink != null else "not initialized"}
func _write_json(path: String, data: Dictionary) -> bool:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(data, "\t"))
	file.flush()
	var success := file.get_error() == OK
	file.close()
	return success
func _write_marker(clean: bool) -> void:
	_write_json(session_directory.path_join("session.json"), {"id": session_id, "process_id": OS.get_process_id(), "started_at": _started_at, "updated_at": Time.get_datetime_string_from_system(), "clean_exit": clean})
func _export_pressed() -> void:
	var path := export_logs()
	_operation_status = "EXPORTED: " + path if not path.is_empty() else last_export_error
	refresh_view()
func _open_export_folder() -> void:
	_operation_status = open_export_folder()
	refresh_view()
func open_export_folder() -> String:
	var result := DirAccess.make_dir_recursive_absolute(export_directory)
	if result == OK:
		result = OS.shell_open(ProjectSettings.globalize_path(export_directory))
	return ProjectSettings.globalize_path(export_directory) if result == OK else "Cannot open export folder: " + error_string(result)
func shutdown(mark_clean: bool = true) -> void:
	if _closed:
		return
	_closed = true
	close()
	if sink != null:
		if mark_clean:
			info("Session ended normally.", "session")
		if _registered:
			OS.remove_logger(sink)
			_registered = false
		sink.close_file()
	_write_marker(mark_clean)
func _exit_tree() -> void:
	shutdown()
