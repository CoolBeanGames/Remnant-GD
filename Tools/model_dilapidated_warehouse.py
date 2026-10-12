"""Metre-scale warehouse shell; loose machines live in independent Blender files."""
import argparse
import math
import random
import sys
from pathlib import Path
import bpy
from mathutils import Vector
sys.path.insert(0,str(Path(__file__).resolve().parent))
import warehouse_common as w

p=argparse.ArgumentParser();p.add_argument('--samples',type=int,default=128)
p.add_argument('--width',type=int,default=1800);p.add_argument('--views',default='all');p.add_argument('--no-render',action='store_true')
args=p.parse_args(sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else [])
ROOM=w.ROOT/'Models/Architecture/DilapidatedWarehouse'
ASSEMBLY=w.ROOT/'Models/Interiors/DilapidatedWarehouse'
rng=random.Random(20261011)
bpy.ops.wm.read_factory_settings(use_empty=True)
scene=w.configure(args.samples,args.width,round(args.width*2/3))
w.asset=w.collection('ARCHITECTURE | dilapidated warehouse')
concrete=w.material('concrete');brick=w.material('brick');rust=w.material('rust');steel=w.material('steel')
green=w.material('paint_green');yellow=w.material('paint_yellow');cream=w.material('paint_cream');plaster=w.material('plaster')
dark=w.plain('Warehouse / cavities',(.016,.018,.015),.95)
glass=w.plain('Warehouse / dirty broken glazing',(.31,.36,.30),.16)
bs=glass.node_tree.nodes.get('Principled BSDF');bs.inputs['Transmission Weight'].default_value=.75
bs.inputs['IOR'].default_value=1.45;bs.inputs['Alpha'].default_value=.23;glass.surface_render_method='DITHERED'
window_records=[]
office_glass=w.plain('Warehouse / office glazing',(.70,.74,.69),.065)
obs=office_glass.node_tree.nodes.get('Principled BSDF')
obs.inputs['Transmission Weight'].default_value=.95;obs.inputs['IOR'].default_value=1.45
obs.inputs['Alpha'].default_value=.24;office_glass.surface_render_method='DITHERED'


def ibeam(name,a,b,depth=.36,width=.25):
    a,b=Vector(a),Vector(b);direction=b-a
    # Three separate rolled profiles, merged locally into one reusable mesh.
    objects=[]
    for x,dx,dy in [(-width/2+.014,.028,depth), (width/2-.014,.028,depth),(0,width-.045,.028)]:
        o=w.box(name,(0,0,0),(dx,dy,direction.length),rust,.006)
        o.location=(a+b)/2+direction.to_track_quat('Z','Y')@Vector((x,0,0))
        o.rotation_euler=direction.to_track_quat('Z','Y').to_euler();objects.append(o)
    bpy.ops.object.select_all(action='DESELECT')
    for o in objects:o.select_set(True)
    bpy.context.view_layer.objects.active=objects[0];bpy.ops.object.join();objects[0].name=name
    return objects[0]


def window(side,ycentre,index):
    x=side*11.99
    w.box('Window sill',(x,ycentre,3.55),(.34,2.68,.13),concrete)
    w.box('Window lintel',(x,ycentre,6.6),(.32,2.70,.16),concrete)
    for j in range(5):w.box('Rusted window mullion',(x,ycentre-1.30+j*.65,5.10),(.10,.055,3.0),rust,.005)
    for j in range(4):w.box('Rusted window transom',(x,ycentre,3.61+j*.99),(.10,2.67,.055),rust,.005)
    for row in range(3):
        for col in range(4):
            yc=ycentre-1.3+(col+.5)*.65;zc=3.61+(row+.5)*.99
            roll=rng.random();key=f'{side}_{index}_{row}_{col}'
            if roll<.24:
                window_records.append({'name':key,'state':'missing','centre':[x,yc,zc]})
                continue
            ya,yb=yc-.297,yc+.297;za,zb=zc-.469,zc+.469
            if roll<.63:
                # Only perimeter shards remain; the centre is genuinely empty.
                verts=[(x,ya,za),(x,yb,za),(x,ya+.18,za+.20),
                       (x,ya,zb),(x,yb,zb),(x,yb-.19,zb-.24),
                       (x,ya,za),(x,ya,zb),(x,ya+.11,zc+.04)]
                o=w.mesh('Jagged glass / '+key,verts,[(0,1,2),(3,4,5),(6,7,8)],glass)
                o.visible_shadow=False
                window_records.append({'name':key,'state':'broken','centre':[x,yc,zc]})
            else:
                o=w.box('Surviving glass / '+key,(x,yc,zc),(.007,.597,.938),glass,0)
                o.visible_shadow=False
                window_records.append({'name':key,'state':'intact','centre':[x,yc,zc]})


def railing(name,a,b):
    a,b=Vector(a),Vector(b);span=(b-a).length
    for height in (.50,1.03):w.beam(name+' horizontal',a+Vector((0,0,height)),b+Vector((0,0,height)),.045,yellow)
    for i in range(math.ceil(span/1.5)+1):
        t=i/math.ceil(span/1.5);p=a.lerp(b,t)
        w.beam(name+' post',p,p+Vector((0,0,1.04)),.055,rust)
    w.beam(name+' toe board',a+Vector((0,0,.09)),b+Vector((0,0,.09)),.12,rust,height=.035)


def roof_panel(name,x0,x1,y0,y1):
    nx=math.ceil((x1-x0)*12)
    verts=[]
    for y in (y0,y1):
        for i in range(nx+1):
            x=x0+(x1-x0)*i/nx
            z=11.1-abs(x)*.155+math.sin(x*math.tau*3)*.028
            verts.append((x,y,z))
    faces=[(i,i+1,nx+2+i,nx+1+i) for i in range(nx)]
    o=w.mesh(name,verts,faces,rust);w.uv(o,3)
    so=o.modifiers.new('Sheet thickness','SOLIDIFY');so.thickness=.025
    return o


# Jointed floor slabs rather than a seamless grey plane.
for ix in range(6):
    for iy in range(9):
        w.box('Jointed concrete slab',(-10+ix*4,-16+iy*4,-.15),(3.988,3.988,.30),concrete,.008,tile=3)
for side in (-1,1):
    w.box('Lower brick wall',(side*12.14,0,1.77),(.38,36.4,3.54),brick,.02,tile=1.2)
    w.box('Upper brick wall',(side*12.14,0,7.96),(.38,36.4,2.72),brick,.02,tile=1.2)
    for i in range(13):
        y=-18+i*3
        w.box('Brick window pier',(side*12.14,y,5.10),(.38,.36,3.2),brick,.02,tile=1.2)
    for i in range(12):window(side,-16.5+i*3,i)
    # Flaking low paint band, damp rising from the slab and rusty rain streaks.
    for i in range(12):
        y=-16.5+i*3
        w.decal('Brick damp bloom',(side*11.943,y,.90),(2.97,1.80),'damp','wall_x')
        if i%2==0:w.decal('Window rain streak',(side*11.941,y,3.0),(2.2,1.45),'damp','wall_x')
    w.box('Concrete wall base',(side*11.98,0,.17),(.14,36,.34),concrete)

# Solid gable ends with actual pedestrian/loading openings.
for y in (-18.18,18.18):
    opening=5.0 if y>0 else 2.0
    for x in (-1,1):w.box('End masonry pier',(x*(12+opening)/2,y,2.28),(12-opening,.38,4.56),brick,.02,tile=1.2)
    w.box('End masonry header',(0,y,6.91),(24.4,.38,4.70),brick,.02,tile=1.2)
    w.mesh('Brick gable',[(-12.2,y,9.25),(12.2,y,9.25),(0,y,11.14)],[(0,1,2)],brick)
    for x in (-opening,opening):w.box('Loading door jamb',(x,y,2.3),(.14,.46,4.6),rust)
    w.box('Loading door lintel',(0,y,4.62),(opening*2+.1,.49,.16),rust)
    if y>0:
        for z in (3.5,3.64,3.78,3.92,4.06,4.20,4.34,4.48):w.box('Jammed roller shutter',(0,y,z),(9.89,.075,.14),green,.01)
        w.cylinder('Shutter roller',(0,y,4.85),.18,10.2,rust,(1,0,0))
    w.decal('End wall damp',(-7,y-(.194 if y>0 else -.194),1.5),(7,2.9),'damp','wall_y')

# Riveted columns, roof trusses, diagonal bracing and purlins.
for y in (-15,-9,-3,3,9,15):
    for side in (-1,1):
        ibeam('Riveted wall column',(side*11.65,y,.1),(side*11.65,y,9.25),.48,.34)
        w.box('Column base plate',(side*11.65,y,.04),(.8,.75,.08),rust)
        for dx in (-.27,.27):
            for dy in (-.24,.24):w.cylinder('Anchor bolt',(side*11.65+dx,y+dy,.105),.035,.085,steel,vertices=6)
    ibeam('Truss tie beam',(-11.65,y,8.85),(11.65,y,8.85),.34,.25)
    ibeam('West rafter',(-11.65,y,9.22),(0,y,11.02),.35,.24)
    ibeam('East rafter',(0,y,11.02),(11.65,y,9.22),.35,.24)
    for x in (-9,-6,-3,0,3,6,9):
        z=11.02-abs(x)*.154
        w.beam('Truss vertical web',(x,y,8.9),(x,y,z-.07),.105,rust)
        if x<9:w.beam('Truss diagonal web',(x,y,8.9),(x+3,y,11.02-abs(x+3)*.154-.07),.09,rust)
    w.box('Truss riveted gusset',(0,y,10.85),(.6,.055,.45),rust)
for x in (-10,-7,-4,-1,1,4,7,10):
    ibeam('Roof purlin',(x,-18,11.00-abs(x)*.155),(x,18,11.00-abs(x)*.155),.14,.10)
for side in (-1,1):
    for y in (-12,12):
        w.beam('Wall diagonal tie',(side*11.70,y-3,4.0),(side*11.70,y+3,8.8),.055,rust)
roof=[]
roof.append(roof_panel('ROOF | west main',-12.3,-3,-18.3,18.3))
roof.append(roof_panel('ROOF | west crown',-1,0,-18.3,18.3))
roof.append(roof_panel('ROOF | skylight south strip',-3,-1,-18.3,-4))
roof.append(roof_panel('ROOF | skylight north strip',-3,-1,5,18.3))
roof.append(roof_panel('ROOF | east sheet',0,12.3,-18.3,18.3))
for x in (-3,-2,-1):w.beam('Broken rooflight frame',(x,-4,11.1-abs(x)*.155),(x,5,11.1-abs(x)*.155),.055,rust)
for y in (-4,-1,2,5):w.beam('Rooflight crossbar',(-3,y,10.635),(-1,y,10.945),.055,rust)

# Upper catwalk is at 4.2m, reached by 24 x 175mm stair rises.
cat_z=4.2
w.box('Catwalk deck',(9.85,4.0,cat_z-.06),(1.8,14.0,.12),rust)
w.box('Catwalk return',(5.10,9.80,cat_z-.06),(10.0,1.6,.12),rust)
for x in (9.03,10.67):ibeam('Catwalk longitudinal support',(x,-3,4.0),(x,11,4.0),.22,.15)
for y in (-2,2,6,10):
    ibeam('Catwalk wall bracket',(8.99,y,3.97),(11.69,y,3.97),.20,.14)
    w.beam('Catwalk diagonal bracket',(11.69,y,2.83),(9.08,y,3.88),.13,rust)
railing('Catwalk hall edge',(8.95,-3,cat_z),(8.95,8.95,cat_z))
railing('Catwalk outer edge',(10.75,-3,cat_z),(10.75,10.60,cat_z))
railing('Catwalk return rail',(.10,9.0,cat_z),(8.90,9.0,cat_z))
railing('Catwalk return end',(.10,9.0,cat_z),(.10,10.60,cat_z))
railing('Catwalk rear gap guard',(.10,10.60,cat_z),(3.90,10.60,cat_z))
for i in range(24):
    y=-9.815+i*.29;z=(i+1)*.175
    w.box('Steel stair tread',(9.85,y,z-.032),(1.80,.29,.064),rust,.006)
    w.box('Worn safety nosing',(9.85,y-.137,z+.002),(1.74,.027,.015),yellow,.002)
for x in (8.95,10.75):
    w.beam('Stair stringer',(x,-9.98,.02),(x,-3.02,4.12),.23,rust,height=.075)
    w.beam('Stair handrail',(x,-9.98,1.08),(x,-3.02,5.24),.055,yellow)
    for i in range(0,24,4):
        y=-9.815+i*.29;z=(i+1)*.175
        w.beam('Stair baluster',(x,y,z),(x,y,z+1.05),.045,rust)

# Elevated production office: supported slab, solid rear walls, glazed front/west.
w.box('Office mezzanine slab',(7.4,13.65,4.08),(7.0,6.1,.24),concrete)
for x in (4.20,10.6):
    for y in (10.90,16.35):
        ibeam('Mezzanine support column',(x,y,.04),(x,y,4.02),.31,.25)
        w.box('Mezzanine base',(x,y,.03),(.6,.6,.06),rust)
    ibeam('Mezzanine frame',(x,10.65,3.95),(x,16.65,3.95),.30,.22)
for y in (10.80,16.5):ibeam('Mezzanine cross beam',(4.0,y,3.94),(10.85,y,3.94),.28,.22)
w.box('Office back wall',(7.4,16.64,5.72),(7.0,.15,3.03),plaster,.005)
w.box('Office east wall',(10.84,13.65,5.72),(.15,6.12,3.03),plaster,.005)
w.box('Office ceiling',(7.4,13.65,7.22),(7.1,6.2,.12),plaster)
for x in (4.00,):
    w.box('Office west spandrel',(x,13.65,4.80),(.11,6.0,1.18),green)
    w.box('Office west head',(x,13.65,7.0),(.11,6.0,.40),green)
    for y in (10.65,12.15,13.65,15.15,16.65):w.box('Office west mullion',(x,y,6.05),(.12,.08,1.95),cream)
    for y in (11.4,12.9,14.4,15.9):
        o=w.box('Office west glazing',(x,y,6.08),(.009,1.40,1.78),office_glass,0);o.visible_shadow=False
for x0,x1 in ((3.95,8.93),(10.17,10.87)):
    x=(x0+x1)/2;span=x1-x0
    w.box('Office front spandrel',(x,10.65,4.80),(span,.11,1.18),green)
    w.box('Office front header',(x,10.65,7.0),(span,.11,.4),green)
    count=math.ceil(span/1.3)
    for i in range(count+1):w.box('Office front mullion',(x0+span*i/count,10.65,6.05),(.055,.11,1.95),cream)
    for i in range(count):
        xx=x0+span*(i+.5)/count
        o=w.box('Office front glazing',(xx,10.65,6.05),(span/count-.065,.009,1.82),office_glass,0);o.visible_shadow=False
for x in (8.93,10.17):w.box('Office open doorway jamb',(x,10.65,5.33),(.06,.15,2.25),cream)
w.box('Office door lintel',(9.55,10.65,6.62),(1.30,.15,.3),cream)
w.label('Production office lettering','PRODUCTION OFFICE',(6.50,10.571,6.94),.24,cream)
w.decal('Office rear damp',(7.45,16.552,4.88),(5.7,1.20),'damp','wall_y')

# Fixed services: disconnected pipework, drains, dead pendant fixtures and signs.
for side in (-1,1):
    w.pipe('Rusting service main',[(side*11.5,-17.9,3.1),(side*11.5,15,3.1),(side*11.5,15,1.0)],.085,rust)
    for y in (-15,-9,-3,3,9,15):w.cylinder('Service flange',(side*11.5,y,3.1),.14,.06,rust,(0,1,0))
for y in (-10,0,10):
    for x in (-5,5):
        w.pipe('Pendant cable',[(x,y,10.1-abs(x)*.155),(x,y,7.55)],.009,dark)
        bpy.ops.mesh.primitive_cone_add(vertices=24,radius1=.42,radius2=.15,depth=.27,location=(x,y,7.49))
        o=bpy.context.object;o.name='Dead industrial pendant';w.put(o,green);w.uv(o)
        w.cylinder('Pendant dark glass',(x,y,7.35),.34,.013,cream)
for y in (-13,-5,3,11):
    w.box('Drain frame',(-9.7,y,.006),(1.1,.42,.012),rust,0)
    for x in range(12):w.box('Drain slot',(-10.17+x*.085,y,.014),(.036,.34,.013),dark,0)
for x,y,sz in [(-7,-8,(5,4)),(-4,6,(4,6)),(2,-2,(5,3)),(5,13,(3,4)),(-10,15,(3,5)),(10,-14,(3,4))]:
    w.decal('Localized concrete oil stain',(x,y,.005),sz,'oil')
for i in range(24):
    w.decal('Settled dirt patch',(rng.uniform(-11,11),rng.uniform(-17,17),.007),(rng.uniform(1,4),rng.uniform(1,5)),'dust')
for y in range(-15,16,3):
    w.box('Faded aisle dashed marking',(3.1,y,.006),(.07,1.2,.011),yellow,0)
w.label('Wall bay marking','BAY 04',(-11.936,-10.2,2.3),.48,cream,(math.pi/2,0,math.pi/2))
w.box('Danger sign backing',(-11.932,3.4,2.15),(.02,1.48,.82),yellow)
w.label('Danger sign','KEEP CLEAR',(-11.913,3.4,2.08),.16,dark,(math.pi/2,0,math.pi/2))

rig=w.collection('PRESENTATION | warehouse daylight and cameras')
# Outdoor paving and airborne dust belong to the presentation, not the export.
architecture_collection=w.asset
w.asset=rig
w.box('Presentation exterior paving',(0,0,-.39),(160,160,.17),concrete,0,tile=4)
volume=bpy.data.materials.new('Presentation / subtle airborne dust');volume.use_nodes=True
volume.node_tree.nodes.clear()
out=volume.node_tree.nodes.new('ShaderNodeOutputMaterial')
v=volume.node_tree.nodes.new('ShaderNodeVolumePrincipled');v.inputs['Density'].default_value=.002
v.inputs['Color'].default_value=(.67,.62,.53,1);v.inputs['Anisotropy'].default_value=.1
volume.node_tree.links.new(v.outputs['Volume'],out.inputs['Volume'])
w.box('Presentation dust volume',(0,0,5.4),(23.7,35.7,10.8),volume,0)
w.asset=architecture_collection
scene.world=bpy.data.worlds.new('Overcast warm industrial daylight');scene.world.use_nodes=True
scene.world.node_tree.nodes['Background'].inputs['Color'].default_value=(.47,.55,.65,1)
scene.world.node_tree.nodes['Background'].inputs['Strength'].default_value=.32
sun_data=bpy.data.lights.new('Afternoon sun through broken glazing','SUN');sun_data.energy=2.0;sun_data.angle=math.radians(3)
sun=bpy.data.objects.new('Afternoon sun through broken glazing',sun_data);rig.objects.link(sun)
sun.rotation_euler=Vector((.72,.35,-.43)).to_track_quat('-Z','Y').to_euler()
for y in (-12,-3,6,15):
    light=w.area(rig,'Window daylight',(-13.4,y,5.2),(-1,y+1,2.3),1500,2.1,(.82,.89,1))
    light.visible_glossy=False
light=w.area(rig,'North loading door daylight',(0,20,3.0),(0,8,1.5),1900,3,(1,.86,.67))
light.visible_glossy=False
w.area(rig,'Office window bounce',(6.5,12.2,6.5),(7.2,14.2,4.7),110,2,(1,.92,.75))
for light in rig.objects:
    if light.type=='LIGHT' and light.data.type=='AREA':
        light.visible_camera=False;light.visible_glossy=False;light.visible_transmission=False
views={
    'production_floor':w.camera(rig,'01 | production hall',(-7.7,-14.8,1.85),(2.7,5.8,4.0),23),
    'catwalk':w.camera(rig,'02 | upper catwalk',(9.9,-2.0,5.85),(6.5,12.0,5.2),24),
    'office':w.camera(rig,'03 | production office',(9.5,15.2,5.8),(5.3,11.0,5.2),24),
    'machines':w.camera(rig,'04 | broken machinery',(-9,-.6,2.2),(-3.4,6.0,1.8),28),
    'exterior':w.camera(rig,'05 | warehouse exterior',(-33,-37,17),(0,0,4.5),35),
    'overview':w.camera(rig,'06 | architectural cutaway',(-32,-41,32),(0,0,3),ortho=48),
}
scene.camera=views['production_floor']
info=w.save_export(ROOM,'dilapidated_warehouse',{'layout':'24 x 36 m hall; wall eaves 9.25 m, ridge 11.1 m; office and catwalk floor 4.2 m',
    'window_panes':window_records,'stairs':{'count':24,'rise_m':.175,'tread_m':.29,'width_m':1.8,'top_m':4.2},
    'office_floor':{'z_m':4.2,'bounds_xy':[3.9,10.9,10.6,16.7]},'views':list(views)})

# Save the assembly path before linking the shell (Blender forbids linking itself).
ASSEMBLY.mkdir(parents=True,exist_ok=True);(ASSEMBLY/'.gdignore').write_text('')
assembly_path=ASSEMBLY/'warehouse_assembly.blend'
bpy.ops.wm.save_as_mainfile(filepath=str(assembly_path))
architecture=w.asset
scene.collection.children.unlink(architecture)
instances=w.collection('ASSEMBLY | linked architecture and independent props')
placements=[]


def link_asset(path,collection_name,name,pos=(0,0,0),angle=0):
    with bpy.data.libraries.load(str(path),link=True) as (available,linked):
        assert collection_name in available.collections,(path,collection_name)
        linked.collections=[collection_name]
    library_collection=linked.collections[0]
    o=bpy.data.objects.new(name,None);o.instance_type='COLLECTION';o.instance_collection=library_collection
    instances.objects.link(o);o.location=pos;o.rotation_euler.z=math.radians(angle)
    placements.append({'name':name,'source':Path(path).relative_to(w.ROOT).as_posix(),'collection':collection_name,'position_m':list(pos),'rotation_z_degrees':angle})
    return o


room_instance=link_asset(ROOM/'Source/dilapidated_warehouse.blend',architecture.name,'Warehouse shell')
machine_root=w.ROOT/'Models/Interiors/WarehouseMachinery'
for key,stem,positions in [
    ('HydraulicPress','hydraulic_press',[((-5,4,0),0),((-5,10,0),0)]),
    ('IndustrialLathe','industrial_lathe',[((-5,-4,0),-8),((0,5,0),0)]),
    ('AirCompressor','air_compressor',[((4,3,0),-20)]),
    ('ControlCabinet','control_cabinet',[((7,13,0),-10),((-10,6,0),90)]),
    ('OfficeDesk','office_desk',[((6.4,13.5,4.2),180)]),
    ('DebrisKit','debris_kit',[((-9,-10,0),30),((1,12,0),-24),((5,-8,0),65),((-8,14,0),8)])]:
    for j,(pos,angle) in enumerate(positions):
        link_asset(machine_root/key/'Source'/f'{stem}.blend','ASSET | '+key,key+f' {j+1}',pos,angle)
furniture=w.ROOT/'Models/Interiors/StudioFurniture'
for key,stem,pos,angle in [('Chair','chair',(6.4,14.85,4.2),0),('LandlinePhone','landline_phone',(5.95,13.72,4.995),-12),
                           ('PileOfMail','pile_of_mail',(6.40,13.21,4.997),16),('TrashCan','trash_can',(4.5,15.8,4.2),0)]:
    link_asset(furniture/key/'Source'/f'{stem}.blend','ASSET | '+key,key,pos,angle)
for library in bpy.data.libraries:
    library.filepath=bpy.path.relpath(library.filepath,start=str(ASSEMBLY))
scene.camera=views['production_floor'];w.pack()
bpy.ops.wm.save_as_mainfile(filepath=str(assembly_path))
(ASSEMBLY/'assembly_manifest.json').write_text(__import__('json').dumps({'native':assembly_path.relative_to(w.ROOT).as_posix(),
    'architecture_export':info['export'],'instances':placements,'views':list(views),'render_samples':args.samples,
    'complete_model_saved':True,'render_device':scene.cycles.device,'limits':'Art assets only. No level insertion or gameplay collision. Blender daylight is presentation lighting.'},indent=2)+'\n')

# Temporary cutaway swaps the linked complete shell for local visible architecture.
# The saved editable assembly always contains the entire roof and all walls.
chosen=list(views) if args.views=='all' else args.views.split(',')
w.RENDERS.mkdir(parents=True,exist_ok=True);(w.RENDERS/'.gdignore').write_text('')
if not args.no_render:
    for name in chosen:
        scene.camera=views[name];scene.render.filepath=str(w.RENDERS/f'{name}.png')
        changed=[]
        if name=='overview':
            room_instance.hide_render=True;scene.collection.children.link(architecture)
            for o in architecture.objects:
                bounds=[o.matrix_world@Vector(c) for c in o.bound_box] if o.type=='MESH' else [o.location]
                centre=sum(bounds,Vector())/len(bounds)
                ceiling=o.name.startswith(('ROOF |','Truss ','West rafter','East rafter','Roof purlin','Broken rooflight','Rooflight crossbar','Office ceiling'))
                perimeter=(centre.x < -11.1 or centre.y < -17.0) and not o.name.startswith('Jointed concrete slab')
                if ceiling or perimeter:
                    if not o.hide_render:o.hide_render=True;changed.append(o)
        print('WAREHOUSE ROOM RENDER',name,flush=True);bpy.ops.render.render(write_still=True)
        if name=='overview':
            for o in changed:o.hide_render=False
            scene.collection.children.unlink(architecture);room_instance.hide_render=False
print('WAREHOUSE ASSEMBLY COMPLETE',flush=True)
