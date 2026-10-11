extends CanvasLayer
## Read-only snapshots of runtime state and the actual disk save.
@export var tools_context: NodePath
@export var enabled: bool = true
@export var blackboard_key: Key = KEY_F2
@export var flags_key: Key = KEY_F3
@export var save_key: Key = KEY_F4
var context: DevToolsContext
var is_open: bool = false
var mode: int = KEY_F2
var previous_pause: bool
var previous_mouse: Input.MouseMode
var previous_block: Variant
var had_block: bool
var heading: Label
var content: TextEdit

func _ready() -> void:
	context = DevToolsContext.resolve(self, tools_context)
	context.register_tool(&"inspector", self)
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 90
	var screen := ColorRect.new()
	screen.color = Color(0, 0, 0, .94)
	screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(screen)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 28)
	screen.add_child(margin)
	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation", 12)
	margin.add_child(rows)
	heading = Label.new()
	heading.add_theme_font_size_override("font_size", 24)
	rows.add_child(heading)
	var hint := Label.new()
	hint.text = OS.get_keycode_string(blackboard_key) + " BLACKBOARD / " + OS.get_keycode_string(flags_key) + " FLAGS / " + OS.get_keycode_string(save_key) + " SAVE FILE / ESC CLOSE"
	rows.add_child(hint)
	content = TextEdit.new()
	content.editable = false
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	rows.add_child(content)
	var buttons := HBoxContainer.new()
	rows.add_child(buttons)
	var refresh := Button.new()
	refresh.text = "REFRESH"
	refresh.pressed.connect(refresh_view)
	buttons.add_child(refresh)
	var close := Button.new()
	close.text = "CLOSE [ESC]"
	close.pressed.connect(close_inspector)
	buttons.add_child(close)
	hide()

func _input(event: InputEvent) -> void:
	if not enabled or context.tool_open(&"reporter") or not event is InputEventKey or not event.pressed or event.echo:
		return
	var key: int = event.keycode if event.keycode != 0 else event.physical_keycode
	if key in [blackboard_key, flags_key, save_key]:
		get_viewport().set_input_as_handled()
		if is_open and mode == key:
			close_inspector()
		else:
			open_inspector(key)
	elif is_open and key == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		close_inspector()

func open_inspector(key: int) -> void:
	if not context.enter_modal(&"inspector"):
		return
	is_open = true
	mode = key
	refresh_view()
	show()
	content.grab_focus()
func close_inspector() -> void:
	if not is_open:
		return
	is_open = false
	hide()
	context.leave_modal(&"inspector")
func _exit_tree() -> void:
	close_inspector()

func refresh_view() -> void:
	var data: Dictionary = {}
	if mode == blackboard_key:
		heading.text = "BLACKBOARD / LIVE SNAPSHOT"
		data = context.blackboard_snapshot()
	elif mode == flags_key:
		heading.text = "FLAGS / LIVE SNAPSHOT"
		data = context.adapter.flags_snapshot()
	elif mode == save_key:
		heading.text = "SAVE FILE / DISK SNAPSHOT"
		content.text = read_save_text()
		return
	content.text = format_value(data) if not data.is_empty() else "(empty)"
func read_save_text() -> String:
	var snapshot := context.adapter.save_snapshot()
	var prefix := "FILE: " + str(snapshot.get("path", "")) + "\n\n"
	if not str(snapshot.get("error", "")).is_empty():
		return prefix + str(snapshot.error)
	return prefix + "SIZE: " + str(snapshot.get("bytes", 0)) + " bytes\nStored values (not unsaved runtime data):\n\n" + format_value(snapshot.get("data"))
func format_value(value: Variant, depth: int = 0) -> String:
	return context.format_value(value, depth)
