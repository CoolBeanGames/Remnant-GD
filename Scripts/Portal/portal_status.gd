extends CanvasLayer

@export var portal: door_portal
@export var seconds: float = 4.0
var remaining: float = 0.0
@onready var label: Label = $Label

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	portal.destination_changed.connect(_changed)
	label.hide()

func _changed(_id: StringName, title: String) -> void:
	label.text = "MEMORY / %s" % title if not portal.memory_id.is_empty() else "PORTAL / %s\n[F9] NEXT DESTINATION" % title
	remaining = seconds
	label.show()

func _process(delta: float) -> void:
	if not portal.active:
		label.hide()
	visible = not get_tree().paused and not Blackboard.read_data("player_input_blocked") and not DevTools.any_modal_open()
	if get_tree().paused:
		return
	if remaining > 0.0:
		remaining -= delta
		if remaining <= 0.0:
			label.hide()
