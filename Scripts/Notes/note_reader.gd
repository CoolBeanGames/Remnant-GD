class_name note_reader
extends Node

signal closed(note: Dictionary, return_to_journal: bool)
@export var camera: Camera3D
@export var toggle_key: Key = KEY_N
@export var paper_size: Vector2 = Vector2(.36, .45)
@export var paper_distance: float = .48
@export_range(.05, 2, .05) var reading_light_energy: float = .6
const READING_LAYER: int = 1 << 18
var is_open: bool = false
var typed: bool = false
var current_note: Dictionary = {}
var from_journal: bool = false
var session: world_view_session
var holder: Node3D
var print_text: RichTextLabel
var page_viewport: SubViewport
var light_masks: Array[Dictionary] = []
@onready var transcript: CanvasLayer = $Transcript
@onready var title_label: Label = $Transcript/Screen/Center/Panel/Margin/Rows/Header/Title
@onready var body_label: RichTextLabel = $Transcript/Screen/Center/Panel/Margin/Rows/Body

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	Notes.note_read.connect(_on_collected)
	Blackboard.store_data("note_reader", self)
	$Transcript/Screen/Center/Panel/Margin/Rows/Header/Close.pressed.connect(toggle_transcript)
	transcript.hide()

func _on_collected(note: Dictionary) -> void:
	open_note.call_deferred(note, false)

func _definition(note: Dictionary) -> note_definition:
	var path: String = str(note.get("definition_path", ""))
	if not path.is_empty() and ResourceLoader.exists(path):
		return load(path) as note_definition
	var catalog: note_catalog = load("res://Data/Notes/default_catalog.tres")
	for definition in catalog.notes:
		if definition != null and str(definition.id) == str(note.get("id", "")):
			return definition
	return null

func open_note(note: Dictionary, return_to_journal: bool = false) -> bool:
	if note.is_empty() or not is_instance_valid(camera) or DevTools.any_modal_open():
		return false
	if is_open:
		close(false)
	elif Blackboard.read_data("player_input_blocked") == true:
		return false
	current_note = note.duplicate(true)
	from_journal = return_to_journal
	session = world_view_session.new()
	session.begin(camera, true)
	camera.cull_mask |= READING_LAYER
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	is_open = true
	typed = false
	_create_paper(_definition(note))
	title_label.text = str(note.get("title", "NOTE"))
	body_label.text = str(note.get("body", ""))
	body_label.scroll_to_line(0)
	DevTools.log_info("Opened physical note / %s" % note.get("id", ""), "notes")
	return true

func _create_paper(definition: note_definition) -> void:
	holder = Node3D.new()
	holder.name = "HeldReadingNote"
	camera.add_child(holder)
	holder.position = Vector3(0, -.02, -paper_distance)
	# Only its dedicated lamp illuminates the paper; world lights cannot wash it out.
	for light in get_tree().root.find_children("*", "Light3D", true, false):
		light_masks.append({"node": weakref(light), "mask": light.light_cull_mask})
		light.light_cull_mask &= ~READING_LAYER
	var art: Node3D
	if definition != null and definition.reading_scene != null:
		var instance: Node = definition.reading_scene.instantiate()
		if instance is Node3D:
			art = instance
			art.transform = definition.reading_pose
		else:
			instance.free()
	if art == null:
		var sheet := MeshInstance3D.new()
		var quad := QuadMesh.new()
		quad.size = paper_size
		var material := StandardMaterial3D.new()
		material.roughness = 1
		material.metallic_specular = 0
		material.disable_ambient_light = true
		material.disable_receive_shadows = true
		material.cull_mode = BaseMaterial3D.CULL_DISABLED
		if definition != null and definition.page_texture != null:
			material.albedo_texture = definition.page_texture
		else:
			material.albedo_texture = _printed_page()
		quad.material = material
		sheet.mesh = quad
		sheet.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		art = sheet
	holder.add_child(art)
	_prepare_art(art)
	var light := OmniLight3D.new()
	light.name = "ReadingLight"
	holder.add_child(light)
	light.position = Vector3(0, .12, .28)
	light.light_color = Color(1, .95, .84)
	light.light_energy = reading_light_energy
	light.light_specular = 0
	light.light_cull_mask = READING_LAYER
	light.omni_range = 1.1
	light.omni_attenuation = .4

func _prepare_art(node: Node) -> void:
	# Artist supplied art is a display copy, never a scored/colliding world actor.
	if node is VisualInstance3D:
		node.layers = READING_LAYER
	if node is MeshInstance3D and node.mesh != null:
		for surface in node.mesh.get_surface_count():
			var source: Material = node.get_active_material(surface)
			if source is StandardMaterial3D:
				var matte: StandardMaterial3D = source.duplicate()
				matte.disable_ambient_light = true
				matte.metallic_specular = 0
				matte.roughness = maxf(.8, matte.roughness)
				node.set_surface_override_material(surface, matte)
	if node is CollisionObject3D:
		node.collision_layer = 0
		node.collision_mask = 0
	if node is RigidBody3D:
		node.freeze = true
	for child in node.get_children():
		_prepare_art(child)

func _printed_page() -> ViewportTexture:
	page_viewport = SubViewport.new()
	page_viewport.size = Vector2i(640, 896)
	page_viewport.disable_3d = true
	page_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	add_child(page_viewport)
	var page := ColorRect.new()
	page.color = Color(.84, .81, .70)
	page.size = Vector2(page_viewport.size)
	page_viewport.add_child(page)
	print_text = RichTextLabel.new()
	page.add_child(print_text)
	print_text.position = Vector2(44, 50)
	print_text.size = Vector2(552, 790)
	print_text.bbcode_enabled = false
	print_text.scroll_active = true
	print_text.add_theme_color_override("default_color", Color(.035, .035, .027))
	print_text.add_theme_font_size_override("normal_font_size", 30)
	print_text.text = str(current_note.get("title", "NOTE")) + "\n\n" + str(current_note.get("body", ""))
	return page_viewport.get_texture()

func toggle_transcript() -> void:
	if not is_open:
		return
	typed = not typed
	transcript.visible = typed
	holder.visible = not typed
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if typed else Input.MOUSE_MODE_CAPTURED
	if typed:
		body_label.grab_focus()

func close(notify: bool = true) -> void:
	if not is_open:
		return
	is_open = false
	typed = false
	transcript.hide()
	if is_instance_valid(holder):
		holder.free()
	holder = null
	if is_instance_valid(page_viewport):
		page_viewport.free()
	page_viewport = null
	print_text = null
	for state in light_masks:
		var light: Light3D = state.node.get_ref() as Light3D
		if is_instance_valid(light):
			light.light_cull_mask = state.mask
	light_masks.clear()
	session.restore()
	session = null
	var finished: Dictionary = current_note
	var back: bool = from_journal
	current_note = {}
	from_journal = false
	if notify:
		Notes.note_read_finished.emit(finished)
		closed.emit(finished, back)

func _input(event: InputEvent) -> void:
	if DevTools.any_modal_open():
		return
	if is_open and not typed and is_instance_valid(print_text) and event is InputEventMouseButton and event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
		var direction: int = -1 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 1
		print_text.get_v_scroll_bar().value += direction * 90
		page_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
		get_viewport().set_input_as_handled()
		return
	if DevTools.any_modal_open() or not event is InputEventKey or not event.pressed or event.echo:
		return
	var key: int = event.physical_keycode if event.physical_keycode != 0 else event.keycode
	if key == toggle_key:
		if is_open:
			toggle_transcript()
		elif not get_tree().paused and not Blackboard.read_data("player_input_blocked"):
			var notes: Array[Dictionary] = Notes.all_notes()
			if not notes.is_empty() and open_note(notes.back()):
				toggle_transcript()
		get_viewport().set_input_as_handled()
	elif is_open and key == KEY_ESCAPE:
		if typed:
			toggle_transcript()
		else:
			close()
		get_viewport().set_input_as_handled()

func _exit_tree() -> void:
	close(false)
	if Blackboard.read_data("note_reader") == self:
		Blackboard.remove_data("note_reader")
