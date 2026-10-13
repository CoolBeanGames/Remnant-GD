"""Prepare the supplied spreadsheet assets in Blender, without baking gameplay.

Run Blender --background --python Tools/import_trip_models.py -- --preview.
Sources are extracted by prepare_trip_models.py; this tool preserves their UVs,
builds portable PBR materials, applies metre scale and exports independent GLBs.
"""
import argparse
import json
import math
import sys
from pathlib import Path

import bpy
import bmesh
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[1]
BASE = ROOT / 'Models/Imported/Trip'
RENDERS = ROOT / 'Reports/TripModels'
parser = argparse.ArgumentParser()
parser.add_argument('--preview', action='store_true')
parser.add_argument('--only', default='')
args = parser.parse_args(sys.argv[sys.argv.index('--') + 1:] if '--' in sys.argv else [])


def bounds(objects):
    corners = [o.matrix_world @ Vector(c) for o in objects for c in o.bound_box]
    return Vector(tuple(min(c[i] for c in corners) for i in range(3))), Vector(tuple(max(c[i] for c in corners) for i in range(3)))


def configure_render(scene):
    scene.render.engine = 'CYCLES'
    scene.cycles.samples = 16 if args.preview else 32
    scene.cycles.use_denoising = True
    preferences = bpy.context.preferences.addons['cycles'].preferences
    try:
        preferences.compute_device_type = 'OPTIX'
        preferences.refresh_devices()
        gpu = [d for d in preferences.devices if d.type == 'OPTIX']
        for d in preferences.devices:
            d.use = d in gpu
        scene.cycles.device = 'GPU' if gpu else 'CPU'
    except Exception:
        scene.cycles.device = 'CPU'
    scene.render.resolution_x = 360 if args.preview else 640
    scene.render.resolution_y = 300 if args.preview else 480
    scene.render.resolution_percentage = 100
    scene.render.image_settings.file_format = 'PNG'
    scene.view_settings.view_transform = 'AgX'
    scene.world = bpy.data.worlds.new('Neutral studio')
    scene.world.use_nodes = True
    scene.world.node_tree.nodes['Background'].inputs[0].default_value = (.16, .18, .21, 1)
    scene.world.node_tree.nodes['Background'].inputs[1].default_value = .5


def materials(directory, objects):
    textures = list((directory / 'Source').rglob('*.jpg')) + list((directory / 'Source').rglob('*.JPEG'))
    base = next((p for p in textures if '_basecolor' in p.name.lower()), textures[0] if textures else None)
    if base is None:
        raise RuntimeError('Missing supplied base colour: ' + str(directory))
    maps = {key: next((p for p in textures if '_' + key in p.name.lower()), None) for key in ('normal', 'roughness', 'metallic')}
    mat = bpy.data.materials.new(directory.name + ' / supplied PBR')
    mat.use_nodes = True
    shader = mat.node_tree.nodes.get('Principled BSDF')
    shader.inputs['Roughness'].default_value = .78
    for key, path in {'basecolor': base, **maps}.items():
        if not path:
            continue
        tex = mat.node_tree.nodes.new('ShaderNodeTexImage')
        tex.image = bpy.data.images.load(str(path), check_existing=True)
        if key != 'basecolor':
            tex.image.colorspace_settings.name = 'Non-Color'
        if key == 'normal':
            normal = mat.node_tree.nodes.new('ShaderNodeNormalMap')
            normal.inputs['Strength'].default_value = .6
            mat.node_tree.links.new(tex.outputs['Color'], normal.inputs['Color'])
            mat.node_tree.links.new(normal.outputs['Normal'], shader.inputs['Normal'])
        else:
            target = {'basecolor': 'Base Color', 'roughness': 'Roughness', 'metallic': 'Metallic'}[key]
            mat.node_tree.links.new(tex.outputs['Color'], shader.inputs[target])
    for obj in objects:
        obj.data.materials.clear()
        obj.data.materials.append(mat)
    return base


def split_faces(obj, predicate, name):
    """Separate supplied triangles while retaining the original UV/material data."""
    copy = obj.copy()
    copy.data = obj.data.copy()
    copy.name = name
    obj.users_collection[0].objects.link(copy)
    for target, keep in [(copy, True), (obj, False)]:
        bm = bmesh.new()
        bm.from_mesh(target.data)
        faces = [f for f in bm.faces if bool(predicate(f.calc_center_median())) != keep]
        bmesh.ops.delete(bm, geom=faces, context='FACES')
        loose = [v for v in bm.verts if not v.link_faces]
        bmesh.ops.delete(bm, geom=loose, context='VERTS')
        bm.to_mesh(target.data)
        bm.free()
    return copy


def refine(name, objects):
    obj = objects[0]
    if name in ('desk', 'coffee_table'):
        factor = .75 / .65 if name == 'desk' else .42 / .30730334
        for vertex in obj.data.vertices:
            vertex.co.z *= factor
    elif name == 'steel_plate':
        # Gameplay's sheet uses centred XY edges and a .12 m Z thickness.
        low, high = bounds(objects)
        center = (low + high) / 2
        for vertex in obj.data.vertices:
            p = vertex.co - center
            vertex.co = Vector((p.x, p.y * (.115 / (high.y - low.y)), p.z))
        obj.data.update()
    elif name == 'lever':
        # Handle is the left rising arm; the upright indicator post stays fixed.
        handle = split_faces(obj, lambda p: p.z > .62 and p.x < .25 - max(0, p.z - .62) * .40 and p.y < -.06, 'LeverHandle')
        # The shaft meets the housing beside this axle, rather than below it.
        pivot = Vector((.10, -.205, .62))
        for vertex in handle.data.vertices:
            vertex.co -= pivot
        handle.location = pivot
        obj.name = 'LeverBase'
        objects.append(handle)
    elif name == 'door':
        # Crop on real planes rather than face centres: centre selection leaves
        # ragged triangles and doubles the handle across the moving seam.
        leaf = obj.copy()
        leaf.data = obj.data.copy()
        leaf.name = 'DoorLeaf'
        obj.users_collection[0].objects.link(leaf)
        bm = bmesh.new()
        bm.from_mesh(leaf.data)
        for axis, coordinate, lower in [(0, .13, True), (0, 1.42, False), (2, .095, True), (2, 2.96, False)]:
            normal = [0, 0, 0]
            normal[axis] = 1
            point = [0, 0, 0]
            point[axis] = coordinate
            bmesh.ops.bisect_plane(bm, geom=list(bm.verts) + list(bm.edges) + list(bm.faces), dist=.00001, plane_co=point, plane_no=normal, clear_inner=lower, clear_outer=not lower)
        bmesh.ops.recalc_face_normals(bm, faces=list(bm.faces))
        bm.to_mesh(leaf.data)
        bm.free()
        leaf.data.update()
        bpy.context.view_layer.update()
        low, high = bounds([leaf])
        sx = 1.74 / (high.x - low.x)
        sz = 3.18 / (high.z - low.z)
        for vertex in leaf.data.vertices:
            p = vertex.co
            p.x = (p.x - low.x) * sx - 1.74
            p.z = (p.z - low.z) * sz
        # The handle is on the left: hinge the leaf at its right-hand edge.
        leaf.location = Vector((.87, 0, .1295))
        material = bpy.data.materials.new('Door / restored timber edges')
        material.use_nodes = True
        shader = material.node_tree.nodes.get('Principled BSDF')
        shader.inputs['Roughness'].default_value = .8
        texture = material.node_tree.nodes.new('ShaderNodeTexImage')
        texture.image = bpy.data.images.load(str(ROOT / 'Models/Architecture/StudioApartment/Textures/oak_00_worn_albedo.png'), check_existing=True)
        material.node_tree.links.new(texture.outputs['Color'], shader.inputs['Base Color'])
        # Rebuild the retained frame around the exact leaf clearance. The empty
        # neighbouring frame is discarded, and these rails cannot obstruct it.
        frame_parts = []
        for pos, size in [((-.958, 0, 1.735), (.16, .22, 3.47)), ((.958, 0, 1.735), (.16, .22, 3.47)), ((0, 0, 3.397), (2.076, .22, .16))]:
            bpy.ops.mesh.primitive_cube_add(size=1, location=pos)
            part = bpy.context.object
            part.dimensions = size
            bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
            part.data.materials.append(material)
            for face in part.data.polygons:
                for index in face.loop_indices:
                    p = part.data.vertices[part.data.loops[index].vertex_index].co
                    part.data.uv_layers.active.data[index].uv = (p.x * 2 if abs(face.normal.y) > .5 else p.y * 2, p.z / 2)
            bevel = part.modifiers.new('Frame worn edges', 'BEVEL')
            bevel.width = .009
            bevel.segments = 2
            frame_parts.append(part)
        bpy.ops.object.select_all(action='DESELECT')
        for part in frame_parts:
            part.select_set(True)
        bpy.context.view_layer.objects.active = frame_parts[0]
        bpy.ops.object.convert(target='MESH')
        bpy.ops.object.join()
        frame = bpy.context.object
        bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
        obj.data = frame.data.copy()
        bpy.data.objects.remove(frame, do_unlink=True)
        obj.name = 'DoorFrame'
        objects.append(leaf)
    for target in objects:
        target.data.update()
    bpy.context.view_layer.update()


def camera(scene, collection, name, position, target):
    data = bpy.data.cameras.new(name)
    obj = bpy.data.objects.new(name, data)
    collection.objects.link(obj)
    obj.location = position
    obj.rotation_euler = (Vector(target) - obj.location).to_track_quat('-Z', 'Y').to_euler()
    data.type = 'ORTHO'
    scene.camera = obj
    return obj


RENDERS.mkdir(parents=True, exist_ok=True)
(RENDERS / '.gdignore').write_text('')
entries = json.loads((BASE / 'catalog.json').read_text())
for entry in entries:
    name = entry['id']
    if args.only and name not in args.only.split(','):
        continue
    directory = BASE / name
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.context.preferences.filepaths.save_version = 0
    scene = bpy.context.scene
    scene.unit_settings.system = 'METRIC'
    scene.unit_settings.scale_length = 1
    source = next((directory / 'Source').glob('*.fbx'))
    bpy.ops.import_scene.fbx(filepath=str(source))
    objects = [o for o in bpy.context.scene.objects if o.type == 'MESH']
    for obj in list(bpy.context.scene.objects):
        if obj.type != 'MESH':
            bpy.data.objects.remove(obj, do_unlink=True)
    bpy.context.view_layer.update()
    low, high = bounds(objects)
    original = list(high - low)
    base = materials(directory, objects)
    factor = entry['size'] / max(high - low)
    center = Vector(((low.x + high.x) / 2, (low.y + high.y) / 2, low.z))
    for obj in objects:
        obj.matrix_world.translation -= center
        obj.location *= factor
        obj.scale *= factor
        bpy.context.view_layer.objects.active = obj
        obj.select_set(True)
        bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
        obj.select_set(False)
    bpy.context.view_layer.update()
    if not args.preview:
        refine(name, objects)
    low, high = bounds(objects)
    asset = bpy.data.collections.new('ASSET | ' + name)
    scene.collection.children.link(asset)
    for obj in objects:
        for col in list(obj.users_collection):
            col.objects.unlink(obj)
        asset.objects.link(obj)
        if obj.name not in ('DoorFrame', 'DoorLeaf', 'LeverBase', 'LeverHandle'):
            obj.name = name + ' / mesh'
    presentation = bpy.data.collections.new('PRESENTATION | excluded from export')
    scene.collection.children.link(presentation)
    configure_render(scene)
    dimension = max(high - low)
    target = (low + high) / 2
    for title, position, power in [('Key', (2, -3, 4), 500), ('Fill', (-3, -1, 2), 250), ('Rim', (1, 3, 3), 450)]:
        light = bpy.data.lights.new(title, 'AREA')
        light.energy = power * dimension * dimension
        light.shape = 'DISK'
        light.size = 3 * dimension
        obj = bpy.data.objects.new(title, light)
        presentation.objects.link(obj)
        obj.location = Vector(position) * dimension + target
        obj.rotation_euler = (target - obj.location).to_track_quat('-Z', 'Y').to_euler()
    for i, vector in enumerate([(2, -3, 1.8), (-2, 3, 1.4), (0, -1, 3)]):
        cam = camera(scene, presentation, 'View ' + str(i + 1), target + Vector(vector) * dimension, target)
        cam.data.ortho_scale = dimension * 1.8
        scene.render.filepath = str(RENDERS / (name + '_' + str(i + 1) + ( '_preview' if args.preview else '') + '.png'))
        if not args.preview or i == 0:
            bpy.ops.render.render(write_still=True)
    scene.camera = bpy.data.objects['View 1']
    bpy.ops.file.pack_all()
    bpy.ops.wm.save_as_mainfile(filepath=str(directory / 'Source' / (name + '.blend')))
    bpy.ops.object.select_all(action='DESELECT')
    for obj in asset.objects:
        obj.select_set(True)
    bpy.ops.export_scene.gltf(filepath=str(directory / (name + '.glb')), export_format='GLB', use_selection=True, export_apply=True, export_animations=False, export_cameras=False, export_lights=False, export_yup=True, export_extras=True)
    manifest = {**entry, 'native': str((directory / 'Source' / (name + '.blend')).relative_to(ROOT)).replace('\\', '/'), 'collection': asset.name, 'source': str(source.relative_to(ROOT)).replace('\\', '/'), 'export': str((directory / (name + '.glb')).relative_to(ROOT)).replace('\\', '/'), 'original_bounds': original, 'dimensions_m': list(high - low), 'origin': 'centred XY sheet' if name == 'steel_plate' else 'bottom centre / named moving pivots', 'vertices': sum(len(o.data.vertices) for o in objects), 'triangles': sum(sum(len(p.vertices) - 2 for p in o.data.polygons) for o in objects), 'texture': str(base.relative_to(ROOT)).replace('\\', '/'), 'views': 1 if args.preview else 3, 'objects': [o.name for o in objects]}
    (directory / 'asset_manifest.json').write_text(json.dumps(manifest, indent=2) + '\n')
    print('PREPARED', name, list(high - low), flush=True)
