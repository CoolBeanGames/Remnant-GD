# Editing the workshop computer

Open `Scenes/testing_level.tscn` and select **Computer**. Press E to focus the actual PC screen. Click/scroll its textured display; Esc or EXIT restores gameplay. See [world interfaces](../WORLD_INTERFACES.md).

## Catalog and prices

The Computer's **Catalog** is `Data/Computer/default_catalog.tres`. Each entry is its own `.tres` in this folder. Select an entry in Godot to edit its title, description, tab (Mechanics / Self / Store), base cost, cost multiplier, and maximum level. A zero maximum is unlimited; Store entries are always repeatable. Enable Escalating Store Price to increase cost by Cost Multiplier after each successful purchase; leave it off for fixed prices.

To add something, duplicate an entry, give it a unique **Id**, and add it to the catalog's Entries array. Upgrade entries need one or more Effects, or a nonempty Unlock Flag for a regular story permission. Store entries need a Delivery Scene and Delivery Kind. No UI code changes are needed to add rows.

## Upgrade effects

Each `upgrade_effect` has a Target, Property, Operation (Add / Multiply / Set), and Amount. Examples:

| Target | Property | Operation / amount | Applies to |
| --- | --- | --- | --- |
| fan | force | Multiply / 1.25 | New store fans only |
| fan | maximum_speed | Multiply / 1.15 | New store fans only |
| plate | physics_material_override:bounce | Add / 0.1 | New store plates only |
| item_value | score | Multiply / 2 | New chute items only |
| movement | move_speed | Multiply / 1.15 | Current player |
| movement | jump_enabled | Set / 1 | Unlock Space jump |
| pickup | grab_capacity | Add / 1 | Current player |

Effects repeat once per purchased level and use original values as baselines. Existing fans, plates and spawned items keep their stats; do not call `Progression.apply_new_prop` on old props. Fan/plate physics materials are duplicated per purchase so shared resources cannot change old objects.

For another player ability, implement an exported numeric/bool property in the appropriate controller, then target it with an effect. For another mechanical target, extend Progression's target resolver and Delivery Kind enum. Use unique entry IDs across all terminals in the session.

## Delivery and artwork

Move **DeliveryPoint** in the testing level to choose where purchases drop from the sky. Computer > Delivery Point and Delivery Parent can be changed independently. Store entries can reference any Node3D scene; current stock is Fan, Steel Plate, Light, Basket, Push Broom, Train Rail, Rail Slider, Automatic Spawner, Mulcher and Mulch Bin. Air placement is a Mechanics unlock on normal future fans/plates. Mark future fan/plate entries with their matching Delivery Kind to receive purchased Mechanics upgrades.

`Scenes/Computer/computer_terminal.tscn` is the placeholder physical computer. Keep its root script and collider when replacing the artwork. `Scenes/UI/computer_ui.tscn` controls the viewport layout/theme and `computer_row.tscn` is the reusable offer row. Keep named control paths referenced by `computer_ui.gd` when rearranging those scenes.

## Controls and state

F with Multi Grab collects nearby loose items up to Grab Capacity (defaults to one); Grab Radius is adjustable on Player_Pickup. Tools and baskets remain single pickups. F drops the group; RMB throws the whole group. Extra items retain spacing, disable collisions, fade while carried, and recover their physics on release. Jump is disabled until purchased; Space only jumps while grounded. Speed upgrades affect both walking and sprinting.

Purchases spend the current Blackboard `score`, including points as they arrive from the existing payout queue. `Progression.levels` and Blackboard `upgrade_levels` contain purchased tiers; disk saving remains separate. Invalid, unaffordable and completed purchases do not deduct score. UI refreshes score as payouts arrive and restores the previous mouse/input state when closed or removed.

## Optional audio

The Footsteps bus now sends to Game_Master directly, so the room's SFX mute does not silence walking. Your selected footstep sound banks are preserved.

Fan > Optional Audio > Fan Sound accepts a clip, or assign a stream directly on its **FanSound** AudioStreamPlayer3D child. Volume and bus are configurable; its max distance is editable on the player node. The sound repeats while the fan is visible, stops during ghost placement, and resumes afterward. Empty streams are silent and safe. Both normal and upgraded fans inherit this player.

Room OmniLight3D > Optional Audio > Flicker Sounds is an optional random sound bank. Each outage plays one assigned sound at the light position using the existing pool, with configurable volume/bus (RoomSFX default). An empty array or a null slot is safely skipped.

## Staged workshop and runtime restoration

`Scenes/testing_level.tscn` uses `Scripts/Level/level_sequence.gd`. Its exported delay defaults to 3 seconds after the player physically exits the room. Until then the lever/chute is disabled and its prompts are hidden. Five successful manual lever pulls enable the grinder; 30 awarded score enables the computer screen and interaction. These unlocks remain enabled after spending score.

| Flag | Result |
| --- | --- |
| exited room | Existing visibility rule removes the room and retains the door; startup skips the room |
| level enabled | Chute, manual lever, level and chute lights enabled |
| grinder enabled | Grinder intake, rollers, running audio and grinder lights enabled |
| computer enabled | Computer screen, interaction and overhead spotlight enabled |

Startup reads these flags before lights initialize. A later stage implies the initial level stage. Restored lights turn on silently; live transitions play one optional pooled 3D power-on clip per light. `Scripts/Level/staged_light.gd` exports Unlock Flag, Power On Sound, Sound Volume and Sound Bus; clearing the sound is safe. The provided `Audio/SFX/light_power_on.wav` can be replaced. Spotlights preserve their authored intensity. Select the testing-level root to change delay, thresholds, system references and Kill Height (default -10).

The testing level contains no loose test props. The manual chute remains available alongside store deliveries. Every base spawned scoring item is worth 1; value upgrades and combo bonuses still apply.

### Automatic spawner

`Scenes/Actors/automatic_spawner.tscn` is a pickup/ghost-placeable prop sold for 400 score initially. Place it using B/B/F like other props. Its Output marker determines where items appear; Item Pool determines which random scene is selected. It produces one item every 8 seconds while placed, unheld and the level is enabled. Inspector exports configure the item pool, interval, minimum interval and required flag. Empty Required Flag removes the level requirement.

`Data/Computer/spawner_speed.tres` starts at 250 score, scales by 3.0, has five tiers and multiplies the interval by 0.8 each tier. This upgrade applies to existing and future spawners. The default catalog has 48 entries: eighteen Mechanics, six Self, twelve Store and twelve Mulch. Edit these resources to change prices and effects. The effect target and store delivery kind accept spawner.

### Blackboard state

`Global/world_state.gd` is autoloaded as WorldState. `begin(level, player, kill_height)` restores player and spawned props after tree setup. `spawn_item(scene, parent, transform, apply_value)` and `track(actor)` register runtime deliveries; `untrack(actor)` removes ground items before deletion. `capture()` updates the item array. New custom spawn paths should call spawn_item or track after adding the actor to the level or game root.

Player state updates every physics tick: `player_transform` (Transform3D), `player_position` and `player_rotation` (Vector3), and `player_camera_rotation` (Vector3). Player Transform is preferred at startup; position/rotation are the fallback. Look-controller targets synchronize to the restored camera and body rotation.

`spawned_items` is an Array of Dictionaries refreshed every 0.1 seconds and on registry changes. Each entry holds a stable id, scene resource path, actor transform, nested rigid-body transforms/velocities/freeze state, score value, saved mechanics properties/baselines, placement/support links, and spawner interval/cooldown. Restoration preserves purchased item properties rather than reapplying current upgrades. Held props and basket contents restore as released physics objects. `lever_pulls` and `upgrade_levels` are also restored.

Items with all their rigid bodies below Kill Height are destroyed without score or grinding audio and removed from the array. Wrapper root positions do not prevent culling fallen child bodies. These snapshots are persisted by the existing single-file SaveGame system; see Data/SAVING.md.

`Tests/level_progression_test.tscn` checks stages, delay, automatic output, existing-spawner speed upgrades, score-one defaults, falling cleanup, exact player/body restoration and preserved item values.

## Current price curves

Mechanics/self tier costs are `ceil(base_cost * multiplier^purchased_level)`. Fan power starts at 40, plate bounce at 30, run speed at 30, multi grab at 50, jump at 60 and spawner speed at 250; their multiplier is 3.0. Item value starts at 50 with a 3.5 multiplier. Existing effect strengths/tier limits are unchanged.

| Store entry | Initial price | Multiplier per purchase |
|---|---|---|
| Steel plate | 20 | 1.8 |
| Basket | 30 | 1.8 |
| Fan | 175 | 1.8 |
| Automatic spawner | 400 | 1.8 |
| Train Rail | 90 | 1.8 |
| Rail Slider | 65 | 1.8 |
| Light | 10 | Fixed |
| Push broom | 10 | Fixed |

The fan now starts at 175 score (previously 35). Its existing 1.8 multiplier makes the first three purchases cost 175, 315 and 567. Saved delivery counts continue to determine the next price. Tune `buy_fan.tres` to adjust this balance; Fan Power and other fan upgrade prices are unchanged.

Successful deliveries increment their entry count in Progression.levels and Blackboard upgrade_levels. These counts persist separately from current world ownership: dropping, losing or retrieving an item does not reduce its next purchase price. The store shows DELIVERED / RISING PRICE for escalating offers. Snapshots are duplicated so resetting the live progression dictionary cannot erase saved counts. computer_entry exports escalating_store_price; cost(level) applies its exponent to upgrades and opted-in store entries, with bounded nonnegative integer costs.

The catalog now has eighteen Mechanics, six Self, twelve Store and twelve Mulch entries. Mulch is hidden until current-run Mulcher/Bin purchases; those upgrades use permanent coins and stack after normal tiers. Full prices/effects/authoring: Data/Mulch/README.md.

## Approved attachments and air placement

Air Fan and Air Plate are no longer separate store stock. Fan Air Placement (600 score) and Plate Air Placement (450) are one-time Mechanics upgrades for future normal deliveries; B still starts ghost placement and V optionally locks the held pose in air. Existing legacy air props remain compatible with saves. Vacuum Head (200), Fan Swivel Mount (150), Broom Side Skirt (75), Light Beam Hood (100) and Coloured Lens (80) are also single-tier upgrades for future tools. H switches upgraded fans between blow/suction, G empties their bag, J toggles sweep and L changes upgraded light colour.

Rail (90) and Slider (65) store deliveries each escalate by 1.8. Place the slider on the rail; resting cargo and built props follow it. A mounted powered fan drives it opposite the airflow. [Controls, prices and integration](../Items/MANUAL_AUTOMATION.md), [tool authoring](../Items/TOOL_UPGRADES.md), [rail authoring](../Items/RAILS.md).

## Lever and endpoint deliveries

See Data/Computer/LEVER_UPGRADES.md for the five-tier cooldown/output upgrades, staggered random drops and queue persistence. Rail Loader (140 initial score) and Unloader (170) are regular escalating Store deliveries; Data/Items/RAIL_STATIONS.md covers endpoint-only ghost placement and cargo transfer. Data/Mulch/PRESTIGE_ITEMS.md documents the 500-pellet permanent permission for the new prestige items group.


## Memory unlocks

The Self tab offers Memory 1 (1,500 score), Memory 2 (25,000) and Memory 3 (50,000). Each is a fixed-price, one-time run purchase that sets a saved flag, shows UNLOCKED and restores on Continue. Purchases open the apartment/warehouse/hospital portals. Other memory purchases wait for the active memory’s explicit completion flag. Unfinished return/reentry retains the portal; completed return closes it. F9 previews preserve paid-memory ownership even during an unfinished memory. See Data/Computer/MEMORY_UPGRADES.md for exact flag names, resource fields and tests.

## Catalog discovery and combo upgrades

Computer entries export reveal_lifetime_score (default 0), checked against Progression.lifetime_score(). Awarded score increments persistent profile.lifetime_score; spending does not reverse introductions, and New Game retains earnings. Old saves migrate their current balance; already purchased entries remain visible. Editable starter thresholds introduce ordinary upgrades gradually, from 75 earnings for Fan Power through 4,500 for spawner speed. Memories separately appear at half their fixed price and disappear after purchase; Data/Computer/MEMORY_UPGRADES.md defines the corrected return flow.

Mechanics adds Combo Maximum (+5 cap, 250 initial score / 350 reveal), Combo Increment (+0.25 step, 500 / 800 reveal) and Combo Decay (20% less window-shortening penalty, 750 / 1,500 reveal). Five tiers each, ×3 price growth, target=combo in upgrade_effect; effects apply immediately and restore from original baselines. Global/grind_combo.gd now caps the base multiplier at 15; initial 1.0 and +0.5 steps remain. The payout still uses the accelerating one-point queue.

single_purchase (default false) makes a Store resource one-time. Mulcher installs persistently and Mulch Bin is limited to one purchase per run. The physical screen layout fills its viewport with 18 px outer margins, 20 px default text and 114 px offer rows. F1–F7/tilde pass to global diagnostic tools before PC input forwarding, including focus/return motion.
