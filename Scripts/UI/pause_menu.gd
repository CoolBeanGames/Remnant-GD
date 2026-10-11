class_name pause_menu
extends CanvasLayer

var options: options_menu
var is_open: bool = false
var previous_mouse: Input.MouseMode
var previous_block: Variant
var previous_pause: bool = false
var pickup_reader: bool = false
var current_note: Dictionary = {}
var entries: Array[Dictionary] = []
@onready var main: VBoxContainer = $Screen/Center/Panel/Margin/Rows/Main
@onready var journal: VBoxContainer = $Screen/Center/Panel/Margin/Rows/Journal
@onready var list: ItemList = $Screen/Center/Panel/Margin/Rows/Journal/Columns/List
@onready var title_label: Label = $Screen/Center/Panel/Margin/Rows/Journal/Columns/Reader/Title
@onready var body_label: RichTextLabel = $Screen/Center/Panel/Margin/Rows/Journal/Columns/Reader/Body

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	main.get_node("Continue").pressed.connect(close)
	main.get_node("Notes").pressed.connect(show_notes)
	main.get_node("Exit").pressed.connect(_quit)
	main.get_node("Options").pressed.connect(_options)
	journal.get_node("Back").pressed.connect(_back)
	list.item_selected.connect(_select_note)
	Notes.note_read.connect(_on_note_read)
	Blackboard.store_data("pause_menu", self)
	hide()

func _input(event: InputEvent) -> void:
	if IssueReporter.is_open or DebugInspector.is_open or DevConsole.is_open:
		return
	if is_instance_valid(options) and options.is_open:
		return
	if not event is InputEventKey or not event.pressed or event.echo or event.physical_keycode != KEY_ESCAPE and event.keycode != KEY_ESCAPE:
		return
	if not is_open and Blackboard.read_data("player_input_blocked"):
		return
	if is_open:
		if journal.visible and not pickup_reader:
			show_main()
		else:
			close()
	else:
		open()
	get_viewport().set_input_as_handled()

func open() -> void:
	if not is_open:
		previous_mouse = Input.mouse_mode
		previous_block = Blackboard.read_data("player_input_blocked")
		previous_pause = get_tree().paused
	is_open = true
	Blackboard.store_data("player_input_blocked", true)
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	show()
	show_main()

func close(notify_reading: bool = true) -> void:
	if not is_open:
		return
	is_open = false
	hide()
	get_tree().paused = previous_pause
	Blackboard.store_data("player_input_blocked", previous_block)
	Input.mouse_mode = previous_mouse
	if pickup_reader and notify_reading and not current_note.is_empty():
		Notes.note_read_finished.emit(current_note)
	pickup_reader = false
	current_note = {}

func show_main() -> void:
	pickup_reader = false
	main.show()
	journal.hide()
	$Screen/Center/Panel/Margin/Rows/Header.text = "PAUSED"
	main.get_node("Continue").grab_focus()

func show_notes() -> void:
	main.hide()
	journal.show()
	list.show()
	journal.get_node("Back").text = "BACK"
	$Screen/Center/Panel/Margin/Rows/Header.text = "NOTES"
	entries = Notes.all_notes()
	list.clear()
	for note in entries:
		list.add_item(note.title)
	if entries.is_empty():
		title_label.text = "NO NOTES FOUND"
		body_label.text = "Notes you pick up from the chute will be kept here."
	else:
		list.select(0)
		_select_note(0)
	journal.get_node("Back").grab_focus()

func _select_note(index: int) -> void:
	if index < 0 or index >= entries.size():
		return
	_display(entries[index])

func _display(note: Dictionary) -> void:
	title_label.text = str(note.get("title", "NOTE")).to_upper()
	body_label.text = str(note.get("body", ""))
	body_label.scroll_to_line(0)

func _on_note_read(note: Dictionary) -> void:
	_open_note.call_deferred(note)

func _open_note(note: Dictionary) -> void:
	open()
	pickup_reader = true
	current_note = note.duplicate(true)
	show_notes()
	list.hide()
	_display(note)
	$Screen/Center/Panel/Margin/Rows/Header.text = "NOTE FOUND"
	journal.get_node("Back").text = "CONTINUE"

func _back() -> void:
	if pickup_reader:
		close()
	else:
		show_main()

func _quit() -> void:
	SaveGame.exit_game()

func _exit_tree() -> void:
	close(false)
	if Blackboard.read_data("pause_menu") == self:
		Blackboard.remove_data("pause_menu")

func _options() -> void:
	if not is_instance_valid(options):
		options = load("res://Scenes/UI/options_menu.tscn").instantiate()
		add_child(options)
	options.open()
