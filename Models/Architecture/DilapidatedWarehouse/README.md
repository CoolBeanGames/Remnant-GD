# Dilapidated warehouse

A standalone textured industrial environment: a **24 × 36 m** production hall,
9.25 m wall eaves and an approximately 11.1 m pitched roof ridge. The upper
catwalk and supported production-office floor are at **4.2 m**. A 1.8 m wide
stair has 24 rises of 175 mm and 290 mm treads; its top meets the catwalk deck.

The architecture includes jointed/cracked concrete slabs, original textured brick,
localized damp/oil/dirt, corrugated rusty roof panels, a damaged rooflight,
rolled-steel columns/trusses, fixed pipes, drainage, dead hanging fixtures,
guardrails, mezzanine supports, and the office enclosure. The two long elevations
have 288 window cells: 174 missing/broken centres and 114 surviving panes. Broken
panes have real empty centres and jagged perimeter shards, rather than a painted
crack on a solid surface. Both end-wall entrances are actual structural openings.

## Files and asset separation

- [Source/dilapidated_warehouse.blend](Source/dilapidated_warehouse.blend): complete
  editable architecture with packed images and presentation cameras/light rig.
- [dilapidated_warehouse.glb](dilapidated_warehouse.glb): separate metre-scale,
  engine Y-up architecture; no camera, light, dust or exterior presentation ground.
- [asset_manifest.json](asset_manifest.json): exact mesh count, evaluated triangle
  count/bounds, window cell records, stair dimensions and camera list.
- [../../Interiors/WarehouseMachinery](../../Interiors/WarehouseMachinery/README.md):
  six independently editable/exported new props: press, lathe, compressor,
  electrical cabinet, office desk and loose debris kit.
- [../../Interiors/DilapidatedWarehouse/warehouse_assembly.blend](../../Interiors/DilapidatedWarehouse/warehouse_assembly.blend):
  17 linked instances using the shell, six new prop libraries and four reused
  studio furniture libraries. Keep the repository's relative folder structure.

Machines and furniture are never joined into the architectural shell. The
electrical cabinet door retains an independent hinge hierarchy. This is an art
delivery: the room is not placed in testing_level and has no engine colliders,
interactions, navigation or gameplay machine behaviour.

## Textures and lighting

Textures/ contains original deterministic PBR artwork generated with NumPy/Pillow.
Metre-scale UVs carry albedo, tangent normals, roughness and appropriate metallic
channels. Local alpha decals provide damp, oil and dirt. Glass uses deliberate
Principled transmission/roughness; office glass is clearer than factory glazing.
Used image maps are packed in each native source and embedded in GLBs.
Textures/PROVENANCE.md records authorship; no downloaded art or texture licences.

The native preview uses Cycles/OptiX, warm afternoon sunlight, soft exterior fill
and a restrained airborne-dust volume. Area emitters are hidden from camera,
glossy and transmission rays, avoiding bright lamp discs through glass. These
are Blender presentation choices, requiring separate engine lighting setup.
Source/ and Textures/ use .gdignore to avoid redundant automatic imports.

## Reproduce and verify

Use the installed Blender 4.5.1 LTS and Python with Pillow/NumPy:

1. Run `Tools/make_warehouse_textures.py` with Python.
2. Run Blender with `--background --factory-startup --python-exit-code 1 --python
   Tools/model_warehouse_machinery.py -- --samples 80 --width 1000`.
3. Run the same Blender options with `Tools/model_dilapidated_warehouse.py --
   --samples 128 --width 1800`. It saves/exports the independent shell, links
   props relatively, saves the complete assembly, then renders six views.
4. `Tools/refine_warehouse_presentation.py` is an optional repeatable fast pass
   for the final camera/light/desk-placement refinements without rebuilding the
   architecture. The structural authoring script already contains those values.
5. Run `Tools/configure_warehouse_imports.py` before the first Godot editor import.
   Existing sidecars and UIDs are preserved; new imports keep compressed maps
   embedded instead of extracting duplicate PNGs beside each export.
6. Run `Tools/verify_warehouse_assets.py` with Python and
   `Tools/verify_warehouse_native.py` through Blender using `--python-exit-code 1`.
   Checks cover GLB buffer bounds/UVs/normals/maps/triangles, render coverage,
   packed native maps, pivots, relative links, complete saved visibility,
   actual window-hole rays, stair/deck continuity and office/catwalk support.
7. After Godot headless editor import, run `Tests/warehouse_asset_import_test.gd`
   with isolated APPDATA. It loads all seven real exports and verifies mesh
   counts, textured PBR surfaces, converted dimensions and the cabinet hinge.

Successful file checks do not replace visual QA: open every final PNG and inspect
framing, texture scale, placement, glass/light artifacts and visibility.
The six environment PNGs are 1800 × 1200 at 128 samples; every new prop has three
1000 × 1000 views at 80 samples. The saved assembly retains the roof and walls;
the overview only temporarily cuts them away for its render.

[Phone gallery](https://remnant-development-summary.callmehaptic.chatgpt.site/Warehouse/index.html)
· [Offline gallery](../../../Reports/Warehouse/index.html)
· [Assembly verification record](../../Interiors/DilapidatedWarehouse/verification.json)
