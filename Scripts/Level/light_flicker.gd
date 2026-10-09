class_name light_flicker
extends Light3D

@export var flicker_enabled: bool = true
@export var steady_interval: Vector2 = Vector2(1.5, 4.0)
@export var off_interval: Vector2 = Vector2(0.04, 0.18)
@export var on_interval: Vector2 = Vector2(0.03, 0.12)
@export var outage_count: Vector2i = Vector2i(2, 5)
@export_category("Optional Audio")
@export var flicker_sounds: Array[AudioStream] = []
@export var sound_volume: float = 1.0
@export var sound_bus: StringName = &"RoomSFX"
var original_energy: float
var remaining: float = 0.0
var transitions_left: int = 0
var powered: bool = true
var random := RandomNumberGenerator.new()

func _ready() -> void:
	original_energy = light_energy
	random.randomize()
	remaining = _duration(steady_interval)

func _duration(interval: Vector2) -> float:
	return maxf(0.001, random.randf_range(minf(interval.x, interval.y), maxf(interval.x, interval.y)))

func _process(delta: float) -> void:
	if not flicker_enabled:
		light_energy = original_energy
		powered = true
		transitions_left = 0
		remaining = _duration(steady_interval)
		return
	remaining -= delta
	var iterations: int = 0
	while remaining <= 0 and iterations < 64:
		iterations += 1
		if transitions_left == 0:
			transitions_left = maxi(1, random.randi_range(mini(outage_count.x, outage_count.y), maxi(outage_count.x, outage_count.y))) * 2
		powered = not powered
		transitions_left -= 1
		light_energy = original_energy if powered else 0.0
		if not powered and not flicker_sounds.is_empty():
			var stream: AudioStream = flicker_sounds.pick_random()
			if stream != null:
				audio_global.play_3d(stream, global_position, sound_volume, 1.0, sound_bus)
		remaining += _duration(steady_interval if transitions_left == 0 else (on_interval if powered else off_interval))

func _exit_tree() -> void:
	light_energy = original_energy
