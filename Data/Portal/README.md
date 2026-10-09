# Doorway room test

Run the normal game. Leave the initial room and look away until it disappears. The retained Strange Door now links to a small room at `(1600, 0, 0)`. Open it with E and walk through; the door inside returns to the workshop. Approaching from behind or walking around it cannot reveal or enter the room.

Edit `Scenes/Portal/sky_test_room.tscn` to change the test area. `Scenes/testing_level.tscn` has a DoorPortal node with adjustable destination_scene, sky_position, aperture, source_offset, resolution_scale and room_environment. These are independent of the initial room's disappearance rules. Activation listens to the existing `exited room` flag, including startup restoration.

Replacement room scenes must have a direct child named Entrance. Its origin is the centre of the doorway, its positive local Z points into the room, and its Y is the aperture's centre height. Put the room floor at local Y zero. The test doorway centre is 1.7195 metres above the floor. The runtime return door aligns to this marker using source_offset.

Render and physics layer 20 are reserved for the destination. Runtime setup applies this layer recursively to the room and transferred objects, removes it from the outside player camera and lights, and updates the player's physics, interaction ray and placement queries when crossing. Do not use layer 20 for workshop objects. Destination lighting is supplied by its own lights and `Data/Portal/sky_environment.tres`.

Held props, basket contents, attached props and tracked thrown items can cross. Motion and orientation map between the two entrance frames. Automatic spawner output inherits its space. Blackboard `portal_inside`, player transform and spawned_items records restore the player and items to their appropriate space; this remains in-memory state, not disk saving.

This is a single doorway prototype using one perspective-matched SubViewport and a screen-coordinate portal shader. It does not implement recursive portals or interaction rays through the doorway before crossing. Keep destination geometry behind its entrance plane. The return door mirrors the original door's animation, prompts and optional sound settings.

## Script API

| Path / class | Inheritance / autoload | Configuration and state | API / signals |
|---|---|---|---|
| Scripts/Portal/door_portal.gd / door_portal | Node3D / none | Exported door, player, destination_scene, return_door_scene, sky_position, activation_flag, source_offset, aperture, resolution_scale, room_environment. Runtime active, inside, pending, room, entrance frames, view surfaces, viewport/camera, original camera settings, previous camera/body positions. | request_activation(), activate(), mapping(from,to) -> Transform3D, crosses_aperture(frame,previous,current) -> bool, teleport_player(pose_map). Signal crossed(inside: bool). Lifecycle creates, updates and tears down views; tracked loose bodies transfer during physics. |
| Scripts/Portal/portal_space.gd / portal_space | RefCounted / none | Constant ROOM_LAYER = 1 << 19. Actor metadata portal_inside, collision_space_mask and cached original render/light masks. No exports/signals. | Static remap_mask(bits,inside) -> int and apply_actor(actor,inside) recursively remap space. |
| Scripts/Portal/portal_return_door.gd / portal_return_door | Node3D / none | Runtime target: start_room_door and animation: AnimationPlayer. No exports/signals. | interact(), get_look_prompts() -> prompt_set, sync_animation(). Creates raw model collision/proxy prompts and mirrors target animation. |

Godot-generated `.gd.uid` files beside these scripts identify them; none is an autoload. Dependencies: Player/Camera3D and existing controller paths, Flags, Blackboard, WorldState, Audio, original start_room_door, the raw doorway GLB, the destination scene and portal_view shader.

Related API: player_pickup.teleport_held(pose_map,inside) maps held assemblies and their saved collision states; basket.portal_transform_contents(pose_map,inside) updates containment reference pose and drop masks; WorldState.spawn_item(scene,parent,pose,apply_value=false,inside_portal=false) can create an item directly in the destination space.

`Tests/door_portal_test.tscn` covers gated activation, camera/layer isolation, doorway bounds, real walking and thrown-item crossing, basket/attachment transfer, return controls, destination floor, spawner output and startup restoration.

Script identities: `door_portal.gd`: `uid://bt22t5fy4mlpu`, `portal_space.gd`: `uid://cukcn0vyejk4g`, `portal_return_door.gd`: `uid://ovsxfk8wogvk`.

The portal render texture uses linear HDR on Forward+/Mobile to avoid a second colour-space conversion. Its resolution defaults to 1.0 and MSAA/camera attributes mirror the player view; Compatibility keeps its supported rendering path. The doorway and direct room views were compared at the same camera pose to verify colour continuity.

The destination is horizontally separated at the workshop floor height. `door_portal.set_suspended(value)` temporarily disables rendering and crossings during a concrete-room respawn; `suspended` defaults false. The room remains isolated on layer 20.

Main-world WorldBoundary sits 500 m from the authored player start on each axis; the remote destination at X1600 is beyond it. Future rooms should be placed 1500+ m away. Portal actors use layer 20 and do not collide with the layer-1 boundary.
