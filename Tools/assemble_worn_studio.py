"""Age the independent room shell, then link the separate props into a preview.

Requires model_studio_apartment.py and model_studio_furniture.py outputs. Furniture
is linked, never baked into architecture. Idempotent room dirt replacement.
"""
import argparse
import json
import math
import sys
from pathlib import Path
import bpy
from mathutils import Vector

ROOT=Path(__file__).resolve().parents[1]
ROOM=ROOT/'Models/Architecture/StudioApartment'
FURN=ROOT/'Models/Interiors/StudioFurniture'
OUT=ROOT/'Models/Interiors/FurnishedStudio'
RENDERS=ROOT/'Reports/FurnishedStudio'
TEX=FURN/'Textures'
p=argparse.ArgumentParser()
p.add_argument('--samples',type=int,default=128)
p.add_argument('--width',type=int,default=1800)
p.add_argument('--views',default='cutaway,living,entry,kitchen,paper')
args=p.parse_args(sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else [])
for folder in (OUT,RENDERS):
    folder.mkdir(parents=True,exist_ok=True)
    (folder/'.gdignore').write_text('')


def configure():
    bpy.context.preferences.filepaths.save_version=0
    s=bpy.context.scene
    s.cycles.samples=args.samples
    s.cycles.adaptive_threshold=.025
    s.render.resolution_x=args.width
    s.render.resolution_y=round(args.width*2/3)
    s.render.resolution_percentage=100
    pref=bpy.context.preferences.addons['cycles'].preferences
    try:
        pref.compute_device_type='OPTIX'
        pref.refresh_devices()
        available=[d for d in pref.devices if d.type=='OPTIX']
        for d in pref.devices:
            d.use=d in available
        s.cycles.device='GPU' if available else 'CPU'
    except Exception:
        s.cycles.device='CPU'
    return s


def textured(name,key):
    m=bpy.data.materials.get(name) or bpy.data.materials.new(name)
    m.use_nodes=True
    nodes,links=m.node_tree.nodes,m.node_tree.links
    nodes.clear()
    out=nodes.new('ShaderNodeOutputMaterial')
    shader=nodes.new('ShaderNodeBsdfPrincipled')
    links.new(shader.outputs['BSDF'],out.inputs['Surface'])
    for suffix,target in [('albedo','Base Color'),('roughness','Roughness'),('normal','Normal')]:
        im=bpy.data.images.load(str(TEX/f'{key}_{suffix}.png'),check_existing=True)
        if suffix!='albedo':
            im.colorspace_settings.name='Non-Color'
        node=nodes.new('ShaderNodeTexImage')
        node.image=im
        if suffix=='normal':
            normal=nodes.new('ShaderNodeNormalMap')
            normal.inputs['Strength'].default_value=.25
            links.new(node.outputs['Color'],normal.inputs['Color'])
            links.new(normal.outputs['Normal'],shader.inputs[target])
        else:
            links.new(node.outputs['Color'],shader.inputs[target])
    return m


def stain_material():
    mat=bpy.data.materials.get('Architecture / damp and grime') or bpy.data.materials.new('Architecture / damp and grime')
    mat.use_nodes=True
    mat.surface_render_method='DITHERED'
    shader=mat.node_tree.nodes.get('Principled BSDF')
    shader.inputs['Roughness'].default_value=.96
    tex=mat.node_tree.nodes.new('ShaderNodeTexImage')
    tex.image=bpy.data.images.load(str(TEX/'damp_stain.png'),check_existing=True)
    mat.node_tree.links.new(tex.outputs['Color'],shader.inputs['Base Color'])
    mat.node_tree.links.new(tex.outputs['Alpha'],shader.inputs['Alpha'])
    return mat


def stain(collection,name,position,size,axis='north'):
    w,h=size
    vertices=[(-w/2,0,-h/2),(w/2,0,-h/2),(w/2,0,h/2),(-w/2,0,h/2)]
    if axis=='east':
        vertices=[(0,-w/2,-h/2),(0,w/2,-h/2),(0,w/2,h/2),(0,-w/2,h/2)]
    if axis=='floor':
        vertices=[(-w/2,-h/2,0),(w/2,-h/2,0),(w/2,h/2,0),(-w/2,h/2,0)]
    mesh=bpy.data.meshes.new(name)
    mesh.from_pydata(vertices,[],[(0,1,2,3)])
    mesh.update()
    uv=mesh.uv_layers.new()
    for i,co in enumerate([(0,0),(1,0),(1,1),(0,1)]):
        uv.data[i].uv=co
    o=bpy.data.objects.new(name,mesh)
    collection.objects.link(o)
    o.location=position
    mesh.materials.append(grime)
    return o


bpy.ops.wm.open_mainfile(filepath=str(ROOM/'Source/studio_apartment.blend'))
scene=configure()
architecture=bpy.data.collections['APARTMENT | permanent architecture']
for obj in list(architecture.objects):
    if obj.name.startswith('Grime /'):
        bpy.data.objects.remove(obj,do_unlink=True)
plaster=textured('Warm lime plaster / fine texture','plaster_dirty')
tile=textured('Bathroom / muted sage ceramic','tile_dirty')
trim=textured('Trim / bone-white enamel','aged_cream')
# Existing material identities stay intact; floor maps gain dust and scuffing.
for index in range(4):
    mat=bpy.data.materials.get('Oak / board tone %02d'%index)
    node=next(n for n in mat.node_tree.nodes if n.type=='TEX_IMAGE' and n.image and 'albedo' in n.image.name)
    # Never darken a previously aged map again on a repeated assembly run.
    original=bpy.data.images.load(str(ROOM/'Textures'/('oak_%02d_albedo.png'%index)),check_existing=False)
    import numpy as np
    data=np.array(original.pixels[:],dtype=np.float32).reshape(original.size[1],original.size[0],4)
    yy,xx=np.mgrid[0:data.shape[0],0:data.shape[1]]
    wear=(np.sin(xx*.13+np.sin(yy*.016)*3)*.5+.5)**14
    data[:,:,:3]=data[:,:,:3]*.76+np.array([.026,.027,.021])
    data[:,:,:3]-=wear[:,:,None]*.029
    path=ROOM/'Textures'/('oak_%02d_worn_albedo.png'%index)
    image=bpy.data.images.get(path.stem) or bpy.data.images.new(path.stem,original.size[0],original.size[1],alpha=False)
    image.colorspace_settings.name='sRGB'
    image.filepath_raw=str(path)
    image.file_format='PNG'
    image.pixels.foreach_set(data.ravel())
    image.save()
    node.image=image
    bpy.data.images.remove(original)
grime=stain_material()
patches=[('North damp below window',(.2,3.097,.40),(2.4,.72),'north'),
         ('North damp corner',(3.68,3.097,1.37),(.41,2.68),'north'),
         ('East damp corner',(3.897,2.72,1.25),(.7,2.43),'east'),
         ('West kitchen grease',(-3.897,-1.05,1.28),(2.85,2.15),'east'),
         ('West rising damp',(-3.897,-2.8,.35),(.53,.65),'east'),
         ('Bathroom wall mildew',(-3.897,1.91,1.65),(2.15,2.28),'east'),
         ('Floor kitchen grease',(-3.30,-1.04,.003),(.94,3.20),'floor'),
         ('Floor entrance traffic',(1.53,-2.58,.004),(1.06,1.0),'floor'),
         ('Floor dark corner',(3.25,2.56,.004),(1.18,.95),'floor'),
         ('Bathroom grout stain',(-2.95,2.33,.012),(1.55,1.13),'floor')]
for name,pos,size,axis in patches:
    stain(architecture,'Grime / '+name,pos,size,axis)
for im in bpy.data.images:
    if im.source=='FILE' and im.users:
        im.pack()
scene.camera=bpy.data.objects['02 / entry towards daylight']
bpy.ops.wm.save_as_mainfile(filepath=str(ROOM/'Source/studio_apartment.blend'))
bpy.ops.object.select_all(action='DESELECT')
for o in architecture.objects:
    o.select_set(True)
bpy.ops.export_scene.gltf(filepath=str(ROOM/'studio_apartment.glb'),export_format='GLB',use_selection=True,export_apply=True,export_animations=False,export_cameras=False,export_lights=False,export_extras=True,export_yup=True)
manifest=json.loads((ROOM/'asset_manifest.json').read_text())
manifest['architecture_meshes']=sum(o.type=='MESH' for o in architecture.objects)
tris=0
for o in architecture.objects:
    if o.type=='MESH':
        ev=o.evaluated_get(bpy.context.evaluated_depsgraph_get())
        m=ev.to_mesh()
        m.calc_loop_triangles()
        tris+=len(m.loop_triangles)
        ev.to_mesh_clear()
manifest['triangles']=tris
manifest.pop('verification',None)
manifest['surface_finish']='Worn oak, mottled yellowed plaster, aged enamel/tile and 10 local damp/grease/traffic stain patches'
manifest['furniture']=False
(ROOM/'asset_manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')

# Link local-coordinate asset collections; one native source for each furniture type.
assembly=bpy.data.collections.new('ASSEMBLY | linked independent furniture')
scene.collection.children.link(assembly)
placements=[('Kitchenette',(-3.54,-.30,0),90),
            ('Fridge',(-3.49,-2.48,0),90),
            ('Stove',(-3.53,-1.49,0),90),
            ('Sink',(-3.54,-.87,.91),90),
            ('Microwave',(-3.45,.29,.915),90),
            ('CoffeePot',(-3.48,-.25,.915),90),
            ('TrashCan',(-2.53,-1.39,0),0),
            ('Couch',(1.05,.32,0),0),
            ('Chair',(-.48,1.63,0),-25),
            ('TableAndChairs',(2.77,1.71,0),90),
            ('EntertainmentCenter',(-.58,-2.80,0),180),
            ('TV',(-.83,-2.80,.658),180),
            ('VCR',(-.30,-2.80,.382),180),
            ('LandlinePhone',(.0,-2.81,.658),180),
            ('Bookshelf',(3.59,-1.41,0),-90),
            ('PottedPlant',(2.91,2.70,0),0),
            ('PileOfMail',(2.77,1.71,.781),-12),
            ('FamilyPhoto',(3.54,-1.57,1.851),-90)]
linked=[]
for key,pos,angle in placements:
    info=json.loads((FURN/key/'asset_manifest.json').read_text())
    path=ROOT/info['native']
    with bpy.data.libraries.load(str(path),link=True,relative=True) as (src,dst):
        dst.collections=[info['collection']]
    collection=dst.collections[0]
    obj=bpy.data.objects.new('Instance / '+key,None)
    obj.instance_type='COLLECTION'
    obj.instance_collection=collection
    assembly.objects.link(obj)
    obj.location=pos
    obj.rotation_euler.z=math.radians(angle)
    linked.append({'asset':key,'source':info['native'],'position_m':list(pos),'rotation_z_degrees':angle})

# The room is also linked in the assembly. A small local rig is copied deliberately.
local_arch=architecture
local_presentation=bpy.data.collections['PRESENTATION | cameras, lights, backdrop']
# Switch the active document before loading the shell as a library: Blender
# deliberately refuses to link its current file to itself.
bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'studio_apartment_furnished.blend'))
with bpy.data.libraries.load(str(ROOM/'Source/studio_apartment.blend'),link=True,relative=True) as (src,dst):
    dst.collections=['APARTMENT | permanent architecture']
room_collection=dst.collections[0]
scene.collection.children.unlink(local_arch)
room_instance=bpy.data.objects.new('Instance / independent room shell',None)
room_instance.instance_type='COLLECTION'
room_instance.instance_collection=room_collection
scene.collection.objects.link(room_instance)
# Library override on visibility via per-render evaluated local collection copy:
# full source remains linked; cutaway renders only make a temporary local copy.
scene.world.node_tree.nodes['Background'].inputs['Strength'].default_value=.13
dust=bpy.data.materials.get('Presentation / subtle airborne dust')
if dust:
    next(n for n in dust.node_tree.nodes if n.type=='VOLUME_SCATTER').inputs['Density'].default_value=.028
bpy.data.lights['Soft interior bounce'].energy=90
bpy.data.lights['North window daylight'].energy=220
bpy.data.lights['East window daylight'].energy=150
# Keep the diffuse daylight disks outside the shell and within window height.
# The original wide disks crossed the ceiling and made a bright artificial rim.
for name,pos,target in [
    ('North window daylight',(1.1,4.3,1.7),(1.1,3.05,1.65)),
    ('East window daylight',(4.8,.55,1.7),(3.85,.55,1.65)),
]:
    daylight=bpy.data.objects[name]
    daylight.location=pos
    daylight.rotation_euler=(Vector(target)-daylight.location).to_track_quat('-Z','Y').to_euler()
    daylight.data.size=1.2
data=bpy.data.lights.new('Kitchen warm under cabinet task lamp','AREA')
data.energy=35
data.color=(1,.74,.43)
data.size=1.4
obj=bpy.data.objects.new(data.name,data)
local_presentation.objects.link(obj)
obj.location=(-3.18,-.31,1.63)
obj.rotation_euler=(Vector((-3.48,-.3,.91))-obj.location).to_track_quat('-Z','Y').to_euler()


def cam(name,pos,target,lens=23,ortho=None):
    data=bpy.data.cameras.new(name)
    data.lens=lens
    data.clip_start=.035
    if ortho:
        data.type='ORTHO'
        data.ortho_scale=ortho
    obj=bpy.data.objects.new(name,data)
    local_presentation.objects.link(obj)
    obj.location=pos
    obj.rotation_euler=(Vector(target)-obj.location).to_track_quat('-Z','Y').to_euler()
    return obj


views={'cutaway':cam('Furnished / complete cutaway',(11,-13,12),(0,0,.9),ortho=11.8),
       'living':cam('Furnished / living towards windows',(-2.3,-2.60,1.55),(1.5,1.95,1.16),23),
       'entry':cam('Furnished / daylight towards entry',(2.79,2.7,1.57),(-.8,-1.62,1.04),22),
       'kitchen':cam('Furnished / kitchenette detail',(-1.58,-2.65,1.58),(-3.38,-.36,1.18),22),
       'paper':cam('Furnished / torn newsprint detail',(.55,1.36,1.72),(1.27,3.065,1.64),32)}
scene.camera=views['living']
bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'studio_apartment_furnished.blend'))
(OUT/'assembly_manifest.json').write_text(json.dumps({'room_source':'Models/Architecture/StudioApartment/Source/studio_apartment.blend','linked_assets':linked,'views':list(views),'render_samples':args.samples,'render_device':scene.cycles.device,'physics':'Standalone linked art preview; no gameplay integration'},indent=2)+'\n')
for key in args.views.split(','):
    if key not in views:
        raise ValueError('Unknown assembly view: '+key)
    scene.camera=views[key]
    scene.render.resolution_y=round(args.width*(.78 if key=='cutaway' else 2/3))
    if key=='cutaway':
        room_instance.hide_render=True
        scene.collection.children.link(local_arch)
        hidden=[]
        for o in local_arch.objects:
            if (any(w in o.name.lower() for w in ['south entry','east exterior','east window','side window','entrance','ceiling','recessed light','ventilation','baseboard / east','baseboard / south'])
                or o.name=='Grime / East damp corner'):
                o.hide_render=True
                hidden.append(o)
        bpy.data.objects['Presentation dust volume (not exported)'].hide_render=True
    scene.render.filepath=str(RENDERS/(key+'.png'))
    print('FURNISHED RENDER',key,flush=True)
    bpy.ops.render.render(write_still=True)
    if key=='cutaway':
        for o in hidden:
            o.hide_render=False
        scene.collection.children.unlink(local_arch)
        room_instance.hide_render=False
        bpy.data.objects['Presentation dust volume (not exported)'].hide_render=False
print('FURNISHED COMPLETE',flush=True)
