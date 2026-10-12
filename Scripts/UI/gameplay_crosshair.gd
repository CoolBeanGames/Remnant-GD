extends CenterContainer

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	refresh()

func _process(_delta: float) -> void:
	refresh()

func refresh() -> void:
	visible = not get_tree().paused and not Blackboard.read_data("player_input_blocked") and not DevTools.any_modal_open()
