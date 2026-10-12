# Notes, switches and pause menu

## Current physical reading

F holds lit paper. Gameplay feedback temporarily hides during reading and returns when paper is put away. N toggles the transcript; Esc puts paper away. Pause > Notes lists titles and holds selected originals in world, then returns to the journal. Definitions accept Page Texture, Reading Scene and Reading Pose for future physical art. Blank fields print existing text; old journals remain readable. See [current authoring](../WORLD_INTERFACES.md). The old screen reader below is retired history; production chute chance is 2%, and Options/save are implemented.

## Add another note

1. Duplicate a note resource in `Data/Notes`, such as `door.tres`.
2. Give it a unique Id, a Title and its Body text in the Inspector. Body supports multiple lines.
3. Select `Data/Notes/default_catalog.tres` and add your resource to its Notes array.

Select **ceiling_chute** in `Scenes/testing_level.tscn`. **Note Drop Chance** is 0.5 for testing (50% of successful pulls). Set it to 0.01–0.03 for normal play (1–3%). This is a shared chance for a note drop; eligible notes are selected equally. Already spawned or found notes are excluded. With no eligible notes, the chute always drops its normal item. A note replaces that pull's scoring block; the automatic spawner continues to produce ordinary items.

The note scene is `Scenes/Actors/note_drop.tscn`: a textured message in a partially transparent bottle with separate opaque rolled-paper material and a rounded 0.30 m collider, continuous collision detection, increased gravity and a configurable downward exit speed. It fits through the same chute as the blocks. Notes are machine-immune and grant no score. F picks up and reads a note immediately; the note leaves the world, the game pauses and the reader opens. Continue or Esc resumes play.

## Journal and pause

Esc opens `Scenes/UI/pause_menu.tscn`. Continue resumes, Options is a disabled placeholder, Notes lists discovered titles and their text, and Exit closes the game. Esc returns from the journal to the menu, then resumes. Mouse capture, input blocking and the prior pause state are restored on close. The computer keeps its existing Esc-to-close behavior.

Blackboard **found_notes** stores an Array of Dictionaries `{id, title, body}`. Each unique Id is stored once; already found notes can still be reread without duplicates. This is in-memory data prepared for saving, not a disk save implementation. WorldState also snapshots the definition resource path for uncollected notes, so level restoration preserves their contents and physical position.

## Fan and light switches

Look at a fan or work light and press E to turn it off/on. The prompt follows the current state. E also toggles a held fan/light, except during building. Turning off a fan stops its imported blades, wind, particles and its optional audio; turning off a light hides its light sources. Both ordinary and upgraded fans support toggling. Blackboard spawned-item records retain the Powered state.

The facing arrow lives in `Scenes/UI/build_direction.tscn`, referenced by the fan's **Build Direction Preview**. It appears only in the ghost and rotates with it. The placed and held models have no arrow. Other rotatable props can opt into a preview scene using the same exported property.

The authored PC-area spotlight **ceiling_chute/LevelLight2** uses the **computer enabled** flag, so it turns on at 30 awarded score. The redundant additional spotlight was removed. Your assigned power-on sounds remain unchanged.

## Combo tuning

GrindCombo starts at 1.0× with a 3-second window. Each subsequent item adds 0.5× and refills a window 0.4 seconds shorter, down to 0.5 seconds. Thus multipliers are 1.0, 1.5, 2.0, 2.5... Payout still joins the accelerating one-point score queue. Tune the exported values in `Global/grind_combo.gd`.

## Debugger cleanup and validation

Removed the obsolete Buildings autoload referring to the deleted building_registry.gd. Interaction proxies no longer print repeatedly and safely ignore missing targets. Optional null audio streams are ignored before touching the pool, collision matrices skip empty entries, and pools unregister/clear their Blackboard state when removed. The start-room fixture now supplies an actual audio pool.

`Tests/notes_and_switches_test.tscn` verifies actual chute passage, F pickup/read, deduplicated Blackboard collection, pause/journal/Esc/Continue, dropped-note and fan-state restoration, wind/light switches, ghost-only arrow, and the authored PC spotlight at 30 score. Existing combo, physics, placement, purchase, audio, prompt and score suites remain active.

## Solid floor collision

The imported level floor was a zero-thickness triangle mesh; small fast note capsules could pass through it despite continuous collision detection. `Scenes/model_instances/game_stage_base.tscn` now disables the inherited ground/StaticBody3D/CollisionShape3D and uses **SolidFloor**, a Floor-group StaticBody3D with four BoxShape3D slabs. They are 0.5 m thick with their top at world Y=0, preserve the authored floor extent and leave the original 3.8214 m × 8.3822 m grinder opening clear. Visual geometry, note artwork and chute geometry remain as authored.

The Left/Right colliders share FloorSides; Front/Back share FloorEnds. Edit these collision shapes/positions alongside any future floor or grinder-opening model changes. The note's rounded collider and continuous collision detection remain active and can be reused with the planned bottle artwork.

`Tests/floor_collision_test.tscn` verifies note impacts at 40 m/s on all four sections and a clear grinder opening. `Tests/notes_and_switches_test.tscn` now waits for the actual chute note to land, checks it remains above the floor and then checks collection; passage alone is insufficient.

# Random item spawn pool

The lever/chute and automatic spawner share `Data/Items/default_spawn_pool.tres`. Select it in Godot and add physical item scenes to **Items**. Each nonempty entry has an equal chance. The pool contains `Scenes/test_object.tscn` plus `Scenes/Items/beer_bottle.tscn`, `book.tscn`, `syringe.tscn` and `teddy_bear.tscn`, each with base value 1 and its own collision bank. See [imported art guide](ART.md) for materials, sounds and replacement props. Models alone are not entries: each needs a gameplay scene with rigid-body collision, pick-up/score groups, prompts, score component and collision sounds matching the test item. Keep the colliders small enough to clear the chute and enable continuous collision detection. Base item value remains 1; value upgrades still apply at spawn.

Select **ceiling_chute** or a placed automatic spawner to override its **Item Pool** with another resource. Lever pulls first try the eligible-note roll (50% for testing); if that roll fails or no eligible notes remain, they pick a random regular item. Automatic spawners use the item pool without notes. Null scene entries are ignored; an empty/null pool produces no regular item safely.

## Notes spawn only once

Blackboard **spawned_notes** stores an Array of note Id strings as soon as the physical note enters the world. These are separate from **found_notes**, which remains the picked-up journal. The note catalog excludes both already spawned and already found notes, so leaving a note on the floor cannot create duplicates. Deleting/loss/culling does not reset its spawn history. Restored world notes mark their Id as spawned too; older found-note data also suppresses duplicates without requiring spawn history.

To deliberately reset a note during development, clear its Id from spawned_notes and its entry from found_notes. Set Note Drop Chance to 0.01–0.03 for production. Add new note definitions to Data/Notes/default_catalog.tres as before; each must have a unique Id.

## Script API

`Scripts/Actors/item_spawn_pool.gd`: class item_spawn_pool extends Resource, UID `uid://dh6aqxub3dcnh`; no autoload, signals or runtime state. Export `items: Array[PackedScene]`; `pick_item() -> PackedScene` returns a random valid entry or null. Default resource: Data/Items/default_spawn_pool.tres. ceiling_chute and automatic_spawner now export `item_pool` instead of their former single-scene properties test_actor/item_scene. WorldState.spawn_item still applies value effects, positions, tracks and restores each selected scene separately.

Notes adds `has_spawned(id: StringName) -> bool` and `mark_spawned(id: StringName)`; note_drop._ready calls mark_spawned for fresh and restored drops, and collect also marks legacy journal entries. note_catalog.available uses has_spawned.

`Tests/spawn_pool_test.tscn` checks unique uncollected drops, exhausted-note fallback, random selection across two physical scene types, ordinary scoring, deletion without respawn, older journal compatibility, null/empty pools and automatic output.
