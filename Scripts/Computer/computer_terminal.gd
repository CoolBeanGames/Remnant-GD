class_name computer_terminal
extends StaticBody3D

@export var catalog: computer_catalog
@export var player: CharacterBody3D
@export var delivery_point: Node3D
@export var delivery_parent: Node
@export var interface_scene: PackedScene = preload("res://Scenes/UI/computer_ui.tscn")
@export var enabled: bool = true
@export var display_resolution: Vector2i = Vector2i(1024, 768)
## Minimum distance; screen fit also accounts for viewport shape and mesh scale.
@export_range(.12, 2, .01) var viewing_distance: float = .18
@export_range(20, 75, 1) var viewing_fov: float = 35
@export_range(.5, .95, .01) var screen_coverage: float = .88
@export_group("View Motion")
@export_range(0, 2, .05) var focus_seconds: float = .55
@export_range(0, 2, .05) var return_seconds: float = .40
var closing: bool = false
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
	session.move_camera(self, focus_pose(camera), focus_seconds, Callable(), viewing_fov)
	interface.open(self)
	display_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	screen_material.albedo_color = Color.WHITE
	screen_material.albedo_texture = display_viewport.get_texture()
	$Text.hide()
	DevTools.log_info("Connected to in-world terminal.", "computer")

func focus_pose(camera: Camera3D) -> Transform3D:
	var viewport_size: Vector2 = camera.get_viewport().get_visible_rect().size
	var aspect: float = viewport_size.x / maxf(1, viewport_size.y)
	var tangent: float = tan(deg_to_rad(viewing_fov) * .5)
	var tangent_y: float = tangent if camera.keep_aspect == Camera3D.KEEP_HEIGHT else tangent / aspect
	var tangent_x: float = tangent_y * aspect
	var size: Vector2 = (screen.mesh as QuadMesh).size * Vector2(screen.global_basis.x.length(), screen.global_basis.y.length())
	var distance: float = maxf(viewing_distance, maxf(size.x / (2 * tangent_x * screen_coverage), size.y / (2 * tangent_y * screen_coverage)))
	var facing: Basis = screen.global_basis.orthonormalized()
	return Transform3D(facing, screen.global_position + facing.z * distance)

func close_interface(immediate: bool = false) -> void:
	if session == null:
		return
	if immediate or not is_inside_tree():
		_finish_close()
		return
	if closing:
		return
	closing = true
	if is_instance_valid(interface):
		interface.suspend(true)
	# Keep the display visible and input owned while the camera eases back.
	session.move_camera(self, session.pose, return_seconds, _finish_close, session.original_camera_fov)

func _finish_close() -> void:
	if session == null:
		return
	if is_instance_valid(interface):
		interface.suspend()
	if is_instance_valid(display_viewport):
		display_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
		if pointer_inside:
			display_viewport.notify_mouse_exited()
	pointer_inside = false
	screen_material.albedo_texture = null
	screen_material.albedo_color = Color(.01, .08, .03)
	$Text.visible = enabled
	session.restore()
	session = null
	closing = false
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
	if session == null or not is_instance_valid(interface) or DevTools.any_modal_open() or get_tree().paused:
		return
	# Global development shortcuts belong to the root viewport, not the PC UI.
	if event is InputEventKey and (event.keycode in [KEY_F1, KEY_F2, KEY_F3, KEY_F4, KEY_F5, KEY_F6, KEY_F7, KEY_F9, KEY_QUOTELEFT] or event.physical_keycode in [KEY_F1, KEY_F2, KEY_F3, KEY_F4, KEY_F5, KEY_F6, KEY_F7, KEY_F9, KEY_QUOTELEFT]):
		return
	if event is InputEventKey and event.pressed and not event.echo and (event.keycode == KEY_ESCAPE or event.physical_keycode == KEY_ESCAPE):
		close_interface()
		get_viewport().set_input_as_handled()
		return
	if closing or session.is_moving():
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
		close_interface(true)

func _exit_tree() -> void:
	close_interface(true)
