extends CanvasLayer

@export var portal: door_portal
@export var seconds: float = 4.0
var remaining: float = 0.0
@onready var label: Label = $Label

func _ready() -> void:
	portal.destination_changed.connect(_changed)
	label.hide()

func _changed(_id: StringName, title: String) -> void:
	label.text = "PORTAL / %s\n[F9] NEXT DESTINATION" % title
	remaining = seconds
	label.show()

func _process(delta: float) -> void:
	if remaining > 0.0:
		remaining -= delta
		if remaining <= 0.0:
			label.hide()
