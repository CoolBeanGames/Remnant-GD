class_name computer_ui
extends CanvasLayer

@export var row_scene: PackedScene
var terminal: computer_terminal
var previous_mouse: Input.MouseMode
var previous_block: Variant
var is_open: bool = false
var rows: Array[Dictionary] = []
var last_score: int = -1
var last_mulch: int = -1
@onready var score_label: Label = $Screen/Center/Panel/Margin/Rows/Header/Score
@onready var tabs: TabContainer = $Screen/Center/Panel/Margin/Rows/Tabs
@onready var status: Label = $Screen/Center/Panel/Margin/Rows/Status

func _ready() -> void:
	$Screen/Center/Panel/Margin/Rows/Header/Close.pressed.connect(close)
	Progression.changed.connect(refresh)
	Mulch.changed.connect(refresh)
	hide()

func open(source: computer_terminal) -> void:
	terminal = source
	if not is_open:
		previous_mouse = Input.mouse_mode
		previous_block = Blackboard.read_data("player_input_blocked")
	is_open = true
	Blackboard.store_data("player_input_blocked", true)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	status.text = "SCORE / REGULAR UPGRADES. MULCH / PERMANENT UPGRADES."
	_build_rows()
	show()
	refresh()
	$Screen/Center/Panel/Margin/Rows/Header/Close.grab_focus()

func close() -> void:
	if not is_open:
		return
	is_open = false
	Blackboard.store_data("player_input_blocked", previous_block)
	Input.mouse_mode = previous_mouse
	hide()

func _exit_tree() -> void:
	close()

func _input(event: InputEvent) -> void:
	if is_open and event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		close()
		get_viewport().set_input_as_handled()

func _process(_delta: float) -> void:
	if is_open:
		if not is_instance_valid(terminal):
			close()
		elif last_score != Progression.score() or last_mulch != Mulch.coins():
			refresh()

func _build_rows() -> void:
	rows.clear()
	for tab in tabs.get_children():
		var list: VBoxContainer = tab.get_node("List")
		for child in list.get_children():
			list.remove_child(child)
			child.queue_free()
	if terminal.catalog == null or row_scene == null:
		return
	for entry in terminal.catalog.entries:
		if entry == null:
			continue
		var row: HBoxContainer = row_scene.instantiate()
		tabs.get_child(entry.tab).get_node("List").add_child(row)
		row.get_node("Text/Title").text = entry.title.to_upper()
		row.get_node("Text/Description").text = entry.description
		row.get_node("Buy").pressed.connect(_buy.bind(entry))
		rows.append({"entry": entry, "row": row})

func refresh() -> void:
	if not is_open:
		return
	last_score = Progression.score()
	last_mulch = Mulch.coins()
	tabs.set_tab_hidden(3, not Mulch.tab_unlocked())
	score_label.text = "CREDIT: %08d / MULCH: %06d" % [last_score, last_mulch]
	for state in rows:
		var entry: computer_entry = state.entry
		var tier: int = Progression.level(entry)
		var complete: bool = entry.tab != computer_entry.Tab.STORE and entry.max_level > 0 and tier >= entry.max_level
		var button: Button = state.row.get_node("Buy")
		var installed: bool = entry.installation == "mulcher" and Flags.check_flag("mulcher purchased")
		var balance: int = last_mulch if entry.tab == computer_entry.Tab.MULCH else last_score
		button.disabled = complete or installed or balance < entry.cost(tier) or (entry.tab == computer_entry.Tab.MULCH and not Mulch.tab_unlocked())
		button.text = "INSTALLED" if installed else ("COMPLETE" if complete else "BUY / %d%s" % [entry.cost(tier), " MULCH" if entry.tab == computer_entry.Tab.MULCH else ""])
		if entry.tab == computer_entry.Tab.STORE:
			state.row.get_node("Text/Level").text = "DELIVERED %d / RISING PRICE" % tier if entry.escalating_store_price else ("GRINDER INSTALLATION" if entry.installation == "mulcher" else "SKY DELIVERY")
		else:
			state.row.get_node("Text/Level").text = "LEVEL %d / %s" % [tier, str(entry.max_level) if entry.max_level > 0 else "--"]

func _buy(entry: computer_entry) -> void:
	var result: String = terminal.buy(entry)
	status.text = result.to_upper() if not result.is_empty() else ("DELIVERY INBOUND: " if entry.tab == computer_entry.Tab.STORE else "UPGRADE INSTALLED: ") + entry.title.to_upper()
	refresh()
