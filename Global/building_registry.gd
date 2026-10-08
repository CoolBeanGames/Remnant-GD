extends Node

## Blackboard keeps this same Array instance; previews/packages never enter it.
var buildables: Array[buildable] = []


func _ready() -> void:
	Blackboard.store_data("buildables", buildables)


func register_building(building: buildable) -> void:
	if not buildables.has(building):
		buildables.append(building)


func unregister_building(building: buildable) -> void:
	buildables.erase(building)


func get_save_data() -> Array[Dictionary]:
	var records: Array[Dictionary] = []
	for building in buildables:
		if is_instance_valid(building) and not building.is_queued_for_deletion():
			records.append(building.get_save_data())
	return records
