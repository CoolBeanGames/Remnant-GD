# October 13 issue fixes and warning cleanup

All 27 local F1 submissions in this batch were read with their actual screenshots. The six initial reports and 21 later reports include duplicate door/lever requests. Original descriptions and images stay private; each verified report has its own local resolution record. Current code and this guide supersede earlier room dimensions and fixture assumptions.

## Workshop and controls

The wooden door hinges on the edge opposite its handle, opening clockwise from the front. Its source panel UVs are preserved; the fixed frame and moving leaf remain separate. The entire lever shaft rotates from its lower axle, without leaving a stationary shaft segment. The computer display fits the CRT opening: 0.265 × 0.212 m, centre (0.018, 1.272, 0.133). Focus blends position, rotation and FOV; the screen occupies 88% of the limiting viewport dimension while fitting completely at different aspect ratios. Closing restores the exact original FOV and pose. MulchBinMount moves sideways to X=2.2; the designer's Mulcher mount stays intact and its output faces away from the intake.

Empty-handed RMB smoothly zooms toward 35 degrees, returning to the original FOV on release. Holding an object keeps RMB throw. Paused menus, developer dialogs, waking and PC/note sessions prevent inspection zoom. `Scripts/Player/player_view_zoom.gd` / player_view_zoom / Node has camera, pickup, zoom_fov and response exports; Controllers/Player_View_Zoom owns it. No autoload or persistent state is added.

F9 retains initial-room visibility gating. After the first exit, a request made during a concrete-room respawn is queued and fulfilled after unseen-room removal. The visible room is never erased just to serve the shortcut. PC input permits this global shortcut. Paid memories retain their completion/return rules.

Combo and portal text have black outlines against pale surfaces; no combo panel returns.

## Apartment, warehouse and hospital

The apartment is **16.2 × 6.2 m**, including the separate 4.25 × 6.2 m east bedroom and 1.195 × 2.2 m doorway. Furniture leaves a tested capsule route from entrance to bedroom. The trash can is beside the TV. The office desk is absent from the bedroom. Independent packed sources, portable GLBs and linked native assemblies match current engine placements; presentation lighting/cameras stay in separate native files.

Warehouse production machines are 1.65× their previous size. The office desk is 1.2×, with phone and bills raised to its surface. Its shutter is closed. Front/west office glass uses an alpha 0.12 override and roughness 0.12, exposing the space beyond. `environment_art.material_overrides` maps mesh-name fragments to editable materials without changing supplied source textures.

Hospital wall bags sit inside the hall, and the bench clears the staff entrance. Seven ward doors and the added staff door start closed, expose E Open/Close prompts and move their real colliders with the leaf. The staff door occupies the actual crosshall opening. The far EXIT uses the main wooden door model and remains locked. `Scenes/Actors/memory_door.tscn` / `Scripts/Actors/hinged_world_door.gd` / @tool hinged_world_door extends environment_art. Exports: locked, door_title, open_degrees, travel_seconds, optional open_sound/close_sound. API: interact(); moving/is_open prevent overlapping tweens. Shared Audio plays optional opening audio and closing audio after motion finishes. These doors have no starting-room or memory-completion authority. Their runtime colliders receive the portal collision layer.

## Editable book sleeves

`Scripts/Items/book_sleeve.gd` is an @tool Resource with title, author, artwork, cover_color and ink_color. `Data/Books/Shelves/book_01.tres` through book_25.tres supply independent shelf books in stable imported-node order. `book_sleeve_library` extends environment_art and exports sleeves/spine_filter; apply_sleeve(mesh, resource) replaces a cover and creates appropriately scaled, shaded spine text. Gold decorative rules are excluded. Blank titles retain the original plain colour style. Two-line labels account for author length and spine width.

`book_cover.gd` is an @tool Node3D for the production book's optional front art/title/author, using Data/Books/default_book.tres. This adds no scoring, collider or saved actor. Run `Tools/prepare_book_sleeves.gd` only when intentionally regenerating the catalog/wrapper; preserve authored resources.

## Physical grinder debris

`Scenes/Effects/grind_debris.tscn` / grind_debris / RigidBody3D uses a shared small mesh, CCD and friction. `grind_debris_pool.gd` / grind_debris_pool / Node3D reuses object_pool: 6 chips per item, 64 bodies maximum, 1.8-second lifetime, 16 initial bodies. Same-frame requests are coalesced and bounded; expired bodies stop simulation, hide and return for reuse. Processing stops when no bodies are active. Chips collide with the applicable floor layer, cannot block player movement or be picked up/ground, and never enter the saved spawned-item list. GrindingArea.debris_enabled is optional. This is separate from the Mulcher's existing lightweight pellet-output visual burst.

## Resource loading

`scene_warmup.gd` / scene_warmup / RefCounted is a resource-only cache for Game and the three memories. API: begin(), poll(), progress(), ready(), get_scene(path), release(). State: scenes, queue, pending, failed_path. One background request runs at a time; no hidden room is instantiated and no story/audio actors are activated. The title preloads while visible. Scenes/save_loader.tscn shows a minimal loading percentage/progress line, waits for all four resources, restores save data, then enters Game. A 0.35-second minimum ensures the loading screen is drawn even with a warm cache. Headless tests use synchronous one-resource-per-frame loading because the dummy renderer cannot safely share mesh RIDs across loading threads. SaveGame releases the cache on shutdown; portal destination lookup reuses it. Resource caching avoids repeated disk parsing but does not eliminate room instantiation costs.

## Diagnostics and maintenance

The actual Godot 4.7.2 language server checks every project script. All 161 original warnings/errors were corrected: shadowed names, static Audio calls, incompatible print ternaries, integer divisions, duplicate compatibility class, missing @tool, unused signal declarations and redundant await. No warning suppression was added. `audio_player.audio_2d` replaces the old misleading audio_global player field; audio_global.play_* static calls use the class. Flags route through flag.set_state(), and finished-note notifications use Notes.finish_read(), emitting the existing signals. The root scene_def.gd compatibility script inherits the canonical Global definition.

Authoring tools: apply_issue_layouts.py updates scoped scene poses; revise_memory_architecture.py closes the shutter and updates glass/exit geometry; expand_trip_apartment.py uses an ignored original shell snapshot; sync_trip_assemblies.py matches scene transforms; render_issue_memories.py creates three useful views per room. Targeted bake_trip_art.gd -- --stage currently publishes 22 wrappers / 42 resources without regenerating story scenes.

## Verification and delivery

Tests/trip_issue_followup_test.tscn covers real F9 input/respawn removal, hinge/axle continuity, CRT fit, focus coverage/restore and Mulcher clearance. Tests/issue_oct13_test.tscn covers resource-only preload, intermediate RMB FOV, 25 editable spines, real full-capsule entrance/bedroom/ward/staff traversal and pooled floor collisions, expiry, reuse and capacity. The fixture uses the player's real flashlight in the destination lighting layer for captures. save_loader_test observes the actual loading UI before saved scene initialization and retains the four cached resources. Audio shutdown, rail/cargo/stations, dialogue, manual props, plate edges, persistence, memory, interfaces and title/options checks supplement these changes. Logs are inspected for warnings even with exit code zero.

See the dated [development chapter](https://coolbeangames.github.io/Remnant-GD/index.html#issues-october-13) and [reviewed gallery](../Reports/IssueOctober13/index.html) for final build/push/publication records. Isolated data protects the player's save. Selected checks and reviewed render views do not replace a complete manual playthrough.
