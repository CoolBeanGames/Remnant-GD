extends Node

var loaded_scenes : Dictionary[StringName, scene_def] = {}
var loaded_bundles : Dictionary = {}


func load_scene(
	scn : PackedScene,
	access_name : StringName,
	bundle : StringName = "",
	parent : Node = null
) -> Node:
	
	if scn == null:
		push_error("Cannot load an empty scene.")
		DevTools.log_error("Cannot load empty scene '%s'." % access_name, "scene")
		return null
	if scene_exists(access_name):
		push_error("ERROR[001]: the scene list already has a scene with the given name, choose a new name or unload the previous scene")
		return null
	
	#use the game root from the blackboard if no parent was provided
	if not is_instance_valid(parent):
		parent = Blackboard.read_data("game_root")
	
	#if the game root wasn't found, fall back to the scene tree root
	if not is_instance_valid(parent):
		parent = get_tree().root
	
	var def : scene_def = _create_scene_def(scn)
	def.name = access_name
	
	var nd : Node = scn.instantiate()
	parent.add_child(nd)
	def.node = nd
	
	if bundle == "":
		add_scene(access_name, def)
	else:
		add_bundle(bundle, def)
	
	print("loaded scene: " + access_name)
	DevTools.log_info("Loaded scene '%s'." % access_name, "scene")
	return nd


func scene_exists(access_name : StringName) -> bool:
	return is_instance_valid(get_scene(access_name))


func check_bundles(access_name : StringName) -> bool:
	for key in loaded_bundles.keys():
		for def in loaded_bundles[key]:
			if def.name == access_name:
				return is_instance_valid(def.node) and not def.node.is_queued_for_deletion()
	
	return false


func add_scene(access_name : StringName, def : scene_def) -> void:
	loaded_scenes[access_name] = def


func add_bundle(bundle : StringName, def : scene_def) -> void:
	if loaded_bundles.has(bundle):
		loaded_bundles[bundle].append(def)
	else:
		var new_bundle : Array[scene_def] = [def]
		loaded_bundles[bundle] = new_bundle


func unload_scene(access_name : StringName) -> void:
	if loaded_scenes.has(access_name):
		if is_instance_valid(loaded_scenes[access_name].node):
			loaded_scenes[access_name].node.queue_free()
		loaded_scenes.erase(access_name)
		print("Scene unloaded: " + access_name)
		return
	
	for key in loaded_bundles.keys():
		var bundle_arr : Array[scene_def] = loaded_bundles[key]
		
		for i in range(bundle_arr.size()):
			if bundle_arr[i].name == access_name:
				if is_instance_valid(bundle_arr[i].node):
					bundle_arr[i].node.queue_free()
				bundle_arr.remove_at(i)
				
				#remove the bundle if it is now empty
				if bundle_arr.is_empty():
					loaded_bundles.erase(key)
				
				print("Scene unloaded from bundle: " + access_name)
				return
	
	push_error("ERROR[002]: attempted to unload a scene that was not loaded")


func get_scene(access_name : StringName) -> Node:
	if loaded_scenes.has(access_name):
		var node: Variant = loaded_scenes[access_name].node
		if is_instance_valid(node) and not node.is_queued_for_deletion():
			return node
		loaded_scenes.erase(access_name)
	
	for key in loaded_bundles.keys():
		for def in loaded_bundles[key]:
			if def.name == access_name:
				if is_instance_valid(def.node) and not def.node.is_queued_for_deletion():
					return def.node
				loaded_bundles[key].erase(def)
				if loaded_bundles[key].is_empty():
					loaded_bundles.erase(key)
				return null
	
	return null


func _create_scene_def(scn : PackedScene) -> scene_def:
	var def : scene_def = scene_def.new()
	def.asset = scn
	return def
