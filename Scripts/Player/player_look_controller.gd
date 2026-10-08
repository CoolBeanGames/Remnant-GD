extends Node

@export var Head: Node3D
@export var Body: Node3D

@export_category("Look Settings")
@export var sensitivity: Vector2 = Vector2(0.08, 0.08)
@export var smoothness: float = 18.0
@export var clamp_look: Vector2 = Vector2(-89.0, 89.0)

@export_category("Input")
@export var quit_key: Key = Key.KEY_ESCAPE

var mouse_input: Vector2 = Vector2.ZERO
var look_rotation: Vector2 = Vector2.ZERO
var target_rotation: Vector2 = Vector2.ZERO


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

	# Start from the current rotations of the nodes.
	target_rotation.x = Head.rotation_degrees.x
	target_rotation.y = Body.rotation_degrees.y

	look_rotation = target_rotation


func _input(event: InputEvent) -> void:

	if event is InputEventMouseMotion:
		mouse_input += event.relative

	elif event is InputEventKey:
		if event.pressed and event.keycode == quit_key:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _process(delta: float) -> void:
	look(delta)

	mouse_input = Vector2.ZERO


func look(delta: float) -> void:

	# Convert mouse movement into rotation.
	target_rotation.y -= mouse_input.x * sensitivity.x
	target_rotation.x -= mouse_input.y * sensitivity.y

	# Prevent looking too far up/down.
	target_rotation.x = clamp(
		target_rotation.x,
		clamp_look.x,
		clamp_look.y
	)

	# Smoothly approach the target rotation.
	var smoothing := 1.0 - exp(-smoothness * delta)

	look_rotation.x = lerp(
		look_rotation.x,
		target_rotation.x,
		smoothing
	)

	look_rotation.y = lerp(
		look_rotation.y,
		target_rotation.y,
		smoothing
	)

	# Apply rotations.
	Head.rotation_degrees.x = look_rotation.x
	Body.rotation_degrees.y = look_rotation.y
