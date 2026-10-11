"""Replace window paper in the current room without rebuilding architecture/props.

Run in Blender. Then assemble_worn_studio.py updates the separate GLB and linked
furnished preview. This revision is idempotent and uses the versioned scan atlas.
"""
from pathlib import Path
import json
import sys

import bpy

sys.path.insert(0,str(Path(__file__).resolve().parent))
from studio_newspaper_layout import replace_coverings

ROOT=Path(__file__).resolve().parents[1]
ROOM=ROOT/'Models/Architecture/StudioApartment'
bpy.context.preferences.filepaths.save_version=0
bpy.ops.wm.open_mainfile(filepath=str(ROOM/'Source/studio_apartment.blend'))
architecture=bpy.data.collections['APARTMENT | permanent architecture']
created=replace_coverings(architecture)
for mat in list(bpy.data.materials):
    if mat.users==0 and mat.name.startswith(('Newspaper /','Window tape /')):
        bpy.data.materials.remove(mat)
for image in list(bpy.data.images):
    if image.users==0:
        bpy.data.images.remove(image)
    elif image.source=='FILE':
        image.pack()
bpy.ops.wm.save_as_mainfile(filepath=str(ROOM/'Source/studio_apartment.blend'))
manifest=json.loads((ROOM/'asset_manifest.json').read_text())
manifest['window_coverings']={'sheets':sum(bool(o.get('window_covering')) for o in created),
    'material':'Overlapping torn, wrinkled newsprint clippings with varied atlas crops and small grey adhesive tabs',
    'print_source':'Generated fictional newsprint_scan_atlas.png; prompt recorded in Textures/newsprint_scan_atlas.md',
    'openings':'Six irregular masks in the north window, four in the east; plus torn edge notches. Physical holes through every overlap.',
    'beams':'Real geometric openings; sunlight and dust belong to the presentation rig'}
manifest['textures']='Packed PBR maps; generated fictional newspaper scan atlas and original procedural surface maps'
manifest.pop('verification',None)
(ROOM/'asset_manifest.json').write_text(json.dumps(manifest,indent=2)+'\n',encoding='utf-8',newline='\n')
print('NEWSPAPER REWORK:',manifest['window_coverings']['sheets'],'independent clippings',flush=True)
