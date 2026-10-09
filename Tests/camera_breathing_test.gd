extends Node
var failures: Array[String] = []
func check(ok: bool, text: String) -> void:
	if not ok:
		failures.append(text)
		push_error(text)
func _ready() -> void:
	run.call_deferred()
func run() -> void:
	Blackboard.store_data("player_input_blocked", false)
	var camera := Camera3D.new()
	add_child(camera)
	camera.position = Vector3(0, 1.887, 0)
	camera.rotation = Vector3(-.3, .2, 0)
	var original: Transform3D = camera.transform
	var breathing := camera_breathing.new()
	breathing.camera = camera
	add_child(breathing)
	breathing.set_process(false)
	for i in 600:
		breathing._process(1.0 / 60.0)
		var displacement: Vector3 = (camera.position - original.origin).abs()
		check(displacement.x <= breathing.amplitude.x + breathing.noise_amount + .00001 and displacement.y <= breathing.amplitude.y + breathing.noise_amount + .00001 and displacement.z <= breathing.amplitude.z + breathing.noise_amount + .00001, "Breathing stays bounded without camera drift")
	check(not camera.position.is_equal_approx(original.origin), "Breathing adds gentle camera motion")
	check(is_equal_approx(camera.rotation.x, original.basis.get_euler().x) and is_equal_approx(camera.rotation.y, original.basis.get_euler().y), "Mouse-look pitch and yaw are preserved")
	var before: Vector3 = camera.position
	Blackboard.store_data("player_input_blocked", true)
	breathing._process(1)
	check(camera.position == before, "Menus freeze camera breathing")
	Blackboard.store_data("player_input_blocked", false)
	breathing.enabled = false
	breathing._process(.1)
	check(camera.transform.is_equal_approx(original), "Disabling restores the authored pose")
	breathing.enabled = true
	breathing.amplitude = Vector3.ZERO
	breathing.noise_amount = 0
	breathing.roll_degrees = 0
	breathing._process(1)
	check(camera.transform.is_equal_approx(original), "Zero amplitude and noise fully remove motion")
	breathing.amplitude = Vector3(.004, .012, .003)
	breathing._process(1)
	breathing.reset()
	check(camera.transform.is_equal_approx(original) and breathing.offset == Vector3.ZERO, "Respawn reset removes prior camera offsets")
	breathing.queue_free()
	camera.queue_free()
	await get_tree().process_frame
	print("Camera breathing bounds, look, menus and reset: ", "PASS" if failures.is_empty() else failures)
	get_tree().quit(0 if failures.is_empty() else 1)
