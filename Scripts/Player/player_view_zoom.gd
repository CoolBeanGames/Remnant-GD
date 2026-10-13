class_name player_view_zoom
extends Node

## Empty hands use RMB to inspect the world; held items retain RMB throw.
@export var camera: Camera3D
@export var pickup: player_pickup
@export_range(15, 70, 1) var zoom_fov: float = 35
@export_range(1, 30, .5) var response: float = 8
var normal_fov: float = 75

func _ready() -> void:
	if camera != null:
		normal_fov = camera.fov

func can_zoom() -> bool:
	return camera != null and not get_tree().paused and (Input.mouse_mode == Input.MOUSE_MODE_CAPTURED or DisplayServer.get_name() == "headless") and Blackboard.read_data("player_input_blocked") != true and not DevTools.any_modal_open() and Blackboard.read_data("world_view_session") == null and (pickup == null or not pickup.is_holding_object())

func _process(delta: float) -> void:
	if camera == null or Blackboard.read_data("world_view_session") != null:
		return
	var target: float = minf(zoom_fov, normal_fov) if can_zoom() and Input.is_action_pressed("throw") else normal_fov
	camera.fov = lerpf(camera.fov, target, 1.0 - exp(-response * delta))
	if absf(camera.fov - target) < .01:
		camera.fov = target
