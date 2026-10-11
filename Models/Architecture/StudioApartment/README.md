# Studio apartment / Blender modelling test

An original unfurnished architectural shell, authored in Blender 4.5.1 LTS. The clear interior is approximately 7.8 x 6.2 metres with a 2.8 m ceiling; a separate 2.5 x 2.3 m bathroom occupies the northwest corner. No furniture, appliances or sanitary fixtures are included. Doors, windows, trim, electrical plates, a ventilation grille and recessed ceiling luminaires are permanent architectural details.

## Files

- `Source/studio_apartment.blend`: editable model with named architectural parts, hinged door leaves, packed textures, four cameras and a separate presentation lighting/backdrop/dust collection. Opens with the complete shell and an interior camera selected.
- `studio_apartment.glb`: Godot-ready metre-scale, Y-up architecture with embedded PBR textures. Includes opaque newspaper and tape; excludes presentation cameras, lights, backdrop and dust volume. The ceiling and all exterior walls remain in the export; the overview render temporarily hides selected walls/ceiling as a cutaway.
- `studio_apartment.glb.import`: keeps textures embedded as Basis Universal instead of extracting duplicate PNGs into the project. Import UID: `uid://bdkr5w4gcna3i`. Imported meshes keep their names, tangents, generated LODs and shadow meshes.
- `Textures/`: original deterministic albedo and tangent normal PNGs for oak, plaster, ceramic, porcelain, concrete and newspaper, plus three original typeset newspaper print maps. Native file and GLB already embed these; `.gdignore` prevents redundant raw texture imports. `Source/` is also ignored by Godot so automatic Blender source imports are unnecessary.
- `asset_manifest.json`: dimensions, Blender version, evaluated geometry totals and render settings. Current model has 114 architectural meshes and 101,128 triangles.
- `Reports/StudioApartment/`: actual Cycles renders from four views and a responsive HTML gallery.

The model is an authoring experiment, not an instance in the current game or portal room. It has no Godot physics collisions, gameplay script, autoload, UID, signals or persistent state. Its glass uses glTF transmission; renderer-specific glass appearance may differ from Blender.

## Newspaper windows

Both windows are covered with 14 individual opaque newspaper sheets, shallow folds, curled lower edges and masking tape. The print is original typography and a halftone roofline illustration. Ordinary sheet joins overlap; two seams in the north window (23 and 18 mm) and one in the east window (25 mm) are actual gaps that admit sunlight.

`newspaper_window()` in the Blender authoring tool controls sheet bounds, rows/columns, overlap and seam width in metres. Sheets retain individual named meshes and UV layouts. Each window's tape tabs are consolidated. To edit the print, run `python Tools/make_apartment_newspaper.py` with Pillow and NumPy; the resulting PNGs are versioned, so Blender rebuilds only need their existing files. The generator uses local Times or DejaVu Serif fonts and falls back to Pillow's default.

The render rig uses directional sunlight and a subtle interior dust volume to show shafts in air and stripes on the floor. Glass panes disable Cycles shadow visibility to admit direct sunlight without refractive caustics; this is a Blender presentation setting, not a glTF runtime lighting feature. The GLB exports the paper and physical gaps but excludes the volume and lighting. Godot needs its own lighting/volumetric setup to reproduce the beams. The overview hides dust with the cutaway walls for a clear floorplan.

## Rebuild / edit

`Tools/model_studio_apartment.py` is a standalone Blender Python tool using bpy, NumPy and mathutils. Run Blender with `--background --factory-startup --python Tools/model_studio_apartment.py -- --samples 96 --width 1800`. Optional `--views cutaway,living,entry,bathroom` chooses outputs. Run from the repository, with a local BLENDER_USER_CONFIG override if desired. No downloaded texture assets or user preferences are required.

It creates geometry, real window/door apertures, original UV-mapped PBR maps, newspaper coverings with open light seams, a separate presentation rig, native/GLB files and renders. Oak and ceramic parts are consolidated into named meshes after their edge modifiers are applied. Image maps are packed before export. `Source/.gdignore` and `Textures/.gdignore` keep authoring data out of Godot's import/export scan; native and raw texture files remain versioned for editing.

Default render setup: Cycles with available OptiX GPU (CPU fallback), AgX, adaptive sampling and denoising. Saved camera names begin 01–04. Functions include box(), segment_x()/segment_y(), consolidate(), window(), door(), camera(), textured(), image_map()/normal_map(), light() and newspaper_window(). Its output locations are derived from the script's repository root. It does not alter testing_level, player state or saved games.

## Verification

Review all four actual renders, inspect packed texture/UV presence and GLB content, and run Godot's editor import. The game's Windows delivery process runs a release export and isolated startup smoke. A successful Godot import does not prove identical lighting or transmission rendering, or make this shell collision-ready.

Verified on 2026-10-11 after the newspaper update: all four final Cycles PNGs visually opened; 20 packed native textures and 20 embedded GLB images; 14 opaque UV-mapped sheets and their three open seam widths verified in both rows; GLB selection, UVs/normals and 101,128 triangles match. Godot imports 114 meshes with 44 textured/normal-mapped surfaces and unchanged bounds (8.165, 3.23, 6.58) metres. Import logs are clean. Presentation glass, lighting and dust are not a matched Godot render.
