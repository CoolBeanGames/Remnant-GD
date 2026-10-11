extends CanvasLayer
## Local development inbox. Capture the game before displaying the modal.
signal issue_saved(path: String)

@export var tools_context: NodePath
@export var toggle_key: Key = KEY_F1
@export var enabled: bool = true
var context: DevToolsContext
@export var report_directory: String = "res://.issues/inbox"
var is_open: bool = false
var screenshot: Image
var previous_pause: bool
var previous_mouse: Input.MouseMode
var previous_block: Variant
var had_block: bool
var screen: ColorRect
var description: TextEdit
var status: Label
var submit: Button

func _ready() -> void:
	context = DevToolsContext.resolve(self, tools_context)
	context.register_tool(&"reporter", self)
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 100
	_build_ui()
	hide()

func _input(event: InputEvent) -> void:
	if not enabled or not event is InputEventKey or not event.pressed or event.echo:
		return
	if event.keycode == toggle_key or event.physical_keycode == toggle_key:
		get_viewport().set_input_as_handled()
		if not is_open:
			open_report()
	elif is_open and (event.keycode == KEY_ESCAPE or event.physical_keycode == KEY_ESCAPE):
		get_viewport().set_input_as_handled()
		close_report()

func _build_ui() -> void:
	screen = ColorRect.new()
	screen.color = Color(0, 0, 0, .85)
	screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(screen)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	screen.add_child(center)
	var panel := PanelContainer.new()
	center.add_child(panel)
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 24)
	panel.add_child(margin)
	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation", 12)
	margin.add_child(rows)
	var title := Label.new()
	title.text = "WHAT'S WRONG?"
	title.add_theme_font_size_override("font_size", 28)
	rows.add_child(title)
	var hint := Label.new()
	hint.text = "Describe the issue or change you want. The game screenshot is included."
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	rows.add_child(hint)
	description = TextEdit.new()
	description.placeholder_text = "What happened? What should happen instead?"
	description.custom_minimum_size = Vector2(520, 220)
	rows.add_child(description)
	status = Label.new()
	status.custom_minimum_size.x = 520
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	rows.add_child(status)
	var buttons := HBoxContainer.new()
	rows.add_child(buttons)
	submit = Button.new()
	submit.text = "SAVE REPORT"
	submit.pressed.connect(_submit)
	buttons.add_child(submit)
	var cancel := Button.new()
	cancel.text = "CLOSE [ESC]"
	cancel.pressed.connect(close_report)
	buttons.add_child(cancel)

func open_report(captured_image: Image = null) -> void:
	if is_open or not context.enter_modal(&"reporter"):
		return
	screenshot = captured_image
	if screenshot == null and DisplayServer.get_name() != "headless":
		screenshot = get_viewport().get_texture().get_image()
	is_open = true
	description.text = ""
	description.editable = true
	submit.disabled = false
	status.text = "Screenshot captured. Choose SAVE REPORT to add it to the local inbox."
	if screenshot == null or screenshot.is_empty():
		status.text = "Screenshot unavailable. Try again in the running game."
	show()
	description.grab_focus()
func close_report() -> void:
	if not is_open:
		return
	hide()
	is_open = false
	context.leave_modal(&"reporter")
	screenshot = null
func _exit_tree() -> void:
	close_report()

func _submit() -> void:
	if description.text.strip_edges().is_empty():
		status.text = "Please describe what's wrong first."
		return
	if screenshot == null or screenshot.is_empty():
		status.text = "No screenshot captured. Close and reopen the reporter in the game."
		return
	var path := save_report(description.text, screenshot)
	if path.is_empty():
		return
	status.text = "SAVED. The next coding session will review: " + path
	submit.disabled = true
	description.editable = false
	issue_saved.emit(path)

func save_report(text: String, image: Image) -> String:
	if text.strip_edges().is_empty() or image == null or image.is_empty():
		return ""
	var directory := report_directory
	# Exported PCKs are read-only: retain a usable local inbox in user data.
	if directory.begins_with("res://") and not OS.has_feature("editor"):
		directory = "user://issue_reports/inbox"
	var root := ProjectSettings.globalize_path(directory)
	var ancestor := root
	while not DirAccess.dir_exists_absolute(ancestor):
		if FileAccess.file_exists(ancestor):
			status.text = "Report directory is blocked by a file: " + ancestor
			return ""
		var parent := ancestor.get_base_dir()
		if parent == ancestor or parent.is_empty():
			break
		ancestor = parent
	if DirAccess.make_dir_recursive_absolute(root) != OK:
		status.text = "Cannot create report directory: " + root
		return ""
	var id := Time.get_datetime_string_from_system().replace(":", "-") + "-" + str(Time.get_ticks_usec())
	var folder := root.path_join(id)
	if DirAccess.make_dir_recursive_absolute(folder) != OK:
		status.text = "Cannot create report folder."
		return ""
	var png_path := folder.path_join("screenshot.png")
	if image.save_png(png_path) != OK:
		status.text = "Could not save screenshot. Your text is still here; retry."
		return ""
	var scene := get_tree().current_scene
	var report := {
		"version": 1, "id": id, "status": "pending",
		"created_at": Time.get_datetime_string_from_system(),
		"timezone": Time.get_time_zone_from_system(),
		"description": text.strip_edges(), "screenshot": "screenshot.png",
		"scene": scene.scene_file_path if is_instance_valid(scene) else "",
		"engine": Engine.get_version_info().get("string", "")
	}
	report["context"] = context.adapter.report_context()
	var temp := folder.path_join("report.json.tmp")
	var file := FileAccess.open(temp, FileAccess.WRITE)
	if file == null:
		status.text = "Could not write report. Your text is still here; retry."
		return ""
	file.store_string(JSON.stringify(report, "\t"))
	file.flush()
	var error := file.get_error()
	file.close()
	if error != OK or DirAccess.rename_absolute(temp, folder.path_join("report.json")) != OK:
		status.text = "Report write failed. Your text is still here; retry."
		return ""
	return folder.path_join("report.json")
