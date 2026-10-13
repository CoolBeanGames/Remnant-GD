# Random item spawn pool

The lever/chute and automatic spawner share `Data/Items/default_spawn_pool.tres`. Select it in Godot and add physical item scenes to **Items**. Each nonempty entry has an equal chance. Its nine production entries under `Scenes/Items` are baby_bottle, beer_bottle, clipboard, meat_slab_a, meat_slab_b, meat_block, syringe, book and teddy_bear, each with base score 1 and a configured collision bank. `Scenes/test_object.tscn` remains for older saves/tests and is excluded from this pool. See the [imported art guide](ART.md) and [Trip workflow](TRIP_MODELS.md) for materials, sounds and replacement props. Models need gameplay scenes with rigid-body collision, pick-up/score groups, prompts, score components and pooled collision sounds. Keep colliders small enough to clear the chute and enable continuous collision detection. Value upgrades apply at spawn.

Select **ceiling_chute** or a placed automatic spawner to override its **Item Pool** with another resource. Lever drops first try the eligible-note roll (2% by default); if that roll fails or no eligible notes remain, they pick a random regular item. The current default note catalog contains first_shift, power and door. Automatic spawners use the item pool without notes. Null scene entries are ignored; an empty/null pool produces no regular item safely.

## Notes spawn only once

Blackboard **spawned_notes** stores an Array of note Id strings as soon as the physical note enters the world. These are separate from **found_notes**, which remains the picked-up journal. The note catalog excludes both already spawned and already found notes, so leaving a note on the floor cannot create duplicates. Culling an unread note below the floor or in the chute releases its spawn history; scene unload and collected notes do not. Restored world notes mark their Id as spawned too; older found-note data also suppresses duplicates without requiring spawn history.

To deliberately reset a note during development, clear its Id from spawned_notes and its entry from found_notes. Set Note Drop Chance to 0.01–0.03 for production. Add new note definitions to Data/Notes/default_catalog.tres as before; each must have a unique Id.

## Script API

`Scripts/Actors/item_spawn_pool.gd`: class item_spawn_pool extends Resource, UID `uid://dh6aqxub3dcnh`; no autoload, signals or runtime state. Export `items: Array[PackedScene]`; `pick_item() -> PackedScene` returns a random valid entry or null. Valid authored pools pick directly without allocating a temporary list; null slots use a filtered fallback and retain equal valid-entry weighting. Default resource: Data/Items/default_spawn_pool.tres. ceiling_chute and automatic_spawner export `item_pool`. WorldState.spawn_item applies value effects, positions, tracks and restores each selected scene separately.

Notes adds `has_spawned(id: StringName) -> bool` and `mark_spawned(id: StringName)`; note_drop._ready calls mark_spawned for fresh and restored drops, and collect also marks legacy journal entries. note_catalog.available uses has_spawned.

`Tests/spawn_pool_test.tscn` checks unique uncollected drops, exhausted-note fallback, random selection across two physical scene types, ordinary scoring, deletion without respawn, older journal compatibility, null/empty pools and automatic output.

`Tests/trip_models_test.tscn` checks nine-entry production selection and every model clearing the actual chute and landing on the floor. `Tools/verify_trip_assets.py` verifies all 32 current portable source/export/render paths; the Trip guide also identifies the native and linked-assembly checks.
