# Essential gameplay feedback and in-world prompts

The user prefers restrained traditional UI and in-world displays, while explicitly keeping the crosshair and useful gameplay prompts. Essential feedback stays usable. Old-school UI is acceptable for early drafts.

## Visible while playing

Scenes/testing_level.tscn has a tiny CenterContainer/TextureRect crosshair, a reusable Scenes/UI/world_prompts.tscn Node3D, text-only ComboDisplay/PortalStatus, and existing WordMessage/DialoguePlayer captions. Look text appears beside the targeted object. Carry controls follow the held model; B placement controls follow the visible ghost. If there is no placement surface, Cancel stays available beside the hold position. Existing key bindings and editable Data/Prompts resources are unchanged. Raycast debugging remains off.

World lettering follows the camera with a subtle local-Y angle (7 degrees by default), and stays unshaded and outlined, with normal depth testing: it needs no additional lamp and respects world geometry. The look ray still enforces range, enabled state and physical occlusion. Only the current controls are instantiated. Mesh bounds are cached for the current owner, exclude hidden upgrade variants and the ghost direction arrow, and move with the model. Readability scaling is bounded; positioning tries the right, then left, and clamps within the viewport. Up to three controls form one column; larger sets use two columns. There is no bottom prompt row or panel.

## Authoring and reuse

Scripts/UI/prompt_display.gd keeps class prompt_display and UID uid://dydvfnp1pg6a4, now extends Node3D; no autoload or signals. Scene: Scenes/UI/world_prompts.tscn. Exports: camera, ray, pickup, placement, placement_prompts, carrying_prompts, label_scene, yaw_degrees=7.0, reference_distance=1.6, screen_gap=18, screen_margin=20, single_column_limit=3, column_gap=.08, row_gap=.025. Runtime: labels:Array[world_prompt_label], displayed_texts:Array[String], layout_size and a single cached target-local AABB. APIs: refresh(), get_current_prompts(). Bind the four player references when adding the reusable scene. Set WorldPrompts > Presentation > Yaw Degrees to tune the static angle (-12 to 12 degrees); 0 restores the flat orientation. The angle affects look, carry and ghost labels together, rotates around camera-local Y without rolling the text, and keeps existing depth testing and readability behavior. Selection still uses prompt_entry.get_display_text() and InputMap, so rebinding and changing Resources updates the existing text.

Scripts/UI/world_prompt_label.gd extends Label3D, class world_prompt_label, UID uid://w43kct8lr32x; no autoload, signals or exports; API set_prompt(entry). Edit Scenes/UI/world_prompt_label.tscn for typography, outline, pixel_size, wrapping and colour. Defaults: 48-point font, .0016 pixel size, 560-pixel wrapping width, normal depth test, opaque prepass, no shadows. The original 2D prompt_label scene/script remains reusable legacy presentation, but is not used in gameplay.

Scripts/UI/object_prompts.gd retains class object_prompts and UID uid://0ojj3a5mwcai, extends Node and has no autoload/signals. Exports: prompts:prompt_set and optional world_anchor:Node3D. Add a Marker3D beside an object and assign it to world_anchor to override automatic placement. Public get_prompts()/static find_for(target) and look-prompt group behavior are unchanged. The marker's projected position is clamped if needed for visibility. Turn/power labels remain dynamic. Labels adopt the player's collision_space_mask metadata as their render layer (workshop 1, portal room 20), so they belong to the current space instead of appearing in the opposite portal camera.

## Visibility and ownership

Scripts/UI/gameplay_crosshair.gd extends CenterContainer, UID uid://d2vp0rgn4opt3. refresh() hides it during pause, input locks and developer modals. Crosshair controls ignore mouse input and cannot obstruct PC clicks.

The world prompt controller uses PROCESS_MODE_ALWAYS and clears during pause/input locks/developer modals. gameplay_hud includes the world Node3D, crosshair, combo/portal layers and story labels. Scripts/UI/world_view_session.gd handles Node3D, CanvasItem and CanvasLayer with weak references and original visibility. PC and physical-note sessions hide these plus held cargo/ghosts, then restore exact camera/input ownership. Existing PC display, lit paper, N transcript and paused journal behavior remain.

## Verification

Tests/world_prompts_test.tscn checks an actual lever ray, movement with unchanged glyph reuse, readable Y-only camera-relative orientation, authored marker placement, wall occlusion, compact carry layout, viewport bounds, portal layer routing, Cancel with no surface and input/pause restoration. Tests/prompt_system_test.tscn retains Resource selection, custom text, key rebinding, power/axis changes and freed-target cleanup. Tests/world_interfaces_test.tscn checks real look/carry/build prompts, screen-coordinate PC purchases, modal hiding/restoration, paper/N/Esc/journal, original save look, custom art, basket identity and unload. Actual D3D12 captures are in Reports/WorldPrompts; legacy HUDFeedback and WorldInterfaces galleries remain historical. Placement, carry-attachment and portal-assembly suites cover the shared dependencies. Isolate APPDATA for all fixtures.
