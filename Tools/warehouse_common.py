"""Blender geometry, packing and presentation helpers for separate industrial assets."""
import json
import math
from pathlib import Path
import bpy
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[1]
TEX = ROOT / 'Models/Architecture/DilapidatedWarehouse/Textures'
RENDERS = ROOT / 'Reports/Warehouse'
asset = None
ASSET_LABEL = 'Warehouse'


def configure(samples=96, width=1600, height=1067):
    bpy.context.preferences.filepaths.save_version=0
    s=bpy.context.scene
    s.unit_settings.system='METRIC'
    s.unit_settings.scale_length=1
    s.render.engine='CYCLES'
    s.cycles.samples=samples
    s.cycles.use_denoising=True
    s.cycles.adaptive_threshold=.025
    s.cycles.max_bounces=9
    s.cycles.transparent_max_bounces=12
    s.view_settings.view_transform='AgX'
    s.view_settings.look='AgX - Medium High Contrast'
    s.view_settings.exposure=.65
    s.render.resolution_x=width
    s.render.resolution_y=height
    s.render.resolution_percentage=100
    s.render.image_settings.file_format='PNG'
    s.render.image_settings.color_mode='RGB'
    prefs=bpy.context.preferences.addons['cycles'].preferences
    try:
        prefs.compute_device_type='OPTIX'
        prefs.refresh_devices()
        gpu=[d for d in prefs.devices if d.type=='OPTIX']
        for d in prefs.devices: d.use=d in gpu
        s.cycles.device='GPU' if gpu else 'CPU'
    except Exception:
        s.cycles.device='CPU'
    return s


def collection(name):
    c=bpy.data.collections.new(name)
    bpy.context.scene.collection.children.link(c)
    return c


def material(key):
    name=ASSET_LABEL+' / '+key
    if name in bpy.data.materials: return bpy.data.materials[name]
    m=bpy.data.materials.new(name)
    m.use_nodes=True
    bs=m.node_tree.nodes.get('Principled BSDF')
    for suffix, target in [('albedo','Base Color'),('normal','Normal'),('roughness','Roughness'),('metallic','Metallic')]:
        path=TEX/f'{key}_{suffix}.png'
        if not path.exists(): continue
        n=m.node_tree.nodes.new('ShaderNodeTexImage')
        n.image=bpy.data.images.load(str(path),check_existing=True)
        if suffix!='albedo': n.image.colorspace_settings.name='Non-Color'
        if suffix=='normal':
            normal=m.node_tree.nodes.new('ShaderNodeNormalMap')
            normal.inputs['Strength'].default_value=.35
            m.node_tree.links.new(n.outputs['Color'],normal.inputs['Color'])
            m.node_tree.links.new(normal.outputs['Normal'],bs.inputs[target])
        else: m.node_tree.links.new(n.outputs['Color'],bs.inputs[target])
    return m


def plain(name,colour,rough=.6,metal=0):
    if name in bpy.data.materials: return bpy.data.materials[name]
    m=bpy.data.materials.new(name)
    m.use_nodes=True
    bs=m.node_tree.nodes.get('Principled BSDF')
    bs.inputs['Base Color'].default_value=(*colour,1)
    bs.inputs['Roughness'].default_value=rough
    bs.inputs['Metallic'].default_value=metal
    return m


def put(o,mat=None,parent=None):
    for c in list(o.users_collection): c.objects.unlink(o)
    asset.objects.link(o)
    if mat: o.data.materials.append(mat)
    if parent: o.parent=parent
    return o


def uv(o,tile=1):
    if o.type!='MESH': return
    layer=o.data.uv_layers.active or o.data.uv_layers.new(name='Metre scale planar UV')
    offset=(sum(map(ord,o.name))%431/137, sum(map(ord,o.name))%233/83)
    for poly in o.data.polygons:
        axis=max(range(3),key=lambda i:abs(poly.normal[i]))
        a,b=((0,1) if axis==2 else (0,2) if axis==1 else (1,2))
        for li in poly.loop_indices:
            p=o.data.vertices[o.data.loops[li].vertex_index].co
            layer.data[li].uv=(p[a]/tile+offset[0],p[b]/tile+offset[1])


def box(name,pos,dims,mat=None,bevel=.015,parent=None,tile=1):
    bpy.ops.mesh.primitive_cube_add(size=1,location=pos)
    o=bpy.context.object
    o.name=name
    o.scale=dims
    bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
    uv(o,tile)
    if bevel:
        m=o.modifiers.new('Worn softened edges','BEVEL')
        m.width=bevel
        m.segments=2
        o.modifiers.new('Corner normals','WEIGHTED_NORMAL')
    return put(o,mat,parent)


def cylinder(name,pos,radius,depth,mat=None,direction=None,parent=None,vertices=24):
    bpy.ops.mesh.primitive_cylinder_add(vertices=vertices,radius=radius,depth=depth,location=pos)
    o=bpy.context.object
    o.name=name
    if direction: o.rotation_euler=Vector(direction).to_track_quat('Z','Y').to_euler()
    bevel=o.modifiers.new('Machined edges','BEVEL');bevel.width=min(.01,radius*.08);bevel.segments=2
    o.modifiers.new('Corner normals','WEIGHTED_NORMAL')
    return put(o,mat,parent)


def sphere(name,pos,scale,mat=None,parent=None):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=24,ring_count=12,location=pos)
    o=bpy.context.object;o.name=name;o.scale=scale
    bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
    for p in o.data.polygons:p.use_smooth=True
    return put(o,mat,parent)


def beam(name,a,b,width,mat,height=None):
    a,b=Vector(a),Vector(b)
    o=box(name,(a+b)/2,(width,height or width,(b-a).length),mat,min(.01,width*.07))
    o.rotation_euler=(b-a).to_track_quat('Z','Y').to_euler()
    return o


def pipe(name,points,radius,mat=None,parent=None):
    data=bpy.data.curves.new(name,'CURVE');data.dimensions='3D';data.bevel_depth=radius;data.bevel_resolution=2
    sp=data.splines.new('POLY');sp.points.add(len(points)-1)
    for p,co in zip(sp.points,points):p.co=(*co,1)
    o=bpy.data.objects.new(name,data);asset.objects.link(o)
    bpy.context.view_layer.objects.active=o;o.select_set(True)
    bpy.ops.object.convert(target='MESH');o.select_set(False)
    uv(o)
    if mat:o.data.materials.append(mat)
    if parent:o.parent=parent
    return o


def label(name,text,pos,size,mat,rotation=(math.pi/2,0,0),parent=None):
    data=bpy.data.curves.new(name,'FONT');data.body=text;data.size=size;data.align_x='CENTER';data.extrude=.0008
    o=bpy.data.objects.new(name,data);asset.objects.link(o);o.location=pos;o.rotation_euler=rotation
    bpy.ops.object.select_all(action='DESELECT');o.select_set(True);bpy.context.view_layer.objects.active=o
    bpy.ops.object.convert(target='MESH');uv(o)
    o.data.materials.append(mat)
    if parent:o.parent=parent
    return o


def decal(name,pos,size,kind='damp',axis='floor'):
    key=ASSET_LABEL+' decal / '+kind
    m=bpy.data.materials.get(key)
    if not m:
        m=bpy.data.materials.new(key);m.use_nodes=True;m.surface_render_method='DITHERED'
        bs=m.node_tree.nodes.get('Principled BSDF');bs.inputs['Roughness'].default_value=.97
        t=m.node_tree.nodes.new('ShaderNodeTexImage');t.image=bpy.data.images.load(str(TEX/f'{kind}_decal.png'),check_existing=True)
        m.node_tree.links.new(t.outputs['Color'],bs.inputs['Base Color']);m.node_tree.links.new(t.outputs['Alpha'],bs.inputs['Alpha'])
    w,h=size
    vertices=[(-w/2,-h/2,0),(w/2,-h/2,0),(w/2,h/2,0),(-w/2,h/2,0)]
    if axis=='wall_x':vertices=[(0,a,b) for a,b,c in vertices]
    if axis=='wall_y':vertices=[(a,0,b) for a,b,c in vertices]
    mesh=bpy.data.meshes.new(name);mesh.from_pydata(vertices,[],[(0,1,2,3)]);mesh.update()
    layer=mesh.uv_layers.new()
    for i,co in enumerate([(0,0),(1,0),(1,1),(0,1)]):layer.data[i].uv=co
    o=bpy.data.objects.new(name,mesh);asset.objects.link(o);o.location=pos;mesh.materials.append(m)
    return o


def mesh(name,verts,faces,mat):
    data=bpy.data.meshes.new(name);data.from_pydata(verts,[],faces);data.update()
    o=bpy.data.objects.new(name,data);asset.objects.link(o);data.materials.append(mat);uv(o)
    return o


def camera(rig,name,pos,target,lens=28,ortho=None):
    data=bpy.data.cameras.new(name);data.lens=lens;data.clip_start=.02;data.clip_end=500
    if ortho:data.type='ORTHO';data.ortho_scale=ortho
    o=bpy.data.objects.new(name,data);rig.objects.link(o);o.location=pos
    o.rotation_euler=(Vector(target)-o.location).to_track_quat('-Z','Y').to_euler()
    return o


def area(rig,name,pos,target,power,size,colour=(1,.91,.74)):
    d=bpy.data.lights.new(name,'AREA');d.energy=power;d.shape='DISK';d.size=size;d.color=colour
    o=bpy.data.objects.new(name,d);rig.objects.link(o);o.location=pos
    o.rotation_euler=(Vector(target)-o.location).to_track_quat('-Z','Y').to_euler()
    return o


def pack():
    for im in list(bpy.data.images):
        if im.users==0:bpy.data.images.remove(im)
        elif im.source=='FILE':im.pack()


def save_export(folder,stem,extra=None):
    bpy.context.preferences.filepaths.save_version=0
    folder=Path(folder);source=folder/'Source';source.mkdir(parents=True,exist_ok=True);(source/'.gdignore').write_text('')
    pack();bpy.context.view_layer.update()
    points=[o.matrix_world@Vector(p) for o in asset.objects if o.type=='MESH' for p in o.bound_box]
    lo=Vector([min(p[i] for p in points) for i in range(3)])
    hi=Vector([max(p[i] for p in points) for i in range(3)])
    bpy.ops.wm.save_as_mainfile(filepath=str(source/f'{stem}.blend'))
    bpy.ops.object.select_all(action='DESELECT')
    for o in asset.objects:o.select_set(True)
    bpy.ops.export_scene.gltf(filepath=str(folder/f'{stem}.glb'),export_format='GLB',use_selection=True,
        export_apply=True,export_animations=False,export_cameras=False,export_lights=False,export_extras=True,export_yup=True)
    triangles=0
    for o in asset.objects:
        if o.type!='MESH':continue
        ev=o.evaluated_get(bpy.context.evaluated_depsgraph_get());me=ev.to_mesh();me.calc_loop_triangles()
        triangles+=len(me.loop_triangles);ev.to_mesh_clear()
    info={'key':stem,'native':(source/f'{stem}.blend').relative_to(ROOT).as_posix(),'export':(folder/f'{stem}.glb').relative_to(ROOT).as_posix(),
          'collection':asset.name,'mesh_objects':sum(o.type=='MESH' for o in asset.objects),'triangles':triangles,
          'dimensions_blender_m':[round(v,4) for v in hi-lo],'bounds_min':[round(v,4) for v in lo],'bounds_max':[round(v,4) for v in hi],
          'packed_images':sum(bool(im.packed_file) for im in bpy.data.images),'blender':bpy.app.version_string,
          'origin':'Floor contact at Z=0, local centre; Z up, front faces -Y','physics':'Standalone art; no gameplay placement or collision shapes',
          'textures':'Original portable PBR image maps; packed native images and embedded GLB channels'}
    info.update(extra or {})
    (folder/'asset_manifest.json').write_text(json.dumps(info,indent=2)+'\n')
    print(ASSET_LABEL.upper()+' EXPORT',stem,info['mesh_objects'],triangles,flush=True)
    return info


def prop_rig():
    s=bpy.context.scene
    rig=collection('PRESENTATION | prop studio')
    s.world=bpy.data.worlds.new('Neutral industrial studio');s.world.use_nodes=True
    s.world.node_tree.nodes['Background'].inputs['Strength'].default_value=.25
    ground=box('Studio ground',(0,0,-.025),(200,200,.04),plain('Studio backdrop',(.18,.18,.16),.9),0)
    asset.objects.unlink(ground);rig.objects.link(ground)
    bpy.context.view_layer.update()
    pts=[o.matrix_world@Vector(p) for o in asset.objects if o.type=='MESH' for p in o.bound_box]
    lo=Vector([min(p[i] for p in pts) for i in range(3)]);hi=Vector([max(p[i] for p in pts) for i in range(3)])
    center=(lo+hi)/2;span=max(hi-lo)
    for name,pos,power,size in [('Key',(-3,-4,6),750,4),('Fill',(4,-1,3),400,4),('Rim',(2,4,5),850,3)]:
        area(rig,name,center+Vector(pos),center,power,size)
    views={name:camera(rig,name,center+Vector(direction)*span,center,ortho=span*1.45)
           for name,direction in [('front',(1.6,-2,1)),('rear',(-1.7,2,1.1)),('detail',(-1.1,-1.5,1.8))]}
    s.camera=views['front']
    return views
