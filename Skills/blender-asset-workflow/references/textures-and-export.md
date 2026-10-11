# Texture and export checks

Read for procedural image maps, portable exports or game-engine assets.

## Image maps and UVs

- Set a generated Blender image's colour space, file format and path before assigning its pixel buffer. Changing colour space after writing generated pixels can invalidate that buffer. Save, reload or inspect representative values, and actually view the textured render.
- Base colour uses an appropriate colour space; tangent normal, roughness, metallic and mask maps are non-colour data. Check normal handedness and the target engine's conventions. Keep wood grain, labels and paper text readable from the intended side.
- UV scale should correspond to physical dimensions. Inspect small items independently; a room overview can conceal backwards text, seams or missing surfaces.
- Pack all required image maps into the .blend and verify packed image data. Exported textures must be embedded or supplied with valid portable paths. Keep authoring-only originals outside redundant engine import scans where the project supports it.

## Portable PBR assets

Prefer export-supported Principled materials for base colour, normals, roughness, metallic and transparency. Bake unsupported procedural effects when exporting them. Inspect the exported material assignments and maps rather than assuming the native shader graph survives.

Apply intended scale and evaluate modifiers deliberately. After joining rotated pieces, bake the surviving object's rotation when appropriate: an otherwise correct model can inherit an inflated engine bounding box. Check the actual imported bounds and transforms.

Give each separate prop a useful local pivot and consistent front/up convention. The presentation assembly's world placement belongs on instances. Keep movable parts and their pivots intact; avoid flattening animations or articulated geometry into a room export.

Select only the intended room or prop for each export. Exclude render cameras, light rigs, studio ground and dust volumes. Retain full walls and ceiling even if a preview hides them for a cutaway.

Transparent glass may look different across renderers. A native ray-visibility setting or volumetric rig does not automatically become an engine feature. Verify transparency in the target where needed and state which light-beam/shader effects remain native presentation only. Engine import alone does not establish physics collisions or identical lighting.
