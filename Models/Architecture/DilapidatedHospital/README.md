# Dilapidated hospital wing

An independent **18 × 26 m** hospital shell with **3.35 m** ceilings,
two intersecting **3.2 m** hallways, six shared patient wards, a treatment room
and an open nursing station. All finished floors meet at Blender Z=0. Seven
1.55 m architectural ward/treatment openings, two 2.6 m end exits and a 1.45 m
rear staff entry keep the layout connected. Open door props retain their hinges.

The shell includes dirty tile and worn vinyl floors, split sage/plaster walls,
localized damp, damaged acoustic ceilings, exposed rusted services, signs and
handrails. Sixty glazing cells include **48 physically open broken/missing
centres** and twelve surviving panes. Perimeter shards are real geometry;
window openings are not painted onto solid walls. Dried blood pools, wall
smears and faded shoe prints use separate original transparent texture maps.

- [Native shell](Source/dilapidated_hospital.blend): packed used textures,
  complete ceiling/wall visibility and an eye-level camera.
- [Separate shell GLB](dilapidated_hospital.glb): 512 meshes, 57,378 triangles,
  embedded portable PBR textures; no presentation rig or loose furniture.
- [Linked assembly](../../Interiors/DilapidatedHospital/hospital_assembly.blend):
  50 relative collection instances; architecture and furniture remain separate.
- [Medical prop catalogue](../../Interiors/HospitalProps/README.md): eight
  independent sources/GLBs, with three views each.
- [Offline gallery](../../../Reports/Hospital/index.html) and
  [phone gallery](https://remnant-development-summary.callmehaptic.chatgpt.site/Hospital/index.html):
  eight environment and 24 independent prop renders.

The assembly includes thirteen beds (twelve ward beds and an examination bed),
twelve bedside cabinets, seven IV stands, two trolleys, two wheelchairs, a
nursing counter, seven doors and two benches. Existing telephone, mail and bin
assets remain separate linked furniture sources. Asset manifests record mesh
counts, evaluated triangles, dimensions, sources and local transforms.

## Authoring and rendering

`Tools/make_hospital_textures.py` creates eleven original 1024px PBR material
sets and five localized RGBA decals using Python, Pillow and NumPy. No models
or images were downloaded. [Texture provenance](Textures/PROVENANCE.md)
records the surface purposes. Native sources pack used images; exports embed
supported albedo, normal, roughness and metallic channels. Texture and native
source folders have `.gdignore` to avoid redundant automatic engine imports.

Run Blender 4.5.1 LTS in background with `--python-exit-code 1` and:

1. `Tools/model_hospital_props.py -- --samples 80 --width 1000`
2. `Tools/model_dilapidated_hospital.py -- --no-render`
3. `Tools/verify_hospital_native.py`
4. `Tools/render_hospital_views.py -- --samples 128 --width 1800`

The prop author accepts `--assets HospitalBed,Wheelchair` subsets. The room
renderer accepts `--views hallway,patient_room` and `--preview` for ignored
low-resolution trials. Default final room rendering uses eight views at
1800 × 1200, 128 samples; props use three 1000 × 1000 views at 80 samples.
Cycles uses OptiX when available and CPU otherwise. The render-only cutaway
temporarily substitutes the shell without ceilings and two perimeter walls;
it never overwrites the complete native assembly. Preserve the source folder
structure when moving a linked asset collection.

`Tools/warehouse_common.py` supplies shared geometry, UV, packing, export and
presentation helpers. `ASSET_LABEL` and texture/render roots select Hospital
without changing the warehouse defaults. Each room/prop script creates its own
collection. Export selection contains only that asset's meshes and pivots.

## Verification and engine setup

- `Tools/verify_hospital_native.py`: native used-map packing, UVs/materials,
  exact bounds, the ten-child door hinge, complete saved visibility, relative
  libraries and transforms. Evaluated geometry ray tests check all sixty
  glazing centres, ward doorways, floor continuity, both hall routes, all eight
  room entries and the staff path behind the counter. Ward furniture stays
  inside room wall bounds.
- `Tools/verify_hospital_assets.py`: all nine GLB structures, UVs/normals,
  embedded image and buffer integrity, evaluated/export triangle agreement,
  render coverage and SHA-256 records for 51 delivered files.
- `Tools/configure_hospital_imports.py`: embedded compressed image handling;
  existing Godot UIDs remain intact.
- `Tests/hospital_asset_import_test.gd`: actual Godot imports/instances for all
  nine GLBs, matching mesh counts, metre bounds, 730 texture-mapped surfaces
  and retained door hierarchy. Run with isolated APPDATA.
- `Tools/make_hospital_gallery.py`: responsive self-contained gallery,
  searchable prop catalogue, source/export links and all 32 reviewed images.

Every final render must also be **visually opened and reviewed**. File/hash
and automated geometry checks do not substitute for visual review. The linked
assembly's `verification.json` records actual review and verification evidence.

These are reusable art assets, not an inserted gameplay level. Configure
collision, doors, navigation, spawn points and engine lighting in a gameplay
scene when integrating them. GLBs use Y up; Blender uses Z up. All room and
prop transforms are metre scale. Presentation cameras, lights and exterior
paving are excluded from exports. The ordinary Windows release/startup check
validates the existing game and engine asset packaging, not a hospital playtest.
