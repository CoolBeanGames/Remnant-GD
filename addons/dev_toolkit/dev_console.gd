extends CanvasLayer
## Local command console; never evaluates scripts or shell commands.
@export var tools_context: NodePath
@export var toggle_key: Key = KEY_QUOTELEFT
@export var enabled: bool = true
var context: DevToolsContext
var is_open: bool = false
var previous_pause: bool
var previous_mouse: Input.MouseMode
var previous_block: Variant
var had_block: bool
var output: TextEdit
var entry: LineEdit
var history: Array[String] = []
var history_index: int = 0

func _ready() -> void:
	context = DevToolsContext.resolve(self, tools_context)
	context.register_tool(&"console", self)
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 95
	var screen := ColorRect.new()
	screen.color = Color(0, 0, 0, .95)
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
	title.text = "CONSOLE / " + OS.get_keycode_string(toggle_key) + " OR ESC TO CLOSE"
	rows.add_child(title)
	output = TextEdit.new()
	output.editable = false
	output.size_flags_vertical = Control.SIZE_EXPAND_FILL
	output.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	rows.add_child(output)
	entry = LineEdit.new()
	entry.placeholder_text = "Enter command (help for commands)"
	entry.text_submitted.connect(_submit)
	entry.gui_input.connect(_entry_input)
	rows.add_child(entry)
	output.text = help_text()
	hide()

func _input(event: InputEvent) -> void:
	if not enabled or context.tool_open(&"reporter") or not event is InputEventKey or not event.pressed or event.echo:
		return
	if event.physical_keycode == toggle_key or event.keycode == toggle_key or (toggle_key == KEY_QUOTELEFT and event.keycode == KEY_ASCIITILDE):
		get_viewport().set_input_as_handled()
		if is_open:
			close_console()
		else:
			open_console()
	elif is_open and event.keycode == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		close_console()

func open_console() -> void:
	if is_open or not context.enter_modal(&"console"):
		return
	is_open = true
	show()
	output.text = context.help_text() + "\n\n" + output.text if output.text.is_empty() else output.text
	entry.grab_focus()
func close_console() -> void:
	if not is_open:
		return
	is_open = false
	hide()
	context.leave_modal(&"console")
func _exit_tree() -> void:
	close_console()

func _entry_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not history.is_empty() and event.keycode in [KEY_UP, KEY_DOWN]:
		history_index = clampi(history_index + (-1 if event.keycode == KEY_UP else 1), 0, history.size())
		entry.text = history[history_index] if history_index < history.size() else ""
		entry.caret_column = entry.text.length()
		entry.accept_event()

func _submit(command: String) -> void:
	if command.strip_edges().is_empty():
		return
	history.append(command)
	history_index = history.size()
	output.text += "\n\n> " + command + "\n" + execute(command)
	entry.clear()
	output.set_caret_line(output.get_line_count() - 1)

func help_text() -> String:
	return context.help_text()
func tokenize(command: String) -> Array[String]:
	return context.tokenize(command)
func execute(command: String) -> String:
	return context.execute(command)
