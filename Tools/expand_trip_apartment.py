"""Extend the existing textured shell into a one-bedroom apartment.

Architecture and a worn domestic bed remain independent assets. Existing
newsprint geometry, bathroom and portal entrance retain their authored scale.
"""
import json, math, sys
from pathlib import Path
import bpy
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[1]
ROOM = ROOT / 'Models/Architecture/StudioApartment'
CACHE = ROOT / '.godot/trip_apartment_original.blend'
bpy.context.preferences.filepaths.save_version = 0
if not CACHE.exists():
    import shutil
    shutil.copy2(ROOM / 'Source/studio_apartment.blend', CACHE)
bpy.ops.wm.open_mainfile(filepath=str(CACHE))
scene = bpy.context.scene
architecture = bpy.data.collections['APARTMENT | permanent architecture']
plaster = bpy.data.materials['Warm lime plaster / fine texture']
wood = bpy.data.materials['Oak / board tone 00']
trim = bpy.data.materials['Trim / bone-white enamel']


def box(name, pos, size, material, collection=architecture, bevel=.006):
    bpy.ops.mesh.primitive_cube_add(size=1, location=pos)
    obj = bpy.context.object
    obj.name = name
    obj.dimensions = size
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    obj.data.materials.append(material)
    # Metre based face UVs keep wood/plaster density consistent in the extension.
    uv = obj.data.uv_layers.active or obj.data.uv_layers.new()
    for face in obj.data.polygons:
        axes = sorted(range(3), key=lambda i: abs(face.normal[i]))[:2]
        for index in face.loop_indices:
            p = obj.data.vertices[obj.data.loops[index].vertex_index].co
            uv.data[index].uv = (p[axes[0]] / 1.7, p[axes[1]] / 1.7)
    if bevel:
        mod = obj.modifiers.new('Worn edge', 'BEVEL')
        mod.width = min(bevel, min(size) * .15)
        mod.segments = 2
    for col in list(obj.users_collection):
        col.objects.unlink(obj)
    collection.objects.link(obj)
    return obj


for obj in list(architecture.objects):
    name = obj.name
    # Movable doors are separate reusable imports, rather than part of the shell.
    if name.startswith(('Apartment entrance /', 'Bathroom door /')):
        bpy.data.objects.remove(obj, do_unlink=True)
        continue
    if (name.startswith(('East exterior', 'East window', 'Side window', 'Baseboard / east'))
            or name == 'Grime / East damp corner'):
        obj.location.x += 4.4
    if name.startswith('Fixed electrical outlet') and obj.location.x > 3.8:
        obj.location.x += 4.4
box('Bedroom structural slab', (6.2, 0, -.14), (4.45, 6.56, .22), bpy.data.objects['Continuous structural floor slab'].data.materials[0], bevel=.01)
box('Bedroom north exterior', (6.2, 3.19, 1.4), (4.4, .18, 2.8), plaster)
box('Bedroom south exterior', (6.2, -3.19, 1.4), (4.4, .18, 2.8), plaster)
box('Bedroom complete ceiling', (6.2, 0, 2.89), (4.4, 6.56, .18), bpy.data.materials['Ceiling / soft white'])
for y1, y2 in [(-3.1, -1.2), (.05, 3.1)]:
    box('Bedroom partition pier', (3.93, (y1 + y2) / 2, 1.4), (.14, y2 - y1, 2.8), plaster)
box('Bedroom doorway lintel', (3.93, -.575, 2.55), (.14, 1.25, .5), plaster)
for y in [-1.2, .05]:
    box('Bedroom door jamb', (3.93, y, 1.1), (.20, .055, 2.2), trim)
box('Bedroom door head', (3.93, -.575, 2.22), (.20, 1.3, .055), trim)
for side in [-1, 1]:
    box('Bedroom north/south skirting', (6.2, side * 3.073, .065), (4.4, .04, .13), trim)
for i in range(25):
    for j in range(4):
        material = bpy.data.materials['Oak / board tone %02d' % ((i + j) % 4)]
        box('Bedroom worn oak board', (4.00 + (i + .5) * .176, -3.1 + (j + .5) * 1.55, -.014), (.174, 1.548, .028), material, bevel=.001)
bpy.context.view_layer.update()
bpy.ops.file.pack_all()
bpy.ops.wm.save_as_mainfile(filepath=str(ROOM / 'Source/studio_apartment.blend'))
bpy.ops.object.select_all(action='DESELECT')
for obj in architecture.objects:
    obj.select_set(True)
bpy.ops.export_scene.gltf(filepath=str(ROOM / 'studio_apartment.glb'), export_format='GLB', use_selection=True, export_apply=True, export_animations=False, export_cameras=False, export_lights=False, export_yup=True)
info = json.loads((ROOM / 'asset_manifest.json').read_text())
info.update({'dimensions_m': [12.2, 6.2, 2.8], 'bedroom_m': [4.25, 6.2], 'bedroom_door_clearance_m': [1.195, 2.2], 'architecture_meshes': len([o for o in architecture.objects if o.type == 'MESH']), 'furniture': False, 'revision': 'October Trip spreadsheet: separate east bedroom, original bath/entrance/newsprint retained'})
(ROOM / 'asset_manifest.json').write_text(json.dumps(info, indent=2) + '\n')

# Domestic bed: independent native, using existing packed worn fabric/wood maps.
bed_folder = ROOT / 'Models/Interiors/StudioFurniture/BedroomBed'
(bed_folder / 'Source').mkdir(parents=True, exist_ok=True)
(bed_folder / 'Source/.gdignore').write_text('')
bed = bpy.data.collections.new('ASSET | BedroomBed')
scene.collection.children.link(bed)
fabric = bpy.data.materials.new('Bedroom / worn mattress fabric')
fabric.use_nodes = True
shader = fabric.node_tree.nodes.get('Principled BSDF')
shader.inputs['Roughness'].default_value = .96
texture_path = next((ROOT / 'Models/Interiors/StudioFurniture/Textures').glob('*fabric*albedo*'), None)
if texture_path is None:
    texture_path = ROOT / 'Models/Interiors/StudioFurniture/Textures/aged_cream_albedo.png'
texture = fabric.node_tree.nodes.new('ShaderNodeTexImage')
texture.image = bpy.data.images.load(str(texture_path), check_existing=True)
fabric.node_tree.links.new(texture.outputs['Color'], shader.inputs['Base Color'])
box('Bed worn timber frame', (0, 0, .28), (1.65, 2.18, .25), wood, bed, .015)
box('Bed mattress', (0, 0, .48), (1.59, 2.10, .21), fabric, bed, .055)
box('Bed headboard', (0, .99, .68), (1.66, .10, 1.1), wood, bed, .015)
for x in [-.7, .7]:
    for y in [-.9, .9]:
        box('Bed foot', (x, y, .14), (.12, .12, .28), wood, bed)
for x in [-.4, .4]:
    pillow = box('Worn pillow', (x, .72, .64), (.67, .38, .13), fabric, bed, .06)
    pillow.rotation_euler.z = .06 if x > 0 else -.04
box('Bed folded blanket', (0, -.54, .602), (1.5, .89, .035), fabric, bed)
# Remove room/presentation from this native; the bed stays local and reusable.
for collection in list(scene.collection.children):
    if collection != bed:
        scene.collection.children.unlink(collection)
bpy.ops.file.pack_all()
bpy.ops.wm.save_as_mainfile(filepath=str(bed_folder / 'Source/bedroom_bed.blend'))
bpy.ops.object.select_all(action='DESELECT')
for obj in bed.objects:
    obj.select_set(True)
bpy.ops.export_scene.gltf(filepath=str(bed_folder / 'bedroom_bed.glb'), export_format='GLB', use_selection=True, export_apply=True, export_animations=False, export_cameras=False, export_lights=False, export_yup=True)
(bed_folder / 'asset_manifest.json').write_text(json.dumps({'native': str((bed_folder / 'Source/bedroom_bed.blend').relative_to(ROOT)).replace('\\', '/'), 'export': str((bed_folder / 'bedroom_bed.glb').relative_to(ROOT)).replace('\\', '/'), 'collection': bed.name, 'dimensions_m': [1.66, 2.18, 1.23], 'textures': 'Existing worn oak and aged fabric maps, packed'}, indent=2) + '\n')
print('EXPANDED APARTMENT / 12.2 x 6.2 m / independent bedroom bed', flush=True)
