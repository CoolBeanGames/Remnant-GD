"""Check portable GLB structure, render coverage and authoring dependencies."""
from pathlib import Path
import hashlib
import json
import struct
from PIL import Image, ImageStat

ROOT=Path(__file__).resolve().parents[1]
ROOM=ROOT/'Models/Architecture/DilapidatedWarehouse'
PROPS=ROOT/'Models/Interiors/WarehouseMachinery'
ASSEMBLY=ROOT/'Models/Interiors/DilapidatedWarehouse'
RENDERS=ROOT/'Reports/Warehouse'
manifests=[ROOM/'asset_manifest.json',*sorted(PROPS.glob('*/asset_manifest.json'))]
assert len(manifests)==7,'Expected architecture plus six independent props'
records=[]
total_triangles=0
for path in manifests:
    info=json.loads(path.read_text())
    native=ROOT/info['native'];export=ROOT/info['export']
    assert native.read_bytes()[:7]==b'BLENDER',native
    data=export.read_bytes()
    magic,version,length=struct.unpack_from('<4sII',data)
    assert magic==b'glTF' and version==2 and length==len(data),export
    json_length,chunk_type=struct.unpack_from('<II',data,12)
    assert chunk_type==0x4e4f534a
    gltf=json.loads(data[20:20+json_length])
    assert not gltf.get('cameras') and not gltf.get('extensions',{}).get('KHR_lights_punctual')
    assert len(gltf['buffers'])==1 and 'uri' not in gltf['buffers'][0]
    for view in gltf.get('bufferViews',[]):
        assert view.get('byteOffset',0)+view['byteLength']<=gltf['buffers'][0]['byteLength']
    for image in gltf.get('images',[]):
        assert 'bufferView' in image and image.get('mimeType') in ('image/png','image/jpeg')
    mesh_nodes=[n for n in gltf.get('nodes',[]) if 'mesh' in n]
    assert len(mesh_nodes)==info['mesh_objects'],(export,len(mesh_nodes),info['mesh_objects'])
    tris=0
    for node in mesh_nodes:
        assert 'Studio' not in node.get('name','') and 'Presentation' not in node.get('name','')
        for prim in gltf['meshes'][node['mesh']]['primitives']:
            assert 'NORMAL' in prim['attributes'] and 'TEXCOORD_0' in prim['attributes'],(export,node)
            assert 'material' in prim
            tris+=gltf['accessors'][prim['indices']]['count']//3
    assert tris==info['triangles'],(export,tris,info['triangles'])
    assert any('baseColorTexture' in m.get('pbrMetallicRoughness',{}) for m in gltf['materials'])
    if path.parent==ROOM:
        views=[RENDERS/f'{name}.png' for name in info['views']]
    else:
        views=[RENDERS/path.parent.name/f'{name}.png' for name in info['views']]
    for image_path in views:
        im=Image.open(image_path).convert('RGB')
        assert im.width>=1000 and im.height>=1000,image_path
        assert max(ImageStat.Stat(im).stddev)>8,'Blank image: '+str(image_path)
    for f in (native,export,*views):
        records.append({'file':f.relative_to(ROOT).as_posix(),'bytes':f.stat().st_size,'sha256':hashlib.sha256(f.read_bytes()).hexdigest()})
    total_triangles+=tris
    print('WAREHOUSE PORTABLE PASS',info['key'],info['mesh_objects'],'meshes;',tris,'triangles;',len(views),'views')
assembly=json.loads((ASSEMBLY/'assembly_manifest.json').read_text())
assert len(assembly['instances'])==17
for instance in assembly['instances']:
    assert (ROOT/instance['source']).exists(),instance
native=ROOT/assembly['native']
assert native.read_bytes()[:7]==b'BLENDER'
records.append({'file':native.relative_to(ROOT).as_posix(),'bytes':native.stat().st_size,'sha256':hashlib.sha256(native.read_bytes()).hexdigest()})
result={'assets':len(manifests),'new_props':6,'assembly_instances':17,'triangles_separate_exports':total_triangles,
        'actual_render_images':24,'checked_files':records,
        'visual_review':'All final images must also be opened and reviewed; these structural checks do not substitute for visual QA.'}
(ASSEMBLY/'verification.json').write_text(json.dumps(result,indent=2)+'\n')
print('WAREHOUSE PORTABLE COMPLETE:',len(records),'files;',total_triangles,'separate-export triangles')
