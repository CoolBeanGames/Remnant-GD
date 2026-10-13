extends Node
var failures: Array[String] = []
func check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
		push_error(message)
func _ready() -> void:
	run.call_deferred()
func run() -> void:
	SaveGame.enabled = false
	SaveGame.saving_disabled = true
	SaveGame.save_path = "res://.godot/inspector_test_" + str(Time.get_ticks_usec()) + ".save"
	var node := Node.new()
	node.name = "ExampleNode"
	add_child(node)
	Blackboard.store_data("inspector_test", {"nested": [123, node, "hello"]})
	Blackboard.remove_data("player_input_blocked")
	DebugInspector.open_inspector(KEY_F2)
	check(DebugInspector.content.text.contains("ExampleNode") and DebugInspector.content.text.contains("123"), "Nested values and node names appear")
	check(get_tree().paused and not DebugInspector.content.editable, "Inspector is paused and read-only")
	Blackboard.store_data("inspector_test", 456)
	DebugInspector.refresh_view()
	check(DebugInspector.content.text.contains("456"), "Refresh obtains current values")
	Flags.set_flag("inspector false flag", false)
	Flags.set_flag("inspector true flag", true)
	DebugInspector.open_inspector(KEY_F3)
	check(DebugInspector.content.text.contains("inspector false flag: false") and DebugInspector.content.text.contains("inspector true flag: true"), "All flags including false flags appear")
	DebugInspector.open_inspector(KEY_F4)
	check(DebugInspector.content.text.contains("No save file"), "Missing save shown explicitly")
	var file := FileAccess.open(SaveGame.save_path, FileAccess.WRITE)
	file.store_var({"version": 2, "blackboard": {"saved_only": 789}, "flags": {"stored flag": true}, "profile": {"mulch_coins": 12}})
	file.close()
	var before := FileAccess.get_file_as_bytes(SaveGame.save_path)
	DebugInspector.refresh_view()
	check(DebugInspector.content.text.contains("saved_only: 789") and DebugInspector.content.text.contains("mulch_coins: 12"), "Actual stored data includes run/profile")
	check(before == FileAccess.get_file_as_bytes(SaveGame.save_path) and not Blackboard.data_exists("saved_only"), "Inspection neither writes nor loads save into runtime")
	DebugInspector.close_inspector()
	check(not get_tree().paused and not Blackboard.data_exists("player_input_blocked"), "Prior pause and absent input lock restored")
	get_tree().paused = true
	Blackboard.store_data("player_input_blocked", true)
	DebugInspector.open_inspector(KEY_F2)
	DebugInspector.open_inspector(KEY_F3)
	DebugInspector.close_inspector()
	check(get_tree().paused and Blackboard.read_data("player_input_blocked"), "Switching tabs preserves existing pause ownership")
	get_tree().paused = false
	var event := InputEventKey.new()
	event.pressed = true
	event.keycode = KEY_F2
	DebugInspector._input(event)
	check(DebugInspector.is_open, "F2 opens")
	DebugInspector._input(event)
	check(not DebugInspector.is_open, "Repeated key closes")
	DebugInspector.open_inspector(KEY_F2)
	IssueReporter.open_report(Image.create(8, 8, false, Image.FORMAT_RGBA8))
	check(not DebugInspector.is_open and IssueReporter.is_open, "Reporter replaces inspector without stacking pause ownership")
	DebugInspector._input(event)
	check(not DebugInspector.is_open, "Inspector shortcuts do not interrupt report typing")
	IssueReporter.close_report()
	check(not get_tree().paused, "Reporter closes back to original state")
	node.queue_free()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SaveGame.save_path))
	print("F2/F3/F4 inspectors, nested names, disk-only reading and modal ownership: ", "PASS" if failures.is_empty() else str(failures))
	get_tree().quit(0 if failures.is_empty() else 1)
