@tool
extends EditorPlugin
## Optional installer. Existing host integrations are never overwritten.
const AUTOLOAD_NAME := "DevTools"
const AUTOLOAD_SCENE := "res://addons/dev_toolkit/dev_tools.tscn"

func _enable_plugin() -> void:
	var key := "autoload/" + AUTOLOAD_NAME
	if not ProjectSettings.has_setting(key):
		add_autoload_singleton(AUTOLOAD_NAME, AUTOLOAD_SCENE)
	elif str(ProjectSettings.get_setting(key)).trim_prefix("*") != AUTOLOAD_SCENE:
		push_warning("Dev Toolkit: an existing DevTools autoload was retained. Add the toolkit scene manually or adapt that integration.")

func _disable_plugin() -> void:
	var key := "autoload/" + AUTOLOAD_NAME
	if ProjectSettings.has_setting(key) and str(ProjectSettings.get_setting(key)).trim_prefix("*") == AUTOLOAD_SCENE:
		remove_autoload_singleton(AUTOLOAD_NAME)
