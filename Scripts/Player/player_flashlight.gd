extends SpotLight3D

@export var toggle_key: Key = KEY_T
@export var powered: bool = true
@export var show_off_hint: bool = true
var off_hint: world_prompt_label

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var saved: Variant = Blackboard.read_data("flashlight_powered")
	set_powered(saved if saved is bool else powered)
	off_hint = load("res://Scenes/UI/world_prompt_label.tscn").instantiate() as world_prompt_label
	off_hint.name = "FlashlightOffHint"
	off_hint.position = Vector3(-1.1, -.65, -1.8)
	off_hint.rotation.y = deg_to_rad(7.0)
	off_hint.pixel_size = .0016
	off_hint.no_depth_test = true
	# Transparent lettering avoids the depth-prepass outline covering its fill.
	off_hint.alpha_cut = Label3D.ALPHA_CUT_DISABLED
	off_hint.add_to_group("gameplay_hud")
	get_parent().add_child.call_deferred(off_hint)

func _process(_delta: float) -> void:
	# BB edits from the console/inspector must affect the live lamp, not just reload.
	var saved: Variant = Blackboard.read_data("flashlight_powered")
	if saved is bool and saved != powered:
		set_powered(saved)
	if is_instance_valid(off_hint):
		off_hint.text = "[%s] Turn On Flashlight" % OS.get_keycode_string(toggle_key)
		off_hint.visible = show_off_hint and not powered and not get_tree().paused and Blackboard.read_data("player_input_blocked") != true and not DevTools.any_modal_open()

func _exit_tree() -> void:
	if is_instance_valid(off_hint) and not off_hint.is_queued_for_deletion():
		off_hint.queue_free()

func set_powered(value: bool) -> void:
	powered = value
	visible = value
	Blackboard.store_data("flashlight_powered", value)

func _unhandled_input(event: InputEvent) -> void:
	if get_tree().paused or Blackboard.read_data("player_input_blocked") == true or DevTools.any_modal_open():
		return
	if event is InputEventKey and event.pressed and not event.echo and (event.keycode == toggle_key or event.physical_keycode == toggle_key):
		set_powered(not powered)
		DevTools.log_info("Flashlight on" if powered else "Flashlight off", "player")
		get_viewport().set_input_as_handled()
