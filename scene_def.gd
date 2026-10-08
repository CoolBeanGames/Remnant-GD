#this class holds data that defines a single scene
class_name scene_def

var name: StringName
var node : 	Node 		#the node this scene points to
var type :  node_type 	#the type of node this is
var asset : PackedScene #the packed scene used to load this

enum node_type
{
	ui,
	actor
	} 
