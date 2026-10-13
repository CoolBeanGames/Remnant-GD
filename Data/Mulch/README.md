# Mulcher, pellets and permanent mulch upgrades

Buy Mulcher in the computer Store for 1,000 score. Permanent ownership automatically installs it at testing_level/grinding_area/MulcherMount in subsequent runs. Buy one Mulch Bin per run for 500 score: it installs at grinding_area/MulchBinMount beside the machine, stays solid and cannot be picked up or moved. Edit those markers and the independent Scenes/Mulch scenes for placement/art. Retain the station Output, Status, DamageGrid, Prompts and PromptAnchor nodes. Old portable-bin saves migrate to this fixed mount; duplicate bin records are removed.

Accepted ordinary grinder items contribute score_object.mulch_value, clamped 1–5, times current efficiency. Defaults: test block 5, beer bottle 4, book 3, teddy bear 2, syringe 1; unconfigured items use 1. Normal score/combo continues. Each 100 points ejects one physical, square 0.24 m pellet. Box physics, zero bounce, CCD and a separate enlarged aim target keep it usable without rolling. F picks up pellets; carry-capacity upgrades now include nearby pellets in real multi-grabs. Held pellets cannot be deposited or ground. Currency remains excluded from other machinery feedstock through machine-immune.

## Bank or regrind

Each item contributes half its actual base score, after item-value upgrades but before combo multiplication, to the pellet ledger. FIFO points/score contributions split proportionally at pellet boundaries. Efficiency can create more pellets, but conserves the same total stored score. Fractional values survive save/Continue; the ordinary combo rounds only its final payout. Pending legacy points and old pellets have zero stored score because their historical value was not recorded.

Drop a pellet into the fixed bin to bank its coin_value (default one) into permanent mulch currency. Alternatively grind it to award its stored_score through the normal combo and accelerating ScoreRewards queue. Regrinding consumes that pellet and does not produce mulch points or damage the mulcher; it cannot recursively generate currency. Deposit/deletion guards prevent duplicate rewards.

Each ordinary item adds one damage; base durability is 100. The physical machine has a 10×10 damage grid. Look prompts show current damage, Repair Mulcher / cost [E] when broken, and the remaining repair time. PromptAnchor keeps text clear of the adjacent bin. Full damage stops mulching while ordinary grinding remains available. First repair costs 100 score, takes four seconds and later costs multiply by 1.6 per completed repair. Saved in-progress repairs resume; repeated interactions cannot charge twice.

## Upgrades

Regular Mechanics buys durability (250 score, ×1.5 per tier) and efficiency (500 score, ×1.25); both have ×3 prices. The fourth PC tab requires installed Mulcher and the current run's bin. Its twelve entries use permanent banked coins and stack after ordinary upgrades. Existing item value, run speed, carry capacity, jumping/height, durability, efficiency, fan power, spawner interval and Grind Additional Items remain available.

| New permanent entry | Initial cost | Behavior / adjustable resource |
| --- | --- | --- |
| Automatic Lever | 50 coins, once | Data/Mulch/automatic_lever.tres. Automates the existing lever; E pauses/resumes. Default two-second delay after reset; it waits for the previous spaced batch to drain. |
| Lever Output Multiplier | 12 coins, ×2.5 price, unlimited | Data/Mulch/lever_output.tres. Doubles output after ordinary output tiers; maximum 256 items per pull, individually spaced through the existing chute. |
| Mulch Collector | 25 coins, once | Data/Mulch/collector.tres. Banks new output automatically and collects loose workshop pellets at purchase. Held pellets and memory-space pellets are excluded. |

New Game keeps coins, permanent tiers, Mulcher ownership and lifetime earnings. Run score/regular upgrades, bin ownership, damage/repairs, pending contribution ledger and unbanked pellets reset. Explicit Delete Save in Options deletes run and profile data. Collector banking coalesces profile persistence for each output batch or existing-pellet sweep.

## API / state

| Script / identity | State / API / dependencies |
| --- | --- |
| Global/mulch.gd / Mulch / Node autoload / uid://dgh4wrf1yedj6 | points_per_pellet, base durability/efficiency, damage_per_item, repair settings, pellet_scene; level, station, bin, contributions, automatic_collection. restore(), bind_level(root), install()->bool, install_bin()->mulch_bin, consume(item,score_value=-1), deposit(pellet,persist=true)->bool, repair()->String, buy_upgrade(entry,player). Signals changed, pellet_produced, coins_changed. Uses Blackboard, Flags, SaveGame, WorldState and Progression. |
| Scripts/Mulch/mulcher_station.gd / mulcher_station / StaticBody3D / uid://xu0ohq42ko84 | refresh, interact, get_look_prompts; existing reusable object_prompts child and authored anchor. |
| Scripts/Mulch/mulch_pellet.gd / mulch_pellet / RigidBody3D / uid://bdrh7fn1s7rta | coin_value=1, stored_score=0, can_grind; WorldState tracking and dynamic F prompt. Groups pick-up, mulch-pellet, machine-immune. |
| Scripts/Mulch/mulch_bin.gd / mulch_bin / StaticBody3D / uid://dhnsd4qfajvhf | Deposit Area3D, solid open-top walls, _deposit and get_look_prompts. Groups mulch-bin, machine-immune, look-prompt; no pickup. |
| Scripts/Actors/physics_items.gd / physics_items / RefCounted | is_multi_grabbable adds eligible loose pellets; is_processable keeps reusable tools excluded. player_pickup uses this shared gate for nearby cargo. |
| Scripts/Level/grinding_area.gd / grinding_area / Area3D | item_ground(points:float). Pellet stored score enters GrindCombo directly, without Mulch.consume. |
| Global/grind_combo.gd / GrindCombo / Node autoload | base_points and record_item(points) retain floats; pending_points rounds the final multiplied payout into the existing integer reward queue. |
| Global/world_state.gd / WorldState / Node autoload | Actor pellet_score and pending contribution ledger restore; legacy bins install once at their fixed mount. Saved persistent_item_id is assigned before _ready to prevent duplicate registry aliases. |

Flags: mulcher purchased, mulch bin purchased. Blackboard: mulch_points, mulch_contributions [{points,score}], mulcher_damage, mulcher_repairs, mulcher_repair_remaining, lever_auto_paused, upgrade_levels. Profile: mulch_coins, mulch_upgrades, mulcher_unlocked. Individual actor records store pellet_score. All remain in the existing single save file.

Tests/mulch_system_test checks installation, production, real deposits, repairs, stacked upgrades and New Game. Tests/mulch_followup_test checks actual repair ray/prompt, fractional ledger conservation and reload, no recycling, old duplicate bins, real radius multi-grab, collection and actual automatic animations. Its rendered fixture uses Reports/MulchFollowup/game. Related authoring: Data/Computer/LEVER_UPGRADES.md and Data/Mulch/PRESTIGE_ITEMS.md.

## Item upgrade prerequisites

Permanent Fan and Spawner upgrades additionally require the matching first Store purchase in the current run. The paid permanent effects survive New Game and apply to later deliveries, but further tiers remain hidden until that run buys the tool. Regular/permanent Mulcher durability and efficiency accept its persistent installation; Collector accepts the run's Mulch Bin purchase. The shared `required_purchase` field and both purchase APIs enforce this rule. See [computer authoring](../Computer/README.md).
