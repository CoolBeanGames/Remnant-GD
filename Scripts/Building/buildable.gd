class_name buildable
extends StaticBody3D

@export var definition: buildable_definition
var save_id: String = ""


func _ready() -> void:
	add_to_group("building")
	if definition == null:
		push_warning("Building has no definition; it cannot be saved or packed.")
		return
	if save_id.is_empty():
		save_id = "%s-%s" % [Time.get_ticks_usec(), randi()]
	Buildings.register_building(self)


func _exit_tree() -> void:
	Buildings.unregister_building(self)


## Plain values ready for JSON; file writing/loading is left to a save system.
func get_save_data() -> Dictionary:
	var pose: Transform3D = global_transform
	return {
		"save_id": save_id,
		"definition": definition.resource_path,
		"buildable_id": String(definition.id),
		"position": [pose.origin.x, pose.origin.y, pose.origin.z],
		"basis": [
			pose.basis.x.x, pose.basis.x.y, pose.basis.x.z,
			pose.basis.y.x, pose.basis.y.y, pose.basis.y.z,
			pose.basis.z.x, pose.basis.z.y, pose.basis.z.z
		]
	}
