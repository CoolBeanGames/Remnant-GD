# Mulch, flashlight and journal followup

Ten new local F1 descriptions and sibling screenshots were read and visually opened before editing. This followup addresses repair prompts, portal flashlight, F9 cycling, pellet multi-grab/value/shape, fixed bin, automatic lever/output/collector upgrades and journal clicks. The user confirmed the ambiguous automatic-lever request. Original reports/screenshots and resolution records stay private in .issues/inbox.

## Current behavior / controls

Look at the broken mulcher for Repair Mulcher / cost [E]. Repairs show their remaining time; healthy machines show damage. The bin is permanently fixed beside it at MulchBinMount, with old portable saves migrated once. Pellets use actual box physics and now participate in multi-grab. Bank for permanent currency, or grind to recover half the producing items' pre-combo score through the existing combo/reward queue. No recursive mulch production. Pending and emitted fractional score survive Continue.

The Mulch tab adds Automatic Lever (50 coins once), Lever Output Multiplier (12 initially, ×2 per tier with ×2.5 costs), and Mulch Collector (25 once). E pauses/resumes automatic animation. Output stacks with ordinary tiers and stays individually spaced; automation waits for the chute batch. Collector banks new machine output and loose workshop pellets at purchase; it skips held/remote currency. All permanent tiers survive New Game.

T toggles the camera flashlight. It keeps its choice across rooms and Continue, and a mapped light illuminates the viewed space through either side of the doorway. Existing ambient environments are untouched. Closed/off-screen/suspended portals disable the extra beam. F9 cycles environments even with an unfinished paid memory, preserves its ownership and completion flags, and restores normal completion behavior when cycled back to the owned area. It does not bypass future memory purchase locks.

Clicking an already-selected first journal row opens its physical paper. Enter also works. Esc returns to the journal; N retains the typed transcript.

## Editable systems / validation

Data/Mulch/README.md describes contributions, pellet_score, the fixed bin, profile/run boundaries and repair APIs. Data/Computer/LEVER_UPGRADES.md covers automation and output effects. Data/Computer/MEMORY_UPGRADES.md and Data/Portal/README.md document paid preview identities and player_flashlight. Data/WORLD_INTERFACES.md records actual click handling. Scenes retain reusable prompt components; audio continues through Audio and the existing pool.

Selected scene checks cover real physics multi-grab/deposit, fractional save reload, duplicate-bin migration, automatic animations, queued output, ordinary upgrades, story purchase locks, preview Continue, actual note mouse/Enter input, scoring and nested portal cargo. Rendered checks cover repair text visibility, source/reverse/direct flashlight contribution and journal paper. Windows export, rendered release-PCK check, HTML/browser verification and actual source/hosting outcomes are recorded in Reports/development_summary.html#mulch-followup. These checks are not a full manual playthrough or final economy balance.
