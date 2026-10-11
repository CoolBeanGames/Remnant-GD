class_name options_menu
extends CanvasLayer
signal closed
var is_open: bool = false
var previous_pause: bool = false
var previous_mouse: Input.MouseMode
var status: Label
var widgets: Dictionary = {}
var delete_button: Button
var rows: VBoxContainer
var tabs: TabContainer
const CHOICES: Dictionary = {
	"window_mode": {"labels": ["WINDOWED", "FULLSCREEN"], "values": [0, 1]},
	"fps_limit": {"labels": ["UNLIMITED", "30", "60", "90", "120", "144", "165", "240"], "values": [0, 30, 60, 90, 120, 144, 165, 240]},
	"antialiasing": {"labels": ["OFF", "FXAA", "MSAA 2X", "MSAA 4X", "MSAA 8X"], "values": [0, 1, 2, 3, 4]},
	"shadow_quality": {"labels": ["LOW", "MEDIUM", "HIGH", "ULTRA"], "values": [0, 1, 2, 3]},
}

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
	rows = VBoxContainer.new()
	rows.add_theme_constant_override("separation", 16)
	centre.add_child(rows)
	var heading := Label.new()
	heading.text = "OPTIONS"
	heading.add_theme_font_size_override("font_size", 36)
	rows.add_child(heading)
	tabs = TabContainer.new()
	tabs.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rows.add_child(tabs)
	var audio := _tab("AUDIO")
	var controls := _tab("CONTROLS")
	var graphics := _tab("GRAPHICS")
	for definition in [["master", "MASTER", 0.0, 100.0, 1.0], ["sfx", "SFX", 0.0, 100.0, 1.0], ["vocals", "VOCALS", 0.0, 100.0, 1.0], ["music", "MUSIC", 0.0, 100.0, 1.0]]:
		_slider(audio, definition)
	_slider(controls, ["sensitivity", "LOOK SENSITIVITY", .1, 5.0, .05])
	for definition in [["invert_x", "INVERT MOUSE X"], ["invert_y", "INVERT MOUSE Y"]]:
		_toggle(controls, definition[0], definition[1])
	_choice(graphics, "window_mode", "DISPLAY MODE")
	_toggle(graphics, "vsync", "V-SYNC")
	_choice(graphics, "fps_limit", "FRAME RATE LIMIT")
	_slider(graphics, ["render_scale", "3D RENDER SCALE", 50.0, 100.0, 5.0])
	_choice(graphics, "antialiasing", "ANTIALIASING")
	_choice(graphics, "shadow_quality", "SHADOW QUALITY")
	_toggle(graphics, "ambient_occlusion", "AMBIENT OCCLUSION")
	var note := Label.new()
	note.text = "Lower 3D scale, antialiasing and shadows to improve performance.\nText stays sharp. V-sync may limit FPS below the selected cap."
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	graphics.add_child(note)
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
	get_viewport().size_changed.connect(_resize)
	_resize()
	hide()

func _tab(title: String) -> VBoxContainer:
	var scroll := ScrollContainer.new()
	scroll.name = title
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	tabs.add_child(scroll)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 18)
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(content)
	return content

func _row(parent: VBoxContainer, title: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	parent.add_child(row)
	var label := Label.new()
	label.text = title
	label.custom_minimum_size.x = 210
	row.add_child(label)
	return row

func _slider(parent: VBoxContainer, definition: Array) -> void:
	var key: String = definition[0]
	var row := _row(parent, definition[1])
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

func _toggle(parent: VBoxContainer, key: String, title: String) -> void:
	var box := CheckBox.new()
	box.text = title
	parent.add_child(box)
	widgets[key] = box
	box.toggled.connect(_toggle_changed.bind(key))

func _choice(parent: VBoxContainer, key: String, title: String) -> void:
	var row := _row(parent, title)
	var choice := OptionButton.new()
	choice.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for label: String in CHOICES[key].labels:
		choice.add_item(label)
	row.add_child(choice)
	widgets[key] = choice
	choice.item_selected.connect(_choice_changed.bind(key))

func _resize() -> void:
	var size: Vector2 = get_viewport().get_visible_rect().size
	rows.custom_minimum_size.x = minf(680, maxf(320, size.x - 48))
	tabs.custom_minimum_size.y = clampf(size.y - 310, 100, 460)

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
		elif widgets[key] is OptionButton:
			widgets[key].select(CHOICES[key].values.find(int(Settings.values[key])))
		else:
			var amount: float = float(Settings.values[key]) * (1.0 if key == "sensitivity" else 100.0)
			widgets[key].slider.set_value_no_signal(amount)
			widgets[key].label.text = "%.2f" % amount if key == "sensitivity" else "%d%%" % roundi(amount)
	delete_button.disabled = false
	status.text = "Changes apply immediately and save automatically. Delete Save removes this run and all banked mulch progress, then exits."

func _slider_changed(value: float, key: String) -> void:
	Settings.set_value(key, value if key == "sensitivity" else value / 100.0)
	widgets[key].label.text = "%.2f" % value if key == "sensitivity" else "%d%%" % roundi(value)

func _toggle_changed(value: bool, key: String) -> void:
	Settings.set_value(key, value)

func _choice_changed(index: int, key: String) -> void:
	Settings.set_value(key, CHOICES[key].values[index])

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
	if DevTools.any_modal_open():
		return
	if is_open and event is InputEventKey and event.pressed and not event.echo and (event.keycode == KEY_ESCAPE or event.physical_keycode == KEY_ESCAPE):
		close()
		get_viewport().set_input_as_handled()

func _exit_tree() -> void:
	if is_open:
		is_open = false
		get_tree().paused = previous_pause
		Input.mouse_mode = previous_mouse
