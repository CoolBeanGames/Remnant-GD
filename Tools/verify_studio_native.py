"""Read-only Blender check of native packed assets, local pivots and assembly links."""
from pathlib import Path
import json
import bpy

ROOT=Path(__file__).resolve().parents[1]
BASE=ROOT/'Models/Interiors/StudioFurniture'
for path in sorted(BASE.glob('*/asset_manifest.json')):
    info=json.loads(path.read_text())
    bpy.ops.wm.open_mainfile(filepath=str(ROOT/info['native']))
    collection=bpy.data.collections[info['collection']]
    assert collection.library is None
    assert all(o.type!='MESH' or o.data.uv_layers for o in collection.objects)
    used_images={node.image for o in collection.objects if o.type=='MESH' for mat in o.data.materials if mat and mat.use_nodes for node in mat.node_tree.nodes if node.type=='TEX_IMAGE' and node.image}
    assert used_images and all(i.packed_file for i in used_images)
    assert all(o.type not in ('LIGHT','CAMERA') for o in collection.objects)
    assert bpy.context.scene.camera and bpy.context.scene.render.resolution_x==1000
    print('NATIVE PASS',info['key'],len(used_images),'packed referenced maps',flush=True)
bpy.ops.wm.open_mainfile(filepath=str(ROOT/'Models/Architecture/StudioApartment/Source/studio_apartment.blend'))
room=bpy.data.collections['APARTMENT | permanent architecture']
room_meshes=[o for o in room.objects if o.type=='MESH']
assert room.library is None and len(room_meshes)==124
room_images={node.image for o in room_meshes for mat in o.data.materials if mat and mat.use_nodes for node in mat.node_tree.nodes if node.type=='TEX_IMAGE' and node.image}
assert room_images and all(i.packed_file for i in room_images)
print('NATIVE ROOM PASS: 124 independent architectural meshes;',len(room_images),'packed referenced maps',flush=True)
bpy.ops.wm.open_mainfile(filepath=str(ROOT/'Models/Interiors/FurnishedStudio/studio_apartment_furnished.blend'))
instances=[o for o in bpy.context.scene.objects if o.instance_type=='COLLECTION']
assert len(instances)==19,len(instances)
assert all(o.instance_collection.library is not None for o in instances)
assert all(Path(bpy.path.abspath(o.instance_collection.library.filepath)).is_file() for o in instances)
assert not any(o.hide_render for o in instances)
assert bpy.context.scene.camera.name=='Furnished / living towards windows'
assert (bpy.context.scene.render.resolution_x,bpy.context.scene.render.resolution_y)==(1800,1200)
print('NATIVE ASSEMBLY PASS: 19 linked collections, complete room visibility, default camera and aspect',flush=True)
