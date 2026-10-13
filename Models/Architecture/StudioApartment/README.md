# Worn studio apartment / independent architectural shell

An original architectural shell, authored in Blender 4.5.1 LTS. Its current finish has mottled yellowed plaster, worn oak, aged enamel/tile and ten local damp, grease and traffic-stain patches. The expanded clear interior is **16.2 x 6.2 metres**, with a 2.8 m ceiling, a 4.25 x 6.2 m east bedroom and the retained northwest bathroom. Furniture, appliances and the kitchenette are separate native/export assets under Models/Interiors/StudioFurniture and Models/Imported/Trip. The linked preview in Models/Interiors/FurnishedStudio assembles them; none are baked into this shell. Entry and bathroom doors now use separate imported art wrappers in the playable portal scene. Windows, trim, electrical plates, ventilation grille and recessed ceiling luminaires remain permanent architectural details.

## Files

- `Source/studio_apartment.blend`: editable model with named architectural parts, hinged door leaves, packed textures, four cameras and a separate presentation lighting/backdrop/dust collection. Opens with the complete shell and an interior camera selected.
- `studio_apartment.glb`: Godot-ready metre-scale, Y-up architecture with embedded PBR textures. Includes opaque newspaper and tape; excludes presentation cameras, lights, backdrop and dust volume. The ceiling and all exterior walls remain in the export; the overview render temporarily hides selected walls/ceiling as a cutaway.
- `studio_apartment.glb.import`: keeps textures embedded as Basis Universal instead of extracting duplicate PNGs into the project. Import UID: `uid://bdkr5w4gcna3i`. Imported meshes keep their names, tangents, generated LODs and shadow meshes.
- `Textures/`: original deterministic albedo and tangent normal PNGs for oak, plaster, ceramic, porcelain, concrete and newspaper, plus three original typeset newspaper print maps. Native file and GLB already embed these; `.gdignore` prevents redundant raw texture imports. `Source/` is also ignored by Godot so automatic Blender source imports are unnecessary.
- `asset_manifest.json`: dimensions, Blender version, evaluated geometry totals and render settings. Current model has 158 architectural meshes and 133,024 triangles.
- `Reports/StudioApartment/`: retained earlier unfurnished newspaper-window renders and gallery. Current worn/furnished views are in Reports/FurnishedStudio; the complete gallery is Reports/StudioFurniture/index.html.

The shell is now used by Scenes/Environments/furnished_apartment.tscn, with baked static collision in Scenes/Environments/Art/StudioApartment_studio_apartment.tscn. Its independent source has no gameplay script or persistent state. Its glass uses glTF transmission; renderer-specific glass appearance may differ from Blender. Earlier unfurnished verification below is historical; current assignments and scoped rebuild instructions are in Data/Items/TRIP_MODELS.md.

The extension boards cover X=3.9..12.3 m and meet the original timber at a normal **1.8 mm seam**. Tools/repair_apartment_floor.py fixes the existing 192 extension boards without rebuilding other architecture; Tools/expand_trip_apartment.py uses the same corrected dimensions for future rebuilds. Export the shell and bake with `--only=apartment_shell` to refresh its collision. Four reviewed current Cycles views and four game views are in Reports/ApartmentCorrection, with a separate presentation native under Models/Interiors/ApartmentCorrectionPresentation/Source. The linked TV/stand/phone/VCR placement belongs to the assembly and game scene, not this architectural export.

## Newspaper windows / reference revision

The current coverings use 48 independently modelled clippings, with overlapping,
slightly rotated edges, curled corners, torn notches and small grey adhesive tabs.
Partial-page crops from four fictional newspaper scans give dense varied columns,
halftone photographs and adverts instead of the former repeated front-page grid.
The reference informed this patchwork appearance; its graffiti was not added.

Tools/studio_newspaper_layout.py is shared by the structural builder and the
in-place Tools/rework_studio_newspaper.py. The latter updates only coverings in
the saved room, preserving its worn architecture and the separate furniture.
Run the rework, then Tools/assemble_worn_studio.py to refresh the room GLB and
linked preview. Default output is five views, including the newsprint close-up.

Six north-window and four east-window masks remove geometry through every overlap;
additional torn edge notches leave irregular gaps. Tools/verify_studio_newspaper.py
checks packed atlas, clipping UVs/count and ten unobstructed rays through these
openings. Sunlight, glass shadow visibility and dust remain Blender presentation
settings; engine lighting/volumetrics need their own setup.

Textures/newsprint_scan_atlas.png was generated with built-in ImageGen. Its exact
prompt/provenance is in Textures/newsprint_scan_atlas.md. The PNG is versioned and
packed into the native room and GLB; rebuilding needs no external generation.
The former original typeset maps and unfurnished renders remain historical assets.

## Rebuild / edit

`Tools/model_studio_apartment.py` is a standalone Blender Python tool using bpy, NumPy and mathutils. Run Blender with `--background --factory-startup --python Tools/model_studio_apartment.py -- --samples 96 --width 1800`. Optional `--views cutaway,living,entry,bathroom` chooses outputs. Run from the repository, with a local BLENDER_USER_CONFIG override if desired. The versioned generated scan atlas and original PBR maps are required; no texture download or user preferences are needed.

It creates geometry, real window/door apertures, original UV-mapped PBR maps, photographic newspaper clippings with geometric openings, a separate presentation rig, native/GLB files and renders. Oak and ceramic parts are consolidated into named meshes after their edge modifiers are applied. Image maps are packed before export. `Source/.gdignore` and `Textures/.gdignore` keep authoring data out of Godot's import/export scan; native and raw texture files remain versioned for editing.

Default render setup: Cycles with available OptiX GPU (CPU fallback), AgX, adaptive sampling and denoising. Saved camera names begin 01–04. Functions include box(), segment_x()/segment_y(), consolidate(), window(), door(), camera(), textured(), image_map()/normal_map(), light() and the shared studio_newspaper_layout.cover_window(). Its output locations are derived from the script's repository root. It does not alter testing_level, player state or saved games.

## Verification

Review all four actual renders, inspect packed texture/UV presence and GLB content, and run Godot's editor import. The game's Windows delivery process runs a release export and isolated startup smoke. A successful Godot import does not prove identical lighting or transmission rendering, or make this shell collision-ready.

Verified on 2026-10-11 after the newspaper update: all four final Cycles PNGs visually opened; 20 packed native textures and 20 embedded GLB images; 14 opaque UV-mapped sheets and their three open seam widths verified in both rows; GLB selection, UVs/normals and 101,128 triangles match. Godot imports 114 meshes with 44 textured/normal-mapped surfaces and unchanged bounds (8.165, 3.23, 6.58) metres. Import logs are clean. Presentation glass, lighting and dust are not a matched Godot render.

## Worn finish and linked furniture update

Tools/assemble_worn_studio.py follows the structural builder with an idempotent ageing pass. It preserves openings and newspaper geometry, updates the existing material identities, adds worn floor maps and ten transparent local grime patches, packs textures and re-exports the independent shell. It then links the room and 18 separate furniture collections into studio_apartment_furnished.blend and renders four views. Run it after rebuilding the furniture to reproduce the current furnished study. Refer to the furniture README for the complete asset catalogue. Blender lighting and dust remain presentation-only. The historical verification above records the earlier newspaper-only revision; current checks and hashes are recorded in the furnished preview verification.json and development summary.
