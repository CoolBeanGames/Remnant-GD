# Imported items and replacement art

The shared pool now includes the original test block plus beer bottle, book, syringe and teddy bear. Each entry has an equal chance. The four new gameplay scenes are in `Scenes/Items`; they use normal F pickup/drop, throwing, baskets, fan forces, grinding and WorldState restoration. Every item has base score 1; existing value upgrades still apply to future spawns.

| Item scene | All-collision sound bank | Approximate longest dimension |
|---|---|---|
| Scenes/Items/beer_bottle.tscn | Data/Collision Sounds/glass_all.tres | 0.35 m |
| Scenes/Items/book.tscn | Data/Collision Sounds/book_all.tres | 0.36 m |
| Scenes/Items/syringe.tscn | Data/Collision Sounds/plastic_all.tres | 0.30 m |
| Scenes/Items/teddy_bear.tscn | Data/Collision Sounds/teddy_bear_all.tres | 0.40 m |

Each scene wraps one CCD RigidBody3D with a compact box/capsule collider, collision monitor, reusable pickup prompts and a score component. The collision sound matrix receives body_entered and plays a random bank entry through the pooled 3D SFX players. `group = "*"` is the fallback for every collision; named group entries take priority. To add sounds, edit the bank's Sounds array in the Inspector. The source banks include all real WAV files from their corresponding folders. The Teddy_Bear/__MACOSX folder has `.gdignore` because its `._*.wav` entries are archive metadata rather than audio.

The new items have zero initial random impulse and friction 0.35, avoiding the test block's strong launch on their smaller masses. The chute's exported Item Exit Speed defaults to 3 m/s downward. Automatic spawners release the new scenes naturally under gravity.

Items leaving the chute receive friction 1 and damping 2; their compact colliders are unchanged. Imported items and note bottles have a separate reusable PickupTarget Area3D for easier aiming.

## Art and materials

`Scenes/Art` contains normalized, editable art scenes for the four items, computer, plate, fan and note bottle. Each retains source_model metadata pointing to the original FBX, which is untouched. The saved mesh resources are compressed in `Data/ArtMeshes`; they are prepared copies rather than live FBX instances. `Materials/Items` contains editable materials with the supplied albedo, normal, metallic and roughness textures. Normal strength is 0.6; roughness uses the red channel. Original UVs are retained. Replace the prepared art/mesh resources when revising the source models.

The replacement corrugated aluminum art is used by `Scenes/Actors/steel_plate.tscn` and its upgraded scene. Its principal plane is aligned to the existing plate axes and its geometry fits the original 2.4 × 2.4 × 0.12 m collider. Rotation, anchor behavior and ghost placement remain available.

`Scenes/Actors/fan.tscn` uses the supplied housing and separate blades. `Model/BladePivot` is centred on the rotor; the model faces local -Z to match wind and the ghost arrow. Blade Speed Degrees (default 720) and Blade Axis (default -Z) are editable on the fan. Turning off stops the blades, wind, particles and optional sound; upgraded fans inherit the same model. The three solid colliders fit the base, stem and housing; blades are visual geometry rather than moving physics colliders.

`Scenes/Computer/computer_terminal.tscn` uses the old computer model, with a lit Screen and Text aligned over its actual display and an OfflineScreen black cover. The existing 30-score flag controls the screen and prompts. The three-tab interface and delivery system are retained.

`Scenes/Actors/note_drop.tscn` uses the supplied message-in-a-bottle meshes. The bottle and rolled paper have separate materials and their respective texture sets. `Materials/Items/note_bottle_bottle.tres` uses alpha transparency 0.26 and roughness 0.18; the paper stays opaque. A rounded 0.30 m capsule with CCD preserves chute/floor collision. It uses the same glass sound bank as the beer bottle. F reading, once-only spawn history and journal persistence are unchanged; the hidden Title node remains a data/display hook.

## Script API changes

| Script / inheritance | Added configuration and runtime behavior |
|---|---|
| Scripts/Actors/collision_sound_matrix.gd / collision_sound_matrix → Node3D | get_collision_entry(other) returns the first matching named group, otherwise the `*` fallback. collide(other) plays pooled positional audio on SFX. Existing sound_matrix export remains Array[collision_sound_entry]. No new signals/autoload. |
| Scripts/Actors/CollisionSoundEntry.gd / collision_sound_entry → Resource | Existing name, group, volume and sounds exports; group now accepts `*` as an all-collision fallback. No runtime state/signals/autoload. |
| Scripts/Actors/fan.gd / switchable_prop → RigidBody3D | blade_speed_degrees: float and blade_axis: Vector3 exports; runtime blade_pivot: Node3D. _process(delta) rotates only while powered and visible, independently of optional audio. _apply_power continues wind/particle/audio switching. Requires Model/BladePivot, Wind, Airflow and optional FanSound. No new signals/autoload. |
| Scripts/Actors/note_drop.gd / note_drop → RigidBody3D | collision_sounds: collision_sound_entry export; _ready connects body_entered, and _on_collision(body) safely chooses an optional pooled SFX impact. Existing note/collected/read_note API remains. Requires hidden Title and model's two meshes. No new signals/autoload. |
| Scripts/Actors/ceiling_chute.gd / ceiling_chute → Node3D | item_exit_speed: float export (3.0); spawn() assigns downward velocity to regular item's rigid bodies after spawning. Existing note_exit_speed and pool/note selection remain independent. No new signals/autoload. |
| Scripts/Computer/computer_terminal.gd / computer_terminal → StaticBody3D | set_enabled(value) also switches OfflineScreen visibility, preserving existing Screen/Text and modal behavior. Requires Model, Screen, OfflineScreen, Text and Collision. No new exports/signals/autoload. |

Godot UID files beside these scripts retain their existing identities. Tests/imported_items_test.tscn covers random selection, real contacts and SFX banks, pickup, grinding value, exact type restoration, blade stopping, separate bottle/paper materials and all four items passing through the actual level chute. Existing placement/carry, floor, notes, computer and portal regressions cover the replaced props.

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

The computer gameplay scene restores the source model height (about 2.85 m). Fan source reimports use Scripts/Actors/fan_import.gd to restore both four-map materials; gameplay fan meshes were refreshed and BladePivot now follows the corrected imported blade origin.

Current masses: book 0.8 kg, teddy bear 0.18 kg, syringe 0.04 kg, beer bottle 0.35 kg, note bottle 0.25 kg. Collision clips now use Audio.play_collision and share a ten-clip limit. Unread notes culled below the floor or in the chute return to their pool; collected journal entries remain excluded.
