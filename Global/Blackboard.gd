#a class for storing global system wide data and retrieving it
class_name blackboard
extends Node

#the actual data store for the information
var _data : Dictionary = {}

#used for storing or updating data
func store_data(key : String,data : Variant) -> void:
	_data[key] = data

#used for reading data out of the blackboard
func read_data(key : String) -> Variant:
	if(_data.has(key)):
		return _data[key]
	return null

#check if data exists
func data_exists(key : String) -> bool:
	return _data.has(key)

#return all data that has 'subkey' inside of its name
func return_set(subkey : String) -> Dictionary:
	var ret : Dictionary = {}
	for k in _data.keys():
		if k.begins_with(subkey):
			ret[k]=_data[k]
	return ret

#removes data from the list
func remove_data(key : String) -> void:
	_data.erase(key)
