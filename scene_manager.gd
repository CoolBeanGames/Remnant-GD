class_name scene_manager
extends Node

var game_root : Node 
var loaded_scenes : Dictionary[StringName, scene_def] = {} 
var loaded_bundles : Dictionary[StringName, Array] = {}

func load_scene(scn : PackedScene, access_name : StringName, bundle : StringName = "", parent : Node = game_root) -> Node:
	if loaded_scenes.has(access_name) or check_bundles(access_name):
		push_error("ERROR[001]: the scene list already has a scene with the given name, choose a new name or unload the previous scene")
		return null
	
	if parent == null:
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
	return nd

func scene_exists(access_name : StringName) -> bool:
	return loaded_scenes.has(access_name) or check_bundles(access_name)

func check_bundles(access_name : StringName) -> bool:
	for key in loaded_bundles.keys():
		for def in loaded_bundles[key]:
			if def.name == access_name:
				return true
	return false

func add_scene(access_name : StringName, def : scene_def):
	loaded_scenes[access_name] = def

func add_bundle(bundle : StringName, def : scene_def):
	if loaded_bundles.has(bundle):
		loaded_bundles[bundle].append(def)
	else:
		var new_bundle : Array[scene_def] = [def]
		loaded_bundles[bundle] = new_bundle

func unload_scene(access_name : StringName):
	if loaded_scenes.has(access_name):
		loaded_scenes[access_name].node.queue_free()
		loaded_scenes.erase(access_name)
		print("Scene unloaded: " + access_name)
		return
	
	for key in loaded_bundles.keys():
		var bundle_arr = loaded_bundles[key]
		for i in range(bundle_arr.size()):
			if bundle_arr[i].name == access_name:
				bundle_arr[i].node.queue_free()
				bundle_arr.remove_at(i)
				print("Scene unloaded from bundle: " + access_name)
				return
				
	push_error("ERROR[002]: attempted to unload a scene that was not loaded")

func get_scene(access_name : StringName) -> Node:
	if loaded_scenes.has(access_name):
		return loaded_scenes[access_name].node
		
	for key in loaded_bundles.keys():
		for def in loaded_bundles[key]:
			if def.name == access_name:
				return def.node
				
	return null

func _create_scene_def(scn : PackedScene) -> scene_def:
	var def : scene_def = scene_def.new()
	def.asset = scn
	return def
