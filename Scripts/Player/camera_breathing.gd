class_name camera_breathing
extends Node

@export var camera: Camera3D
@export var enabled: bool = true
@export_range(1.0, 40.0, 0.5) var breaths_per_minute: float = 15.0
## Metres of local side-to-side, vertical and forward motion.
@export var amplitude: Vector3 = Vector3(0.012, 0.035, 0.006)
@export_range(0.0, 0.02, 0.001) var noise_amount: float = 0.006
@export var roll_degrees: float = 0.35
@export var noise_speed: float = 0.25
@export var smoothing: float = 4.0
@export var noise_seed: int = 731
var elapsed: float = 0.0
var offset: Vector3 = Vector3.ZERO
var roll_offset: float = 0.0
var noise := FastNoiseLite.new()

func _ready() -> void:
	noise.seed = noise_seed
	noise.frequency = 1.0
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH

func _process(delta: float) -> void:
	if not is_instance_valid(camera):
		return
	if not enabled:
		reset()
		return
	if Blackboard.read_data("player_input_blocked"):
		return
	elapsed += delta
	var phase: float = elapsed * TAU * breaths_per_minute / 60.0
	var target := Vector3(sin(phase * .5), sin(phase), sin(phase + .7)) * amplitude
	var sample_time: float = elapsed * noise_speed
	target += Vector3(noise.get_noise_2d(sample_time, 0), noise.get_noise_2d(sample_time, 17), noise.get_noise_2d(sample_time, 31)) * noise_amount
	var next_offset: Vector3 = offset.lerp(target, 1.0 - exp(-maxf(.01, smoothing) * delta))
	# Only replace our contribution; authored position and mouse look stay intact.
	camera.position += next_offset - offset
	offset = next_offset
	var next_roll: float = lerpf(roll_offset, deg_to_rad(roll_degrees) * sin(phase * .5), 1.0 - exp(-maxf(.01, smoothing) * delta))
	camera.rotation.z += next_roll - roll_offset
	roll_offset = next_roll

func reset() -> void:
	if is_instance_valid(camera):
		camera.position -= offset
		camera.rotation.z -= roll_offset
	offset = Vector3.ZERO
	roll_offset = 0.0
	elapsed = 0.0

func _exit_tree() -> void:
	reset()
