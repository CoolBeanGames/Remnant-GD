"""Repair only the expanded shell's existing timber boards, keeping materials.

Run with Blender --background --python Tools/repair_apartment_floor.py.
The original builder uses the same 3.9..12.3 m coverage. This in-place repair
preserves all other architecture, newspaper, stains and authoring lights.
"""
import json
from pathlib import Path

import bpy
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[1]
ROOM = ROOT / 'Models/Architecture/StudioApartment'
bpy.context.preferences.filepaths.save_version = 0
bpy.ops.wm.open_mainfile(filepath=str(ROOM / 'Source/studio_apartment.blend'))
architecture = bpy.data.collections['APARTMENT | permanent architecture']
boards = sorted((o for o in architecture.objects if o.name.startswith('Bedroom worn oak board')),
                key=lambda o: (round(o.location.x, 4), round(o.location.y, 4)))
if len(boards) != 192:
    raise RuntimeError('Expected 48 columns of four existing extension boards')
width = (12.3 - 3.9) / 48
for index, obj in enumerate(boards):
    obj.location.x = 3.9 + (index // 4 + .5) * width
    obj.dimensions.x = width - .0018
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.select_all(action='DESELECT')
    obj.select_set(True)
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    # Maintain the original metre-based UV density after resizing the boards.
    uv = obj.data.uv_layers.active
    for face in obj.data.polygons:
        axes = sorted(range(3), key=lambda i: abs(face.normal[i]))[:2]
        for loop in face.loop_indices:
            p = obj.data.vertices[obj.data.loops[loop].vertex_index].co
            uv.data[loop].uv = (p[axes[0]] / 1.7, p[axes[1]] / 1.7)
bpy.context.view_layer.update()
original = bpy.data.objects['Oak floor | staggered individual boards']
original_end = max((original.matrix_world @ Vector(v)).x for v in original.bound_box)
extension_start = min((boards[0].matrix_world @ Vector(v)).x for v in boards[0].bound_box)
seam = extension_start - original_end
if not .0017 <= seam <= .0019:
    raise RuntimeError(f'Floor seam remains incorrect: {seam}')
bpy.ops.file.pack_all()
bpy.ops.wm.save_as_mainfile(filepath=str(ROOM / 'Source/studio_apartment.blend'))
bpy.ops.object.select_all(action='DESELECT')
for obj in architecture.objects:
    obj.select_set(True)
bpy.ops.export_scene.gltf(filepath=str(ROOM / 'studio_apartment.glb'), export_format='GLB',
                          use_selection=True, export_apply=True, export_animations=False,
                          export_cameras=False, export_lights=False, export_yup=True)
manifest = json.loads((ROOM / 'asset_manifest.json').read_text())
manifest['floor_extension_m'] = [3.9, 12.3]
manifest['floor_board_seam_m'] = .0018
manifest['revision'] = 'Expanded apartment with continuous oak floor; separate bedroom retained'
(ROOM / 'asset_manifest.json').write_text(json.dumps(manifest, indent=2) + '\n')
print(f'Floor repair: PASS / 192 retained boards / {seam:.6f} m seam', flush=True)
