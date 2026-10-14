extends switchable_prop

@export_group("Light Upgrades")
@export var beam_hood_enabled: bool = false
@export var beam_hood_active: bool = true
@export var coloured_lens_enabled: bool = false
@export_range(0, 5, 1) var lens_index: int = 0
@export_range(15, 80, 1) var beam_angle: float = 45.0
@export var hood_mount: Vector3 = Vector3(0, .38, -.23)
const LENS_COLOURS: Array[Color] = [Color(1, 1, .44), Color(1, .32, .2), Color(.25, .65, 1), Color(.3, 1, .45), Color(1, .55, .15), Color(.8, .4, 1)]
var beam: SpotLight3D
var hood: MeshInstance3D

func _ready() -> void:
	super._ready()
	if not InputMap.has_action(&"toggle_light_beam"):
		InputMap.add_action(&"toggle_light_beam")
		var key := InputEventKey.new()
		key.physical_keycode = KEY_K
		InputMap.action_add_event(&"toggle_light_beam", key)
	if beam_hood_enabled:
		beam = SpotLight3D.new()
		beam.name = "HoodBeam"
		beam.position = hood_mount + Vector3(0, 0, -.1)
		beam.spot_range = 14.0
		beam.spot_angle = beam_angle
		beam.light_energy = 2.0
		beam.light_cull_mask = int($OmniLight3D.get_meta("portal_original_light_mask", $OmniLight3D.light_cull_mask))
		add_child(beam)
		var shield := MeshInstance3D.new()
		shield.name = "BeamHood"
		shield.position = hood_mount
		shield.rotation.x = PI / 2.0
		var mesh := CylinderMesh.new()
		mesh.top_radius = .19
		mesh.bottom_radius = .13
		mesh.height = .18
		mesh.cap_top = false
		mesh.cap_bottom = false
		var material := StandardMaterial3D.new()
		material.albedo_color = Color(.12, .13, .14)
		material.metallic = .65
		mesh.material = material
		shield.mesh = mesh
		add_child(shield)
		hood = shield
	if get_meta("portal_inside", false):
		portal_space.apply_actor(self, true)
	_apply_power()

func _apply_power() -> void:
	var directional: bool = beam_hood_enabled and beam_hood_active
	if hood != null:
		hood.visible = directional
	for lamp in find_children("*", "Light3D", true, false):
		lamp.visible = powered and ((directional and lamp == beam) or (not directional and lamp != beam))
		if coloured_lens_enabled:
			lamp.light_color = LENS_COLOURS[posmod(lens_index, LENS_COLOURS.size())]

func cycle_lens() -> void:
	if not coloured_lens_enabled:
		return
	lens_index = (lens_index + 1) % LENS_COLOURS.size()
	_apply_power()
	WorldState.capture()

func _unhandled_input(event: InputEvent) -> void:
	if not is_visible_in_tree() or event.is_echo() or Blackboard.read_data("player_input_blocked"):
		return
	var cone_toggle: bool = beam_hood_enabled and event.is_action_pressed(&"toggle_light_beam")
	var colour_cycle: bool = coloured_lens_enabled and event.is_action_pressed(&"cycle_light_colour")
	if not cone_toggle and not colour_cycle:
		return
	var target: bool = held
	if not target and is_instance_valid(WorldState.player):
		var pickup: player_pickup = WorldState.player.get_node_or_null("Controllers/Player_Pickup")
		if pickup != null and not pickup.is_holding_object() and pickup.ray != null:
			target = pickup.ray.get_looked_at() == self
	if target:
		if cone_toggle:
			set_beam_active(not beam_hood_active)
		else:
			cycle_lens()
		get_viewport().set_input_as_handled()

func set_beam_active(value: bool) -> void:
	if not beam_hood_enabled:
		return
	beam_hood_active = value
	_apply_power()
	WorldState.capture()
	DevTools.log_info("Light cone %s" % ("enabled" if value else "disabled"), "tools")

func _lens_prompt() -> prompt_entry:
	var entry := prompt_entry.new()
	entry.text = "Change Colour"
	entry.action = &"cycle_light_colour"
	entry.key_first = true
	return entry

func get_carry_prompts() -> prompt_set:
	return _append_light_prompts(super.get_carry_prompts())

func _append_light_prompts(base: prompt_set) -> prompt_set:
	var result := prompt_set.new()
	if base != null:
		result.entries.assign(base.entries)
	if coloured_lens_enabled:
		result.entries.append(_lens_prompt())
	if beam_hood_enabled:
		var cone := prompt_entry.new()
		cone.text = "Omni Light" if beam_hood_active else "Cone Light"
		cone.action = &"toggle_light_beam"
		cone.key_first = true
		result.entries.append(cone)
	return result

func get_look_prompts() -> prompt_set:
	return _append_light_prompts(super.get_look_prompts())
