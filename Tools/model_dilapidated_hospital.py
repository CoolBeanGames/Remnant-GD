"""A connected, human-scale hospital wing; medical furniture remains linked assets."""
import argparse
import json
import math
import random
import sys
from pathlib import Path
import bpy
from mathutils import Vector
sys.path.insert(0,str(Path(__file__).resolve().parent))
import warehouse_common as w
w.TEX=w.ROOT/'Models/Architecture/DilapidatedHospital/Textures'
w.RENDERS=w.ROOT/'Reports/Hospital';w.ASSET_LABEL='Hospital'
ROOM=w.ROOT/'Models/Architecture/DilapidatedHospital'
ASSEMBLY=w.ROOT/'Models/Interiors/DilapidatedHospital'
p=argparse.ArgumentParser();p.add_argument('--samples',type=int,default=128)
p.add_argument('--width',type=int,default=1800);p.add_argument('--views',default='all')
p.add_argument('--no-render',action='store_true');args=p.parse_args(sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else [])
rng=random.Random(202610111)
bpy.ops.wm.read_factory_settings(use_empty=True)
scene=w.configure(args.samples,args.width,round(args.width*2/3));scene.view_settings.exposure=.85
w.asset=w.collection('ARCHITECTURE | dilapidated hospital')
plaster=w.material('plaster');sage=w.material('sage');cream=w.material('cream');tile=w.material('tile')
vinyl=w.material('vinyl');concrete=w.material('concrete');rust=w.material('rust');steel=w.material('steel')
dark=w.plain('Hospital / dark recess',(.012,.019,.015),.95)
paper=w.plain('Hospital / faded sign letters',(.66,.66,.52),.96)
red=w.plain('Hospital / faded warning red',(.22,.033,.025),.86)
glass=w.plain('Hospital / remaining dirty glazing',(.26,.34,.30),.17)
bs=glass.node_tree.nodes.get('Principled BSDF');bs.inputs['Transmission Weight'].default_value=.70
bs.inputs['IOR'].default_value=1.45;bs.inputs['Alpha'].default_value=.70;glass.surface_render_method='DITHERED'
glass_edge=w.plain('Hospital / chipped glass edges',(.43,.51,.46),.25)
windows=[];doors=[];room_records=[]


def wall_segment(name,axis,fixed,start,end,bottom=0,top=3.35):
    if end-start<.01 or top-bottom<.01:return
    for za,zb,mat in [(max(bottom,0),min(top,1.3),sage),(max(bottom,1.3),top,plaster)]:
        if zb-za<.01:continue
        pos=(fixed,(start+end)/2,(za+zb)/2) if axis=='x' else ((start+end)/2,fixed,(za+zb)/2)
        dims=(.18,end-start,zb-za) if axis=='x' else (end-start,.18,zb-za)
        w.box(name,pos,dims,mat,.006,tile=1.35)
    if bottom==0:
        pos=(fixed,(start+end)/2,.075) if axis=='x' else ((start+end)/2,fixed,.075)
        dims=(.21,end-start,.15) if axis=='x' else (end-start,.21,.15)
        w.box('Skirting | '+name,pos,dims,concrete,.008)


def wall_with_holes(name,axis,fixed,start,end,holes):
    cursor=start
    for centre,width,bottom,top in sorted(holes):
        a,b=centre-width/2,centre+width/2
        wall_segment(name,axis,fixed,cursor,a)
        if bottom>0:wall_segment(name+' sill',axis,fixed,a,b,0,bottom)
        wall_segment(name+' header',axis,fixed,a,b,top,3.35)
        cursor=b
    wall_segment(name,axis,fixed,cursor,end)


def window(side,yc,index):
    x=side*9.0
    for y in (yc-1.4,yc+1.4):w.box('Window frame jamb',(x,y,1.90),(.19,.085,1.84),cream)
    for z in (1.0,2.8):w.box('Window frame horizontal',(x,yc,z),(.20,2.87,.085),cream)
    w.box('Window sill',(x-side*.08,yc,.985),(.39,3.02,.09),concrete)
    for i in (1,2):w.box('Window central mullion',(x,yc-1.4+i*.933,1.90),(.13,.042,1.74),rust)
    w.box('Window middle transom',(x,yc,1.90),(.13,2.8,.047),rust)
    for row in range(2):
        for col in range(3):
            y=yc-1.4+(col+.5)*.933;z=1.0+(row+.5)*.9;key=f'{side}_{index}_{row}_{col}'
            roll=rng.random();state='missing' if roll<.28 else 'broken' if roll<.80 else 'intact'
            if state=='intact':
                o=w.box('GLASS | intact '+key,(x,y,z),(.007,.874,.836),glass,0);o.visible_shadow=False
            elif state=='broken':
                ya,yb=y-.436,y+.436;za,zb=z-.418,z+.418
                verts=[(x,ya,za),(x,yb,za),(x,ya+.29,za+.22),(x,ya,zb),(x,yb,zb),(x,yb-.26,zb-.27),
                       (x,yb,za),(x,yb,zb),(x,yb-.14,z+.02)]
                o=w.mesh('GLASS | jagged '+key,verts,[(0,1,2),(3,4,5),(6,7,8)],glass);o.visible_shadow=False
                o.data.materials.append(glass_edge)
                edge=o.modifiers.new('Glass thickness and exposed chipped edge','SOLIDIFY');edge.thickness=.008;edge.material_offset_rim=1
            windows.append({'name':key,'state':state,'centre':[x,y,z]})
    w.decal('Window leakage',(x-side*.106,yc,.56),(2.77,1.05),'damp','wall_x')


# Single accessible floor datum: all rooms and passages meet at Z=0.
w.box('Foundation',(0,0,-.17),(18.25,26.25,.28),concrete,.01,tile=2)
w.box('Hall north south',(0,0,-.009),(3.22,26,.018),tile,0)
w.box('Hall east west',(0,0,-.008),(18,3.22,.016),tile,0)
bands=[('South',-13,-5.8,-9.4),('Middle',-5.8,-1.7,-3.75),('NorthInner',1.7,7.3,4.5),('NorthEnd',7.3,13,10.15)]
for side in (-1,1):
    for name,ya,yb,yc in bands:
        title=('Treatment' if side<0 else 'Nursing') if name=='Middle' else 'Ward'
        number=(1 if side<0 else 2)+{'South':0,'NorthInner':2,'NorthEnd':4}.get(name,0)
        ident=title if title!='Ward' else f'Ward {number:02d}'
        room_records.append({'name':ident,'bounds_xy':[-8.9,-1.8,ya+.1,yb-.1] if side<0 else [1.8,8.9,ya+.1,yb-.1],
                             'door_centre':[-1.7 if side<0 else 1.7,yc,0],'floor_z':0})
        w.box('Room floor | '+ident,(side*5.35,(ya+yb)/2,-.006),(7.1,yb-ya-.02,.012),vinyl,0)
    # Side walls include actual punched openings and broken glazing.
    centres=[-9.4,-3.75,0,4.5,10.15]
    wall_with_holes('OUTER | side wall','x',side*9,-13,13,[(y,2.8,1.0,2.8) for y in centres])
    for i,y in enumerate(centres):window(side,y,i)
    holes=[]
    for name,ya,yb,yc in bands:
        if side>0 and name=='Middle':holes.append((yc,yb-ya,0,3.35));continue
        holes.append((yc,1.55,0,2.31));doors.append({'side':side,'centre':[side*1.7,yc,0],'width':1.55,'height':2.31})
    wall_with_holes('INNER | corridor partitions','x',side*1.7,-13,13,holes+[(0,3.4,0,3.35)])
    for y in (-5.8,-1.7,1.7,7.3):
        if side>0 and y==-1.7:
            wall_with_holes('DIVIDER | staff access','y',y,1.7,9,[(5.8,1.45,0,2.31)])
        else:wall_segment('DIVIDER | ward partitions','y',y,-9,-1.7) if side<0 else wall_segment('DIVIDER | ward partitions','y',y,1.7,9)
for y in (-13,13):wall_with_holes('OUTER | end wall','y',y,-9,9,[(0,2.6,0,2.31)])

# Ceiling panels, open service gaps, rusted rails and dangling wiring.
missing={(2,2),(5,3),(3,5),(4,7),(1,8),(6,6)}
for ix in range(8):
    for iy in range(10):
        x=-7.875+ix*2.25;y=-11.7+iy*2.6
        if (ix,iy) not in missing:w.box('CEILING | stained acoustic panel',(x,y,3.30),(2.23,2.58,.08),plaster,.003,tile=1.5)
        else:
            w.pipe('CEILING | hanging electrical wire',[(x-.30,y,3.5),(x-.30,y,3.0),(x-.10,y+.13,2.60)],.006,dark)
            for dx in (-.30,.3):w.box('CEILING | exposed service joist',(x+dx,y,3.53),(.045,2.63,.06),rust,.003)
for ix in range(9):w.box('CEILING | suspension rail',(-9+ix*2.25,0,3.35),(.025,26,.025),rust,.003)
for iy in range(11):w.box('CEILING | cross rail',(0,-13+iy*2.6,3.35),(18,.025,.025),rust,.003)
for x in (-.72,.73):w.pipe('CEILING | corridor service pipe',[(x,-13,3.13),(x,13,3.13)],.038,rust)
for y in (-10,-4,3.5,9.5):
    w.box('CEILING | dead fluorescent housing',(0,y,3.15),(.64,1.32,.10),cream)
    for x in (-.17,.17):w.cylinder('CEILING | fluorescent tube',(x,y,3.09),.018,1.18,paper,(0,1,0))
for y in (-11.8,-7,-.5,6.1,11.8):
    for side in (-1,1):
        # The handrail is interrupted before every doorway.
        if any(abs(y-d['centre'][1])<1.02 and d['side']==side for d in doors):continue
        w.box('Corridor impact rail',(side*1.592,y,.93),(.06,1.22,.12),cream)

# Stains are localized rather than a uniform dirty overlay.
for side in (-1,1):
    for y in (-11.3,-6.5,2.1,6.4,12.2):
        w.decal('Wall rising damp',(side*1.595,y,.55),(1.27,1.07),'damp','wall_x')
for x,y,size in [(-.10,-8,(1.6,2.4)),(-5.8,-8.9,(2.6,2.4)),(.33,3.3,(1.2,2.3)),(-4.8,4.8,(2.6,2.1)),(5.5,10.2,(2.4,2.7))]:
    w.decal('Dried blood pool',(x,y,.012),size,'blood_pool')
for x,y in [(.1,-5.5),(-.25,-2),(.12,1.8),(.13,6.1)]:
    w.decal('Faded bloody shoe trail',(x,y,.013),(.95,3.0),'blood_steps')
for side,y,z in [(-1,-7.2,1.04),(1,5.8,1.0),(-1,-2.25,1.4)]:
    w.decal('Dried hand drag on corridor wall',(side*1.596,y,z),(1.05,1.6),'blood_smear','wall_x')
w.decal('Patient room wall blood',(-8.894,2.2,1.25),(1.50,1.7),'blood_smear','wall_x')
for i in range(30):
    w.decal('Settled floor grime',(rng.uniform(-8.6,8.6),rng.uniform(-12.5,12.5),.010),
            (rng.uniform(.7,2.7),rng.uniform(.7,2.7)),'dust')
# Fallen ceiling fragments stay beside walls and outside tested circulation routes.
for i in range(14):
    x=(-1 if i%2 else 1)*rng.uniform(7.5,8.7);y=rng.uniform(-12.4,12.4)
    o=w.box('DAMAGE | fallen acoustic tile',(x,y,.018+rng.uniform(0,.06)),(.34,.49,.018),plaster,.002)
    o.rotation_euler=(rng.uniform(-.08,.08),rng.uniform(-.12,.12),rng.uniform(-3,3))

for record in room_records:
    if record['name']=='Nursing':continue
    x,y,z=record['door_centre'];side=1 if x>0 else -1
    w.box('Room number sign',(x-side*.109,y,2.58),(.024,1.20,.27),sage)
    rotation=(math.pi/2,0,-math.pi/2 if side>0 else math.pi/2)
    w.label('Room designation',record['name'].upper(),(x-side*.124,y,2.51),.14,paper,rotation)
w.box('Nurse station overhead sign',(1.58,-3.70,2.54),(.035,2.65,.43),sage)
w.label('Nurse station lettering','NURSES STATION',(1.552,-3.70,2.43),.21,paper,(math.pi/2,0,-math.pi/2))
w.box('Cross corridor wayfinding',(0,1.605,2.51),(2.37,.031,.42),sage)
w.label('Cross corridor directions','WARD C  /  TREATMENT',(0,1.580,2.42),.14,paper)
w.box('Exit sign backing',(0,12.88,2.60),(.82,.035,.31),sage)
w.label('Exit sign lettering','EXIT',(0,12.85,2.52),.22,paper)

architecture=w.asset;rig=w.collection('PRESENTATION | hospital daylight and cameras')
w.asset=rig
w.box('Presentation exterior ground',(0,0,-.34),(120,120,.16),concrete,0,tile=4)
w.asset=architecture
scene.world=bpy.data.worlds.new('Cold overcast hospital daylight');scene.world.use_nodes=True
scene.world.node_tree.nodes['Background'].inputs['Color'].default_value=(.47,.57,.64,1)
scene.world.node_tree.nodes['Background'].inputs['Strength'].default_value=.45
data=bpy.data.lights.new('Low afternoon sun','SUN');data.energy=2.2;data.angle=math.radians(4)
sun=bpy.data.objects.new('Low afternoon sun',data);rig.objects.link(sun)
sun.rotation_euler=Vector((.75,.35,-.34)).to_track_quat('-Z','Y').to_euler()
for side in (-1,1):
    for y in (-9.4,-3.75,0,4.5,10.15):
        w.area(rig,'Overcast window daylight',(side*9.9,y,2.03),(side*4,y+.1,1.2),310,1.35,(.73,.84,1))
for y in (-10,-4,3.5,9.5):
    w.area(rig,'Faint surviving hallway tube',(0,y,3.025),(0,y,0),65,.70,(.69,.79,.61))
w.area(rig,'Nursing station desk bounce',(4,-3.7,2.6),(3.3,-3.7,.6),60,1.8,(.77,.83,.70))
for o in rig.objects:
    if o.type=='LIGHT' and o.data.type=='AREA':o.visible_camera=False;o.visible_glossy=False;o.visible_transmission=False
views={
    'hallway':w.camera(rig,'01 | long corridor',(.63,-12.35,1.68),(-.1,4.0,1.52),24),
    'nursing_station':w.camera(rig,'02 | nursing station',(-1.1,-.9,1.70),(4.4,-3.6,1.20),24),
    'cross_hall':w.camera(rig,'03 | intersecting hallways',(-7.8,-.45,1.68),(2.2,.2,1.55),24),
    'patient_room':w.camera(rig,'04 | south patient ward',(-2.3,-6.30,1.70),(-6.7,-9.4,1.06),22),
    'treatment':w.camera(rig,'05 | treatment room',(-2.5,-2.2,1.72),(-6.3,-4.2,1.06),25),
    'north_ward':w.camera(rig,'06 | north patient ward',(2.8,8.05,1.67),(6.4,11.4,1.18),25),
    'windows':w.camera(rig,'07 | broken windows and stains',(-5.6,2.25,1.75),(-8.9,3.55,1.75),28),
    'overview':w.camera(rig,'08 | connected wing cutaway',(-28,-34,34),(0,0,0),ortho=37),
}
scene.camera=views['hallway']
info=w.save_export(ROOM,'dilapidated_hospital',{'layout':'18 x 26m; 3.35m ceiling; 3.2m intersecting halls; six wards, treatment room and open nursing station',
    'rooms':room_records,'door_openings':doors,'window_panes':windows,'views':list(views),
    'circulation':'All floor surfaces share Z=0; seven 1.55m architectural door openings, 1.45m staff entry behind counter, two 2.6m end exits',
    'staff_entry':{'centre':[5.8,-1.7,0],'width_m':1.45,'height_m':2.31},
    'blood':'Localized dried pools, wall smears and faded shoe prints; no bodies'})
ASSEMBLY.mkdir(parents=True,exist_ok=True);(ASSEMBLY/'.gdignore').write_text('')
assembly_path=ASSEMBLY/'hospital_assembly.blend'
bpy.ops.wm.save_as_mainfile(filepath=str(assembly_path));scene.collection.children.unlink(architecture)
instances=w.collection('ASSEMBLY | linked hospital architecture and props');placements=[]


def link(path,col,name,pos=(0,0,0),angle=0):
    existing=next((c for c in bpy.data.collections if c.name==col and c.library and
                   Path(bpy.path.abspath(c.library.filepath)).resolve()==Path(path).resolve()),None)
    if existing is None:
        with bpy.data.libraries.load(str(path),link=True) as (available,data):
            assert col in available.collections,(path,col);data.collections=[col]
        existing=data.collections[0]
    o=bpy.data.objects.new(name,None);o.instance_type='COLLECTION';o.instance_collection=existing
    instances.objects.link(o);o.location=pos;o.rotation_euler.z=math.radians(angle)
    placements.append({'name':name,'source':Path(path).relative_to(w.ROOT).as_posix(),'collection':col,
                       'position_m':list(pos),'rotation_z_degrees':angle})
    return o


shell=link(ROOM/'Source/dilapidated_hospital.blend',architecture.name,'Hospital shell')
PROP=w.ROOT/'Models/Interiors/HospitalProps'
stems={'HospitalBed':'hospital_bed','BedsideCabinet':'bedside_cabinet','Wheelchair':'wheelchair','IVStand':'iv_stand',
       'MedicalTrolley':'medical_trolley','NursingCounter':'nursing_counter','HospitalDoor':'hospital_door','WaitingBench':'waiting_bench'}
def prop(key,name,pos,angle=0):return link(PROP/key/'Source'/f'{stems[key]}.blend','ASSET | '+key,name,pos,angle)
for record in room_records:
    key=record['name'];side=1 if record['door_centre'][0]>0 else -1
    yc=record['door_centre'][1]
    if key.startswith('Ward'):
        for j,dy in enumerate((-1.45,1.45)):
            prop('HospitalBed',key+f' bed {j+1}',(side*6.7,yc+dy,0),90 if side<0 else -90)
            prop('BedsideCabinet',key+f' cabinet {j+1}',(side*8.2,yc+dy+.8,0),90 if side<0 else -90)
        prop('IVStand',key+' IV stand',(side*5.4,yc+.45,0),12)
    elif key=='Treatment':
        prop('HospitalBed','Treatment examination bed',(-6.7,yc-.05,0),90)
        prop('MedicalTrolley','Treatment trolley',(-4.7,yc-1.05,0),-16)
        prop('IVStand','Treatment IV stand',(-5.65,yc+.9,0),0)
    elif key=='Nursing':
        prop('NursingCounter','Nursing station counter',(3.5,yc,0),-90)
        prop('MedicalTrolley','Nursing supplies trolley',(7.5,-2.5,0),20)
        prop('Wheelchair','Stored nursing wheelchair',(7.35,-4.65,0),-40)
for i,d in enumerate(doors):prop('HospitalDoor',f'Ward door {i+1}',tuple(d['centre']),90 if d['side']<0 else -90)
prop('Wheelchair','Abandoned hall wheelchair',(-.84,-6.8,0),-15)
prop('WaitingBench','Cross hall waiting bench',(4.5,-1.22,0),0)
prop('WaitingBench','West waiting bench',(-5.4,1.22,0),180)
FURN=w.ROOT/'Models/Interiors/StudioFurniture'
for key,stem,pos,angle in [('LandlinePhone','landline_phone',(3.65,-3.15,1.01),-90),
                          ('PileOfMail','pile_of_mail',(3.60,-4.27,1.01),-80),('TrashCan','trash_can',(8.1,-3.6,0),0)]:
    link(FURN/key/'Source'/f'{stem}.blend','ASSET | '+key,'Nursing '+key,pos,angle)
for library in bpy.data.libraries:library.filepath=bpy.path.relpath(library.filepath,start=str(ASSEMBLY))
w.pack();scene.camera=views['hallway'];bpy.ops.wm.save_as_mainfile(filepath=str(assembly_path))
(ASSEMBLY/'assembly_manifest.json').write_text(json.dumps({'native':assembly_path.relative_to(w.ROOT).as_posix(),
    'architecture_export':info['export'],'instances':placements,'views':list(views),'render_samples':args.samples,
    'render_device':scene.cycles.device,'complete_model_saved':True,'limits':'Standalone linked art; no gameplay level insertion, collision or engine lighting.'},indent=2)+'\n')
w.RENDERS.mkdir(parents=True,exist_ok=True);(w.RENDERS/'.gdignore').write_text('')
chosen=list(views) if args.views=='all' else args.views.split(',')
if not args.no_render:
    for key in chosen:
        scene.camera=views[key];scene.render.filepath=str(w.RENDERS/f'{key}.png');changed=[]
        if key=='overview':
            shell.hide_render=True;scene.collection.children.link(architecture)
            for o in architecture.objects:
                # Complete high walls remain behind the plan; front walls are cut only for this view.
                if o.name.startswith('CEILING |') or (o.name.startswith(('OUTER |','Skirting | OUTER')) and (o.location.x<-8.8 or o.location.y<-12.8)):
                    o.hide_render=True;changed.append(o)
        print('HOSPITAL ROOM RENDER',key,flush=True);bpy.ops.render.render(write_still=True)
        if key=='overview':
            for o in changed:o.hide_render=False
            scene.collection.children.unlink(architecture);shell.hide_render=False
print('HOSPITAL ASSEMBLY COMPLETE',len(placements),'relative instances',flush=True)
