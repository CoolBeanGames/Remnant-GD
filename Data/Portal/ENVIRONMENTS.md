# Portal environment authoring

## In-game test

After leaving the concrete room and letting it vanish unseen, buy Memory 1/2/3 at the computer for its apartment/warehouse/hospital portal. E opens the retained Strange Door. Unfinished paid memories permit two-way travel and retain their portal for reentry. Only a completed return closes the portal and safely evacuates saved cargo. Completion flags also gate further memory purchases. See Data/Computer/MEMORY_UPGRADES.md. F9 remains an explicit debug preview even while a paid memory is unfinished; it preserves purchased ownership/completion and it selects apartment, warehouse, hospital, then wraps. The destination is stored in the Blackboard; a brief text-only portal status confirms the destination. F9 is a host gameplay shortcut, not an addon modal. Menus/wake-up/respawn room/keyboard repeat cannot activate it. Later story triggers can call DoorPortal.select_destination(&"hospital") and await destination_changed.

## Editable scene files

| Destination | Engine scene | Art instances | Features |
| --- | --- | --- | --- |
| Apartment | Scenes/Environments/furnished_apartment.tscn | 19 | Worn shell, all 18 furniture assets, short entrance vestibule, open entry leaf, bathroom access |
| Warehouse | Scenes/Environments/dilapidated_warehouse.tscn | 17 | Machines, all 24 stair treads, 4.2 m catwalk and accessible furnished office |
| Hospital | Scenes/Environments/dilapidated_hospital.tscn | 50 | Six wards, treatment room, nursing counter and rear staff passage, beds, cabinets, chairs, equipment |

Each scene has a portal_room root, Entrance Marker3D, Art instances, Lighting and optional entrance landing. Entry markers face the native south/front openings (local +Z into the building, floor Y=0, centre Y=1.7195). Every imported model keeps textures, original metre scale, hierarchy and transforms mapped from the Blender manifests: (x,y,z) → (x,z,-y), Z rotation → Y rotation. Original .blend/GLB files remain independently editable.

The apartment's small native doorway uses a short exterior vestibule for the taller existing story door. An engine-only pose override opens its leaf to 94 degrees; the native model is unchanged. The player capsule now uses a 0.35 m radius with an explicit 1.8 m height and 1.65 m eye height, allowing ordinary doorways without walking through visible walls. The camera/controller/support systems are retained. Objects and scenery use actual solid geometry, not enlarged targeting volumes.

## Collision bake / lighting

Scenes/Environments/Art/ contains **35 shared model wrappers**, each instancing its original GLB and a Solid StaticBody3D. Collision/ contains corresponding versioned ConcavePolygonShape3D resources. Opaque solid triangles are merged once per unique asset, excluding transparent grime/blood/print/decal meshes and degenerate faces. Shapes are baked before runtime and reused by beds, cabinets and repeated machines. Backface collision is enabled for thin sheet geometry. The static material has 0.95 friction; collider groups include Floor for the existing audio/contact system.

Run the installed Godot editor import, then `Godot --headless --path . --script Tools/bake_portal_environments.gd` to rebuild wrappers/rooms from the Blender assembly manifests. The builder uses typed GDScript, original packed models and ResourceSaver; no Blender remodelling or texture generation is needed. It writes Art/Collision and all three scenes. This is a generated base: keep later designer overrides in inherited scenes or update the builder before regenerating. Never commit .godot import caches.

Lighting stays separate under Lighting. The apartment uses Data/Portal/apartment_environment.tres and dim amber fixtures. Warehouse/hospital have no powered Light3D fixtures and use Data/Portal/dark_environment.tres (black background, zero ambient). portal_room.suppress_player_light disables the automatic camera lamp while inside; physical carried/built lights remain available. Settings registration preserves authored SSAO, render scale, AA and shadows. Room-layer lights do not illuminate workshop actors. Door audio remains on the existing Audio pool. Required E furniture/machine interactions and look-only flavor are authored through reusable memory_object resources; Data/Dialogue/MEMORY_TRIGGERS.md lists exact 3/5/4 objectives and saved completion flags. Static imported art is not registered as a spawned/scoring item.

## Persistence / switching

Data/Portal/{apartment,warehouse,hospital}.tres are editable definitions. Rendered DoorPortal instances warm their PackedScene resources sequentially in the background. No unused room is instantiated; only one destination becomes live. Headless tools load on demand because the dummy renderer cannot safely allocate shared mesh RIDs on loader threads. In-flight loads are joined on teardown. Give new entries unique stable ids and point scene_path at an exported .tscn. Add them to DoorPortal.destinations in testing_level. Scene paths work with the existing all_resources export preset. Roots and Entrance markers must inherit Node3D; inherited room scenes are supported.

Selection stores portal_destination_id in the Blackboard. Player/items remain in the existing single-save workflow. F9 from inside returns the player/held contraption outside the workshop door; other saved items are evacuated to workshop space before old scenery is freed. A prop attached to old static room scenery detaches; attachments to retained items stay together. PackedScene resources are cached; instantiated rooms are freed and do not accumulate their old furniture. The safe replacement validator keeps the prior room on bad input. The concrete-room respawn still suspends the portal until that room is unseen.

## Verification

Use Tests/portal_destinations_test.tscn for actual capsule movement, inventory/layer restoration, real input, destination persistence and failure recovery. Existing door_portal_test keeps its small-room fixture explicitly; portal_assembly, graphics_options, rail_player, prop_placement, carry_attachment, wake_up and player_voice cover shared regressions. Isolate APPDATA and inspect error/warning logs even on exit 0.

Tests/portal_destinations_visual_test.tscn runs with a real renderer and writes Reports/PortalEnvironments/*.png. The gallery includes doorway/direct poses, furnished interiors, the warehouse catwalk, hospital ward and station. Review every capture; headless physics does not prove lighting/material appearance. Portal rendering is perspective/HDR matched but is not recursive or a remote interaction ray. Baked furniture retains its solid geometry; selected wrappers now provide E story prompts and independent look-only flavor. Tests/memory_triggers_test.tscn verifies all required objectives and completion travel.

Windows delivery also passed editor import, release export and an isolated 90-frame exported startup. An additional rendered probe loaded the release Remnant.pck with the matching Godot 4.7.2 console engine, exercised F9 through all three destinations, checked their collision bodies and saved three actual room images. All three images were opened and reviewed. This probe checks packaged content/rendering; it is distinct from the release EXE startup check. The build manifest records its pre-commit source HEAD and the explicit worktree changes.


## Completed memory returns

Unfinished memories permit return and reentry while retaining their ownership and live room. They still block another memory purchase. Explicit completion does not remove an occupied room; actual completed return safely moves saved cargo out, closes the door and releases the area. Continue restores this same travel/completion behavior. Script/API identities are in Data/Computer/MEMORY_UPGRADES.md. Debug previews retain ordinary two-way travel.

Portal render remapping now unpairs a live instance from its scenario before changing render/light masks, then rejoins that same world. This avoids Godot's stale light pairs during completed cargo return and room unloading; masks are changed only when needed. See [upstream engine issue](https://github.com/godotengine/godot/issues/121989). The real Forward+/D3D12 walking/save/return fixture verifies this path with inspected logs.

## October environment corrections

The warehouse renders the original stair treads, but their collisions use StairWalkingSurface: one continuous ramp in the Floor and smooth-walking-surface groups. The player step helper skips its forward-height teleport probe for that group, allowing native slope movement. Stringers, rails, landings and office remain solid. Rear catwalk gaps now have guard rails/posts/toe boards. Hospital headers meet the 3.18 m portal aperture; far exit leaves close the opening to void, corridor rails stop at intersections, waiting benches face inward and ward door faces meet without coplanar overlaps. Apartment room arrays supply three left and three right wood footstep samples through the shared footstep override; workshop defaults restore on return. Art/native sources and manifests remain separate from engine lighting/collision.


When an open editor locks generated files, run the bake with `-- --stage`, then run `python Tools/publish_portal_bake.py`. The successful bake records a completion manifest under ignored .godot/portal_bake; the publisher validates its 73 scoped resources and replaces target files atomically with bounded lock retries. No editor window is closed, and incomplete bakes cannot be published.
