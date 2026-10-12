# Memory unlock upgrades

The in-world computer's Self tab sells Memory 1 for 1,500 score (apartment), Memory 2 for 25,000 (warehouse) and Memory 3 for 50,000 (hospital). Each is purchased once at a fixed price. Buying opens the selected area through the Strange Door. No other memory can be bought until the purchased memory's completion flag is true; ordinary upgrades and store purchases remain available.

## Complete, return and reopen

Story triggers set exactly memory 1 complete, memory 2 complete or memory 3 complete with Flags.set_flag("memory 1 complete", true). Completion releases the purchase lock immediately and does not erase an occupied area. Walking back through the door closes the portal, unloads its scenery and requests the existing animated door closure. Saved loose/attached/contained cargo is safely evacuated to the workshop first. Leaving alone does not invent story completion.

An unfinished owned memory has a free OPEN button after returning. This prevents an early exit from stranding the player behind a permanent purchase lock. An already open memory cannot charge again; a completed memory cannot be repurchased. Continue preserves unlock/completion flags, purchased tiers and portal identity. The existing startup/respawn wake-up still returns the player to the concrete room, suspending an owned portal until that room disappears; re-entering costs nothing. With cinematics disabled, the saved inside pose/layers also restore exactly (verified by the persistence fixture). New Game resets these run purchases and retains the existing permanent mulch profile.

## Author the purchases

Edit Data/Computer/memory_1.tres, memory_2.tres or memory_3.tres. Title, description, price, Unlock Flag, Memory Destination and Completion Flag are editable. The resources use max_level=1 and the default catalog. Saved unlock flags are memory 1 unlocked, memory 2 unlocked and memory 3 unlocked; completion flags are separate. No earlier-number prerequisite is imposed beyond completing any already purchased memory. The story events that set completion remain to be authored.

Scripts/Computer/computer_entry.gd (computer_entry / Resource / uid://dl5o07aajxv84) exports unlock_flag:String, memory_destination:StringName and completion_flag:String, empty by default. Regular Mechanics/Self permissions can set a saved flag without numeric Effects; memory destinations additionally select an existing DoorPortal destination. Store/mulch entries retain their own purchase behavior.

Global/progression.gd (Progression / Node autoload / uid://wmyou0qisasn) owns register_catalog, level and purchase, with changed/purchased signals. Memory destination validation/selection succeeds before score is charged. A successful transaction stores deducted score and upgrade_levels, then sets the unlock flag before purchased/changed. Catalog registration repairs missing flags from purchased regular tiers and subscribes to completion changes. pending_memory(), memory_purchase_error(entry), memory_portal(entry), memory_is_open(entry) and reopen_memory(entry) coordinate the lock and free reopening. Invalid, unaffordable, blocked and completed purchases spend nothing.

Scripts/Portal/door_portal.gd (door_portal / Node3D / uid://bt22t5fy4mlpu) exports purchase_required (false by default; true in testing_level), registers the story-portal group and adds open_memory(id,destination_id). Runtime memory_id and closing_memory track the owned portal; Blackboard active_memory_id and portal_destination_id preserve it. Returning defers room cleanup until teleport/cargo movement finishes. The existing crossed and destination_changed signals, portal layers, view matching, audio, graphics and save services remain. F9 is a debug preview only while no paid memory is active or unfinished; Purchase Required=false preserves autonomous test-room behavior for other scenes.

Scripts/UI/computer_ui.gd (computer_ui / Control / uid://bjci6pu4481e4) uses existing rows and the PC SubViewport. Unowned offers show their exact price; blocked rows explain which memory must be completed. Owned incomplete rows show OPEN/OPEN PORTAL and AWAITING COMPLETION. Completed rows show disabled UNLOCKED. E focuses the display; Esc/EXIT returns to gameplay.

## Verification

Tests/memory_unlocks_test.tscn exercises actual screen buttons, exact prices, insufficient funds, one-time charges, all three real destinations, completion gating, return cleanup, free reopening, flag/tier disk reload and New Game reset. Tests/memory_portals_test.tscn exercises the production testing level, actual capsule walking, saving while inside, Continue restoration, explicit completion, return closure and saved cargo evacuation. Isolate APPDATA for save-mutating tests. Existing computer/save/mulch/prestige/lever/level/world-interface and portal/assembly/graphics tests cover shared behavior. Optional rendered screen captures use the same fixture.
