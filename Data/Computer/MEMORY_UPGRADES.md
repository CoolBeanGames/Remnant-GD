# Memory unlock upgrades

The physical PC Self tab offers Memory 1 for 1,500 score (apartment), Memory 2 for 25,000 (warehouse) and Memory 3 for 50,000 (hospital). Each first appears at half its price: 750 / 12,500 / 25,000 current score. Introduction stays saved in Blackboard.revealed_memories after spending. Purchase opens the selected area through the Strange Door and removes the offer entirely; there is no second charge or recovery button to buy.

## Return freely; complete before finishing

The October F1 correction supersedes completion-only travel: an unfinished memory permits ordinary door interaction and two-way walking. Returning leaves that same memory and portal available for reentry, with ownership and active_memory_id intact. Other memory purchases remain blocked until its completion flag is true. F9 explicitly previews destinations even while a purchased memory is unfinished; it preserves that purchase and its completion flags. Leaving does not invent completion.

Story triggers set exactly `memory 1 complete`, `memory 2 complete` or `memory 3 complete` with Flags.set_flag(name,true). Explicit completion releases the purchase lock. An occupied area remains until the player returns; completed return closes the portal, evacuates original saved cargo to the workshop, restores player layers and requests the existing animated door closure. There is no return barrier or locked-door prompt. Future story triggers remain to be authored.

Continue retains unlock/completion flags, tiers, introduced offers and portal identity. Production startup still performs the concrete-room wake-up, suspending the owned portal until that room disappears. With cinematics disabled the save fixture verifies exact inside pose/layers. New Game resets these run purchases; permanent mulch, Mulcher ownership and lifetime earnings remain.

## Authoring and APIs

Data/Computer/memory_{1,2,3}.tres expose Title, Description, Base Cost, Unlock Flag, Memory Destination and Completion Flag. Each has max_level=1. No earlier-number prerequisite is imposed beyond finishing another purchased memory. Unlock flags are separate `memory N unlocked` values.

- Scripts/Computer/computer_entry.gd / computer_entry / Resource / uid://dl5o07aajxv84: destination, completion, reveal_lifetime_score and single_purchase fields. Memory reveal uses half Base Cost independently of regular lifetime thresholds.
- Global/progression.gd / Progression / Node autoload / uid://wmyou0qisasn: register_catalog, entry_visible, purchase, pending_memory, memory_purchase_error, memory_portal, memory_is_open and reopen_memory; changed/purchased signals. Validation precedes charging; purchased tiers repair missing unlock flags. Reopen remains an API recovery operation; purchased rows are hidden.
- Scripts/Portal/door_portal.gd / door_portal / Node3D / uid://bt22t5fy4mlpu: purchase_required is true in testing_level; open_memory(id,destination), memory_complete, teleport_player, crossed and destination_changed. active_memory_id/portal_destination_id/portal_inside persist through Blackboard. Only completed return disposes scenery.
- Scripts/Portal/portal_return_door.gd / portal_return_door / Node3D / uid://ovsxfk8wogvk: normal shared-door interaction, mirrored animation/prompts and optional pooled Audio. No completion travel lock.
- Scripts/UI/computer_ui.gd / computer_ui / Control / uid://bjci6pu4481e4: hides introduced-unaffordable/purchased offers according to Progression; existing PC SubViewport/row scenes. E focuses; Esc/EXIT returns. Global diagnostic keys pass through even during camera motion.
- Scripts/Portal/portal_space.gd / portal_space / RefCounted / uid://cukcn0vyejk4g: remap_mask/apply_actor, original mask caching and live-instance scenario unpair/rejoin during actual mask changes. Retains the installed-engine stale-light-pair workaround during cargo evacuation.

## Verification

Tests/memory_unlocks_test.tscn covers actual screen purchases, exact prices, hidden purchased offers, unfinished return/reentry, completion-only disposal, flag/tier disk reload and New Game reset. Tests/memory_portals_test.tscn covers the production scene, real capsule walking, save/Continue, retained ownership, completion and original cargo evacuation. Tests/issue_batch_test.tscn covers reveal thresholds and persistence. Isolate APPDATA for save-mutating fixtures; inspect logs and rendered views separately.

## F9 preview ownership

F9 cycles apartment → warehouse → hospital after the initial room disappears. It works during an unfinished paid memory and returns an inside player/cargo safely before replacing the area. Ordinary select_destination(id) still refuses to replace a paid memory; F9 uses select_destination(id,true). Runtime debug_override and Blackboard.portal_debug_preview distinguish a preview from owned memory_id/active_memory_id. Continue preserves both. A preview cannot complete or close another memory. Cycling back to the purchased destination restores its ordinary completion/return behavior. Purchases remain governed by the original memory flags and tiers; debugging does not grant completion. Menus, wake-up and respawn suspension still block the shortcut.
