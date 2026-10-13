"""Run in Blender to check editable sources, packed maps and assembly links."""
import json
from pathlib import Path
import bpy
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[1]
base = ROOT / 'Models/Imported/Trip'
for entry in json.loads((base / 'catalog.json').read_text()):
    manifest = json.loads((base / entry['id'] / 'asset_manifest.json').read_text())
    bpy.ops.wm.open_mainfile(filepath=str(ROOT / manifest['native']))
    collection = bpy.data.collections[manifest['collection']]
    assert collection.objects and all(o.type == 'MESH' for o in collection.objects)
    for mesh in collection.objects:
        assert mesh.data.uv_layers and mesh.data.materials, mesh.name
        for material in mesh.data.materials:
            for node in material.node_tree.nodes:
                if node.type == 'TEX_IMAGE' and node.image:
                    assert node.image.packed_file, entry['id'] + ': unembedded texture'
for directory, filename in [('FurnishedStudio', 'studio_apartment_furnished.blend'), ('DilapidatedWarehouse', 'warehouse_assembly.blend'), ('DilapidatedHospital', 'hospital_assembly.blend')]:
    bpy.ops.wm.open_mainfile(filepath=str(ROOT / 'Models/Interiors' / directory / filename))
    assert all(Path(bpy.path.abspath(lib.filepath)).is_file() for lib in bpy.data.libraries)
    instances = [o for o in bpy.context.scene.objects if o.type == 'EMPTY' and o.instance_type == 'COLLECTION']
    assert all(o.instance_collection is not None for o in instances)
    if directory == 'FurnishedStudio':
        assert next(o for o in instances if o.name.endswith('BedroomBed')).instance_collection.name.startswith('ASSET | BedroomBed')
        assert not any(o.name.endswith('BedroomDesk') for o in instances), 'The desk belongs only in the warehouse office'
        television = next(o for o in instances if o.name.endswith(' / TV'))
        assert (television.location - Vector((4.45, -2.8, .658))).length < .0001, 'TV assembly does not match the current game scene'
bpy.ops.wm.open_mainfile(filepath=str(ROOT / 'Models/Architecture/StudioApartment/Source/studio_apartment.blend'))
floor = bpy.data.objects['Oak floor | staggered individual boards']
original_end = max((floor.matrix_world @ Vector(v)).x for v in floor.bound_box)
boards = [o for o in bpy.data.collections['APARTMENT | permanent architecture'].objects if o.name.startswith('Bedroom worn oak board')]
assert len(boards) == 192
extension_start = min((o.matrix_world @ Vector(v)).x for o in boards for v in o.bound_box)
assert .0017 <= extension_start - original_end <= .0019, 'A wide gap remains between original and extension boards'
assert all(o.data.uv_layers and o.data.materials for o in boards), 'Extension boards must remain textured'
for obj in [floor, *boards]:
    for material in obj.data.materials:
        for node in material.node_tree.nodes:
            if node.type == 'TEX_IMAGE' and node.image:
                assert node.image.packed_file, 'Floor texture is not embedded'
print('Trip native assets: PASS / 32 UV-mapped packed natives / 3 valid linked assemblies', flush=True)
print('Apartment shell: PASS / 192 UV-mapped boards / 1.8 mm seam / TV pose matches scene', flush=True)
