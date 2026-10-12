class_name computer_terminal
extends StaticBody3D

@export var catalog: computer_catalog
@export var player: CharacterBody3D
@export var delivery_point: Node3D
@export var delivery_parent: Node
@export var interface_scene: PackedScene = preload("res://Scenes/UI/computer_ui.tscn")
@export var enabled: bool = true
@export var display_resolution: Vector2i = Vector2i(1024, 768)
@export_range(.35, 2, .01) var viewing_distance: float = .60
var interface: Control
var display_viewport: SubViewport
var session: world_view_session
var pointer_inside: bool = false
var last_pointer: Vector2 = Vector2.ZERO
@onready var screen: MeshInstance3D = $Screen
@onready var screen_material: StandardMaterial3D = screen.mesh.material.duplicate()

func _ready() -> void:
	add_to_group("interact")
	screen.material_override = screen_material
	Progression.register_catalog(catalog)
	Progression.apply_player(player)
	set_enabled(enabled)

func interact() -> void:
	if not enabled or Blackboard.read_data("player_input_blocked") or interface_scene == null:
		return
	_open_interface.call_deferred()

func _open_interface() -> void:
	if not enabled or Blackboard.read_data("player_input_blocked") or not is_instance_valid(player):
		return
	var camera: Camera3D = player.get_node_or_null("Camera3D")
	if camera == null:
		return
	if not is_instance_valid(interface):
		display_viewport = SubViewport.new()
		display_viewport.name = "DisplayViewport"
		display_viewport.size = display_resolution
		display_viewport.disable_3d = true
		display_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
		add_child(display_viewport)
		interface = interface_scene.instantiate()
		display_viewport.add_child(interface)
	session = world_view_session.new()
	session.begin(camera, false)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var facing: Basis = screen.global_basis.orthonormalized()
	camera.global_transform = Transform3D(facing, screen.global_position + facing.z * viewing_distance)
	interface.open(self)
	display_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	screen_material.albedo_color = Color.WHITE
	screen_material.albedo_texture = display_viewport.get_texture()
	$Text.hide()
	DevTools.log_info("Connected to in-world terminal.", "computer")

func close_interface() -> void:
	if session == null:
		return
	if is_instance_valid(interface):
		interface.suspend()
	if is_instance_valid(display_viewport):
		display_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	screen_material.albedo_texture = null
	screen_material.albedo_color = Color(.01, .08, .03)
	$Text.visible = enabled
	if session != null:
		session.restore()
	session = null
	DevTools.log_info("Disconnected from in-world terminal.", "computer")

## Map window pixels onto the real display quad, including perspective/rotation.
func screen_pointer(window_position: Vector2) -> Vector2:
	if session == null or not is_instance_valid(session.camera):
		return Vector2(-1, -1)
	var camera: Camera3D = session.camera
	var ray_origin: Vector3 = camera.project_ray_origin(window_position)
	var ray_direction: Vector3 = camera.project_ray_normal(window_position)
	var normal: Vector3 = screen.global_basis.z.normalized()
	if ray_direction.dot(normal) >= -.0001:
		return Vector2(-1, -1)
	var hit: Variant = Plane(normal, screen.global_position).intersects_ray(ray_origin, ray_direction)
	if hit == null:
		return Vector2(-1, -1)
	var local: Vector3 = screen.to_local(hit)
	var size: Vector2 = (screen.mesh as QuadMesh).size
	var uv: Vector2 = Vector2(local.x / size.x + .5, .5 - local.y / size.y)
	if uv.x < 0 or uv.x > 1 or uv.y < 0 or uv.y > 1:
		return Vector2(-1, -1)
	return uv * Vector2(display_viewport.size)

func _input(event: InputEvent) -> void:
	if not is_instance_valid(interface) or not interface.is_open or DevTools.any_modal_open() or get_tree().paused:
		return
	if event is InputEventKey and event.pressed and not event.echo and (event.keycode == KEY_ESCAPE or event.physical_keycode == KEY_ESCAPE):
		close_interface()
		get_viewport().set_input_as_handled()
		return
	if event is InputEventMouse:
		var point: Vector2 = screen_pointer(event.position)
		if point.x < 0:
			if pointer_inside:
				display_viewport.notify_mouse_exited()
				pointer_inside = false
			return
		if not pointer_inside:
			display_viewport.notify_mouse_entered()
			pointer_inside = true
		var mapped: InputEventMouse = event.duplicate()
		mapped.position = point
		mapped.global_position = point
		if mapped is InputEventMouseMotion:
			mapped.relative = point - last_pointer
		last_pointer = point
		display_viewport.push_input(mapped, true)
		get_viewport().set_input_as_handled()
	elif event is InputEventKey:
		display_viewport.push_input(event, true)
		get_viewport().set_input_as_handled()

func buy(entry: computer_entry) -> String:
	if not enabled:
		return "Computer offline."
	var parent: Node = delivery_parent if is_instance_valid(delivery_parent) else get_parent()
	return Progression.purchase(entry, parent, delivery_point, player)

func set_enabled(value: bool) -> void:
	enabled = value
	set_meta("interaction_enabled", value)
	$Screen.visible = value
	$OfflineScreen.visible = not value
	$Text.visible = value
	if not value:
		close_interface()

func _exit_tree() -> void:
	close_interface()
