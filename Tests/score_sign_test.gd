extends Node

var failures: Array[String] = []


func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error(message)


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	Blackboard.remove_data("score")
	var sign_scene := preload("res://Scenes/Actors/score_sign.tscn").instantiate()
	add_child(sign_scene)
	var label := sign_scene.get_node("Label3D") as score_sign
	check(label.text == "000000000000000000", "Missing score should show eighteen zeroes.")
	check(label.horizontal_alignment == HORIZONTAL_ALIGNMENT_LEFT and label.offset.x < 0, "Sign should preserve its left edge and fill right.")
	Blackboard.store_data("score", 27)
	await get_tree().process_frame
	await get_tree().process_frame
	check(label.text == "000000000000000027", "Score changes should update the sign automatically.")
	label.minimum_digits = 4
	label.update_score()
	check(label.text == "0027", "Digit count should be configurable.")
	Blackboard.store_data("score", 123456)
	label.update_score()
	check(label.text == "123456", "Large scores should never be truncated.")
	Blackboard.store_data("score", -7)
	label.update_score()
	check(label.text == "-0007", "Negative scores should retain their sign.")
	sign_scene.queue_free()
	await get_tree().process_frame
	print("Score sign tests: ", "PASS" if failures.is_empty() else "FAIL")
	get_tree().quit(0 if failures.is_empty() else 1)
