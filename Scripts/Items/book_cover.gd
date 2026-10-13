@tool
class_name book_cover
extends Node3D

@export var sleeve: book_sleeve
@export var surface_size: Vector2 = Vector2(.228, .32)

func _ready() -> void:
	if sleeve == null:
		return
	if sleeve.artwork != null:
		var quad := QuadMesh.new()
		quad.size = surface_size
		var material := StandardMaterial3D.new()
		material.albedo_texture = sleeve.artwork
		material.albedo_color = sleeve.cover_color
		material.roughness = .9
		quad.material = material
		var face := MeshInstance3D.new()
		face.mesh = quad
		add_child(face)
	if not sleeve.title.is_empty():
		var label := Label3D.new()
		label.text = sleeve.title + ("\n" + sleeve.author if not sleeve.author.is_empty() else "")
		label.font_size = 32
		label.pixel_size = surface_size.x / 400
		label.width = surface_size.x / label.pixel_size
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.modulate = sleeve.ink_color
		label.shaded = true
		label.position.z = .002
		add_child(label)
	portal_space.apply_actor(self, bool(get_parent().get_meta("portal_inside", false)))
