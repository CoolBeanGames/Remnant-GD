"""Build independent textured Blender/GLB furniture and three Cycles views per asset.

Run Blender --background --factory-startup --python Tools/model_studio_furniture.py
-- --assets all --samples 64 --width 1000. No game scene or save data is modified.
Front is -Y, up is Z, origins are bottom-centred; tabletop props sit at Z=0.
"""
import argparse
import json
import math
import sys
from pathlib import Path
import bpy
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[1]
BASE = ROOT / 'Models/Interiors/StudioFurniture'
TEX = BASE / 'Textures'
RENDERS = ROOT / 'Reports/StudioFurniture'
KEYS = ['Couch', 'TableAndChairs', 'Chair', 'TV', 'Bookshelf', 'Fridge', 'Stove',
        'Microwave', 'CoffeePot', 'Sink', 'TrashCan', 'LandlinePhone', 'VCR',
        'EntertainmentCenter', 'PottedPlant', 'PileOfMail', 'FamilyPhoto', 'Kitchenette']
parser = argparse.ArgumentParser()
parser.add_argument('--assets', default='all')
parser.add_argument('--samples', type=int, default=64)
parser.add_argument('--width', type=int, default=1000)
parser.add_argument('--no-render', action='store_true')
args = parser.parse_args(sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else [])


def material(key, metal=0):
    name = key + (' / metal' if metal else '')
    if name in bpy.data.materials:
        return bpy.data.materials[name]
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    nodes, links = mat.node_tree.nodes, mat.node_tree.links
    p = nodes.get('Principled BSDF')
    p.inputs['Metallic'].default_value = metal
    for suffix, target in [('albedo', 'Base Color'), ('roughness', 'Roughness'), ('normal', 'Normal')]:
        image = bpy.data.images.load(str(TEX / f'{key}_{suffix}.png'), check_existing=True)
        if suffix != 'albedo':
            image.colorspace_settings.name = 'Non-Color'
        t = nodes.new('ShaderNodeTexImage')
        t.image = image
        if suffix == 'normal':
            n = nodes.new('ShaderNodeNormalMap')
            n.inputs['Strength'].default_value = .34
            links.new(t.outputs['Color'], n.inputs['Color'])
            links.new(n.outputs['Normal'], p.inputs[target])
        else:
            links.new(t.outputs['Color'], p.inputs[target])
    return mat


def plain(name, color, rough=.6, metal=0, transmission=0):
    if name in bpy.data.materials:
        return bpy.data.materials[name]
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    p = mat.node_tree.nodes.get('Principled BSDF')
    p.inputs['Base Color'].default_value = (*color, 1)
    p.inputs['Roughness'].default_value = rough
    p.inputs['Metallic'].default_value = metal
    p.inputs['Transmission Weight'].default_value = transmission
    p.inputs['IOR'].default_value = 1.45
    return mat


def print_material(name, image, emission=0):
    mat = plain(name, (.65, .6, .5), .74)
    n = mat.node_tree.nodes.new('ShaderNodeTexImage')
    n.image = bpy.data.images.load(str(TEX / image), check_existing=True)
    p = mat.node_tree.nodes.get('Principled BSDF')
    mat.node_tree.links.new(n.outputs['Color'], p.inputs['Base Color'])
    if emission:
        mat.node_tree.links.new(n.outputs['Color'], p.inputs['Emission Color'])
        p.inputs['Emission Strength'].default_value = emission
    return mat


def put(o, mat=None, parent=None):
    for c in list(o.users_collection):
        c.objects.unlink(o)
    asset.objects.link(o)
    if mat:
        o.data.materials.append(mat)
    o.parent = parent
    return o


def box(name, pos, dims, mat, bevel=.008, parent=None):
    bpy.ops.mesh.primitive_cube_add(size=1, location=pos)
    o = bpy.context.object
    o.name = name
    o.dimensions = dims
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    put(o, mat, parent)
    # Planar UVs with repeat at metre scale; front print panels override below.
    uv = o.data.uv_layers.active
    for p in o.data.polygons:
        axis = max(range(3), key=lambda i: abs(p.normal[i]))
        a, b = ((0,1) if axis == 2 else (0,2) if axis == 1 else (1,2))
        for li in p.loop_indices:
            v = o.data.vertices[o.data.loops[li].vertex_index].co
            uv.data[li].uv = (v[a] / max(dims[a], .02) + .5, v[b] / max(dims[b], .02) + .5)
    if bevel:
        m = o.modifiers.new('Softened manufactured edges', 'BEVEL')
        m.width = min(bevel, min(dims) * .45)
        m.segments = 5 if bevel > .035 else 3
        m.harden_normals = True
        o.modifiers.new('Weighted corner normals', 'WEIGHTED_NORMAL')
    return o


def sphere(name, pos, dims, mat, parent=None):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=24, ring_count=12, location=pos)
    o = bpy.context.object
    o.name = name
    o.scale = Vector(dims) * .5
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    put(o, mat, parent)
    for p in o.data.polygons:
        p.use_smooth = True
    return o


def cylinder(name, pos, radius, depth, mat, parent=None, rotation=None, vertices=32):
    bpy.ops.mesh.primitive_cylinder_add(vertices=vertices, radius=radius, depth=depth, location=pos)
    o = bpy.context.object
    o.name = name
    if rotation:
        o.rotation_euler = rotation
    put(o, mat, parent)
    for p in o.data.polygons:
        p.use_smooth = len(p.vertices) == 4
    m = o.modifiers.new('Machined edge radius', 'BEVEL')
    m.width = min(.003, depth*.12, radius*.12)
    m.segments = 2
    o.modifiers.new('Weighted normals', 'WEIGHTED_NORMAL')
    return o


def pipe(name, points, radius, mat, parent=None, closed=False):
    curve = bpy.data.curves.new(name, 'CURVE')
    curve.dimensions = '3D'
    curve.resolution_u = 12
    curve.bevel_depth = radius
    curve.bevel_resolution = 3
    s = curve.splines.new('POLY')
    s.points.add(len(points)-1)
    for p, co in zip(s.points, points):
        p.co = (*co, 1)
    s.use_cyclic_u = closed
    o = bpy.data.objects.new(name, curve)
    asset.objects.link(o)
    curve.materials.append(mat)
    o.parent = parent
    bpy.context.view_layer.objects.active = o
    o.select_set(True)
    bpy.ops.object.convert(target='MESH')
    o.select_set(False)
    return o


def lathe(name, profile, mat, pos=(0,0,0), parent=None):
    verts, faces = [], []
    count = 48
    for radius, z in profile:
        for i in range(count):
            a = i / count * math.tau
            verts.append((radius*math.cos(a), radius*math.sin(a), z))
    for j in range(len(profile)-1):
        for i in range(count):
            a = j*count+i
            b = j*count+(i+1)%count
            faces.append((a,b,b+count,a+count))
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata(verts, [], faces)
    mesh.update()
    uv = mesh.uv_layers.new(name='Turned surface')
    for p in mesh.polygons:
        p.use_smooth = True
        for li in p.loop_indices:
            vi = mesh.loops[li].vertex_index
            uv.data[li].uv = (vi % count / count, vi // count / (len(profile)-1))
    o = bpy.data.objects.new(name, mesh)
    asset.objects.link(o)
    mesh.materials.append(mat)
    o.location = pos
    o.parent = parent
    return o


def pivot(name, pos):
    o = bpy.data.objects.new(name, None)
    asset.objects.link(o)
    o.location = pos
    o['part'] = 'Movable subassembly with local pivot'
    return o


def label(name, text, pos, size=.014, mat=None, parent=None):
    c = bpy.data.curves.new(name, 'FONT')
    c.body = text
    c.size = size
    c.extrude = .0001
    c.align_x = 'CENTER'
    o = bpy.data.objects.new(name, c)
    asset.objects.link(o)
    o.location = pos
    o.rotation_euler = (math.pi/2,0,0)
    o.parent = parent
    c.materials.append(mat or cream)
    bpy.context.view_layer.objects.active = o
    o.select_set(True)
    bpy.ops.object.convert(target='MESH')
    o.select_set(False)
    return o


def panel(name, pos, size, mat, horizontal=False, parent=None):
    w,h = size
    vertices = [(-w/2,0,-h/2),(w/2,0,-h/2),(w/2,0,h/2),(-w/2,0,h/2)]
    if horizontal:
        vertices = [(-w/2,-h/2,0),(w/2,-h/2,0),(w/2,h/2,0),(-w/2,h/2,0)]
    m = bpy.data.meshes.new(name)
    m.from_pydata(vertices, [], [(0,1,2,3)])
    m.update()
    uv = m.uv_layers.new()
    for li,co in enumerate([(0,0),(1,0),(1,1),(0,1)]):
        uv.data[li].uv = co
    o = bpy.data.objects.new(name, m)
    asset.objects.link(o)
    m.materials.append(mat)
    o.location = pos
    o.parent = parent
    return o


def cushion(name, pos, dims, mat):
    o = box(name, pos, dims, mat, .07)
    w,d,h = dims
    points = []
    for cx,cy,start in [(w/2-.065,-d/2+.065,-math.pi/2),(w/2-.065,d/2-.065,0),(-w/2+.065,d/2-.065,math.pi/2),(-w/2+.065,-d/2+.065,math.pi)]:
        for k in range(7):
            a = start+k/6*math.pi/2
            points.append((pos[0]+cx+.065*math.cos(a),pos[1]+cy+.065*math.sin(a),pos[2]+h*.33))
    piping = pipe(name+' / stitched piping', points, .0028, seam, closed=True)
    # Retain its initial world pose, then follow cushion rotation (loose pillow
    # and reclined back cushions) rather than leaving stitches floating in space.
    bpy.context.view_layer.update()
    piping.parent = o
    piping.matrix_parent_inverse = o.matrix_world.inverted()
    return o


def sofa(armchair=False):
    w = .9 if armchair else 2.1
    cloth = material('ochre_cloth' if armchair else 'olive_cloth')
    box('Walnut lower sofa frame', (0,.05,.23),(w-.12,.78,.20),wood,.025)
    for x in (-w/2+.13,w/2-.13):
        for y in (-.3,.36):
            cylinder('Tapered timber foot',(x,y,.105),.039,.20,wood)
    for x in (-w/2+.09,w/2-.09):
        cushion('Upholstered arm',(x,.04,.57),(.21,.94,.51),cloth)
    cushion('Upholstered rear frame',(0,.44,.67),(w-.2,.20,.68),cloth)
    n = 1 if armchair else 3
    sw = (w-.43)/n
    for i in range(n):
        x = (i-(n-1)/2)*sw
        cushion('Seat cushion',(x,-.04,.415),(sw-.012,.72,.21),cloth)
        back = cushion('Back cushion',(x,.31,.75),(sw-.008,.18,.50),cloth)
        back.rotation_euler.x = math.radians(8)
        for xx in (-.13,.13):
            sphere('Recessed fabric tuft',(x+xx,.209,.75),(.017,.014,.017),seam)
    if not armchair:
        pillow = cushion('Loose faded ochre pillow',(-.68,.04,.67),(.37,.16,.38),material('ochre_cloth'))
        pillow.rotation_euler = (math.radians(-15),math.radians(-13),math.radians(-11))


def dining_chair(x,y,angle):
    root = pivot('Dining chair / reusable component',(x,y,0))
    before = set(asset.objects)
    box('Dining chair seat',(0,0,.45),(.43,.43,.055),wood,.018)
    cushion('Worn seat pad',(0,-.014,.491),(.38,.38,.054),material('ochre_cloth'))
    for xx in (-.17,.17):
        for yy in (-.17,.17):
            pipe('Chair leg',[(xx*1.12,yy*1.12,.015),(xx,yy,.45)],.022,wood)
        pipe('Back stile',[(xx,.16,.43),(xx,.22,.99)],.023,wood)
    for z in (.73,.87,.98):
        box('Curved-looking back rail',(0,.205,z),(.385,.035,.045),wood,.014)
    for xx in (-.17,.17):
        pipe('Lower chair stretcher',[(xx,-.18,.23),(xx,.18,.23)],.013,wood)
    for o in set(asset.objects)-before:
        if o.parent is None:
            o.parent = root
    root.rotation_euler.z = angle


def table_chairs():
    box('Dining tabletop',(0,0,.755),(1.15,.78,.045),wood,.012)
    for x in (-.44,.44):
        for y in (-.28,.28):
            pipe('Tapered table leg',[(x*1.03,y*1.03,.01),(x,y,.72)],.035,wood)
    for y in (-.27,.27):
        box('Apron rail',(0,y,.685),(.96,.035,.105),wood)
    for x in (-.43,.43):
        box('Apron end',(x,0,.685),(.035,.58,.105),wood)
    dining_chair(0,-.75,math.pi)
    dining_chair(0,.75,0)


def book(name,x,y,z,w,d,h,index):
    cover = plain('Cloth book cover '+str(index%5),[(.20,.08,.04),(.14,.19,.15),(.16,.18,.24),(.38,.25,.12),(.25,.075,.055)][index%5],.9)
    box(name+' / page block',(x,y,z),(w-.006,d-.025,h-.012),material('paper'),.002)
    for xx in (-w/2,w/2):
        box(name+' / cover',(x+xx,y,z),(.006,d,h),cover,.002)
    box(name+' / spine',(x,y-d/2,z),(w+.009,.009,h),cover,.002)
    for zz in (-h*.33,h*.33):
        box('Spine gold rule',(x,y-d/2-.005,z+zz),(w*.75,.001,.003),brass,.0001)


def bookshelf():
    for x in (-.44,.44):
        box('Shelf side',(x,0,.92),(.035,.34,1.84),wood)
    box('Inset rear plywood',(0,.164,.92),(.875,.014,1.84),wood,.002)
    for z in (.04,.40,.76,1.12,1.48,1.82):
        box('Fixed shelf',(0,0,z),(.88,.35,.035),wood)
    for row,z in enumerate((.43,.79,1.15,1.51)):
        x = -.37
        for i in range(7 if row != 1 else 4):
            w = .033+(i%3)*.016
            h = .22+(i%4)*.021
            book('Second-hand book',x+w/2,-.035,z+h/2,w,.245,h,i+row)
            x += w+.012


def television():
    box('CRT rear chassis',(0,.08,.305),(.63,.46,.56),black,.06)
    box('CRT front bezel',(0,-.205,.32),(.66,.055,.53),black,.035)
    box('Convex glass face',( -.045,-.244,.345),(.49,.055,.39),plain('Smoky CRT glass',(.025,.051,.043),.19),.057)
    panel('Subtle phosphor image',(-.045,-.273,.345),(.445,.335),print_material('Phosphor scan lines','crt_screen.png',.3))
    for z in (.35,.46):
        cylinder('Tuning knob',(.267,-.258,z),.024,.024,cream,rotation=(math.pi/2,0,0))
    for i in range(9):
        box('Front speaker slot',(.264,-.242,.125+i*.013),(.055,.009,.004),dark,.001)
    for x in (-.25,.25):
        box('TV foot',(x,0,.022),(.10,.29,.044),black)
    for x in (-.24,.24):
        for z in (.23,.26,.29,.32,.35):
            box('Rear cooling vent',(x,.316,z),(.11,.003,.007),dark,.001)
    for x,a in ((-.07,-.25),(.07,.25)):
        pipe('Telescoping aerial',[(x,.10,.58),(a,.1,.98)],.003,steel)
    label('TV brand','DISTRICT',(.035,-.24,.086),.017)


def fridge():
    box('Refrigerator insulated shell',(0,.015,.82),(.66,.65,1.64),cream,.032)
    for name,z,h in [('Refrigerator',.61,1.16),('Freezer',1.40,.35)]:
        root = pivot(name+' hinge',(-.325,-.337,z-h/2))
        box(name+' enamel door',(.325,0,h/2),(.644,.054,h),cream,.025,root)
        box(name+' black rubber gasket',(.325,.026,h/2),(.626,.016,h-.025),black,.01,root)
        box(name+' pull handle',(.58,-.054,h*.56),(.026,.035,min(.32,h*.60)),black,.012,root)
    for x in (-.23,.23):
        cylinder('Leveling foot',(x,-.22,.018),.03,.036,black)
    box('Condenser frame',(0,.348,.76),(.49,.025,1.27),black)
    for z in range(17):
        pipe('Condenser cooling tube',[(-.24,.365,.15+z*.068),(.24,.365,.15+z*.068)],.004,steel)
    label('Fridge brand','DISTRICT',(0,-.369,1.51),.016,black)


def stove():
    box('Enamel range cabinet',(0,0,.43),(.6,.61,.86),cream,.018)
    box('Black cooktop',(0,0,.883),(.608,.615,.022),black,.008)
    for x in (-.155,.155):
        for y in (-.14,.14):
            cylinder('Burner drip tray',(x,y,.900),.102,.014,steel)
            pts = []
            for i in range(161):
                a = i/160 * 5*math.tau
                r = .012+.078*i/160
                pts.append((x+r*math.cos(a),y+r*math.sin(a),.912))
            pipe('Electric spiral burner',pts,.0045,dark)
    box('Back control riser',(0,.265,.996),(.60,.075,.22),cream)
    for x in (-.20,-.068,.068,.20):
        cylinder('Range control knob',(x,.216,1.00),.025,.025,black,rotation=(math.pi/2,0,0))
    root = pivot('Oven bottom hinge',(0,-.324,.12))
    box('Oven door',(0,0,.26),(.55,.055,.49),cream,.014,root)
    box('Oven dark window',(0,-.03,.27),(.39,.01,.28),black,.015,root)
    pipe('Oven handle',[(-.23,-.064,.46),(-.21,-.083,.46),(.21,-.083,.46),(.23,-.064,.46)],.012,steel,root)
    box('Bottom storage drawer',(0,-.317,.068),(.56,.023,.09),cream)
    label('Range settings','OFF   LOW   HIGH',(0,.214,1.07),.012,black)


def microwave():
    box('Microwave cabinet',(0,0,.16),(.48,.37,.31),cream,.019)
    door = pivot('Microwave side hinge',(-.235,-.195,.032))
    box('Door surround',(.177,0,.118),(.35,.027,.243),black,.014,door)
    box('Door perforated viewing glass',(.159,-.016,.118),(.26,.004,.179),plain('Microwave window',(.046,.055,.047),.32),.01,door)
    for i in range(17):
        box('Window mesh stripe',(.159,-.019,.04+i*.009),(.25,.001,.0017),steel,0,door)
    box('Door handle',(.325,-.032,.125),(.014,.027,.13),cream,.005,door)
    box('Control panel',(.18,-.191,.16),(.083,.010,.26),black)
    label('Microwave clock','12:00',(.18,-.199,.247),.018,green)
    for x in (.16,.19):
        for z in (.073,.103,.133,.163):
            box('Keypad button',(x,-.20,z),(.021,.007,.021),cream,.002)
    for i in range(8):
        box('Microwave side vent',(.242,.04+i*.016,.22),(.002,.009,.06),dark,0)
    for x in (-.19,.19):
        cylinder('Rubber microwave foot',(x,0,.011),.018,.022,black)


def coffee():
    box('Coffee maker hotplate base',(0,0,.028),(.21,.255,.056),black,.018)
    box('Water tank tower',(0,.073,.17),(.20,.08,.25),cream,.024)
    box('Filter housing',(0,-.01,.32),(.21,.22,.08),cream,.023)
    cylinder('Hotplate',(0,-.048,.062),.077,.008,steel)
    glass = plain('Carafe glass',(.92,.95,.90),.085,transmission=1)
    lathe('Hollow glass carafe',[(.002,.074),(.056,.074),(.078,.089),(.081,.17),(.06,.224),(.058,.237),(.054,.237),(.056,.224),(.077,.17),(.074,.09),(.002,.081)],glass,(0,-.045,0))
    cylinder('Coffee liquid',(0,-.045,.111),.073,.05,plain('Old dark coffee',(.039,.018,.005),.2))
    cylinder('Carafe lid',(0,-.045,.24),.064,.013,black)
    pipe('Carafe handle',[(.062,-.045,.214),(.113,-.045,.205),(.119,-.045,.116),(.079,-.045,.102)],.01,black)
    box('On off switch',(.061,-.12,.032),(.026,.006,.015),red,.002)
    for z in (.11,.15,.19,.23):
        box('Tank fill mark',(.103,.072,z),(.001,.024,.002),dark,0)


def sink():
    # A continuous rounded rectangular shell closes every corner. The top stays
    # open, with inner/outer bottom caps and a genuine inset cavity.
    profile=[(.25,.235,.020,.026),(.225,.205,.020,.032),
             (.195,.170,-.155,.044),(.205,.180,-.167,.044),(.25,.235,.002,.026)]
    vertices=[]
    for w,d,z,r in profile:
        for cx,cy,start in [(w-r,-d+r,-math.pi/2),(w-r,d-r,0),(-w+r,d-r,math.pi/2),(-w+r,-d+r,math.pi)]:
            for j in range(9):
                a=start+j/8*math.pi/2
                vertices.append((cx+r*math.cos(a),cy+r*math.sin(a),z))
    count=36
    faces=[]
    for j in range(len(profile)):
        nxt=(j+1)%len(profile)
        for i in range(count):
            k=(i+1)%count
            faces.append((j*count+i,j*count+k,nxt*count+k,nxt*count+i))
    faces.append(tuple(2*count+i for i in range(count)))
    faces.append(tuple(3*count+i for i in reversed(range(count))))
    mesh=bpy.data.meshes.new('Continuous pressed sink shell')
    mesh.from_pydata(vertices,[],faces)
    mesh.update()
    o=bpy.data.objects.new('Continuous open basin and rolled rim',mesh)
    asset.objects.link(o)
    mesh.materials.append(steel)
    uv=mesh.uv_layers.new()
    for poly in mesh.polygons:
        poly.use_smooth=len(poly.vertices)==4
        axis=max(range(3),key=lambda i:abs(poly.normal[i]))
        a,b=((0,1) if axis==2 else (0,2) if axis==1 else (1,2))
        for li in poly.loop_indices:
            v=mesh.vertices[mesh.loops[li].vertex_index].co
            uv.data[li].uv=(v[a]*2+.5,v[b]*2+.5)
    cylinder('Drain basket',(0,0,-.152),.037,.009,steel)
    for a in range(8):
        cylinder('Drain perforation',(.023*math.cos(a*math.tau/8),.023*math.sin(a*math.tau/8),-.146),.004,.002,dark,vertices=12)
    pipe('Gooseneck faucet',[(0,.204,.024),(0,.204,.195),(0,.19,.232),(0,.157,.252),(0,.115,.248),(0,.082,.224),(0,.082,.195)],.013,steel)
    for x in (-.10,.10):
        cylinder('Mixer tap base',(x,.20,.027),.026,.035,steel)
        pipe('Cross tap',[(x-.024,.20,.05),(x+.024,.20,.05)],.005,steel)
        pipe('Cross tap',[(x,.18,.05),(x,.22,.05)],.005,steel)
    cylinder('Drain pipe',(0,0,-.30),.022,.27,steel)


def trash():
    lathe('Open corrugated rubbish bin',[(.0,.014),(.145,.014),(.16,.045),(.19,.51),(.20,.53),(.188,.539),(.180,.51),(.15,.047),(.0,.031)],steel)
    for i in range(28):
        a = i/28*math.tau
        pipe('Pressed steel rib',[(.159*math.cos(a),.159*math.sin(a),.045),(.192*math.cos(a),.192*math.sin(a),.51)],.003,steel)
    for x in (-.198,.198):
        pipe('Bin side handle',[(x,0,.40),(x*1.2,0,.40),(x*1.2,0,.32),(x,0,.32)],.009,steel)
    for i in range(5):
        o = box('Discarded crumpled mail',(math.sin(i)*.06,math.cos(i)*.05,.35+i*.023),(.15,.13,.015),material('paper'),.006)
        o.rotation_euler = (.13*i,.11*i,.64*i)


def phone():
    body = box('Desk telephone base',(0,0,.043),(.225,.21,.085),cream,.026)
    body.rotation_euler.x = math.radians(6)
    for x in (-.083,.083):
        box('Receiver cradle',(x,.055,.102),(.023,.036,.04),cream,.006)
    hand = pivot('Removable receiver',(0,.057,.125))
    box('Receiver bridge',(0,0,.009),(.185,.045,.037),black,.018,hand)
    for x in (-.093,.093):
        sphere('Receiver earpiece',(x,0,0),(.072,.067,.05),black,hand)
        cylinder('Receiver grille',(x,0,-.025),.022,.003,dark,hand)
    for j in range(4):
        for i in range(3):
            box('Telephone keypad',((i-1)*.036,-.068+j*.029,.083+j*.003),(.027,.024,.010),black,.002)
            char = ['*0#','789','456','123'][j][i]
            key = label('Telephone key '+char,char,((i-1)*.036,-.072+j*.029,.089+j*.003),.010,cream)
            key.rotation_euler=(0,0,0)
    pts=[]
    for i in range(401):
        a=i/400*math.tau*22
        pts.append((.133+.008*math.cos(a),.05-i/400*.24,.074+.008*math.sin(a)))
    pipe('Coiled receiver cord',pts,.0021,black)
    pipe('Receiver cord lead',[(.10,.057,.116),(.133,.05,.074)],.0021,black)
    pipe('Telephone cord jack lead',[(.141,-.19,.074),(.14,-.21,.052),(.106,-.086,.055)],.0021,black)
    label('Telephone model','DISTRICT', (0,-.119,.045),.013,black)


def vcr():
    box('VCR chassis',(0,0,.049),(.43,.275,.095),black,.011)
    box('Cassette door',( -.08,-.141,.058),(.24,.006,.037),dark,.002)
    label('Cassette label','VHS',(-.08,-.146,.05),.016,cream)
    box('Display recess',(.132,-.141,.063),(.09,.004,.025),dark,.002)
    label('VCR green counter','00:00',(.132,-.145,.059),.013,green)
    for x in (-.175,-.14,-.10,-.06,.03,.072,.12,.17):
        box('Transport button',(x,-.146,.021),(.022,.009,.009),cream,.001)
    for x in (-.14,.14):
        for y in (-.10,.10):
            cylinder('VCR foot',(x,y,.004),.013,.008,black)
    for x in (-.08,-.04,0,.04,.08):
        cylinder('Rear AV socket',(x,.139,.055),.006,.007,steel,rotation=(math.pi/2,0,0))


def entertainment():
    for x in (-.69,.69):
        box('Cabinet side',(x,0,.33),(.037,.43,.62),wood)
    for z in (.07,.36,.64):
        box('Cabinet shelf',(0,0,z),(1.40,.45,.032),wood)
    box('Centre divider',(0,0,.22),(.025,.43,.28),wood)
    for x in (-.60,.60):
        for y in (-.14,.14):
            cylinder('Cabinet foot',(x,y,.036),.033,.072,wood)
    for x in (-.34,.34):
        door = pivot('Sliding cabinet panel',(x,-.216,.205))
        box('Slatted door',(0,0,0),(.64,.027,.245),wood,.003,door)
        for i in range(13):
            box('Tambour door groove',(-.294+i*.049,-.014,0),(.004,.002,.23),dark,.0005,door)
        box('Inset door pull',(.22,-.023,0),(.025,.012,.08),brass,.004,door)
    box('Inset back with cable opening',(0,.21,.24),(1.35,.015,.34),wood)


def plant():
    lathe('Terracotta pot',[(0,.009),(.10,.009),(.105,.03),(.143,.24),(.153,.246),(.153,.265),(.132,.266),(.131,.241),(.094,.035),(0,.028)],material('ceramic'))
    cylinder('Potting soil',(0,0,.241),.129,.018,material('soil'))
    leaf=material('leaf')
    pipe('Central rooted stem',[(0,0,.23),(0,0,.36),(0,0,.51),(0,0,.69)],.005,leaf)
    for i in range(18):
        a=i*2.399
        z=.30+(i%6)*.085
        rad=.16+(i%3)*.035
        start=Vector((0,0,z-.06))
        end=Vector((math.cos(a)*rad,math.sin(a)*rad,z+.04))
        pipe('Plant stem',[tuple(start),tuple(end)],.003,leaf)
        direction=(end-start).normalized()
        side=direction.cross(Vector((0,0,1))).normalized()
        verts=[]
        for j in range(9):
            t=j/8
            mid=end+direction*t*.17+Vector((0,0,.022*math.sin(t*math.pi)-.07*t*t))
            w=.04*math.sin(t*math.pi)
            for s in (-1,0,1):
                verts.append(tuple(mid+side*w*s+Vector((0,0,.008*(1-abs(s))*math.sin(t*math.pi)))))
        faces=[]
        for j in range(8):
            for k in range(2):
                p=j*3+k
                faces.append((p,p+1,p+4,p+3))
        m=bpy.data.meshes.new('Individual curved leaf')
        m.from_pydata(verts,[],faces)
        m.update()
        uv=m.uv_layers.new()
        for p in m.polygons:
            p.use_smooth=True
            for li in p.loop_indices:
                vi=m.loops[li].vertex_index
                uv.data[li].uv=(vi%3/2,vi//3/8)
        o=bpy.data.objects.new('Curved veined leaf',m)
        asset.objects.link(o)
        m.materials.append(leaf)
        solid=o.modifiers.new('Leaf thickness','SOLIDIFY')
        solid.thickness=.0005


def mail():
    for i in range(7):
        root=pivot('Loose mail piece '+str(i),(math.sin(i*2)*.023,math.cos(i)*.015,.003+i*.003))
        root.rotation_euler.z=math.sin(i)*.13
        box('Folded envelope',(0,0,0),(.222,.135,.0018),material('paper'),.0005,root)
        panel('Printed letter face',(0,0,.0012),(.221,.134),print_material('Letter print '+str(i%3),f'mail_{i%3}.png'),True,root)
        pipe('Envelope reverse flap',[(-.10,-.06,-.0011),(0,.018,-.0011),(.10,-.06,-.0011)],.00035,plain('Envelope seam',(.40,.35,.25),.95),root)


def photo():
    box('Photo frame back',(0,0,.13),(.26,.018,.26),wood,.004)
    for x in (-.124,.124):
        box('Frame side',(x,-.017,.13),(.018,.024,.26),wood,.004)
    for z in (.009,.251):
        box('Frame cross rail',(0,-.017,z),(.238,.024,.018),wood,.004)
    panel('Photograph mount',(0,-.019,.13),(.224,.224),material('paper'))
    panel('Fictional 1980s family photograph',(0,-.020,.13),(.205,.14),print_material('Faded family print','family_photo.png'))
    glass=plain('Photo protective glass',(.93,.95,.90),.11,transmission=1)
    box('Thin protective glazing',(0,-.022,.13),(.223,.001,.222),glass,.0002)
    stand=pivot('Frame easel hinge',(0,.015,.22))
    leg=box('Folding easel',(0,0,-.11),(.06,.008,.22),wood,.002,stand)
    stand.rotation_euler.x=math.radians(22)


def kitchenette():
    # 1.8 m counter unit with real opening for separately instanced sink.
    for x in (-.87,-.29,.29,.87):
        box('Counter carcass upright',(x,0,.45),(.03,.57,.79),wood)
    box('Cabinet back',(0,.275,.45),(1.8,.014,.81),wood)
    box('Cabinet plinth',(0,0,.065),(1.76,.50,.10),wood)
    box('Cabinet bottom shelf',(0,0,.14),(1.8,.56,.025),wood)
    top=material('aged_cream')
    # Sink sits at X=-.57; aperture 0.46 x 0.43. All pieces exactly meet.
    for x,w in [(-.85,.10),(.28,1.24)]:
        box('Laminate countertop',(x,0,.892),(w,.63,.036),top)
    for y in (-.276,.276):
        box('Countertop around sink',(-.57,y,.892),(.48,.078,.036),top)
    for x in (-.58,0,.58):
        for j in (-1,1):
            door=pivot('Lower cupboard hinge',(x+j*.267,-.286,.17))
            box('Panelled cupboard door',(-j*.13,0,.34),(.258,.032,.67),wood,.009,door)
            box('Inset door field',(-j*.13,-.018,.34),(.199,.009,.56),wood,.006,door)
            box('Brass cupboard pull',(-j*.23,-.038,.49),(.011,.024,.09),brass,.004,door)
    grout=plain('Kitchen aged grout',(.27,.25,.19),.97)
    box('Backsplash grout bed',(0,.285,1.17),(1.82,.025,.52),grout)
    for i in range(12):
        for j in range(3):
            box('Grease stained backsplash tile',(-.825+i*.15,.266,.997+j*.15),(.146,.012,.146),material('tile_dirty'),.003)
    for x in (-.60,0,.60):
        box('Upper cupboard cabinet',(x,.10,1.99),(.58,.35,.65),wood)
        door=pivot('Upper cupboard hinge',(x-.28,-.08,1.68))
        box('Upper cupboard door',(.28,0,.31),(.56,.028,.62),wood,.009,door)
        box('Upper pull',(.50,-.022,.14),(.011,.024,.09),brass,.003,door)


BUILDERS={'Couch':lambda:sofa(False),'TableAndChairs':table_chairs,'Chair':lambda:sofa(True),
          'TV':television,'Bookshelf':bookshelf,'Fridge':fridge,'Stove':stove,'Microwave':microwave,
          'CoffeePot':coffee,'Sink':sink,'TrashCan':trash,'LandlinePhone':phone,'VCR':vcr,
          'EntertainmentCenter':entertainment,'PottedPlant':plant,'PileOfMail':mail,'FamilyPhoto':photo,'Kitchenette':kitchenette}


def configure(scene):
    scene.unit_settings.system='METRIC'
    scene.unit_settings.scale_length=1
    bpy.context.preferences.filepaths.save_version=0
    scene.render.engine='CYCLES'
    scene.cycles.samples=args.samples
    scene.cycles.use_denoising=True
    scene.cycles.adaptive_threshold=.035
    scene.cycles.max_bounces=8
    scene.view_settings.view_transform='AgX'
    scene.view_settings.look='AgX - Medium High Contrast'
    scene.view_settings.exposure=.35
    scene.render.image_settings.file_format='PNG'
    scene.render.image_settings.color_mode='RGB'
    scene.render.resolution_x=args.width
    scene.render.resolution_y=args.width
    scene.render.resolution_percentage=100
    p=bpy.context.preferences.addons['cycles'].preferences
    try:
        p.compute_device_type='OPTIX'
        p.refresh_devices()
        available=[d for d in p.devices if d.type=='OPTIX']
        for d in p.devices:
            d.use=d in available
        scene.cycles.device='GPU' if available else 'CPU'
    except Exception:
        scene.cycles.device='CPU'


def camera(presentation,name,pos,target,scale):
    data=bpy.data.cameras.new(name)
    data.type='ORTHO'
    data.ortho_scale=scale
    data.clip_start=.001
    obj=bpy.data.objects.new(name,data)
    presentation.objects.link(obj)
    obj.location=pos
    obj.rotation_euler=(Vector(target)-obj.location).to_track_quat('-Z','Y').to_euler()
    return obj


def build(key):
    global asset,wood,cream,black,steel,dark,brass,seam,red,green
    bpy.ops.wm.read_factory_settings(use_empty=True)
    scene=bpy.context.scene
    configure(scene)
    asset=bpy.data.collections.new('ASSET | '+key)
    scene.collection.children.link(asset)
    asset['asset_key']=key
    asset['origin']='Bottom centre; tabletop props at contact plane. Sink pivot is countertop insertion plane.'
    wood=material('walnut')
    cream=material('aged_cream')
    black=material('black_plastic')
    steel=material('steel',.78)
    dark=plain('Dark cavities',(.018,.019,.014),.86)
    brass=plain('Aged brass',(.37,.255,.10),.39,.7)
    seam=plain('Upholstery seam',(.15,.15,.095),.94)
    red=plain('Faded red switch',(.28,.047,.025),.55)
    green=plain('Green display',(.15,.50,.20),.4)
    BUILDERS[key]()
    # Converted curves/fonts may not carry UVs. Supply planar UVs before export,
    # including pipes using the same portable textured metal material.
    for obj in asset.objects:
        if obj.type != 'MESH' or obj.data.uv_layers:
            continue
        uv = obj.data.uv_layers.new(name='Portable planar layout')
        for poly in obj.data.polygons:
            axis = max(range(3), key=lambda i: abs(poly.normal[i]))
            a,b = ((0,1) if axis == 2 else (0,2) if axis == 1 else (1,2))
            for li in poly.loop_indices:
                point = obj.data.vertices[obj.data.loops[li].vertex_index].co
                uv.data[li].uv = (point[a] * 4, point[b] * 4)
    # Remove unused palette maps so every native file embeds only its own dependencies.
    used={m for o in asset.objects if o.type=='MESH' for m in o.data.materials}
    for m in list(bpy.data.materials):
        if m not in used and m.users==0:
            bpy.data.materials.remove(m)
    for im in list(bpy.data.images):
        if im.users==0:
            bpy.data.images.remove(im)
        elif im.source=='FILE':
            im.pack()
    points=[o.matrix_world@Vector(c) for o in asset.objects if o.type=='MESH' for c in o.bound_box]
    # Ensure hierarchy matrices are current before measuring camera framing.
    bpy.context.view_layer.update()
    points=[o.matrix_world@Vector(c) for o in asset.objects if o.type=='MESH' for c in o.bound_box]
    lo=Vector([min(p[i] for p in points) for i in range(3)])
    hi=Vector([max(p[i] for p in points) for i in range(3)])
    centre=(lo+hi)/2
    dims=hi-lo
    span=max(dims)
    presentation=bpy.data.collections.new('PRESENTATION | studio lights and three cameras')
    scene.collection.children.link(presentation)
    world=bpy.data.worlds.new('Neutral warm studio')
    world.use_nodes=True
    world.node_tree.nodes['Background'].inputs['Color'].default_value=(.33,.36,.39,1)
    world.node_tree.nodes['Background'].inputs['Strength'].default_value=.32
    scene.world=world
    # Temporary geometry helper uses asset collection; move backdrop into presentation.
    floor=box('Presentation floor',(0,0,lo.z-.009),(200,200,.014),plain('Studio floor',(.19,.195,.18),.85),0)
    asset.objects.unlink(floor)
    presentation.objects.link(floor)
    for name,pos,power,size in [('Key',(-2,-3,4),500,3),('Fill',(3,-1,2),270,3),('Rim',(1,3,4),600,2)]:
        data=bpy.data.lights.new(name,'AREA')
        data.energy=power
        data.shape='DISK'
        data.size=size
        o=bpy.data.objects.new(name,data)
        presentation.objects.link(o)
        # Keep studio dimensions constant to avoid tiny props getting absurd exposure.
        o.location=Vector(pos)+centre
        o.rotation_euler=(centre-o.location).to_track_quat('-Z','Y').to_euler()
    views={}
    for name,direction in [('front',(1.5,-2.1,1.05)),('rear',(-1.6,2.0,1.1)),('detail',(-1.2,-1.5,1.8))]:
        target=centre
        views[name]=camera(presentation,name,centre+Vector(direction)*max(span, .25),target,span*1.40)
    scene.camera=views['front']
    folder=BASE/key
    source=folder/'Source'
    source.mkdir(parents=True,exist_ok=True)
    (source/'.gdignore').write_text('')
    renders=RENDERS/key
    renders.mkdir(parents=True,exist_ok=True)
    (RENDERS/'.gdignore').write_text('')
    name=''.join(('_'+c.lower() if c.isupper() else c) for c in key).lstrip('_')
    bpy.ops.wm.save_as_mainfile(filepath=str(source/(name+'.blend')))
    bpy.ops.object.select_all(action='DESELECT')
    for o in asset.objects:
        o.select_set(True)
    bpy.ops.export_scene.gltf(filepath=str(folder/(name+'.glb')),export_format='GLB',use_selection=True,export_apply=True,export_animations=False,export_cameras=False,export_lights=False,export_extras=True,export_yup=True)
    triangles=0
    for o in asset.objects:
        if o.type=='MESH':
            ev=o.evaluated_get(bpy.context.evaluated_depsgraph_get())
            m=ev.to_mesh()
            m.calc_loop_triangles()
            triangles+=len(m.loop_triangles)
            ev.to_mesh_clear()
    info={'key':key,'native':str((source/(name+'.blend')).relative_to(ROOT)).replace('\\','/'),
          'export':str((folder/(name+'.glb')).relative_to(ROOT)).replace('\\','/'),
          'collection':asset.name,'dimensions_blender_m':[round(v,4) for v in dims],
          'origin':asset['origin'],'mesh_objects':sum(o.type=='MESH' for o in asset.objects),
          'triangles':triangles,'packed_images':sum(bool(im.packed_file) for im in bpy.data.images),
          'render_samples':args.samples,'render_device':scene.cycles.device,'blender':bpy.app.version_string,
          'views':list(views),'physics':'No engine colliders; standalone art asset',
          'artwork':'Original generated PBR maps and typography; family_photo.png is a generated fictional photograph'}
    (folder/'asset_manifest.json').write_text(json.dumps(info,indent=2)+'\n')
    print('FURNITURE ASSET',key,triangles,'triangles',flush=True)
    if not args.no_render:
        for view,cam in views.items():
            scene.camera=cam
            scene.render.filepath=str(renders/(view+'.png'))
            print('FURNITURE RENDER',key,view,flush=True)
            bpy.ops.render.render(write_still=True)
    print('FURNITURE DONE',key,flush=True)


for key in KEYS if args.assets=='all' else args.assets.split(','):
    if key not in BUILDERS:
        raise ValueError('Unknown furniture asset: '+key)
    build(key)
print('FURNITURE COMPLETE',flush=True)
