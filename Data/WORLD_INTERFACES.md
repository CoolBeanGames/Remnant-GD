# World interfaces and physical notes

Normal gameplay keeps its crosshair, dynamic in-world look/carry/build prompts, text-only combo, brief portal status and story/dialogue captions. Minimal traditional UI does not mean removing useful gameplay feedback. WordMessage and DialoguePlayer have show_text=true in testing_level. The actual PC screen, physical note reader, pause/options and opt-in developer tools remain. Gameplay HUD hides during PC/note sessions and returns afterward. Look text floats beside the object, carry controls beside the held model, and build controls beside the ghost. A subtle configurable 7-degree local-Y angle makes their perspective visible. See Data/GAMEPLAY_FEEDBACK.md for reusable scene authoring, optional object markers and the shared visibility group.

## PC display

E connects to an enabled PC; mouse clicks and wheel scrolling address its actual screen. Mechanics/Self/Store and conditional Mulch retain their catalog/purchase rules. Esc or on-screen EXIT restores camera/input/mouse and held cargo. Production continues. Closed/disabled displays stop viewport rendering. Enabled flags and authored model size remain.

Scripts/Computer/computer_terminal.gd (computer_terminal : StaticBody3D, existing UID) owns a SubViewport and Scenes/UI/computer_ui.tscn Control. Exports: catalog, player, delivery_point/parent, interface_scene, enabled, display_resolution=1024x768, viewing_distance=.60 m. Runtime: interface/display_viewport/session/screen/material/pointer state. API: interact(), close_interface(), buy(entry), set_enabled(value), screen_pointer(window_position)->viewport pixel or (-1,-1). Ray-plane-UV input supports rotation/scale. Events forward only while connected. Screen uses an unshaded viewport texture; preserve named quad/control paths. Audio/Progression/Mulch/Settings/save are unchanged.

Scripts/UI/computer_ui.gd (computer_ui : Control, existing UID) builds reusable rows and live balances; open(source), close(), suspend(), refresh(), _buy(entry). The terminal owns viewing state. Interfaces are local to each screen, never fullscreen CanvasLayers.

## Notes / controls

F collects a drop into the saved journal and holds readable paper in front of the camera. The world pauses. Esc puts it away. N toggles a scrollable typed transcript, then returns to paper on a second press. N from gameplay opens the latest collected transcript; Esc returns from typing to paper, then puts paper away. Mouse wheel scrolls overflowing generated paper. Pause > Notes lists saved titles; selecting one holds its original in world. Closing returns to the paused journal. Completed-read guidance fires when putting paper away.

## Author your physical notes

Select a note_definition in Data/Notes. Id/title/body supply the spawn pool, journal and typed transcript. Page Texture accepts your scanned/written page for the .36x.45 m sheet. Reading Scene optionally replaces it with your Node3D artwork; face +Z toward the camera, in metres. Reading Pose adjusts the art inside the holder. Use display-only geometry without score/world-item scripts. Existing world drops remain bottles until their art is changed separately.

Blank art fields print current text onto matte paper. Snapshots retain {id,title,body,definition_path,reading_scene_path,page_texture_path}. Definition paths resolve assigned art after reload; old journals fall back by catalog id or print paper. Keep art in exported res:// paths. Reading copies have no scoring, physical collision or WorldState saved duplicate.

Scripts/Notes/note_reader.gd (note_reader : Node, no autoload; Scenes/Notes/note_reader.tscn) binds Notes.note_read. Exports: camera, toggle_key=N, paper_size/distance, reading_light_energy=.6. Signal closed(note,return_to_journal). API: open_note(snapshot,return_to_journal=false)->bool, toggle_transcript(), close(notify=true). Runtime: is_open/typed/current_note/from_journal/session/holder/page_viewport/transcript/light_masks. Reserve render layer 19 for paper. Its lamp only lights that layer; world-light masks and original materials restore. Standard material copies suppress ambient/specular glare while retaining textures. Portal layer 20 is unchanged. Generated pages render once or when scrolled; blanks are safe.

Scripts/UI/world_view_session.gd (world_view_session : RefCounted, no scene/autoload/signals): begin(camera,pause_world), restore(). Captures exact camera/cull mask/mouse/pause/input-lock presence and held cargo/ghost visibility without dropping items. It also temporarily hides gameplay_hud Node3D/CanvasItems/CanvasLayers and restores their prior visibility. Runtime Blackboard.world_view_session is not disk data. WorldState saves original_camera_rotation during monitor focus. Unload restores ownership even if camera is removed first.

Tests/world_interfaces_test.tscn exercises actual ray/prompt/crosshair feedback, carry/build prompts, 3D purchase clicks, modal HUD hiding, viewport stop, save look, lit paper, N/Esc, pause handoff, save codec, custom art, legacy journals, basket identity and unload. Shared computer/notes/guidance/dialogue/menu/save/portal/wake/voice/F1 checks and rendered images supplement it. Isolate APPDATA. Gallery: Reports/WorldInterfaces/index.html. Archive: Reports/index.html.
