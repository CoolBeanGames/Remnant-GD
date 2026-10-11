extends "res://addons/dev_toolkit/context.gd"
func _init() -> void:
	adapter = preload("res://Scripts/Debug/remnant_dev_adapter.gd").new()
	command_catalog = preload("res://Data/Debug/commands.tres")
