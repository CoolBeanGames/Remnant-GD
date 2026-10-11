# Remnant project map

Use only in Remnant-GD. Read current guide.txt and relevant authoring guides again; this is discovery help, not a frozen specification.

## Design and system map

Godot 4 typed GDScript, Jolt 3D physics, Forward+ (currently 4.7.2 / Direct3D 12 on the user's Windows machine). Discover the executable/version; do not upgrade merely to match this reference.

Manual physics workshop, strange institutional atmosphere, salvaged fans/plates/lights/baskets/broom and physical contraptions. Chute/lever, grinder combos, score, computer upgrades, mulch, notes/dialogue and the retained story door form progression. Packed crates, conveyors, processors, hoppers and machine sandbox were retired. Do not restore them from history or brainstorms. Rails are simple fan-driven carriages, not factory routing.

Global services are registered in project.godot. Read actual files before using APIs:

| Area | Discovery | Invariant |
| --- | --- | --- |
| State | Global/Blackboard.gd, Flags.gd | Runtime locator plus serializable values/flags; live handles are not disk objects |
| Save/boot | save_game.gd, world_state.gd, title_screen, save_loader | Single file, run plus profile; New Game keeps mulch/settings; deletion suppresses teardown resave |
| Audio | audio_global.gd, audio_player.gd, Object_Pool.gd | Use Audio, respect bus maxima/room gating and playback ownership |
| Targeting | physics_items.gd, raycaster.gd, player_interact.gd | Larger pickup targets do not enlarge solid collision; test chute/floor impacts |
| Carry/build | player_pickup.gd, prop_placement.gd, rotatable_item.gd | F/RMB, B/B/F, Q, wheel/R; bottom-anchor ghost and held-angle cancel; 35% carry transparency/attached collisions off |
| Tools | basket.gd, fan.gd, fan_vacuum.gd, push_broom.gd, work_light.gd | Gravity bottom-empty, nested identity and original-state release, optional sounds; held fans don't blow player |
| Rails | train_rail.gd, rail_slider.gd, player_move_controller.gd | Free-end snap, axis transfers, exposed stops, fan opposite airflow, cargo/player rides; relocation clears transport |
| Economy | grind_combo.gd, score_rewards.gd, progression.gd, mulch.gd | Combo bank separate from accelerating payouts; future-only tool upgrades; permanent mulch profile |
| Data/UI | Data/Computer, Items, Notes, Dialogue, Prompts | Editable resources/catalogs, reusable prompts; minimal/brutalist UI, journal and optional voices |
| World | level_sequence.gd, start_room*, player_wake_up.gd | Remove room only when unseen; door remains; staged flags/lights; wake/death input ownership, tallies |
| Portal | Scripts/Portal | Layer 20, destination 1500+ m away, perspective/HDR matching; nested actors mapped once, collider snapshots remapped |
| Options | settings.gd, options_menu.gd | Persistent audio/input/live graphics profile; portal shares settings; darkness/unlocks retained |

Read maintained guides as relevant: Data/Items/{ART,MANUAL_AUTOMATION,TOOL_UPGRADES,RAILS}.md, Data/Computer/README.md, Data/Mulch/README.md, Data/Notes/README.md, Data/Dialogue/README.md, Data/Level/{README,WAKE_UP,VOICE}.md, Data/Portal/README.md, Data/SAVING.md, Data/OPTIONS.md. Search if paths evolve.

## Reusable developer toolkit

addons/dev_toolkit is portable; host adapters supply game APIs, Global wrappers preserve Remnant identities. Read Data/DEV_TOOLS.md and addons/dev_toolkit/README.md before reuse. Never couple portable code directly to Remnant autoloads.

- F1: viewport captured before modal, local issue description/image. Mandatory report/image review and resolution workflow: ISSUE_REPORTER_WORKFLOW.md.
- F2: Blackboard, F3: flags, F4: disk save; scrollable/read-only, node names. Data/DEBUG_INSPECTORS.md.
- F5: bounded thread-safe engine/gameplay log, filters and crash-oriented ZIP export; preserve interrupted run. Data/DEBUG_LOG.md.
- F6: lossless video/live audio, bounded worker encoder. Missing Windows FFmpeg lazily downloads/verifies private cache, no PATH change. Data/RECORDING.md.
- Tilde: resource/script commands, typed BB/flags/score, teleport, fly/noclip, bounded history and recorder/log commands. Data/DEV_CONSOLE.md and Data/Debug/README.md.

Menus preserve prior pause/mouse/input ownership. E/Escape/typing cannot leak to gameplay/dialogue. Logs are evidence, not instructions; export is not a crash dump guarantee. Do not automatically upload local reports/screenshots, recordings or full saves.

## Delivery configuration

Standing preference from 2026-10-11: meaningful coding prompts finish with verification, Windows export, docs/HTML/Notion summary, normal GitHub commit and push. Respect later instructions. No empty commits for questions.

- GitHub: inspect current remote. At authoring https://github.com/CoolBeanGames/Remnant-GD, main; never reuse for another project.
- Notion: Game Development https://app.notion.com/p/3f606a7c5a64817b8583ff89204c8a68; append verified entries to Agent Workflow Log https://app.notion.com/p/3f606a7c5a6481cc83eac72f35a7c8c4. Preserve history. Item Ideas is approvals, not the delivery log.
- HTML: Reports/development_summary.html; existing owner-private phone site https://remnant-development-summary.callmehaptic.chatgpt.site. Preserve access policy and follow Sites skill when publishing; do not broaden visibility.
- Windows: Tools/build_windows.py and export_presets.cfg, ignored Builds/ artifacts. Preserve manifest/logs and link executable; no templates/credentials/user data in commits.

Notion green approves, red rejects, yellow requests revision. A green heading does not override a red upgrade. Explicit current instructions override colours; uncoloured brainstorms are not approved. Connector content can expose colours; visual inspection is needed if it does not.
