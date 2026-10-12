# Essential gameplay feedback

The user prefers restrained traditional UI and in-world displays, while explicitly keeping the crosshair and useful gameplay prompts. Do not interpret minimal UI as removing essential feedback. Both the repository and installed Godot skill retain this exception. Old-school UI is acceptable for early drafts.

## Visible while playing

Scenes/testing_level.tscn restores CenterContainer/TextureRect (existing Aim.png), Prompt_Container/HBoxContainer, ComboDisplay and PortalStatus. Dynamic Resource-driven labels retain look-at, carry, power, rotation, B Place and F Cancel behavior. Raycast debugging stays off. The combo remains text-only. WordMessage/DialoguePlayer show_text=true restores story and dialogue captions with existing audio/timing.

The actual PC upgrade display and lit physical notes remain in world. E connects to the PC; F collects/holds notes; N toggles the typed version; Esc disconnects or puts paper away. Pause Notes continues to load physical originals.

## Visibility and ownership

Scripts/UI/gameplay_crosshair.gd extends CenterContainer (UID uid://d2vp0rgn4opt3, no autoload/signals/exports). _ready enables PROCESS_MODE_ALWAYS; refresh() and _process hide it during pause, input locks and developer modals, then show it when gameplay resumes. Both crosshair controls ignore mouse input so they cannot obstruct PC screen clicks.

Scripts/UI/prompt_display.gd retains its existing class, exported wiring, Resource selection, reusable labels and public refresh/get_current_prompts API. PROCESS_MODE_ALWAYS clears prompts during pause/input locks/developer modals, including immediately paused physical reading. Combo/portal displays update visibility while paused, but pause does not advance their timers.

The gameplay_hud group identifies the crosshair root, prompt row, combo/portal layers and story/dialogue labels. Scripts/UI/world_view_session.gd hides these alongside carried 3D objects using weak references and original visibility. _hide supports Node3D, CanvasItem and CanvasLayer; restore handles removed nodes safely. Story labels respect active world viewing sessions while their sequence/audio logic continues at the existing rate. Scene unload restores camera/input/cargo ownership as before.

## Verification

Tests/world_interfaces_test.tscn checks an actual lever ray contact with visible crosshair/prompt labels, held fan controls, ghost place/cancel prompts, hiding during PC/paper and restoration on exit. It also retains screen-coordinate purchases, save look direction, N/Esc/journal, custom art, basket identity and cleanup. Prompt, combo, computer, note, guidance, dialogue, wake-up and portal test scenes verify the existing surrounding behavior. Audio cleanup allows the mixer to release stopped WAV playback before test shutdown.
