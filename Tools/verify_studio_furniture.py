"""Check portable furniture exports and the full multi-angle render delivery.

Run with ordinary Python/Pillow. Native library/packing checks additionally use
Blender via Tools/verify_studio_native.py; Godot import is a separate check.
"""
from pathlib import Path
import json
import struct
from PIL import Image, ImageStat

ROOT=Path(__file__).resolve().parents[1]
BASE=ROOT/'Models/Interiors/StudioFurniture'
manifest_paths=sorted(BASE.glob('*/asset_manifest.json'))
assert len(manifest_paths)==18, f'Expected 17 requested assets and the separate kitchenette, found {len(manifest_paths)}'
total_triangles=0
for path in manifest_paths:
    info=json.loads(path.read_text())
    native=ROOT/info['native']
    assert native.read_bytes()[:7]==b'BLENDER',native
    data=(ROOT/info['export']).read_bytes()
    magic,version,length=struct.unpack_from('<III',data)
    assert magic==0x46546C67 and version==2 and length==len(data),path
    size,kind=struct.unpack_from('<II',data,12)
    assert kind==0x4E4F534A
    g=json.loads(data[20:20+size])
    binary_size,binary_kind=struct.unpack_from('<II',data,20+size)
    assert binary_kind==0x004E4942
    assert not g.get('cameras') and 'KHR_lights_punctual' not in g.get('extensions',{})
    assert g.get('images') and all('bufferView' in im and 'uri' not in im for im in g['images'])
    for view in g['bufferViews']:
        assert view.get('byteOffset',0)+view['byteLength']<=binary_size
    assert not any('Presentation' in n.get('name','') for n in g['nodes'])
    assert len(g['meshes'])==info['mesh_objects'],info['key']
    triangles=0
    for mesh in g['meshes']:
        for primitive in mesh['primitives']:
            assert 'POSITION' in primitive['attributes'] and 'NORMAL' in primitive['attributes']
            assert 'TEXCOORD_0' in primitive['attributes'], (info['key'],mesh.get('name'))
            triangles+=g['accessors'][primitive['indices']]['count']//3
    assert triangles==info['triangles'],(info['key'],triangles,info['triangles'])
    total_triangles+=triangles
    assert info['packed_images']>0
    for key in ('front','rear','detail'):
        image=Image.open(ROOT/'Reports/StudioFurniture'/info['key']/(key+'.png')).convert('RGB')
        assert image.size==(1000,1000)
        assert max(ImageStat.Stat(image).stddev)>12,(info['key'],key)
    print(info['key'],info['mesh_objects'],'meshes;',triangles,'triangles; embedded maps and 3 views PASS')
assembly=json.loads((ROOT/'Models/Interiors/FurnishedStudio/assembly_manifest.json').read_text())
assert len(assembly['linked_assets'])==18
assert len({i['asset'] for i in assembly['linked_assets']})==18
for view in assembly['views']:
    image=Image.open(ROOT/'Reports/FurnishedStudio'/(view+'.png'))
    assert image.width==1800 and image.height>=1200
print('STUDIO DELIVERY PASS:',len(manifest_paths),'independent assets;',total_triangles,'furniture triangles; 54 prop and',len(assembly['views']),'assembled-room views')
