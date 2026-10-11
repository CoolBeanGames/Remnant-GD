class_name options_menu
extends CanvasLayer
signal closed
var is_open: bool = false
var previous_pause: bool = false
var previous_mouse: Input.MouseMode
var status: Label
var widgets: Dictionary = {}
var delete_button: Button

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 60
	var screen := ColorRect.new()
	screen.color = Color(.015, .015, .015, .98)
	screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(screen)
	var centre := CenterContainer.new()
	centre.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	screen.add_child(centre)
	var rows := VBoxContainer.new()
	rows.custom_minimum_size = Vector2(620, 560)
	rows.add_theme_constant_override("separation", 16)
	centre.add_child(rows)
	var heading := Label.new()
	heading.text = "OPTIONS"
	heading.add_theme_font_size_override("font_size", 36)
	rows.add_child(heading)
	for definition in [["master", "MASTER", 0.0, 100.0, 1.0], ["sfx", "SFX", 0.0, 100.0, 1.0], ["vocals", "VOCALS", 0.0, 100.0, 1.0], ["music", "MUSIC", 0.0, 100.0, 1.0], ["sensitivity", "LOOK SENSITIVITY", .1, 5.0, .05]]:
		var key: String = definition[0]
		var row := HBoxContainer.new()
		rows.add_child(row)
		var label := Label.new()
		label.text = definition[1]
		label.custom_minimum_size.x = 210
		row.add_child(label)
		var slider := HSlider.new()
		slider.min_value = definition[2]
		slider.max_value = definition[3]
		slider.step = definition[4]
		slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(slider)
		var value_label := Label.new()
		value_label.custom_minimum_size.x = 70
		row.add_child(value_label)
		widgets[key] = {"slider": slider, "label": value_label}
		slider.value_changed.connect(_slider_changed.bind(key))
	for definition in [["invert_x", "INVERT MOUSE X"], ["invert_y", "INVERT MOUSE Y"]]:
		var box := CheckBox.new()
		box.text = definition[1]
		rows.add_child(box)
		widgets[definition[0]] = box
		box.toggled.connect(_toggle_changed.bind(definition[0]))
	status = Label.new()
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status.custom_minimum_size.y = 55
	rows.add_child(status)
	delete_button = Button.new()
	delete_button.text = "DELETE SAVE AND EXIT"
	delete_button.custom_minimum_size.y = 48
	delete_button.pressed.connect(_delete)
	rows.add_child(delete_button)
	var back := Button.new()
	back.text = "BACK [ESC]"
	back.custom_minimum_size.y = 48
	back.pressed.connect(close)
	rows.add_child(back)
	SaveGame.save_failed.connect(_failed)
	hide()

func open() -> void:
	if is_open:
		return
	previous_pause = get_tree().paused
	previous_mouse = Input.mouse_mode
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	is_open = true
	show()
	for key in widgets:
		if widgets[key] is CheckBox:
			widgets[key].set_pressed_no_signal(bool(Settings.values[key]))
		else:
			var amount: float = float(Settings.values[key]) * (1.0 if key == "sensitivity" else 100.0)
			widgets[key].slider.set_value_no_signal(amount)
			widgets[key].label.text = "%.2f" % amount if key == "sensitivity" else "%d%%" % roundi(amount)
	delete_button.disabled = false
	status.text = "Changes save automatically. Delete Save removes this run and all banked mulch progress, then exits."

func _slider_changed(value: float, key: String) -> void:
	Settings.set_value(key, value if key == "sensitivity" else value / 100.0)
	widgets[key].label.text = "%.2f" % value if key == "sensitivity" else "%d%%" % roundi(value)

func _toggle_changed(value: bool, key: String) -> void:
	Settings.set_value(key, value)

func _delete() -> void:
	SaveGame.reset_and_quit()

func _failed(message: String) -> void:
	if is_open:
		status.text = message

func close() -> void:
	if not is_open:
		return
	Settings.flush()
	is_open = false
	hide()
	get_tree().paused = previous_pause
	Input.mouse_mode = previous_mouse
	closed.emit()

func _input(event: InputEvent) -> void:
	if IssueReporter.is_open or DebugInspector.is_open or DevConsole.is_open:
		return
	if is_open and event is InputEventKey and event.pressed and not event.echo and (event.keycode == KEY_ESCAPE or event.physical_keycode == KEY_ESCAPE):
		close()
		get_viewport().set_input_as_handled()

func _exit_tree() -> void:
	if is_open:
		is_open = false
		get_tree().paused = previous_pause
