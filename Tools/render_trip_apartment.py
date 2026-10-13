"""Render four final apartment angles and three views of its independent bed."""
import bpy, math, json
from pathlib import Path
from mathutils import Vector
ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'Reports/TripModels'
PRESENTATION=ROOT/'Models/Interiors/TripPresentation/Source'
PRESENTATION.mkdir(parents=True,exist_ok=True)
(PRESENTATION/'.gdignore').write_text('')
bpy.context.preferences.filepaths.save_version=0


def configure():
    s=bpy.context.scene;s.render.engine='CYCLES';s.cycles.samples=32;s.cycles.use_denoising=True
    s.render.resolution_x=1280;s.render.resolution_y=853;s.render.resolution_percentage=100
    s.render.image_settings.file_format='PNG'
    prefs=bpy.context.preferences.addons['cycles'].preferences
    try:
        prefs.compute_device_type='OPTIX';prefs.refresh_devices()
        gpu=[d for d in prefs.devices if d.type=='OPTIX']
        for d in prefs.devices:d.use=d in gpu
        s.cycles.device='GPU' if gpu else 'CPU'
    except Exception:s.cycles.device='CPU'
    return s


def cam(collection,name,pos,target,lens=24,ortho=None):
    data=bpy.data.cameras.new(name);data.lens=lens;data.clip_start=.03
    if ortho:data.type='ORTHO';data.ortho_scale=ortho
    obj=bpy.data.objects.new(name,data);collection.objects.link(obj);obj.location=pos
    obj.rotation_euler=(Vector(target)-obj.location).to_track_quat('-Z','Y').to_euler()
    return obj


def area(collection,name,pos,target,power,size=2):
    data=bpy.data.lights.new(name,'AREA');data.energy=power;data.size=size;data.color=(1,.79,.55)
    obj=bpy.data.objects.new(name,data);collection.objects.link(obj);obj.location=pos
    obj.rotation_euler=(Vector(target)-obj.location).to_track_quat('-Z','Y').to_euler()


bpy.ops.wm.open_mainfile(filepath=str(ROOT/'Models/Interiors/FurnishedStudio/studio_apartment_furnished.blend'))
scene=configure();rig=bpy.data.collections.new('PRESENTATION | expanded apartment views');scene.collection.children.link(rig)
area(rig,'Bedroom warm practical',(6.2,1,2.65),(6.2,1,0),180,1.6)
area(rig,'Bedroom window bounce',(7.9,.5,1.8),(6,0,1),140,1.2)
views={
    'apartment_cutaway':cam(rig,'Trip / whole apartment',(15,-14,13),(2.2,0,.9),ortho=16.9),
    'apartment_living':cam(rig,'Trip / living room',(-2.2,-2.5,1.65),(1.6,1.6,1.2),23),
    'apartment_bedroom':cam(rig,'Trip / bedroom',(4.5,-1.65,1.65),(6.4,1.25,.85),22),
    'apartment_doorway':cam(rig,'Trip / bedroom into living',(6.1,-1.65,1.65),(2,-.3,1.15),25)}
scene.camera=views['apartment_living']
bpy.ops.wm.save_as_mainfile(filepath=str(PRESENTATION/'apartment_presentation.blend'))
room=next(o for o in scene.objects if o.type=='EMPTY' and o.instance_type=='COLLECTION' and o.instance_collection.name.startswith('APARTMENT'))
for name,camera in views.items():
    scene.camera=camera;temporary=None;original=room.instance_collection
    if name=='apartment_cutaway':
        temporary=bpy.data.collections.new('TEMPORARY cutaway, complete native retained')
        copies={}
        for obj in original.all_objects:
            if obj is None:
                continue
            copy=obj.copy();copies[obj]=copy;temporary.objects.link(copy)
            lower=obj.name.lower()
            copy.hide_render=any(word in lower for word in ['south entry','east exterior','east window','side window','apartment entrance','ceiling','recessed light','ventilation','bedroom south exterior','bedroom complete ceiling'])
        for original_obj,copy in copies.items():
            if original_obj.parent in copies:copy.parent=copies[original_obj.parent]
        room.instance_collection=temporary
        for obj in scene.objects:
            if 'dust volume' in obj.name.lower():obj.hide_render=True
    scene.render.filepath=str(OUT/(name+'.png'));bpy.ops.render.render(write_still=True)
    if temporary:
        room.instance_collection=original
        for obj in list(temporary.objects):bpy.data.objects.remove(obj,do_unlink=True)
        bpy.data.collections.remove(temporary)

path=ROOT/'Models/Interiors/StudioFurniture/BedroomBed/Source/bedroom_bed.blend'
bpy.ops.wm.open_mainfile(filepath=str(path));scene=configure()
scene.world=bpy.data.worlds.new('Bed studio');scene.world.use_nodes=True
scene.world.node_tree.nodes['Background'].inputs['Strength'].default_value=.5
rig=bpy.data.collections.new('PRESENTATION | bed views');scene.collection.children.link(rig)
area(rig,'Bed studio key',(3,-4,5),(0,0,.5),700,4)
area(rig,'Bed studio rim',(-2,3,3),(0,0,.5),400,3)
for i,pos in enumerate([(3,-4,2.5),(-3,4,2.3),(0,-.2,5)]):
    scene.camera=cam(rig,'Bed / '+str(i+1),pos,(0,0,.5),ortho=3.6)
    scene.render.resolution_x=640;scene.render.resolution_y=480
    scene.render.filepath=str(OUT/('bedroom_bed_'+str(i+1)+'.png'));bpy.ops.render.render(write_still=True)
scene.camera=bpy.data.objects['Bed / 1'];bpy.ops.wm.save_as_mainfile(filepath=str(PRESENTATION/'bed_presentation.blend'))
print('RENDERED apartment x4 / independent bed x3',flush=True)
