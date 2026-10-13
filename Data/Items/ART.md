# Imported items and replacement art

`Data/Items/default_spawn_pool.tres` contains nine equally weighted gameplay scenes under `Scenes/Items`. They use normal F pickup/drop, throwing, baskets, fan forces, grinding and WorldState restoration. Every item has base score 1; existing value upgrades apply to future spawns. The test block remains at `Scenes/test_object.tscn` for old saves and fixtures, outside the production pool. [Trip source and integration workflow](TRIP_MODELS.md) records all 32 imported models and the expanded apartment.

| Item scene | Mass | All-collision sound bank | Approximate longest dimension |
|---|---|---|---|
| Scenes/Items/baby_bottle.tscn | 0.12 kg | Data/Collision Sounds/plastic_all.tres | 0.24 m |
| Scenes/Items/beer_bottle.tscn | 0.35 kg | Data/Collision Sounds/glass_all.tres | 0.30 m |
| Scenes/Items/clipboard.tscn | 0.30 kg | Data/Collision Sounds/book_all.tres | 0.34 m |
| Scenes/Items/meat_slab_a.tscn | 0.60 kg | Data/Collision Sounds/book_all.tres | 0.28 m |
| Scenes/Items/meat_slab_b.tscn | 0.65 kg | Data/Collision Sounds/book_all.tres | 0.30 m |
| Scenes/Items/meat_block.tscn | 0.70 kg | Data/Collision Sounds/book_all.tres | 0.28 m |
| Scenes/Items/syringe.tscn | 0.04 kg | Data/Collision Sounds/plastic_all.tres | 0.20 m |
| Scenes/Items/book.tscn | 0.80 kg | Data/Collision Sounds/book_all.tres | 0.34 m |
| Scenes/Items/teddy_bear.tscn | 0.18 kg | Data/Collision Sounds/teddy_bear_all.tres | 0.32 m |

Each scene wraps one CCD RigidBody3D with a compact box collider, collision monitor, reusable pickup prompts and a score component. The collision sound matrix receives body_entered and plays a random bank entry through `Audio.play_collision`, the pooled 3D SFX players and shared ten-clip collision limit. `group = "*"` is the fallback for every collision; named group entries take priority. To add sounds, edit the bank's Sounds array in the Inspector. Plastic, paper/meat, glass and teddy items share the existing banks listed above. The source banks include all real WAV files from their corresponding folders. The Teddy_Bear/__MACOSX folder has `.gdignore` because its `._*.wav` entries are archive metadata rather than audio.

The production items have zero initial random impulse and friction 0.35. The chute's exported Item Exit Speed defaults to 3 m/s downward. Automatic spawners release these scenes naturally under gravity.

Items leaving the chute receive friction 1 and damping 2; their compact colliders are unchanged. Imported items and note bottles have a separate reusable PickupTarget Area3D for easier aiming.

## Art and materials

The nine item wrappers in `Scenes/Art` and machine wrappers in `Scenes/Art/Trip` instance their independent `Models/Imported/Trip/<id>/<id>.glb` files. Each Trip folder includes an `asset_manifest.json`, untouched extracted FBX/texture source and packed `Source/<id>.blend`. GLBs embed their PBR textures, preserve supplied UVs and exclude presentation cameras/lights. `Source/.gdignore` keeps authoring files out of engine import. `metadata/source_model` identifies the prepared GLB. Normal-map strength is 0.6 where supplied. Revise the native source, export and reimport before updating affected wrappers/collisions.

The retained fan and note bottle still use their earlier editable `Data/ArtMeshes` and `Materials/Items` resources. Those materials keep supplied albedo, normal, metallic and roughness textures; roughness uses the red channel. Older prepared meshes remain useful history and compatibility resources.

The imported rusted siding is used through `Scenes/Art/plate.tscn` by `Scenes/Actors/steel_plate.tscn` and its upgraded scene. Its principal plane is aligned to the existing plate axes and its geometry fits the original 2.4 × 2.4 × 0.12 m collider. Rotation, four-edge joins, anchor behavior and ghost placement remain available.

`Scenes/Actors/fan.tscn` uses the supplied housing and separate blades. `Model/BladePivot` is centred on the rotor; the model faces local -Z to match wind and the ghost arrow. Blade Speed Degrees (default 720) and Blade Axis (default -Z) are editable on the fan. Turning off stops the blades, wind, particles and optional sound; upgraded fans inherit the same model. The three solid colliders fit the base, stem and housing; blades are visual geometry rather than moving physics colliders.

`Scenes/Computer/computer_terminal.tscn` instances the Trip computer and rusted cart separately. The computer begins at local Y=0.76 m, with a total visual height of about 1.434 m. The Screen, OfflineScreen and Text sit on the actual display at local Y=1.26 m; the cart and terminal have separate support collisions. The existing 30-score flag controls the screen/prompts. Three-tab upgrades, camera focus and delivery behavior remain connected.

`Scenes/Actors/lever_assembly.tscn` retains its controller, sounds, green/red indicator lights and cooldown/output upgrades. Animation tracks now rotate `Lever_Base/LeverHandle`, separated from the supplied base with its UV data. `Scenes/Art/doorway.tscn` animates `Model/DoorLeaf` independently of `Model/DoorFrame`; the supplied leaf is cropped on planes, gaps are repaired, and frame/hinge placement fits the existing portal aperture. Existing door audio and story/portal semantics remain.

`Scenes/Mulch/mulcher_station.tscn`, `mulch_bin.tscn` and `mulch_pellet.tscn` retain their gameplay identities while using the imported machine, wooden crate and trash ball. The Output marker preserves safe pellet launch direction. `Output/Debris` produces a one-shot 24-chip burst lasting 0.45 seconds, with multiple pellet signals in a frame coalesced to one visual restart.

`Scenes/Actors/note_drop.tscn` uses the supplied message-in-a-bottle meshes. The bottle and rolled paper have separate materials and their respective texture sets. `Materials/Items/note_bottle_bottle.tres` uses alpha transparency 0.26 and roughness 0.18; the paper stays opaque. A rounded 0.30 m capsule with CCD preserves chute/floor collision. It uses the same glass sound bank as the beer bottle. F reading, once-only spawn history and journal persistence are unchanged; the hidden Title node remains a data/display hook.

## Script API changes

| Script / inheritance | Added configuration and runtime behavior |
|---|---|
| Scripts/Actors/collision_sound_matrix.gd / collision_sound_matrix → Node3D | get_collision_entry(other) returns the first matching named group, otherwise the `*` fallback. collide(other) uses pooled Audio.play_collision on SFX. Existing sound_matrix export remains Array[collision_sound_entry]. No new signals/autoload. |
| Scripts/Actors/CollisionSoundEntry.gd / collision_sound_entry → Resource | Existing name, group, volume and sounds exports; group now accepts `*` as an all-collision fallback. No runtime state/signals/autoload. |
| Scripts/Actors/fan.gd / switchable_prop → RigidBody3D | blade_speed_degrees: float and blade_axis: Vector3 exports; runtime blade_pivot: Node3D. _process(delta) rotates only while powered and visible, independently of optional audio. _apply_power continues wind/particle/audio switching. Requires Model/BladePivot, Wind, Airflow and optional FanSound. No new signals/autoload. |
| Scripts/Actors/note_drop.gd / note_drop → RigidBody3D | collision_sounds: collision_sound_entry export; _ready connects body_entered, and _on_collision(body) safely chooses an optional pooled SFX impact. Existing note/collected/read_note API remains. Requires hidden Title and model's two meshes. No new signals/autoload. |
| Scripts/Actors/ceiling_chute.gd / ceiling_chute → Node3D | item_exit_speed: float export (3.0); spawn() assigns downward velocity to regular item's rigid bodies after spawning. Existing note_exit_speed and pool/note selection remain independent. No new signals/autoload. |
| Scripts/Computer/computer_terminal.gd / computer_terminal → StaticBody3D | set_enabled(value) also switches OfflineScreen visibility, preserving existing Screen/Text and modal behavior. Requires Model, Screen, OfflineScreen, Text and Collision. No new exports/signals/autoload. |
| Scripts/Actors/item_spawn_pool.gd / item_spawn_pool → Resource | items: Array[PackedScene] export; pick_item() returns one equally weighted valid scene or null. A valid selection avoids temporary-array allocation; null slots use the safe filtered fallback. No cache, signals/autoload or runtime state. |
| Scripts/Mulch/mulcher_station.gd / mulcher_station → StaticBody3D | Existing pellet_velocity, pellet_spacing and pellet_columns exports and pellet_pose()/pellet_launch_velocity() API retained. Mulch.pellet_produced triggers deferred _emit_debris(); transient _debris_pending coalesces bursts. Requires optional Output/Debris CPUParticles3D; no new exported settings/signals/autoload. UID uid://xu0ohq42ko84. |

Godot UID files beside these scripts retain their existing identities. `Tests/imported_items_test.tscn` covers real contacts and SFX banks, pickup, grinding value, exact type restoration, blade stopping and separate bottle/paper materials. `Tests/trip_models_test.tscn` checks the nine-entry production distribution, every model passing through the actual chute and landing, separated lever/door animation, and real capsule traversal into the bedroom. Existing placement/carry, plate joins, floor, notes, computer, mulch and portal regressions cover the replaced props. Run with isolated user data and inspect logs; use a real renderer and visually review captures for presentation checks.

## Portal colour continuity

DoorPortal now keeps its SubViewport in linear HDR on Forward+/Mobile, so the main viewport performs the final colour conversion once. Compatibility rendering retains its supported non-HDR path. The portal view defaults to full resolution and copies the player viewport's MSAA and camera attributes. The destination environment and lights are unchanged. A same-pose rendered comparison measured a median colour difference of zero and 95th-percentile difference of 1/255 between the doorway view and direct room view (excluding the surrounding door/frame).

Script identities:

| File | UID |
|---|---|
| `Scripts/Actors/collision_sound_matrix.gd` | `uid://charfnmvsr4so` |
| `Scripts/Actors/CollisionSoundEntry.gd` | `uid://ntd28sbuhvl7` |
| `Scripts/Actors/fan.gd` | `uid://ixf0wp2jrttr` |
| `Scripts/Actors/note_drop.gd` | `uid://buk04abkbs3on` |
| `Scripts/Actors/ceiling_chute.gd` | `uid://di3swkqh5sn4a` |
| `Scripts/Computer/computer_terminal.gd` | `uid://222a5aa8d5t6` |

Fan source reimports use Scripts/Actors/fan_import.gd to restore both four-map materials; gameplay fan meshes and BladePivot follow the corrected imported blade origin.

The separate note bottle remains 0.25 kg. Unread notes culled below the floor or in the chute return to their pool; collected journal entries remain excluded. Note drops are independent of the nine regular entries and retain their normal 2% roll.

## Editable book sleeves

Shelf resources Data/Books/Shelves/book_01.tres through book_25.tres expose title, author, optional artwork and colours independently. The production book uses Data/Books/default_book.tres through its BookCover component. Blank text keeps plain covers; no collider/score/save duplicate is introduced. Current APIs and ordering are in Data/ISSUE_BATCH_2026-10-13.md.
