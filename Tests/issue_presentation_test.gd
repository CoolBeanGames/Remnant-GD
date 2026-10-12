extends "res://Tests/world_interfaces_test.gd"
func _ready() -> void:
	capture_directory = "res://Reports/IssueBatch/game"
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS, true)
	super._ready()
