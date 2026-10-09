@tool
extends EditorScenePostImport

## Keep the separate FBX meshes textured after Blender/Godot reimports.
func _post_import(scene: Node) -> Object:
	for mesh: MeshInstance3D in scene.find_children("*", "MeshInstance3D", true, false):
		var material_path := "res://Materials/Items/fan_" + str(mesh.name) + ".tres"
		if ResourceLoader.exists(material_path):
			mesh.material_override = load(material_path)
	return scene
