"""Keep the native linked memory assemblies in sync with the imported art."""
import json, math
import hashlib
import shutil
import os
import re
import sys
from pathlib import Path
import bpy
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[1]
BASE = ROOT / 'Models/Imported/Trip'
catalog = {e['id']: e for e in json.loads((BASE / 'catalog.json').read_text())}
bpy.context.preferences.filepaths.save_version = 0


def trip_source(name):
    return f'Models/Imported/Trip/{name}/Source/{name}.blend'


def change_entry(entry, name):
    entry['source'] = trip_source(name)
    entry['collection'] = 'ASSET | ' + name


selected = next((a.split('=', 1)[1].split(',') for a in sys.argv if a.startswith('--only=')), [])
allowed = {'FurnishedStudio', 'DilapidatedWarehouse', 'DilapidatedHospital'}
if set(selected) - allowed:
    raise ValueError('Unknown assembly selection: ' + ', '.join(selected))
for directory, filename, key in [('FurnishedStudio', 'studio_apartment_furnished.blend', 'linked_assets'), ('DilapidatedWarehouse', 'warehouse_assembly.blend', 'instances'), ('DilapidatedHospital', 'hospital_assembly.blend', 'instances')]:
    if selected and directory not in selected:
        continue
    folder = ROOT / 'Models/Interiors' / directory
    backup = ROOT / '.godot/trip_assembly_backups' / directory
    backup.mkdir(parents=True, exist_ok=True)
    for relative in ['assembly_manifest.json', filename]:
        original = folder / relative
        copy = backup / relative
        if not copy.exists():
            shutil.copy2(original, copy)
            if hashlib.sha256(original.read_bytes()).digest() != hashlib.sha256(copy.read_bytes()).digest():
                raise RuntimeError('Backup verification failed: ' + relative)
    info = json.loads((folder / 'assembly_manifest.json').read_text())
    entries = info[key]
    for entry in entries:
        name = entry.get('name', entry.get('asset', ''))
        if name == 'Couch':
            change_entry(entry, 'couch')
            entry['position_m'] = [.1, -.25, 0]
        elif name == 'Chair':
            change_entry(entry, 'lounger' if directory == 'FurnishedStudio' else 'office_chair')
        elif name == 'TV':
            change_entry(entry, 'television')
        elif 'PileOfMail' in name:
            change_entry(entry, 'paper_stack')
            if directory == 'FurnishedStudio':
                entry['position_m'] = [1.8, 1.65, .781]
            elif directory == 'DilapidatedWarehouse':
                entry['position_m'][2] = 4.951
        elif name == 'Bookshelf':
            entry['position_m'] = [3.59, 2.15, 0]
        elif name == 'FamilyPhoto':
            entry['position_m'] = [3.54, 2.0, 1.851]
        elif name == 'TableAndChairs':
            entry['position_m'] = [1.8, 1.65, 0]
        elif name == 'BedroomDesk':
            change_entry(entry, 'desk')
        elif name == 'BedroomBed':
            entry['source'] = 'Models/Interiors/StudioFurniture/BedroomBed/Source/bedroom_bed.blend'
            entry['collection'] = 'ASSET | BedroomBed'
        elif name.startswith('HydraulicPress'):
            change_entry(entry, 'industrial_machine_a')
        elif name.startswith('IndustrialLathe'):
            change_entry(entry, 'industrial_machine_b')
        elif name.startswith('AirCompressor'):
            change_entry(entry, 'industrial_machine_c')
        elif name.startswith('ControlCabinet'):
            change_entry(entry, 'industrial_machine_c')
        elif name.startswith('OfficeDesk'):
            change_entry(entry, 'desk')
        elif name == 'LandlinePhone' and directory == 'DilapidatedWarehouse':
            entry['position_m'][2] = 4.952
        elif directory == 'DilapidatedHospital' and 'bed' in name.lower() and 'cabinet' not in name.lower():
            change_entry(entry, 'hospital_bed')
        elif 'wheelchair' in name.lower():
            change_entry(entry, 'wheelchair')
        elif 'waiting bench' in name.lower():
            change_entry(entry, 'waiting_chairs')
        elif name.startswith('Ward door'):
            change_entry(entry, 'door')
            entry['scale'] = [.59, .67, .67]
            entry['leaf_open_degrees'] = 96
    additions = []
    if directory == 'FurnishedStudio':
        additions = [{'asset': 'CoffeeTable', 'source': trip_source('coffee_table'), 'collection': 'ASSET | coffee_table', 'position_m': [0, -1.55, 0], 'rotation_z_degrees': 0}, {'asset': 'BedroomDesk', 'source': trip_source('desk'), 'collection': 'ASSET | desk', 'position_m': [6.2, -2.4, 0], 'rotation_z_degrees': 0}, {'asset': 'BedroomBed', 'source': 'Models/Interiors/StudioFurniture/BedroomBed/Source/bedroom_bed.blend', 'collection': 'ASSET | BedroomBed', 'position_m': [6.3, 1.5, 0], 'rotation_z_degrees': 0}]
    else:
        positions = [(-8, -8, 0), (9, 11, 0), (-9.5, 9, 0), (3, -15, 0)] if directory == 'DilapidatedWarehouse' else [(-7.5, -5, 0), (7.5, 8, 0), (1.6, -9.5, 0), (-1.7, 9, 0)]
        for i, pos in enumerate(positions):
            name = 'garbage_bag_a' if i % 2 == 0 else 'garbage_bag_b'
            additions.append({'name': f'GarbageBag {i + 1}', 'source': trip_source(name), 'collection': 'ASSET | ' + name, 'position_m': pos, 'rotation_z_degrees': math.degrees(i * .73), 'collision': False})
    existing = {e.get('name', e.get('asset')) for e in entries}
    if directory == 'FurnishedStudio':
        additions.extend([
            {'asset': 'EntranceDoor', 'source': trip_source('door'), 'collection': 'ASSET | door', 'position_m': [1.76, -3.15, 0], 'rotation_z_degrees': 0, 'scale': [.49, .63, .63], 'leaf_open_degrees': 96},
            {'asset': 'BathroomDoor', 'source': trip_source('door'), 'collection': 'ASSET | door', 'position_m': [-2.64, .75, 0], 'rotation_z_degrees': 0, 'scale': [.577, .61, .61], 'leaf_open_degrees': 96},
        ])
    entries.extend(e for e in additions if e.get('name', e.get('asset')) not in existing)
    if directory == 'DilapidatedHospital':
        for name, position, angle, scale in [('StaffDoor', [5.8, -1.7, 0], 180, [.74, .665, .665]), ('ClosedExitDoor', [0, 12.94, 0], 0, [1.25, .95, .95])]:
            if name not in {e.get('name', e.get('asset')) for e in entries}:
                entries.append({'name': name, 'source': trip_source('door'), 'collection': 'ASSET | door', 'position_m': position, 'rotation_z_degrees': angle, 'scale': scale, 'leaf_open_degrees': 0})
    # Gameplay scene poses are the current authority for linked presentation props.
    scene_name = {'FurnishedStudio': 'furnished_apartment', 'DilapidatedWarehouse': 'dilapidated_warehouse', 'DilapidatedHospital': 'dilapidated_hospital'}[directory]
    blocks = re.split(r'(?=^\[node )', (ROOT / 'Scenes/Environments' / (scene_name + '.tscn')).read_text(), flags=re.M)
    poses = {}
    for block in blocks:
        header = re.match(r'\[node name="([^"]+)"[^\n]*parent="Art"', block)
        if header is None:
            continue
        transform = re.search(r'^transform = Transform3D\(([^)]+)\)', block, re.M)
        position = re.search(r'^position = Vector3\(([^)]+)\)', block, re.M)
        rotation = re.search(r'^rotation = Vector3\(([^)]+)\)', block, re.M)
        if transform:
            values = [float(v) for v in transform[1].split(',')]
            scale = sum(v*v for v in values[:3]) ** .5
            # TSCN writes the basis by rows; m02 is +sin(yaw), not the
            # third component of its X column. Y-up/Z-up conversion keeps yaw.
            poses[header[1]] = {'position_m': [values[9], -values[11], values[10]], 'rotation_z_degrees': math.degrees(math.atan2(values[2], values[0])), 'scale': [scale]*3}
        elif position:
            values = [float(v) for v in position[1].split(',')]
            poses[header[1]] = {'position_m': [values[0], -values[2], values[1]], 'rotation_z_degrees': math.degrees(float(rotation[1].split(',')[1])) if rotation else 0}
    if directory == 'FurnishedStudio':
        entries[:] = [e for e in entries if e.get('name', e.get('asset')) != 'BedroomDesk']
    for entry in entries:
        name = entry.get('name', entry.get('asset'))
        if name in poses:
            # Door wrapper scales are already held in the native manifest.
            values = dict(poses[name])
            if name.endswith('Door') or name.startswith('Ward door'):
                values.pop('scale', None)
            entry.update(values)
        if name.startswith('Ward door'):
            entry['leaf_open_degrees'] = 0
            entry['scale'] = [.74, .665, .665]
    for entry in entries:
        if 'leaf_open_degrees' in entry:
            entry['leaf_open_degrees'] = -abs(entry['leaf_open_degrees'])
    info['revision'] = 'Trip spreadsheet replacements and expanded one-bedroom apartment'
    (folder / 'assembly_manifest.json').write_text(json.dumps(info, indent=2) + '\n')
    bpy.ops.wm.open_mainfile(filepath=str(folder / filename))
    scene = bpy.context.scene
    # Update named manifest instances in place, preserving unrelated instances,
    # the presentation rig and any content absent from the supplied manifest.
    instances = {o.name.removeprefix('Instance / '): o for o in scene.objects if o.type == 'EMPTY' and o.instance_type == 'COLLECTION'}
    if directory == 'FurnishedStudio' and 'BedroomDesk' in instances:
        bpy.data.objects.remove(instances.pop('BedroomDesk'), do_unlink=True)
    if directory == 'FurnishedStudio':
        entries_for_scene = [{'name': 'Apartment shell', 'source': info['room_source'], 'collection': 'APARTMENT | permanent architecture', 'position_m': [0, 0, 0], 'rotation_z_degrees': 0}, *entries]
    else:
        entries_for_scene = entries
    assembly = bpy.data.collections.get('ASSEMBLY | Trip linked replacements')
    if assembly is None:
        assembly = bpy.data.collections.new('ASSEMBLY | Trip linked replacements')
        scene.collection.children.link(assembly)
    for entry in entries_for_scene:
        source = ROOT / entry['source']
        collection_name = entry.get('collection')
        if collection_name is None:
            manifest = json.loads((source.parent.parent / 'asset_manifest.json').read_text())
            collection_name = manifest['collection']
        with bpy.data.libraries.load(str(source), link=True, relative=True) as (src, dst):
            dst.collections = [collection_name]
        name = entry.get('name', entry.get('asset', ''))
        obj = instances.get(name)
        if obj is None and name == 'Apartment shell':
            obj = instances.get('independent room shell')
        if obj is None:
            obj = bpy.data.objects.new('Instance / ' + name, None)
            obj.instance_type = 'COLLECTION'
            assembly.objects.link(obj)
        obj.instance_collection = dst.collections[0]
        if 'leaf_open_degrees' in entry:
            # A local pose collection shares the independently linked mesh data.
            pose_name = 'POSE | ' + name
            pose = bpy.data.collections.get(pose_name)
            if pose is None:
                pose = bpy.data.collections.new(pose_name)
            for old in list(pose.objects):
                bpy.data.objects.remove(old, do_unlink=True)
            for original in dst.collections[0].objects:
                copied = original.copy()
                pose.objects.link(copied)
                if original.name.startswith('DoorLeaf'):
                    copied.rotation_euler.z = math.radians(entry['leaf_open_degrees'])
            obj.instance_collection = pose
        obj.location = entry['position_m']
        obj.rotation_euler.z = math.radians(entry['rotation_z_degrees'])
        if 'scale' in entry:
            obj.scale = entry['scale']
    staged = folder / (Path(filename).stem + '.rebuilt.blend')
    bpy.ops.wm.save_as_mainfile(filepath=str(staged))
    os.replace(staged, folder / filename)
    print('SYNCED', directory, len(entries_for_scene), 'linked assets', flush=True)
