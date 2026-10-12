class_name note_definition
extends Resource

@export var id: StringName
@export var title: String = "Untitled note"
@export_multiline var body: String = ""

@export_category("Physical reading")
## Optional artist-made Node3D, oriented with its readable face toward +Z.
@export var reading_scene: PackedScene
## Optional scanned/written face for the default paper.
@export var page_texture: Texture2D
@export var reading_pose: Transform3D = Transform3D.IDENTITY

func snapshot() -> Dictionary:
	return {"id": str(id), "title": title, "body": body, "definition_path": resource_path, "reading_scene_path": reading_scene.resource_path if reading_scene != null else "", "page_texture_path": page_texture.resource_path if page_texture != null else ""}
