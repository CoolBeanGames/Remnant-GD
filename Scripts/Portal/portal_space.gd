class_name portal_space
extends RefCounted

const ROOM_LAYER: int = 1 << 19

static func remap_mask(bits: int, inside: bool) -> int:
	var from: int = 1 if inside else ROOM_LAYER
	var to: int = ROOM_LAYER if inside else 1
	return (bits & ~from) | (to if bits & from else 0)

static func apply_actor(actor: Node, inside: bool) -> void:
	actor.set_meta("portal_inside", inside)
	actor.set_meta("collision_space_mask", ROOM_LAYER if inside else 1)
	if actor is VisualInstance3D:
		if not actor.has_meta("portal_original_layers"):
			actor.set_meta("portal_original_layers", actor.layers)
		var layers: int = ROOM_LAYER if inside else int(actor.get_meta("portal_original_layers"))
		var light_mask: int = 0
		if actor is Light3D:
			if not actor.has_meta("portal_original_light_mask"):
				actor.set_meta("portal_original_light_mask", actor.light_cull_mask)
			light_mask = ROOM_LAYER if inside else int(actor.get_meta("portal_original_light_mask")) & ~ROOM_LAYER
		if actor.layers != layers or (actor is Light3D and actor.light_cull_mask != light_mask):
			# Godot 4.7 can retain stale light pairs when a live instance changes layers.
			# Unpair in its old state, then rejoin the same world with the new masks.
			var scenario: RID = actor.get_world_3d().scenario if actor.is_inside_tree() else RID()
			if scenario.is_valid():
				RenderingServer.instance_set_scenario(actor.get_instance(), RID())
			actor.layers = layers
			if actor is Light3D:
				actor.light_cull_mask = light_mask
			if scenario.is_valid():
				RenderingServer.instance_set_scenario(actor.get_instance(), scenario)
	if actor is CollisionObject3D:
		actor.collision_layer = remap_mask(actor.collision_layer, inside)
		actor.collision_mask = remap_mask(actor.collision_mask, inside)
	for child in actor.get_children():
		apply_actor(child, inside)
