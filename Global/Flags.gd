#a system for storing (and reacting to) system flags
class_name flags
extends Node

#private flags data
var _flags : Dictionary[String,flag] = {}

#set a flag
func set_flag(key : String, state : bool = true, connection_set : Array[Callable] = [],connection_unset : Array[Callable] = []) -> void:
	if !_flags.has(key):
		#create our new flag
		var f : flag = flag.new()
		#add the data to the dictionary
		_flags[key] = f
		#connect signals
		_connect_flag(_flags[key],connection_set,connection_unset)
		
	
	#the state for the flag
	_flags[key].state = state
	#fire initial signals
	if _flags[key].state == true:
		_flags[key].flag_set.emit()
	else:
		_flags[key].flag_unset.emit()

#remove the flag from the system
func remove_flag(key : String) -> void:
	_flags.erase(key)

#check if a flag is set, if ti doesnt exist assume its false
func check_flag(key : String) -> bool:
	if _flags.has(key):
		return _flags[key].state
	return false

#connect to flag signals after the fact
func connect_to_flag(key : String, connection_set : Array[Callable] = [],connection_unset : Array[Callable] = [] ) -> void:
	if !_flags.has(key):
		#create our new flag
		var f : flag = flag.new()
		#add the data to the dictionary
		_flags[key] = f
		#the state for the flag
		_flags[key].state = false
	#connect if the flag already exists
	_connect_flag(_flags[key],connection_set,connection_unset)


#region Helpers
#helper function for connecting flags
func _connect_flag(
	f: flag,
	connection_set: Array[Callable],
	connection_unset: Array[Callable]
) -> void:

	for cs in connection_set:
		if cs.is_valid() and !f.flag_set.is_connected(cs):
			f.flag_set.connect(cs)

	for cs in connection_unset:
		if cs.is_valid() and !f.flag_unset.is_connected(cs):
			f.flag_unset.connect(cs)
#endregion
