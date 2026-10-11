"""Portable exports, final multi-angle coverage and dependency/hash evidence."""
from pathlib import Path
import hashlib
import json
import struct
from PIL import Image,ImageStat
ROOT=Path(__file__).resolve().parents[1]
ROOM=ROOT/'Models/Architecture/DilapidatedHospital'
PROPS=ROOT/'Models/Interiors/HospitalProps'
ASSEMBLY=ROOT/'Models/Interiors/DilapidatedHospital'
OUT=ROOT/'Reports/Hospital'
manifests=[ROOM/'asset_manifest.json',*sorted(PROPS.glob('*/asset_manifest.json'))]
assert len(manifests)==9
records=[];triangles=0
for path in manifests:
    info=json.loads(path.read_text());native=ROOT/info['native'];export=ROOT/info['export']
    assert native.read_bytes()[:7]==b'BLENDER'
    data=export.read_bytes();magic,version,length=struct.unpack_from('<4sII',data)
    assert magic==b'glTF' and version==2 and length==len(data)
    size,kind=struct.unpack_from('<II',data,12);assert kind==0x4e4f534a
    gltf=json.loads(data[20:20+size])
    assert not gltf.get('cameras') and not gltf.get('extensions',{}).get('KHR_lights_punctual')
    assert len(gltf['buffers'])==1 and 'uri' not in gltf['buffers'][0]
    for view in gltf.get('bufferViews',[]):assert view.get('byteOffset',0)+view['byteLength']<=gltf['buffers'][0]['byteLength']
    for image in gltf.get('images',[]):assert 'bufferView' in image and image.get('mimeType') in ('image/png','image/jpeg')
    nodes=[n for n in gltf['nodes'] if 'mesh' in n];assert len(nodes)==info['mesh_objects']
    tris=0
    for node in nodes:
        assert 'Studio' not in node.get('name','') and 'Presentation' not in node.get('name','')
        for prim in gltf['meshes'][node['mesh']]['primitives']:
            assert 'NORMAL' in prim['attributes'] and 'TEXCOORD_0' in prim['attributes'] and 'material' in prim
            tris+=gltf['accessors'][prim['indices']]['count']//3
    assert tris==info['triangles']
    assert any('baseColorTexture' in m.get('pbrMetallicRoughness',{}) for m in gltf['materials'])
    folder=OUT if path.parent==ROOM else OUT/path.parent.name
    views=[folder/f'{v}.png' for v in info['views']]
    assert len(views)==(8 if path.parent==ROOM else 3)
    for p in views:
        im=Image.open(p).convert('RGB');assert im.width>=1000 and im.height>=1000
        assert max(ImageStat.Stat(im).stddev)>8,('Blank image',p)
    for p in (native,export,*views):records.append({'file':p.relative_to(ROOT).as_posix(),'bytes':p.stat().st_size,'sha256':hashlib.sha256(p.read_bytes()).hexdigest()})
    triangles+=tris
    print('HOSPITAL PORTABLE PASS',info['key'],info['mesh_objects'],'meshes;',tris,'triangles;',len(views),'views')
assembly=json.loads((ASSEMBLY/'assembly_manifest.json').read_text());assert len(assembly['instances'])==50
for r in assembly['instances']:assert (ROOT/r['source']).exists()
native=ROOT/assembly['native'];assert native.read_bytes()[:7]==b'BLENDER'
records.append({'file':native.relative_to(ROOT).as_posix(),'bytes':native.stat().st_size,'sha256':hashlib.sha256(native.read_bytes()).hexdigest()})
result={'assets':9,'new_props':8,'assembly_instances':50,'triangles_separate_exports':triangles,'actual_render_images':32,'checked_files':records,
        'visual_review':'Final images must also be opened and visually reviewed; structural checks alone do not confirm visual quality.'}
(ASSEMBLY/'verification.json').write_text(json.dumps(result,indent=2)+'\n')
print('HOSPITAL PORTABLE COMPLETE:',len(records),'files;',triangles,'separate-export triangles')
