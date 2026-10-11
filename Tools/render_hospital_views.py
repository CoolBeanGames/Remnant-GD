"""Re-render the linked hospital; temporary cutaway never changes the saved model."""
import argparse
import json
import sys
from pathlib import Path
import bpy
from mathutils import Vector
sys.path.insert(0,str(Path(__file__).resolve().parent))
import warehouse_common as w
p=argparse.ArgumentParser();p.add_argument('--views',default='all');p.add_argument('--samples',type=int,default=128)
p.add_argument('--width',type=int,default=1800);p.add_argument('--preview',action='store_true')
args=p.parse_args(sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else [])
BASE=w.ROOT/'Models/Interiors/DilapidatedHospital';OUT=w.ROOT/'Reports/Hospital'
info=json.loads((BASE/'assembly_manifest.json').read_text())
bpy.ops.wm.open_mainfile(filepath=str(w.ROOT/info['native']))
scene=w.configure(args.samples,args.width,round(args.width*2/3));scene.view_settings.exposure=.85
cameras=[o for o in bpy.data.collections['PRESENTATION | hospital daylight and cameras'].objects if o.type=='CAMERA']
views=dict(zip(info['views'],sorted(cameras,key=lambda o:o.name)))
shell=bpy.data.collections['ASSEMBLY | linked hospital architecture and props'].objects['Hospital shell']
keys=list(views) if args.views=='all' else args.views.split(',')
out=(w.ROOT/'.godot/hospital_previews') if args.preview else OUT
out.mkdir(parents=True,exist_ok=True)
for key in keys:
    scene.camera=views[key];scene.render.filepath=str(out/f'{key}.png')
    temporary=None
    if key=='overview':
        shell.hide_render=True;temporary=w.collection('TEMPORARY | cutaway rendering only')
        for obj in shell.instance_collection.objects:
            if obj.type!='MESH':continue
            if obj.name.startswith('CEILING |') or (obj.name.startswith(('OUTER |','Skirting | OUTER')) and (obj.location.x<-8.8 or obj.location.y<-12.8)):continue
            copy=obj.copy();copy.data=obj.data;temporary.objects.link(copy);copy.hide_render=False
        # Small, high plan light only helps reveal the plan while the roof is removed.
        light=w.area(temporary,'Temporary plan fill',(0,-1,15),(0,0,0),1800,16,(.77,.85,1))
        light.visible_camera=False;light.visible_glossy=False;light.visible_transmission=False
    print('HOSPITAL VIEW',key,'preview' if args.preview else 'final',flush=True)
    bpy.ops.render.render(write_still=True)
    if temporary:
        for obj in list(temporary.objects):bpy.data.objects.remove(obj,do_unlink=True)
        bpy.data.collections.remove(temporary);shell.hide_render=False
print('HOSPITAL VIEWS COMPLETE',flush=True)
