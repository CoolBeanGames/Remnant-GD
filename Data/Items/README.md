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
