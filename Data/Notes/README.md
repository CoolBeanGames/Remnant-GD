# Notes, physical reading and journal

## Current controls

**F** collects a dropped bottle into the saved journal and raises readable, lit paper over 0.50 seconds. The world pauses and gameplay feedback temporarily hides. **Esc** lowers the paper over 0.30 seconds, then restores the previous input, mouse, pause and feedback state. The camera stays still during paper motion.

**N** toggles a scrollable typed transcript while reading; a second press returns to paper. N from gameplay opens the latest collected transcript. Esc from the transcript returns to paper, then a further Esc puts it away. The mouse wheel scrolls overflowing generated paper.

**Pause > Notes** lists saved titles. A single left click, Enter or double click opens the selected original paper, including the initially selected first row. Putting it away returns to the paused journal. Esc/Back returns from the journal to the pause menu; Continue resumes play. Shared Options is implemented with Audio, Controls and Graphics tabs, persistent settings and Delete Save and Exit. Pause-menu Exit saves before quitting. See [physical-reader authoring and motion](../WORLD_INTERFACES.md), [Options](../OPTIONS.md) and [saving](../SAVING.md).

## Add another note

1. Duplicate a note resource in `Data/Notes`, such as `door.tres`.
2. Give it a unique **Id**, **Title** and multiline **Body** in the Inspector.
3. Add the resource to the **Notes** array of `Data/Notes/default_catalog.tres`.
4. Optionally assign **Page Texture**, **Reading Scene** and **Reading Pose** for the held paper.

The default catalog contains the stable ids **first_shift**, **power** and **door**. Blank art fields print the existing text onto matte paper. Page Texture supplies an authored page for the default 0.36 × 0.45 m sheet. Reading Scene accepts display-only Node3D artwork with its readable face toward local +Z, in metres; Reading Pose adjusts it inside the holder. Keep assets in exported `res://` paths. Custom reading art has no scoring, world-item persistence or physical collision. The bottle's world art remains separate from the held reading copy. [Complete art/session API](../WORLD_INTERFACES.md).

## Chute selection and spawn history

Select **ceiling_chute** in `Scenes/testing_level.tscn`. Production **Note Drop Chance** defaults to **0.02 (2%)**, with editable **Note Exit Speed** of 3 m/s downward. Each manual drop first tries this eligible-note roll; eligible notes are selected equally. A successful note replaces that drop's regular item. A failed roll or exhausted catalog selects from the regular item pool. Automatic spawners use ordinary items without notes.

The current regular pool contains nine equally weighted, one-score Trip item scenes. The original test block is retained for old saves/tests outside production. Author ordinary item entries in `Data/Items/default_spawn_pool.tres`; the [item-pool guide](../Items/README.md) and [art guide](../Items/ART.md) provide their scene, sound and collision requirements.

Blackboard **spawned_notes** records an Id when its physical note enters the world. **found_notes** stores the collected journal. The catalog excludes both, preventing duplicates while a note lies on the floor or after collection. Culling an unread note below the floor or in the chute calls `note_drop.on_culled()` and `Notes.release_spawned(id)`, making it eligible again. Collected notes and scene unload retain history. Restored world drops mark their Id as spawned; older journal entries also suppress duplicate drops.

To deliberately reset a note during development, clear its Id from spawned_notes and its entry from found_notes. Keep published ids stable so Continue and older journals still resolve them.

## World drop and saving

`Scenes/Actors/note_drop.tscn` is the textured message bottle with a partially transparent bottle material and separate opaque rolled paper. Its 0.25 kg RigidBody3D has a rounded capsule (0.075 m radius, 0.28 m height), continuous collision detection, gravity scale 1.5, a separate pickup target and the pooled glass collision bank. It clears the actual chute and lands on the solid floor. Notes belong to machine-immune, award no score, and leave the world after F collects them.

`note_definition.snapshot()` supplies `{id, title, body, definition_path, reading_scene_path, page_texture_path}`. Each unique Id enters found_notes once; rereading emits the reading signal without duplicating the journal. Definition paths resolve assigned art after reload; old journals fall back through catalog Id or generated paper.

SaveGame writes note collection and spawn history to the same versioned `user://remnant.save` used for the run. WorldState records the definition resource path and physical state of uncollected drops, restoring their contents and position. Autosaving runs during unpaused gameplay; normal Exit/window close save. Continue restores the journal and world drops. New Game clears run notes/history while retaining the configured permanent profile/settings; Delete Save removes the whole file/profile. [Save format and lifecycle](../SAVING.md).

## Resource and script API

| Script / identity | Configuration and behavior |
| --- | --- |
| Scripts/Notes/note_definition.gd / note_definition → Resource / uid://dp7ou5pac15xo | Exports id:StringName, title:String, body:String, reading_scene:PackedScene, page_texture:Texture2D and reading_pose:Transform3D. snapshot() returns the journal/art-path Dictionary. No autoload or signals. |
| Scripts/Notes/note_catalog.gd / note_catalog → Resource / uid://yypk3kgv6j3h | Exports notes:Array[note_definition]. available() returns non-null, nonempty-Id definitions for which Notes.has_spawned(id) is false. No autoload or signals. |
| Global/notes.gd / Notes autoload → Node / uid://oeuhwghfiw60 | all_notes() returns defensive journal copies; has_note(id), has_spawned(id), mark_spawned(id), release_spawned(id) and collect(definition) manage Blackboard found_notes/spawned_notes. Signals note_read(note:Dictionary), note_read_finished(note:Dictionary), collection_changed. Uses Blackboard, DevTools and note_definition. |
| Scripts/Actors/note_drop.gd / note_drop → RigidBody3D / uid://buk04abkbs3on | Exports note:note_definition and collision_sounds:collision_sound_entry; transient collected protects repeat collection. read_note() untracks, collects and frees the world drop; on_culled() releases unread history. Requires hidden Title and bottle/paper model; uses Notes, WorldState and Audio.play_collision. No autoload or custom signals. |
| Scripts/Notes/note_reader.gd / note_reader → Node / uid://ccu5mjxj0jq8q | Scene Scenes/Notes/note_reader.tscn; binds Notes.note_read. Exports camera, toggle_key=N, paper_size/distance, reading_light_energy and Paper Motion settings. API open_note(snapshot,return_to_journal=false)->bool, toggle_transcript(), close(notify=true,immediate=false). Signal closed(note,return_to_journal). Runtime is_open/typed/closing/current_note/session/holder/paper_motion; no autoload. Full settings, layer 19 lighting and session dependencies are in WORLD_INTERFACES.md. |

## Verification

`Tests/notes_and_switches_test.tscn` checks actual chute passage and floor landing, F pickup/read, deduplicated collection, journal/Esc/Continue, world-note restoration and retained fan/light switches. `Tests/spawn_pool_test.tscn` checks unique drops, exhausted-note fallback, collected-note suppression, null/empty item pools and automatic output. `Tests/note_flow_economy_audio_test.tscn` covers unread culling, repeat eligibility and the retained collision-audio limit.

`Tests/world_interfaces_test.tscn` checks real physical paper, N/Esc, journal mouse/Enter selection, custom art, old journals, save codec and session ownership. `Tests/world_view_motion_test.tscn` observes intermediate motion, cancellation/replacement, diagnostics, instant timing and unload restoration. `Tests/floor_collision_test.tscn` checks 40 m/s note impacts on each solid slab and the clear grinder opening. Use isolated user data and inspect logs; review real rendered captures when changing paper/material presentation. [Interface gallery](../../Reports/WorldInterfaces/index.html).

## Historical implementation records

These records describe earlier implementation work. The early prototype used a screen reader, a 50% test note chance, placeholder Options and journal data prepared for future disk saving. Those settings/interfaces have been replaced by the current physical reader, 2% production chance and implemented shared Options/SaveGame workflows above.

The debugger cleanup removed the obsolete Buildings autoload pointing to the deleted building_registry.gd. Interaction proxies stopped repetitive logging and safely ignored missing targets. Optional null audio streams and empty collision entries were guarded; pools cleared their Blackboard registration on removal. The start-room test fixture gained an actual audio pool. Existing notes, audio, prompt, purchase, physics and score suites retained these regression checks.

The floor correction replaced a zero-thickness imported collision mesh with **SolidFloor**, a Floor-group StaticBody3D containing four 0.5 m thick BoxShape3D slabs whose top is world Y=0. The original 3.8214 × 8.3822 m grinder opening remains clear. Left/Right use FloorSides; Front/Back use FloorEnds. Visual level art and chute geometry stayed separate. The landing/40 m/s tests above continue covering this repair; bottle art and capsule collision are now implemented.

The earlier fan/light pass added E power toggles, saved Powered state, a ghost-only facing arrow at `Scenes/UI/build_direction.tscn`, and the PC spotlight's computer-enabled flag at 30 awarded score. Fans stop blades/wind/particles/optional audio when off; lights hide their light sources. These systems remain maintained in the [manual-tool guide](../Items/MANUAL_AUTOMATION.md), alongside later tool upgrades.

The base combo tuning established a 1.0×/3-second opening window, +0.5× per following item and a 0.4-second window reduction down to 0.5 seconds, feeding the accelerating score queue. `Global/grind_combo.gd` owns the editable base values; current upgrade Resources may change their effective behavior. The historical five-entry/test-block pool was superseded by the current [nine-entry production pool](../Items/README.md).
