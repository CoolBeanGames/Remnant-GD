class_name memory_completion
extends Node

@export var completion_flag: String = ""
@export var required_flags: Array[String] = []

func _ready() -> void:
	for key in required_flags:
		if not key.is_empty():
			Flags.connect_to_flag(key, [refresh])
	refresh()

func refresh() -> void:
	if completion_flag.is_empty() or required_flags.is_empty() or Flags.check_flag(completion_flag):
		return
	for key in required_flags:
		if key.is_empty() or not Flags.check_flag(key):
			return
	Flags.set_flag(completion_flag, true)
	DevTools.log_info("Completed " + completion_flag, "memories")
