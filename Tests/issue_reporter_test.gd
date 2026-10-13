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
	IssueReporter.report_directory = "res://.godot/issue_test_" + str(Time.get_ticks_usec())
	var image := Image.create(48, 32, false, Image.FORMAT_RGBA8)
	image.fill(Color.CORNFLOWER_BLUE)
	Blackboard.remove_data("player_input_blocked")
	IssueReporter.open_report(image)
	check(IssueReporter.is_open and get_tree().paused, "Reporter pauses game")
	IssueReporter._submit()
	check(not IssueReporter.submit.disabled, "Empty description rejected")
	IssueReporter.description.text = "Test bug: fan should turn off."
	var saved: Array[String] = []
	IssueReporter.issue_saved.connect(func(path: String): saved.append(path))
	IssueReporter._submit()
	check(saved.size() == 1, "One report submitted")
	check(not IssueReporter.is_open and not get_tree().paused, "Successful submission automatically closes and restores gameplay")
	check(IssueReporter.description.wrap_mode == TextEdit.LINE_WRAPPING_BOUNDARY, "Long reports wrap without a horizontal document")
	if not saved.is_empty():
		var record: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(saved[0]))
		var restored := Image.load_from_file(saved[0].get_base_dir().path_join("screenshot.png"))
		check(record.description == "Test bug: fan should turn off." and record.status == "pending", "Description and pending status retained")
		check(restored.get_width() == 48 and restored.get_pixel(0, 0).is_equal_approx(Color.CORNFLOWER_BLUE), "Screenshot persisted accurately")
	IssueReporter.close_report()
	check(not get_tree().paused and not Blackboard.data_exists("player_input_blocked"), "Close restores absent input key and unpaused state")
	get_tree().paused = true
	Blackboard.store_data("player_input_blocked", true)
	IssueReporter.open_report(image)
	IssueReporter.close_report()
	check(get_tree().paused and Blackboard.read_data("player_input_blocked"), "Nested pause ownership restored")
	get_tree().paused = false
	Blackboard.store_data("player_input_blocked", false)
	IssueReporter.open_report(image)
	var blocker := "res://.godot/issue_test_blocker"
	var file := FileAccess.open(blocker, FileAccess.WRITE)
	file.store_string("block directory creation")
	file.close()
	IssueReporter.report_directory = blocker + "/inbox"
	IssueReporter.description.text = "Keep this text after failure"
	IssueReporter._submit()
	check(IssueReporter.description.text == "Keep this text after failure" and not IssueReporter.submit.disabled, "Storage failure retains editable text")
	IssueReporter.report_directory = "res://.godot/issue_test_retry_" + str(Time.get_ticks_usec())
	IssueReporter._submit()
	check(saved.size() == 2, "Retry succeeds")
	IssueReporter.close_report()
	var event := InputEventKey.new()
	event.keycode = KEY_F1
	event.pressed = true
	IssueReporter._input(event)
	check(IssueReporter.is_open, "F1 opens reporter even headless")
	event.keycode = KEY_ESCAPE
	IssueReporter._input(event)
	check(not IssueReporter.is_open and not get_tree().paused, "Escape cancels and restores state")
	print("F1 issue reporter persistence, screenshots, validation, retry and modal ownership: ", "PASS" if failures.is_empty() else str(failures))
	get_tree().quit(0 if failures.is_empty() else 1)
