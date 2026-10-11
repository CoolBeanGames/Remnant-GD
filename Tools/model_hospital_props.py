"""Independent hospital props, their portable exports and three reviewed studio views."""
import argparse
import math
import random
import sys
from pathlib import Path
import bpy
sys.path.insert(0,str(Path(__file__).resolve().parent))
import warehouse_common as w
w.TEX=w.ROOT/'Models/Architecture/DilapidatedHospital/Textures'
w.RENDERS=w.ROOT/'Reports/Hospital';w.ASSET_LABEL='Hospital'
p=argparse.ArgumentParser();p.add_argument('--assets',default='all')
p.add_argument('--samples',type=int,default=80);p.add_argument('--width',type=int,default=1000)
p.add_argument('--no-render',action='store_true')
args=p.parse_args(sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else [])


def ring(name,pos,major,minor,mat,rotation=(math.pi/2,0,0)):
    bpy.ops.mesh.primitive_torus_add(major_segments=32,minor_segments=8,location=pos,major_radius=major,minor_radius=minor)
    o=bpy.context.object;o.name=name;o.rotation_euler=rotation
    for f in o.data.polygons:f.use_smooth=True
    return w.put(o,mat)


def caster(pos,r=.075):
    x,y,z=pos
    w.cylinder('Swivel stem',(x,y,z+r+.07),.018,.14,steel)
    for dx in (-.035,.035):w.box('Rusted caster fork',(x+dx,y,z+.04),(.02,.055,.13),rust,.005)
    w.cylinder('Caster tyre',(x,y,z),r,.062,rubber,(1,0,0))
    w.cylinder('Caster hub',(x-.039,y,z),r*.43,.016,steel,(1,0,0))


def bed():
    for x in (-.45,.45):
        for y in (-.89,.89):
            caster((x,y,.09),.09)
            w.pipe('Bed leg',[(x,y,.24),(x,y,.52),(x*.88,y,.61)],.032,enamel)
    w.box('Bed spring frame',(0,0,.59),(1.0,2.03,.095),rust)
    for i in range(11):w.box('Exposed mattress support',(0,-.90+i*.18,.65),(.92,.045,.022),steel,.003)
    w.box('Sagging aged mattress',(0,-.02,.745),(.93,1.92,.19),fabric,.055)
    w.box('Stained folded sheet',(0,-.18,.85),(.91,1.17,.025),fabric,.012)
    w.box('Flattened pillow',(.08,.67,.90),(.60,.38,.10),fabric,.045).rotation_euler.z=.1
    for y,height in [(-1.04,1.00),(1.04,1.25)]:
        w.pipe('Bed head and foot frame',[(-.49,y,.55),(-.49,y,height),(-.38,y,height+.09),(.38,y,height+.09),(.49,y,height),(.49,y,.55)],.031,enamel)
        for x in (-.30,-.10,.10,.30):w.beam('Bed end upright',(x,y,.69),(x,y,height+.06),.021,enamel)
    for x in (-.51,.51):
        ys=(-.6,.6) if x>0 else (-.6,.3)
        for y in ys:w.cylinder('Safety rail post',(x,y,.94),.019,.40,rust)
        w.pipe('Bed safety rail',[(x,ys[0],1.11),(x,ys[-1],1.11)],.022,enamel)
        w.pipe('Lower safety rail',[(x,ys[0],.96),(x,ys[-1],.96)],.019,enamel)
    w.pipe('Broken bed rail',[(-.52,.3,1.10),(-.68,.45,.98),(-.73,.49,.84)],.02,rust)
    w.decal('Mattress dried blood',(0,-.06,.869),(.57,.77),'blood_pool')
    w.label('Bed inventory label','WARD C / 06',(0,-1.075,.80),.045,dark)


def cabinet():
    for x in (-.26,.26):
        for y in (-.23,.23):w.box('Cabinet feet',(x,y,.075),(.04,.04,.15),rust)
    w.box('Cabinet carcass',(0,.05,.45),(.62,.53,.64),cream)
    w.box('Worn bedside laminate top',(0,0,.79),(.69,.62,.07),cream,.025)
    w.box('Dark drawer cavity',(0,-.222,.63),(.55,.019,.19),dark,0)
    w.box('Half open bedside drawer',(0,-.36,.625),(.52,.30,.11),sage)
    w.box('Drawer face',(0,-.525,.645),(.57,.03,.16),cream)
    w.box('Drawer pull',(0,-.56,.65),(.15,.032,.027),steel)
    w.box('Lower cabinet door',(0,-.227,.32),(.55,.035,.36),sage)
    w.box('Cabinet latch',(.21,-.26,.33),(.025,.033,.085),steel)
    w.cylinder('Empty water cup',(.15,.12,.87),.043,.11,cream)
    w.box('Patient card',(-.12,.05,.832),(.23,.16,.006),paper,0).rotation_euler.z=.18
    w.decal('Bedside ring stain',(-.14,-.10,.832),(.27,.23),'damp')


def wheelchair():
    # Large rear wheels have actual tyre/rim/spoke geometry, not solid discs.
    for side in (-1,1):
        x=side*.35;y=.24;z=.33
        ring('Wheelchair rear tyre',(x,y,z),.29,.032,rubber,(0,math.pi/2,0))
        ring('Wheelchair push rim',(x+side*.049,y,z),.255,.012,steel,(0,math.pi/2,0))
        w.cylinder('Wheelchair axle hub',(x,y,z),.045,.11,rust,(1,0,0))
        for i in range(16):
            a=i*math.tau/16
            w.beam('Wheel spoke',(x,y,z),(x,y+math.cos(a)*.27,z+math.sin(a)*.27),.004,steel)
        caster((side*.25,-.37,.065),.065)
        w.pipe('Wheelchair tubular frame',[(side*.25,-.38,.15),(side*.25,-.22,.48),(side*.25,.34,.48),(side*.25,.38,.97)],.021,enamel)
        w.pipe('Padded push handle',[(side*.25,.38,.95),(side*.25,.54,.96)],.027,rubber)
        w.pipe('Arm rest support',[(side*.29,-.20,.47),(side*.29,-.20,.66),(side*.29,.29,.66),(side*.29,.29,.48)],.017,rust)
        w.box('Worn arm pad',(side*.29,.04,.68),(.065,.52,.039),rubber)
        w.pipe('Foot support',[(side*.23,-.30,.36),(side*.23,-.55,.13),(side*.23,-.68,.13)],.02,steel)
        w.box('Wheelchair footplate',(side*.20,-.64,.12),(.20,.18,.022),rust)
    w.box('Sagged seat upholstery',(0,.02,.46),(.51,.55,.045),rubber,.015)
    w.box('Back upholstery',(0,.335,.74),(.50,.035,.40),sage,.018)
    w.box('Split upholstery seam',(0,.312,.77),(.019,.003,.29),dark,0)
    w.label('Wheelchair asset plate','HOSPITAL PROPERTY',(0,.357,.69),.027,paper,(math.pi/2,0,math.pi))


def ivstand():
    for i in range(5):
        a=i*math.tau/5;end=(math.cos(a)*.29,math.sin(a)*.29,.15)
        w.beam('IV star base arm',(0,0,.19),end,.034,steel)
        caster((end[0],end[1],.052),.052)
    w.cylinder('IV lower tube',(0,0,.71),.024,1.06,enamel)
    w.cylinder('IV telescopic pole',(0,0,1.62),.015,.96,steel)
    w.cylinder('Pole adjustment collar',(0,0,1.16),.036,.09,rust)
    w.box('Pole tightening knob',(.05,0,1.15),(.06,.042,.042),rubber)
    for s in (-1,1):w.pipe('IV suspension hook',[(0,0,2.07),(s*.15,0,2.07),(s*.19,0,2.0),(s*.17,0,1.96)],.012,steel)
    w.box('Empty collapsed IV bag',(-.17,0,1.78),(.17,.018,.30),paper,.016)
    w.label('IV bag faded label','500 mL',(-.17,-.014,1.80),.021,dark)
    w.pipe('Dangling IV tube',[(-.17,0,1.63),(-.20,-.025,1.39),(-.13,.04,1.05),(-.28,.035,.68),(-.24,-.08,.48)],.004,cream)


def trolley():
    for x in (-.38,.38):
        for y in (-.24,.24):
            caster((x,y,.065),.065)
            w.cylinder('Trolley upright',(x,y,.53),.024,.82,enamel)
    for z in (.28,.62,.98):
        w.box('Instrument shelf',(0,0,z),(.82,.57,.025),steel)
        for y in (-.28,.28):w.box('Instrument shelf lip',(0,y,z+.035),(.81,.022,.067),rust,.004)
        for x in (-.40,.40):w.box('Shelf short lip',(x,0,z+.035),(.02,.54,.067),rust,.004)
    w.pipe('Trolley handle',[(-.40,.30,.81),(-.40,.30,1.12),(.40,.30,1.12),(.40,.30,.81)],.024,enamel)
    w.box('Sterilizer tray',(.12,.04,1.035),(.32,.23,.059),enamel,.025)
    w.box('Instrument tray recess',(.12,.04,1.067),(.28,.19,.008),dark,.01)
    for x in (-.25,-.17):w.cylinder('Discarded metal instrument',(x,-.03,1.025),.005,.21,steel,(0,1,0),vertices=8)
    w.box('Folded stained gauze',(-.20,.03,.65),(.28,.24,.045),fabric)
    w.decal('Dried tray blood',(-.18,-.025,.998),(.30,.29),'blood_pool')


def counter():
    for x in (-1.28,-.43,.43,1.28):
        w.box('Nursing counter cabinet',(x,0,.47),(.79,.67,.91),cream)
        for z in (.28,.58,.82):
            w.box('Counter drawer',(x,-.345,z),(.70,.035,.21),sage)
            w.box('Counter handle',(x,-.38,z),(.15,.027,.022),steel)
    w.box('Counter work surface',(0,0,.965),(3.62,.88,.075),cream,.018)
    w.box('Counter raised front', (0,-.40,1.11),(3.62,.11,.27),sage)
    w.box('Counter writing ledge',(0,-.44,1.26),(3.74,.32,.07),cream)
    # Narrow return keeps the staff access path open behind the main desk.
    w.box('Counter return cabinet',(1.47,.72,.47),(.65,.78,.91),cream)
    w.box('Counter return top',(1.47,.72,.965),(.76,.84,.075),cream)
    w.box('Open records rack',(-1.15,.14,1.19),(.73,.29,.40),sage)
    for x in (-1.39,-1.16,-.93):
        w.box('Chart pigeonhole opening',(x,-.013,1.20),(.19,.012,.29),dark,0)
        for i in range(4):w.box('Old patient chart',(x,-.03,1.09+i*.008),(.15,.20,.006),paper,0)
    w.box('Closed ward register',(.13,.10,1.03),(.36,.29,.042),sage)
    w.label('Ward register title','WARD REGISTER',(.13,.10,1.055),.031,paper,(0,0,0))
    w.label('Nursing counter front text','NURSES STATION',(0,-.462,1.095),.12,paper)
    w.decal('Counter dried hand smear',(.84,-.44,1.301),(.61,.27),'blood_smear')


def door():
    for x in (-.70,.70):w.box('Door frame jamb',(x,0,1.135),(.09,.14,2.27),sage)
    w.box('Door frame lintel',(0,0,2.245),(1.49,.14,.08),sage)
    pivot=bpy.data.objects.new('PIVOT | hospital door hinge',None);w.asset.objects.link(pivot)
    pivot.location=(-.635,0,0);pivot.rotation_euler.z=math.radians(78)
    for x in (.075,1.195):w.box('Door window side',(x,0,1.055),(.15,.055,2.11),cream,parent=pivot)
    for z,dz in [(.55,1.10),(1.96,.30)]:w.box('Hospital door panel',(.635,0,z),(1.12,.055,dz),cream,parent=pivot)
    w.box('Missing door window bottom frame',(.635,0,1.12),(1.10,.075,.045),rust,parent=pivot)
    w.box('Missing door window upper frame',(.635,0,1.80),(1.10,.075,.045),rust,parent=pivot)
    w.box('Door kickplate',(.635,-.032,.20),(1.0,.015,.32),steel,parent=pivot)
    w.box('Door push plate',(1.13,-.043,1.07),(.10,.02,.32),steel,parent=pivot)
    w.pipe('Door pull handle',[(1.13,.06,.98),(1.13,.09,.98),(1.13,.09,1.19),(1.13,.06,1.19)],.015,rust,parent=pivot)
    for z in (.28,1.09,1.93):w.cylinder('Door barrel hinge',(-.65,0,z),.024,.13,rust)
    w.label('Door warning','WARD C',(.64,-.034,.77),.09,sage,parent=pivot)


def bench():
    for x in (-.92,.92):
        for y in (-.20,.20):w.box('Waiting bench foot',(x,y,.225),(.055,.055,.45),rust)
        w.pipe('Bench arm frame',[(x,-.27,.34),(x,-.27,.64),(x,.24,.64),(x,.24,.34)],.022,enamel)
    for i in range(3):
        x=-.65+i*.65
        w.box('Waiting seat',(x,0,.45),(.60,.48,.075),sage,.035)
        w.box('Waiting back',(x,.24,.71),(.60,.065,.43),sage,.035).rotation_euler.x=-.12
        w.box('Cracked seat seam',(x+.12,-.06,.49),(.010,.29,.006),dark,0).rotation_euler.z=.26
    for y in (-.18,.16):w.box('Bench crossmember',(0,y,.37),(2.07,.04,.045),rust)


BUILDERS={'HospitalBed':bed,'BedsideCabinet':cabinet,'Wheelchair':wheelchair,'IVStand':ivstand,
          'MedicalTrolley':trolley,'NursingCounter':counter,'HospitalDoor':door,'WaitingBench':bench}

for key in BUILDERS if args.assets=='all' else args.assets.split(','):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    scene=w.configure(args.samples,args.width,args.width)
    w.asset=w.collection('ASSET | '+key)
    enamel=w.material('enamel');rust=w.material('rust');steel=w.material('steel');sage=w.material('sage')
    cream=w.material('cream');rubber=w.material('rubber');fabric=w.material('fabric')
    dark=w.plain('Hospital / recess',(.015,.020,.017),.94)
    paper=w.plain('Hospital / yellowed chart paper',(.67,.64,.48),.96)
    BUILDERS[key]();views=w.prop_rig()
    for obj in bpy.data.objects:
        if obj.type=='LIGHT' and obj.data.type=='AREA':obj.visible_camera=False;obj.visible_glossy=False;obj.visible_transmission=False
    stem={'IVStand':'iv_stand'}.get(key,''.join('_'+c.lower() if c.isupper() else c for c in key).lstrip('_'))
    extra={'views':list(views),'render_samples':args.samples,'render_device':scene.cycles.device}
    if key=='HospitalDoor':extra['moving_part']={'pivot':'PIVOT | hospital door hinge','default_open_degrees':78,'clear_width_m':1.30}
    w.save_export(w.ROOT/'Models/Interiors/HospitalProps'/key,stem,extra)
    out=w.RENDERS/key;out.mkdir(parents=True,exist_ok=True);(w.RENDERS/'.gdignore').write_text('')
    if not args.no_render:
        for name,cam in views.items():
            scene.camera=cam;scene.render.filepath=str(out/f'{name}.png')
            print('HOSPITAL PROP RENDER',key,name,flush=True);bpy.ops.render.render(write_still=True)
print('HOSPITAL PROPS COMPLETE',flush=True)
