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
	var package := preload("res://Scenes/Building/packed_light.tscn").instantiate() as packed_buildable
	package.position = Vector3(0, 10, 0)
	add_child(package)
	check(not package.freeze and not package.lock_rotation, "Loose crates should use normal rigid body physics.")
	check(package.collision_layer == 1 and package.collision_mask == 1, "Root crate collider should stay active.")
	var imported := package.find_children("*", "StaticBody3D", true, false)
	check(not imported.is_empty(), "Fixture should contain the imported collider.")
	for collider in imported:
		check(collider.collision_layer == 0 and collider.collision_mask == 0, "Imported colliders should not push against the crate.")
	for frame in range(12):
		await get_tree().physics_frame
	check(package.angular_velocity.length() < 0.001, "An untouched falling crate should not spin on its own.")
	sign_scene.queue_free()
	package.queue_free()
	await get_tree().process_frame
	print("Score sign and loose crate tests: ", "PASS" if failures.is_empty() else "FAIL")
	get_tree().quit(0 if failures.is_empty() else 1)
