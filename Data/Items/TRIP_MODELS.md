# Trip spreadsheet models and apartment integration

The supplied spreadsheet maps 32 ZIP sources to current gameplay uses. `Models/Imported/Trip/catalog.json` records the stable asset ids, intended usage and target metre scale. Original workbook/ZIP inputs stay outside the repository and published reports. Every asset has its own editable source and portable export; architecture, furniture and engine behavior remain separate.

## Files and materials

For each catalog `<id>`, the canonical paths are:

| File | Purpose |
| --- | --- |
| `Models/Imported/Trip/<id>/Source/<id>.blend` | Packed editable native, with `ASSET \| <id>` collection and separate presentation collection |
| `Models/Imported/Trip/<id>/<id>.glb` | Metre-scale engine asset with embedded textures and no presentation cameras/lights |
| `Models/Imported/Trip/<id>/asset_manifest.json` | Source/native/export paths, bounds, texture, object names and geometry counts |
| `Models/Imported/Trip/<id>/Source/` | Extracted original FBX and supplied texture files; `.gdignore` excludes engine import |
| `Reports/TripModels/<id>_1.png`, `_2.png`, `_3.png` | Three actual final Blender views per model, 96 total |

Supplied UVs remain on retained geometry. Materials use supplied base colour and normal/roughness/metallic maps where available, with normal strength 0.6. Textures are packed into the native and embedded in the GLB. Lever separation preserves the source triangles/UVs. Door cropping uses actual planes to retain clean seams; its repaired timber frame has explicit UVs. `*_preview.png` files are earlier previews, separate from final three-view evidence. Presentation lights, cameras and apartment dust are excluded from engine assets.

## Current model assignments

| Stable ids | Current use |
| --- | --- |
| baby_bottle, beer_bottle, clipboard, meat_slab_a, meat_slab_b, meat_block, syringe, book, teddy_bear | Nine equal production chute/automatic-spawner items under Scenes/Items |
| computer, computer_cart | Separate terminal/cart art in Scenes/Computer/computer_terminal.tscn |
| steel_plate | Scenes/Art/plate.tscn; existing ordinary/upgraded plate actors |
| lever | Scenes/Actors/lever_assembly.tscn; separated LeverBase/LeverHandle |
| door | Scenes/Art/doorway.tscn; separate DoorFrame/DoorLeaf, plus open room-door wrappers |
| mulcher, mulch_bin, mulch_pellet | Existing Scenes/Mulch machine, wooden crate bin and trash-ball pellet actors |
| couch, lounger, television, paper_stack, coffee_table, desk | Apartment replacements/additions; paper_stack/desk are also reused in other memories |
| office_chair | Warehouse office replacement |
| industrial_machine_a, industrial_machine_b, industrial_machine_c | Existing warehouse machine targets, retaining their node aliases |
| hospital_bed, wheelchair, waiting_chairs | Hospital replacements |
| garbage_bag_a, garbage_bag_b | Visual-only warehouse/hospital dressing, with no collision |

The wooden crate specifically replaces **Mulch Bin**, the current pellet receptacle. The historical hopper/factory systems remain retired. It retains the existing bin collection, score/conversion and save behavior.

All nine regular items have base score 1, compact CCD box collision, zero initial random impulse, pickup prompts/targets and existing WorldState restoration. Existing value effects still apply at spawn. The old test block remains for saved scene paths and fixtures, outside `Data/Items/default_spawn_pool.tres`. Note drops stay independent: a normal 2% eligible-note roll precedes regular selection; unread culled notes return to their catalog and collected notes remain excluded. [Masses, banks and APIs](ART.md) · [Pool and notes](README.md).

The terminal model starts at local Y=0.76 m on the cart, with about 1.434 m total visual height. Screen/OfflineScreen/Text align to the actual display at local Y=1.26 m. Separate terminal/cart collisions support the assembly. Existing computer enablement, camera motion, tabs and upgrades remain connected.

The lever keeps its green/red lights, controller, sounds and upgrade-driven cycle; only `Lever_Base/LeverHandle` moves. The door keeps its original interaction, audio, portal and story ownership while its leaf moves independently from the repaired fixed frame. The Mulcher retains its safe Output marker, velocity/spacing controls and intake rules. Its `Output/Debris` CPUParticles3D emits 24 small chips for 0.45 seconds; `mulcher_station._debris_pending` coalesces same-frame pellet signals into one deferred burst.

## Expanded apartment and linked memories

The independent apartment shell at `Models/Architecture/StudioApartment` now measures **12.2 × 6.2 m**. The east bedroom is **4.25 × 6.2 m**, with a **1.195 × 2.2 m clear doorway** onto the supported existing floor. Original newspaper windows, bathroom surfaces and worn materials remain. Entry/bathroom door geometry is separated from the shell and replaced by imported open leaves/frames.

The bedroom bed is a new independent textured asset at `Models/Interiors/StudioFurniture/BedroomBed/Source/bedroom_bed.blend` and `bedroom_bed.glb`, using packed worn fabric/wood maps. BedroomDesk and CoffeeTable link their Trip natives. They are assembled through `Models/Interiors/FurnishedStudio/studio_apartment_furnished.blend`; no furniture is baked into the architecture.

Warehouse and hospital native assemblies also link the replacement sources independently. Blender manifests map (x,y,z) to Godot (x,z,-y), with Z rotation becoming Y rotation. Current engine room scenes have **24 apartment, 21 warehouse and 54 hospital art instances**. Story node aliases, required memory Resources and saved flags remain connected; the new furniture does not become scored world items. Garbage bags deliberately have no StaticBody3D. The original warehouse stair ramp/rails and hospital circulation corrections remain authored. [Collision, lighting and portal workflow](../Portal/ENVIRONMENTS.md).

## Authoring tools

These tools are already applied to the current assets. Review intended changes and existing authored scene overrides before rerunning generation.

| Tool | Contract |
| --- | --- |
| Tools/prepare_trip_models.py | Reads the configured supplied workbook, validates the exact 32-file list, safely extracts ZIP members and writes catalog.json |
| Tools/import_trip_models.py | Blender preparation/export; `--preview` makes earlier one-view previews, `--only id,id` scopes assets, normal execution produces final packed natives/GLBs/three views |
| Tools/expand_trip_apartment.py | Blender shell expansion and independent bedroom bed; uses an ignored original-shell snapshot to avoid cumulative expansion |
| Tools/setup_trip_scenes.py | Writes the nine item scenes/pool and art wrappers, replaces room model references and adds named furniture/doors/bags; preserves unrelated scene content |
| Tools/sync_trip_assemblies.py | Updates linked native assemblies and manifests by existing instance name; verifies original backups under ignored .godot and saves via a staged file |
| Tools/bake_trip_art.gd | Inherits bake_portal_environments.gd save helpers; rebuilds only 20 affected wrappers and 38 art/collision resources, preserving authored room scenes |
| Tools/publish_portal_bake.py | Validates a nonempty, unique, scoped .tscn/.tres completion manifest and atomically publishes staged files with bounded lock retries |
| Tools/render_trip_apartment.py | Four final apartment angles plus three independent-bed views; presentation native lives separately under Models/Interiors/TripPresentation/Source |
| Tools/verify_trip_assets.py | Portable GLB/source/UV/material/embedded-texture/render-path checks for all 32 ids |
| Tools/verify_trip_native.py | Blender packed-image/UV/material checks and three linked-assembly path/collection checks |
| Tools/benchmark_trip_hotpaths.tscn | Five-sample local microbenchmark; writes .godot/trip_hotpath_benchmark.json |

Use the installed Blender for its scripts, for example `Blender --background --python Tools/import_trip_models.py -- --only lever,door`. Run the installed Godot editor import after exports, then apply the targeted staged bake:

```text
Godot --headless --path . --script Tools/bake_trip_art.gd -- --stage
python Tools/publish_portal_bake.py
python Tools/verify_trip_assets.py
Blender --background --python Tools/verify_trip_native.py
```

**Do not blindly run the old whole-room bake.** `Tools/bake_portal_environments.gd` regenerates room scenes and can remove current memory scripts, stair fixes, lighting and designer overrides. The Trip bake deliberately changes only shared art/collision resources. Its completion manifest contains 38 files for the current 20 wrappers; the publisher validates scope rather than requiring the historical fixed count of 73. `.godot` backups/staging and original input workbook/ZIPs remain local.

## Verification and performance

The documented canonical paths were checked against disk: all 32 packed natives, 32 GLBs, 32 manifests and 96 final prop renders exist, along with the independent bed, apartment presentation native and named actor/tool/test files. Local guide links resolve.

`Tests/trip_models_test.tscn` checks nine-entry random distribution, exclusion of the test block, all nine actual chute paths and floor landings, score/friction, separate lever and door animation, and real player-capsule movement through the bedroom opening. Existing imported_items, spawn_pool, computer, memory, portal walking, mulch and plate suites cover retained behavior. Use isolated user data, inspect logs, and review real renderer captures for visual changes; headless physics does not prove materials or screen alignment.

`item_spawn_pool.pick_item()` now takes a direct valid selection from the authored array before its null-safe fallback, avoiding a temporary array for normal spawns. The Godot 4.7.2 local benchmark measured **350,916 → 50,697 µs** median for 100,000 picks over five samples. This measures that call path, without claiming a whole-game frame-rate improvement. Analytical box bounds were slower in the same benchmark, so existing cached native debug-mesh bounds are retained.

The [local gallery](../../Reports/TripModels/index.html), [hosted gallery](https://coolbeangames.github.io/Remnant-GD/TripModels/index.html) and [dated development summary](https://coolbeangames.github.io/Remnant-GD/index.html#trip-models-apartment) carry final asset/game views and the current Windows/GitHub delivery status. Confirm build and publication outcomes from that dated evidence.
