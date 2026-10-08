extends Node

@export var velocity_target: Vector3

@export_category("Movement")
@export var move_speed: float = 10.0
@export var sprint_speed_mult: float = 2.0
@export var acceleration: float = 40.0
@export var deceleration: float = 40.0

@export_category("References")
@export var body: Node3D
@export var character_body: CharacterBody3D
@export var footstep_player: footstep_audio


func _physics_process(delta: float) -> void:
	var axis := make_axis()

	# Check if sprint is being held.
	var sprinting := Input.is_action_pressed("sprint")

	# Calculate current movement speed.
	var current_speed := move_speed

	if sprinting:
		current_speed *= sprint_speed_mult

	# Get movement directions relative to the player's body.
	var forward := -body.global_transform.basis.z
	var right := body.global_transform.basis.x

	# Build desired movement velocity.
	var desired_velocity := (
		right * axis.x +
		forward * axis.y
	) * current_speed

	# Preserve vertical velocity.
	desired_velocity.y = character_body.velocity.y

	# Decide whether we're accelerating or slowing down.
	var rate := acceleration if axis.length_squared() > 0.0 else deceleration

	# Smoothly move toward desired velocity.
	character_body.velocity = character_body.velocity.move_toward(
		desired_velocity,
		rate * delta
	)

	# Actually move the CharacterBody3D.
	character_body.move_and_slide()

	# Get horizontal velocity only.
	var horizontal_velocity := Vector2(
		character_body.velocity.x,
		character_body.velocity.z
	)

	# Only play footsteps while actually moving.
	if horizontal_velocity.length() > 0.1:
		footstep_player.start(sprinting)
	else:
		footstep_player.stop()


func make_axis() -> Vector2:
	var vertical := Input.get_axis("back", "forward")
	var horizontal := Input.get_axis("left", "right")

	var axis := Vector2(horizontal, vertical)

	# Prevent diagonal movement from being faster.
	if axis.length() > 1.0:
		axis = axis.normalized()

	return axis
