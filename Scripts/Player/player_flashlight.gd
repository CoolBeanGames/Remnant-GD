extends SpotLight3D

@export var toggle_key: Key = KEY_T
@export var powered: bool = true

func _ready() -> void:
	var saved: Variant = Blackboard.read_data("flashlight_powered")
	set_powered(saved if saved is bool else powered)

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
