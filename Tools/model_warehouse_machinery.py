"""Author six independent textured warehouse props and three views of each."""
import argparse
import math
import random
import sys
from pathlib import Path
import bpy
sys.path.insert(0,str(Path(__file__).resolve().parent))
import warehouse_common as w

ROOT=w.ROOT
p=argparse.ArgumentParser()
p.add_argument('--assets',default='all')
p.add_argument('--samples',type=int,default=80)
p.add_argument('--width',type=int,default=1000)
p.add_argument('--no-render',action='store_true')
args=p.parse_args(sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else [])


def bolt(name,pos,r=.025,direction=None):
    return w.cylinder(name,pos,r,.035,rust,direction,vertices=6)


def motor(pos,scale=1):
    x,y,z=pos
    w.cylinder('Motor casing',(x,y,z),.22*scale,.54*scale,green,(1,0,0))
    for i in range(9):
        w.cylinder('Motor cooling fins',(x+(-.22+i*.055)*scale,y,z),.25*scale,.018*scale,rust,(1,0,0))
    w.box('Motor junction box',(x,y,z+.26*scale),(.24*scale,.21*scale,.13*scale),green)
    w.cylinder('Broken motor shaft',(x+.36*scale,y,z),.045*scale,.21*scale,steel,(1,0,0))
    for dx in (-.2,.2):w.box('Motor feet',(x+dx*scale,y,z-.23*scale),(.09*scale,.44*scale,.07*scale),rust)


def press():
    w.box('Press foundation',(0,0,.16),(2.9,1.8,.32),rust,.04)
    for x in (-1.07,1.07):
        w.box('Heavy cast upright',(x,0,1.82),(.38,.72,3.3),green,.06)
        w.box('Upright inner slide',(x*.8,-.38,1.92),(.12,.08,2.6),steel)
        for z in (.36,.75,3.25):bolt('Upright fixing',(x,-.38,z),.055,(0,-1,0))
    w.box('Top crosshead',(0,0,3.4),(2.68,.94,.56),green,.045)
    w.cylinder('Hydraulic cylinder',(0,0,2.99),.36,.59,rust)
    w.cylinder('Exposed ram',(0,0,2.54),.15,.42,steel)
    w.box('Ram platen',(0,0,2.29),(1.73,.83,.20),rust,.025)
    w.box('Press bed',(0,-.10,1.13),(2.39,1.04,.32),green,.02)
    for x in (-.68,0,.68):w.box('Press bed groove',(x,-.10,1.295),(.075,.94,.02),dark,0)
    w.box('Crushed die block',(.18,-.04,1.45),(.66,.62,.30),steel)
    w.box('Broken yellow guard',(-1.4,-.44,1.34),(.09,.1,1.15),yellow).rotation_euler.y=.28
    w.box('Guard hanging fragment',(-1.25,-.52,.68),(.35,.07,.08),yellow).rotation_euler.y=.4
    w.box('Hydraulic reservoir',(.62,.76,.59),(.82,.63,.85),green)
    motor((.62,.75,1.26),.7)
    w.pipe('Oil pressure hose',[(-.4,.40,3.49),(-.8,.58,3.64),(-1.33,.59,2.5),(-1.31,.75,1.1),(.6,.75,1.0)],.025,rubber)
    w.pipe('Severed hydraulic hose',[(.35,.45,3.2),(.85,.58,3.32),(1.3,.7,2.95),(1.39,.75,2.2)],.03,rubber)
    w.box('Operator control housing',(.98,-.53,1.70),(.46,.21,.52),cream)
    for x,c in [(.87,red),(1.09,dark)]:w.cylinder('Pushbutton',(x,-.65,1.8),.045,.04,c,(0,-1,0))
    w.label('Press designation','PRESS 04',(0,-.486,3.45),.16,cream)
    w.decal('Press oil seep',(0,-.3,.327),(1.5,.9),'oil')


def lathe():
    for x in (-1.4,1.28):
        w.box('Cast lathe pedestal',(x,0,.57),(.79,.89,1.14),green,.065)
        w.box('Pedestal foot',(x,0,.08),(.95,1.02,.16),rust)
        w.box('Access cover',(x,-.46,.56),(.60,.028,.66),green)
        for dx in (-.24,.24):bolt('Pedestal cover screw',(x+dx,-.49,.81),.014,(0,-1,0))
    w.box('Machine bed',(0,0,1.17),(3.8,.70,.20),green)
    for y in (-.24,.22):w.box('Precision slide rail',(0,y,1.31),(3.72,.10,.085),steel,.006)
    w.box('Headstock',(-1.34,.02,1.68),(.80,.64,.76),green,.04)
    w.cylinder('Spindle',(-.87,.03,1.78),.20,.19,steel,(1,0,0))
    w.cylinder('Three jaw chuck',(-.69,.03,1.78),.27,.18,rust,(1,0,0))
    for i in range(3):
        a=i*math.tau/3
        o=w.box('Chuck jaw',(-.577,.03+math.cos(a)*.155,1.78+math.sin(a)*.155),(.06,.14,.075),steel)
        o.rotation_euler.x=a
    w.cylinder('Abandoned steel stock',(-.09,.03,1.78),.057,.92,rust,(1,0,0))
    w.box('Tailstock',(1.19,.03,1.62),(.48,.51,.47),green)
    w.cylinder('Tailstock quill',(.87,.03,1.78),.06,.28,steel,(1,0,0))
    w.box('Carriage',(.38,-.09,1.39),(.70,.61,.18),rust)
    w.box('Cross slide',(.38,-.1,1.54),(.40,.58,.13),steel)
    w.box('Tool post',(.28,-.08,1.68),(.14,.14,.20),dark)
    w.box('Broken cutting tool',(.12,-.08,1.79),(.32,.055,.045),steel)
    for x in (-1.46,.32,1.58):
        w.cylinder('Handwheel rim',(x,-.56,1.42),.16,.05,rust,(0,-1,0))
        w.cylinder('Handwheel hub',(x,-.601,1.42),.11,.05,dark,(0,-1,0))
        w.cylinder('Handwheel grip',(x+.1,-.67,1.47),.027,.12,rubber,(0,-1,0))
    w.cylinder('Feed lead screw',(0,-.39,1.05),.034,3.4,steel,(1,0,0))
    w.box('Bent drip tray',(0,-.03,.93),(3.76,1.07,.055),rust)
    for y in (-.57,.49):w.box('Drip tray lip',(0,y,.98),(3.73,.05,.10),rust)
    motor((-1.37,.46,.73),.75)
    w.label('Lathe plate','M-12',(-1.34,-.315,1.88),.11,cream)
    for i in range(9):
        x=-.48+i*.13
        w.pipe('Metal swarf',[(x,-.17,.99),(x+.03,-.1,1.03),(x+.05,-.05,1.01),(x,-.03,.995)],.007,steel)


def compressor():
    for x in (-.87,.87):w.box('Skid runner',(x,0,.09),(.15,1.46,.18),rust)
    w.box('Skid cross beam',(0,0,.22),(2.14,1.05,.18),green)
    w.cylinder('Pressure vessel',(0,0,.72),.44,1.7,green,(1,0,0))
    for x in (-.85,.85):w.sphere('Dished tank end',(x,0,.72),(.16,.44,.44),rust)
    for x in (-.55,.55):w.box('Vessel mount',(x,0,.40),(.14,.76,.18),rust)
    w.box('Pump deck',(-.1,0,1.18),(1.39,.77,.12),rust)
    motor((.44,.06,1.48),.72)
    for x in (-.44,-.12):
        w.box('Compressor cylinder block',(x,0,1.52),(.26,.28,.54),green)
        for z in (1.32,1.40,1.48,1.56,1.64):w.box('Cooling vane',(x,0,z),(.34,.36,.035),rust,.003)
        w.cylinder('Pump air intake',(x,0,1.86),.10,.18,rust)
    w.cylinder('Exposed drive pulley',(-.45,-.33,1.44),.28,.09,rust,(0,-1,0))
    w.cylinder('Pulley inset',(-.45,-.386,1.44),.21,.021,dark,(0,-1,0))
    w.pipe('Broken drive belt',[(-.70,-.4,1.56),(-.42,-.41,1.77),(.30,-.4,1.63),(.47,-.4,1.38),(.63,-.47,1.01),(.54,-.5,.52)],.024,rubber)
    w.pipe('Pressure line',[(-.35,.21,1.80),(-.35,.48,1.77),(-.77,.48,.83),(-.90,.20,.81)],.026,rust)
    w.cylinder('Pressure gauge stem',(.0,-.2,1.21),.021,.22,rust)
    w.cylinder('Pressure gauge',(.0,-.2,1.36),.088,.05,cream,(0,-1,0))
    w.beam('Gauge stuck needle',(-.045,-.234,1.32),(.034,-.234,1.395),.004,dark)
    w.pipe('Discarded air hose',[(.84,.0,.75),(1.16,-.2,.39),(1.0,-.70,.09),(.47,-.8,.06),(.27,-.6,.07),(.50,-.45,.09),(.97,-.54,.06)],.027,rubber)
    w.label('Compressor tank marking','DO NOT PRESSURIZE',(0,-.444,.70),.09,cream)


def cabinet():
    w.box('Cabinet plinth',(0,0,.11),(1.34,.64,.22),rust)
    w.box('Rear sheet',(0,.25,1.19),(1.28,.07,2.0),green)
    for x in (-.62,.62):w.box('Cabinet side',(x,0,1.19),(.05,.52,2.0),green)
    for z in (.22,2.18):w.box('Cabinet cap',(0,0,z),(1.28,.55,.055),green)
    w.box('Internal mounting plate',(0,.18,1.18),(1.17,.055,1.84),rust)
    for z in (.65,1.18,1.66):
        w.box('DIN rail',(0,.125,z),(1.06,.025,.055),steel)
        for x in (-.37,-.19,-.01,.17,.35):
            w.box('Cracked relay',(x,.07,z+.085),(.13,.15,.19),cream,.006)
            w.box('Relay contact',(x,-.01,z+.12),(.035,.019,.045),dark,.002)
    rng=random.Random(172)
    for i in range(14):
        x=rng.uniform(-.49,.49)
        w.pipe('Loose electrical cable',[(x,.05,1.88),(x+.08,-.06,1.5),(x-.07,-.15,.92),(x+.16,-.20,.43)],.008,red if i%3==0 else rubber)
    hinge=bpy.data.objects.new('PIVOT | cabinet door hinge',None);w.asset.objects.link(hinge)
    hinge.location=(-.64,-.30,.21);hinge.rotation_euler.z=math.radians(-69)
    w.box('Open cabinet door',(.64,0,.98),(1.28,.055,1.96),green,parent=hinge)
    w.box('Door inset',(.64,-.034,1.0),(1.1,.026,1.65),green,parent=hinge)
    w.box('Door latch',(1.13,-.07,1.05),(.08,.07,.25),steel,parent=hinge)
    w.label('Warning on door','DANGER',(.64,-.055,1.39),.15,yellow,parent=hinge)
    w.label('Cabinet index','240 V',(.64,-.055,.51),.11,cream,parent=hinge)
    for z in (.32,1.06,1.92):w.cylinder('Door hinge',(-.64,-.29,z),.033,.14,rust)


def desk():
    w.box('Worn office desktop',(0,0,.755),(1.85,.82,.075),wood,.012)
    for x in (-.77,.77):
        w.box('Desk pedestal',(x,0,.375),(.32,.70,.68),cream)
        for z in (.25,.53):
            w.box('Drawer front',(x,-.363,z),(.28,.035,.24),green)
            w.box('Drawer handle',(x,-.394,z),(.11,.035,.022),steel)
    w.box('Modesty panel',(0,.22,.48),(1.36,.045,.44),green)
    for i in range(3):w.box('Filing tray',(-.50,.13,.825+i*.064),(.36,.25,.025),rust)
    for i in range(5):w.box('Faded paper',(-.51,.13,.85+i*.006),(.32,.23,.005),cream,0)
    w.cylinder('Pencil cup',(.57,.16,.88),.055,.18,green)
    for i in range(4):w.cylinder('Pencil',(.545+i*.015,.16,.99),.003,.21,wood,vertices=8)
    w.box('Closed logbook',(.03,-.06,.82),(.35,.25,.055),green)
    w.label('Logbook lettering','SHIFT LOG',(.03,-.08,.849),.035,cream,(0,0,0))


def debris():
    rng=random.Random(804)
    for y in (-.44,0,.44):w.box('Pallet support',(-.60,y,.11),(1.15,.10,.16),wood)
    for i in range(6):
        o=w.box('Broken pallet plank',(-1.08+i*.19,0,.215),(.14,1.09,.04),wood,.003)
        if i==2:o.rotation_euler.x=.09;o.location.z=.24
    for i in range(5):
        o=w.box('Discarded timber',(.0+rng.uniform(-.45,.35),-.20+rng.uniform(-.3,.3),.03+i*.018),(.95,.085,.035),wood,.002)
        o.rotation_euler.z=rng.uniform(-1.6,1.6)
    w.cylinder('Rusted barrel',(.72,.26,.44),.31,.88,rust)
    for z in (.11,.23,.68,.80):w.cylinder('Barrel rolled seam',(.72,.26,z),.326,.026,rust)
    w.cylinder('Barrel lid',(.72,.26,.894),.297,.024,rust)
    w.cylinder('Barrel bung',(.86,.32,.912),.029,.022,dark)
    for i in range(8):
        x=rng.uniform(-1.3,1.2);y=rng.uniform(-.66,.73)
        w.mesh('Broken brick rubble',[(x,y,.006),(x+.14,y+.02,.006),(x+.16,y+.12,.011),(x,y+.14,.013),(x+.025,y+.03,.11)],
            [(0,1,4),(1,2,4),(2,3,4),(3,0,4),(0,3,2,1)],brick)
    w.pipe('Discarded bent conduit',[(-.8,.76,.04),(-.4,.8,.045),(-.1,.6,.055),(.3,.64,.052)],.024,rust)


BUILDERS={'HydraulicPress':press,'IndustrialLathe':lathe,'AirCompressor':compressor,
          'ControlCabinet':cabinet,'OfficeDesk':desk,'DebrisKit':debris}

for key in BUILDERS if args.assets=='all' else args.assets.split(','):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    scene=w.configure(args.samples,args.width,args.width)
    w.asset=w.collection('ASSET | '+key)
    green=w.material('paint_green');rust=w.material('rust');steel=w.material('steel');yellow=w.material('paint_yellow')
    cream=w.material('paint_cream');wood=w.material('wood');rubber=w.material('rubber');brick=w.material('brick')
    dark=w.plain('Deep empty recess',(.018,.021,.019),.94)
    red=w.plain('Oxidized red insulation',(.27,.042,.02),.82)
    BUILDERS[key]()
    views=w.prop_rig()
    stem=''.join('_'+c.lower() if c.isupper() else c for c in key).lstrip('_')
    w.save_export(ROOT/'Models/Interiors/WarehouseMachinery'/key,stem,{'views':list(views),'render_samples':args.samples,'render_device':scene.cycles.device})
    render_folder=w.RENDERS/key;render_folder.mkdir(parents=True,exist_ok=True);(w.RENDERS/'.gdignore').write_text('')
    if not args.no_render:
        for view,cam in views.items():
            scene.camera=cam;scene.render.filepath=str(render_folder/f'{view}.png')
            print('WAREHOUSE PROP RENDER',key,view,flush=True);bpy.ops.render.render(write_still=True)
print('WAREHOUSE MACHINERY COMPLETE',flush=True)
