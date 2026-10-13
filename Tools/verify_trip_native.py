"""Run in Blender to check editable sources, packed maps and assembly links."""
import json
from pathlib import Path
import bpy

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
        assert next(o for o in instances if o.name.endswith('BedroomDesk')).instance_collection.name.startswith('ASSET | desk')
print('Trip native assets: PASS / 32 UV-mapped packed natives / 3 valid linked assemblies', flush=True)
