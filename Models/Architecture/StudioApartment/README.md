# Studio apartment / Blender modelling test

An original unfurnished architectural shell, authored in Blender 4.5.1 LTS. The clear interior is approximately 7.8 x 6.2 metres with a 2.8 m ceiling; a separate 2.5 x 2.3 m bathroom occupies the northwest corner. No furniture, appliances or sanitary fixtures are included. Doors, windows, trim, electrical plates, a ventilation grille and recessed ceiling luminaires are permanent architectural details.

## Files

- `Source/studio_apartment.blend`: editable model with named architectural parts, hinged door leaves, packed textures, four cameras and a separate presentation lighting/backdrop collection. Opens with the complete shell and an interior camera selected.
- `studio_apartment.glb`: Godot-ready metre-scale, Y-up architecture with embedded PBR textures. Excludes presentation cameras, lights and backdrop. The ceiling and all exterior walls remain in the export; the overview render temporarily hides selected walls/ceiling as a cutaway.
- `studio_apartment.glb.import`: keeps textures embedded as Basis Universal instead of extracting duplicate PNGs into the project. Import UID: `uid://bdkr5w4gcna3i`. Imported meshes keep their names, tangents, generated LODs and shadow meshes.
- `Textures/`: original deterministic albedo and tangent normal PNGs for oak, plaster, ceramic, porcelain and concrete. Native file and GLB already embed these; `.gdignore` prevents redundant raw texture imports. `Source/` is also ignored by Godot so automatic Blender source imports are unnecessary.
- `asset_manifest.json`: dimensions, Blender version, evaluated geometry totals and render settings. Current model has 98 architectural meshes and 96,312 triangles.
- `Reports/StudioApartment/`: actual Cycles renders from four views and a responsive HTML gallery.

The model is an authoring experiment, not an instance in the current game or portal room. It has no Godot physics collisions, gameplay script, autoload, UID, signals or persistent state. Its glass uses glTF transmission; renderer-specific glass appearance may differ from Blender.

## Rebuild / edit

`Tools/model_studio_apartment.py` is a standalone Blender Python tool using bpy, NumPy and mathutils. Run Blender with `--background --factory-startup --python Tools/model_studio_apartment.py -- --samples 96 --width 1800`. Optional `--views cutaway,living,entry,bathroom` chooses outputs. Run from the repository, with a local BLENDER_USER_CONFIG override if desired. No downloaded texture assets or user preferences are required.

It creates geometry, real window/door apertures, original UV-mapped PBR maps, a separate presentation rig, native/GLB files and renders. Oak and ceramic parts are consolidated into named meshes after their edge modifiers are applied. Image maps are packed before export. `Source/.gdignore` and `Textures/.gdignore` keep authoring data out of Godot's import/export scan; native and raw texture files remain versioned for editing.

Default render setup: Cycles with available OptiX GPU (CPU fallback), AgX, adaptive sampling and denoising. Saved camera names begin 01–04. Functions include box(), segment_x()/segment_y(), consolidate(), window(), door(), camera(), textured(), image_map()/normal_map() and light(). Its output locations are derived from the script's repository root. It does not alter testing_level, player state or saved games.

## Verification

Review all four actual renders, inspect packed texture/UV presence and GLB content, and run Godot's editor import. The game's Windows delivery process runs a release export and isolated startup smoke. A successful Godot import does not prove identical lighting or transmission rendering, or make this shell collision-ready.

Verified on 2026-10-11: all four final Cycles PNGs visually opened; 16 packed native textures and 16 embedded GLB images; GLB selection/UVs/normals and 96,312 evaluated/exported triangles match; Godot imports 98 meshes with 30 textured/normal-mapped surfaces and bounds (8.165, 3.23, 6.58) metres. Import logs are clean. Presentation glass/lighting is not a matched Godot render.
