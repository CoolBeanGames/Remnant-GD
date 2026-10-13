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
	# The first entry is already selected; clicking it still needs to open it.
	list.item_clicked.connect(_click_note)
	list.item_activated.connect(_select_note)
	var reader: note_reader = get_parent().get_node_or_null("NoteReader")
	if reader != null:
		reader.closed.connect(_on_reader_closed)
	Blackboard.store_data("pause_menu", self)
	hide()

func _input(event: InputEvent) -> void:
	if DevTools.any_modal_open():
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
		Notes.finish_read(current_note)
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
		title_label.text = "SELECT A NOTE"
		body_label.text = "Read the original paper in the world. N toggles the typed transcript; Esc puts it away."
	journal.get_node("Back").grab_focus()

func _click_note(index: int, _position: Vector2, button: int) -> void:
	if button == MOUSE_BUTTON_LEFT:
		_select_note(index)

func _select_note(index: int) -> void:
	if not is_open or not journal.visible or index < 0 or index >= entries.size():
		return
	var reader: note_reader = Blackboard.read_data("note_reader") as note_reader
	if reader == null:
		return
	var note: Dictionary = entries[index]
	close(false)
	reader.open_note(note, true)

func _on_reader_closed(_note: Dictionary, return_to_journal: bool) -> void:
	if return_to_journal and is_inside_tree():
		open()
		show_notes()

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
