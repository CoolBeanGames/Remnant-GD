extends Node
var failures: Array[String] = []
var events: Dictionary = {"closed": 0}
func _ready() -> void:
	run.call_deferred()
func check(ok: bool, text: String) -> void:
	if not ok:
		failures.append(text)
		push_error(text)
func wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout
func run() -> void:
	SaveGame.enabled = false
	SaveGame.saving_disabled = true
	Blackboard.store_data("player_input_blocked", false)
	var world := Node3D.new()
	add_child(world)
	var player: CharacterBody3D = load("res://Scenes/Player/player.tscn").instantiate()
	player.process_mode = Node.PROCESS_MODE_DISABLED
	player.disable_mode = CollisionObject3D.DISABLE_MODE_KEEP_ACTIVE
	world.add_child(player)
	var camera: Camera3D = player.get_node("Camera3D")
	camera.position = Vector3(.3, 1.2, 2.5)
	camera.rotation = Vector3(-.15, .3, 0)
	var original: Transform3D = camera.global_transform
	var mouse_before: Input.MouseMode = Input.mouse_mode
	var terminal: computer_terminal = load("res://Scenes/Computer/computer_terminal.tscn").instantiate()
	terminal.player = player
	world.add_child(terminal)
	terminal._open_interface()
	var facing: Basis = terminal.screen.global_basis.orthonormalized()
	var focused := Transform3D(facing, terminal.screen.global_position + facing.z * terminal.viewing_distance)
	check(camera.global_transform.is_equal_approx(original), "PC opening begins at the current camera pose without teleporting")
	await wait(.18)
	check(not camera.global_transform.is_equal_approx(original) and not camera.global_transform.is_equal_approx(focused), "PC position and rotation move through an intermediate pose")
	var halfway: Transform3D = camera.global_transform
	get_tree().paused = true
	await wait(.15)
	check(camera.global_transform.is_equal_approx(halfway), "PC motion stops while a pause owner suspends gameplay")
	get_tree().paused = false
	await wait(.55)
	check(camera.global_transform.is_equal_approx(focused), "PC focus reaches the exact readable screen pose")
	terminal.close_interface()
	terminal.close_interface()
	check(terminal.closing and Blackboard.read_data("player_input_blocked") and camera.global_transform.is_equal_approx(focused), "Repeated close retains input ownership and begins at the current pose")
	await wait(.12)
	check(not camera.global_transform.is_equal_approx(original) and terminal.session != null, "PC return moves smoothly before handing back control")
	await wait(.40)
	check(terminal.session == null and camera.global_transform.is_equal_approx(original) and Input.mouse_mode == mouse_before and not Blackboard.read_data("player_input_blocked"), "PC return restores exact gameplay pose, mouse and lock")
	terminal._open_interface()
	await wait(.08)
	var interrupted: Transform3D = camera.global_transform
	terminal.close_interface()
	check(camera.global_transform.is_equal_approx(interrupted), "Early close reverses from its visible intermediate pose")
	await wait(.48)
	check(camera.global_transform.is_equal_approx(original) and terminal.session == null, "Cancelled PC focus has no stale completion")
	var reader: note_reader = load("res://Scenes/Notes/note_reader.tscn").instantiate()
	reader.camera = camera
	world.add_child(reader)
	reader.closed.connect(func(_note: Dictionary, _back: bool) -> void: events.closed += 1)
	var note: Dictionary = {"id": "motion", "title": "MOTION TEST", "body": "Paper should rise and lower."}
	reader.open_note(note)
	var lowered: Transform3D = reader.holder.transform
	check(lowered.origin.y < -.4 and get_tree().paused, "Paper starts below view while the world pauses")
	await wait(.16)
	check(reader.holder.position.y > lowered.origin.y and reader.holder.position.y < -.02 and camera.global_transform.is_equal_approx(original), "Paper rises while the player's camera stays still")
	# The toolkit owns a diagnostic pause independently of the reader's world pause.
	DebugInspector.open_inspector(KEY_F2)
	await wait(.03)
	var modal_pose: Transform3D = reader.holder.transform
	await wait(.18)
	check(reader.holder.transform.is_equal_approx(modal_pose), "Inspector freezes a paused-world paper transition")
	DebugInspector.close_inspector()
	await wait(.55)
	check(reader.holder.transform.is_equal_approx(reader._reading_pose()), "Paper finishes rising after diagnostics close")
	var readable: Transform3D = reader.holder.transform
	reader.close()
	reader.close()
	check(reader.is_open and reader.closing and reader.holder.transform.is_equal_approx(readable) and events.closed == 0, "Putting paper away keeps its copy and lock until it lowers")
	await wait(.10)
	check(reader.holder.position.y < readable.origin.y and get_tree().paused, "Paper lowers before gameplay resumes")
	await wait(.30)
	check(not reader.is_open and reader.holder == null and events.closed == 1 and not get_tree().paused and not Blackboard.read_data("player_input_blocked"), "Paper completion notifies once and releases its pause")
	reader.open_note(note)
	await wait(.06)
	reader.close()
	reader.open_note({"id": "replacement", "title": "NEXT", "body": "Replacement"})
	await wait(.60)
	check(reader.is_open and reader.current_note.id == "replacement" and events.closed == 1, "Replacing a lowering note cancels its old completion and pause owner")
	reader.close(false, true)
	# Zero timings preserve an explicit immediate authoring option.
	terminal.focus_seconds = 0
	terminal.return_seconds = 0
	terminal._open_interface()
	terminal.close_interface()
	check(terminal.session == null and camera.global_transform.is_equal_approx(original), "Zero-duration PC option restores safely")
	reader.raise_seconds = 0
	reader.lower_seconds = 0
	reader.open_note(note)
	reader.close(false)
	check(not reader.is_open and not get_tree().paused, "Zero-duration paper option restores safely")
	reader.raise_seconds = .5
	reader.open_note(note)
	world.queue_free()
	await wait(.08)
	check(not get_tree().paused and not Blackboard.read_data("player_input_blocked") and Blackboard.read_data("world_view_session") == null, "Unloading during motion releases camera/session ownership immediately")
	print("World view motion / intermediate poses / cancel / pauses / single completion / unload: ", "PASS" if failures.is_empty() else failures)
	get_tree().quit(0 if failures.is_empty() else 1)
