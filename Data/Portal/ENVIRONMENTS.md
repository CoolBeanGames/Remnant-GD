# Portal environment authoring

## In-game test

After leaving the concrete room and letting it vanish unseen, buy Memory 1/2/3 at the computer for its apartment/warehouse/hospital portal. E opens the retained Strange Door. Unfinished paid memories permit two-way travel and retain their portal for reentry. Only a completed return closes the portal and safely evacuates saved cargo. Completion flags also gate further memory purchases. See Data/Computer/MEMORY_UPGRADES.md. F9 remains an explicit debug preview even while a paid memory is unfinished; it preserves purchased ownership/completion and it selects apartment, warehouse, hospital, then wraps. The destination is stored in the Blackboard; a brief text-only portal status confirms the destination. F9 is a host gameplay shortcut, not an addon modal. Menus/wake-up/respawn room/keyboard repeat cannot activate it. Later story triggers can call DoorPortal.select_destination(&"hospital") and await destination_changed.

## Editable scene files

| Destination | Engine scene | Art instances | Features |
| --- | --- | --- | --- |
| Apartment | Scenes/Environments/furnished_apartment.tscn | 23 | Expanded worn shell, separate bedroom/bed/desk, coffee table, short entrance vestibule and open entry/bathroom doors |
| Warehouse | Scenes/Environments/dilapidated_warehouse.tscn | 21 | Replacement machines/office furniture, non-colliding garbage bags, all 24 stair treads, 4.2 m catwalk and accessible office |
| Hospital | Scenes/Environments/dilapidated_hospital.tscn | 56 | Six wards, treatment room, nursing counter/rear staff passage, replacement beds/wheelchairs/waiting seats and non-colliding garbage bags |

Each scene has a portal_room root, Entrance Marker3D, Art instances, Lighting and optional entrance landing. Entry markers face the native south/front openings (local +Z into the building, floor Y=0, centre Y=1.7195). Imported models keep textures and authored metre scale, with transforms mapped from the Blender manifests: (x,y,z) → (x,z,-y), Z rotation → Y rotation. Original .blend/GLB files remain independently editable. The Trip replacements retain story node aliases such as FamilyPhoto, PileOfMail, HydraulicPress and named hospital beds, so memory resources and saved flags continue targeting the same objects. [Trip source/workflow](../Items/TRIP_MODELS.md).

The apartment shell now measures 16.2 × 6.2 m, with a 4.25 × 6.2 m east bedroom and a 1.195 × 2.2 m clear internal doorway. Its bed is an independent textured native/GLB under `Models/Interiors/StudioFurniture/BedroomBed`; the living-room coffee table instances its separate Trip source; the desk is in the warehouse office only. Original newspaper window geometry and bathroom finishes are retained. The short exterior vestibule aligns the taller story door with the smaller apartment entrance. Entry/bathroom leaves use separate imported door wrappers opened to 96 degrees; their frame and open-leaf geometry is baked at that pose. The player capsule uses a 0.35 m radius, 1.8 m height and 1.65 m eye height, fitting both entry and bedroom opening. Existing camera/controller/support systems remain. Pickup targeting volumes are separate from solid geometry.

## Collision bake / lighting

`Scenes/Environments/Art/` contains **54 reusable model wrappers**, retaining the earlier library and adding 19 Trip/bed wrappers. Solid wrappers instance a GLB and a Solid StaticBody3D; `Trip_garbage_bag_a.tscn` and `Trip_garbage_bag_b.tscn` contain visual art only. `Collision/` contains versioned ConcavePolygonShape3D resources for solid geometry. Opaque solid triangles are merged once per unique asset, excluding transparent grime/blood/print/decal meshes and degenerate faces. Shapes are baked before runtime and reused by beds, cabinets and repeated machines. Backface collision is enabled for thin sheets. Static friction is 0.95; collider groups include Floor for existing audio/contact behavior.

Run the installed Godot editor import, then `Godot --headless --path . --script Tools/bake_trip_art.gd -- --stage` and `python Tools/publish_portal_bake.py` for the current art update. The targeted builder refreshes 20 wrappers, including the expanded shell and independent bed, and stages 38 art/collision resources. It preserves the three authored room scenes, story scripts and designer poses. The publisher accepts a validated variable-length completion manifest, checks unique scoped `.tscn`/`.tres` paths and replaces files atomically with bounded lock retries.

**Do not run the old whole-room `Tools/bake_portal_environments.gd` blindly.** That base generator writes all three room scenes and can erase current memory targets, stair corrections, lighting and authored overrides. Update its generation logic or preserve overrides before a deliberate full rebuild. `Tools/bake_trip_art.gd` inherits its save helpers while replacing only art/collision output. Never commit `.godot` staging/import caches.

Lighting stays separate under Lighting. The apartment uses Data/Portal/apartment_environment.tres and dim amber fixtures. Warehouse/hospital have no powered Light3D fixtures and use Data/Portal/dark_environment.tres (black background, zero ambient). portal_room.suppress_player_light disables the automatic camera lamp while inside; physical carried/built lights remain available. Settings registration preserves authored SSAO, render scale, AA and shadows. Room-layer lights do not illuminate workshop actors. Door audio remains on the existing Audio pool. Required E furniture/machine interactions and look-only flavor are authored through reusable memory_object resources; Data/Dialogue/MEMORY_TRIGGERS.md lists exact 3/5/4 objectives and saved completion flags. Static imported art is not registered as a spawned/scoring item.

## Persistence / switching

Data/Portal/{apartment,warehouse,hospital}.tres are editable definitions. Rendered DoorPortal instances warm their PackedScene resources sequentially in the background. No unused room is instantiated; only one destination becomes live. Headless tools load on demand because the dummy renderer cannot safely allocate shared mesh RIDs on loader threads. In-flight loads are joined on teardown. Give new entries unique stable ids and point scene_path at an exported .tscn. Add them to DoorPortal.destinations in testing_level. Scene paths work with the existing all_resources export preset. Roots and Entrance markers must inherit Node3D; inherited room scenes are supported.

Selection stores portal_destination_id in the Blackboard. Player/items remain in the existing single-save workflow. F9 from inside returns the player/held contraption outside the workshop door; other saved items are evacuated to workshop space before old scenery is freed. A prop attached to old static room scenery detaches; attachments to retained items stay together. PackedScene resources are cached; instantiated rooms are freed and do not accumulate their old furniture. The safe replacement validator keeps the prior room on bad input. The concrete-room respawn still suspends the portal until that room is unseen.

## Verification

Use Tests/portal_destinations_test.tscn for actual capsule movement, inventory/layer restoration, real input, destination persistence and failure recovery. Existing door_portal_test keeps its small-room fixture explicitly; portal_assembly, graphics_options, rail_player, prop_placement, carry_attachment, wake_up and player_voice cover shared regressions. Isolate APPDATA and inspect error/warning logs even on exit 0.

`Tests/trip_models_test.tscn` additionally walks the real player capsule through the bedroom opening onto its supported floor and checks imported lever/door animation and all nine chute paths. Use `Tools/verify_trip_assets.py` and Blender's `Tools/verify_trip_native.py` for portable textures/UVs and packed native/linked-assembly checks. `Reports/TripModels` holds 96 prop views, expanded-apartment/bed views and current engine captures; the [Trip gallery](../../Reports/TripModels/index.html) and current development summary record rendered/export verification for this revision.

Tests/portal_destinations_visual_test.tscn runs with a real renderer and writes Reports/PortalEnvironments/*.png. The gallery includes doorway/direct poses, furnished interiors, the warehouse catwalk, hospital ward and station. Review every capture; headless physics does not prove lighting/material appearance. Portal rendering is perspective/HDR matched but is not recursive or a remote interaction ray. Baked furniture retains its solid geometry; selected wrappers now provide E story prompts and independent look-only flavor. Tests/memory_triggers_test.tscn verifies all required objectives and completion travel.

The original portal delivery passed editor import, release export and an isolated 90-frame exported startup. Its matching-engine release-PCK rendered probe exercised F9 through all three destinations, checked collision bodies and saved three reviewed room images. This is earlier evidence; current Trip delivery outcomes belong to the dated development summary and Windows build manifest. A packaged-content rendering probe is distinct from the release EXE startup check. The build manifest records its pre-commit source HEAD and explicit worktree changes.


## Completed memory returns

Unfinished memories permit return and reentry while retaining their ownership and live room. They still block another memory purchase. Explicit completion does not remove an occupied room; actual completed return safely moves saved cargo out, closes the door and releases the area. Continue restores this same travel/completion behavior. Script/API identities are in Data/Computer/MEMORY_UPGRADES.md. Debug previews retain ordinary two-way travel.

Portal render remapping now unpairs a live instance from its scenario before changing render/light masks, then rejoins that same world. This avoids Godot's stale light pairs during completed cargo return and room unloading; masks are changed only when needed. See [upstream engine issue](https://github.com/godotengine/godot/issues/121989). The real Forward+/D3D12 walking/save/return fixture verifies this path with inspected logs.

## October environment corrections

The warehouse renders the original stair treads, but their collisions use StairWalkingSurface: one continuous ramp in the Floor and smooth-walking-surface groups. The player step helper skips its forward-height teleport probe for that group, allowing native slope movement. Stringers, rails, landings and office remain solid. Rear catwalk gaps now have guard rails/posts/toe boards. Hospital headers meet the 3.18 m portal aperture; far exit leaves close the opening to void, corridor rails stop at intersections, waiting benches face inward and ward door faces meet without coplanar overlaps. Apartment room arrays supply three left and three right wood footstep samples through the shared footstep override; workshop defaults restore on return. Art/native sources and manifests remain separate from engine lighting/collision.


When an open editor locks generated files, use the targeted bake's `-- --stage` path, then `python Tools/publish_portal_bake.py`. Only files listed in the successful completion manifest under ignored `.godot/portal_bake` are published. The current Trip bake lists 38 resources; other deliberate bakes may list a different valid count. Editor windows remain open.

## October 13 room revision

Seven ward doors and the staff entrance start closed with E Open/Close prompts; their leaf colliders move in portal space. The far wooden EXIT stays locked. Ward/staff routes are tested with the actual player capsule. Warehouse machines scale 1.65×, its office desk 1.2×, shutter closed and glass alpha 0.12. A resource-only cache warms all three destinations on the title/loading screen; one live room remains the rule. F9 requests after the first exit can wait for respawn-room visibility removal. [Current details](../ISSUE_BATCH_2026-10-13.md).
