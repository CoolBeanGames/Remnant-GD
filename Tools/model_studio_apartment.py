"""Build and render an unfurnished apartment. Run with Blender --background --python.

Standalone authoring tool: no game state, gameplay changes or external asset downloads.
Textures are original deterministic maps and newspaper typography, packed in .blend/GLB.
"""
from pathlib import Path
import argparse
import json
import math
import sys

import bpy
import numpy as np
from mathutils import Vector


ROOT = Path(__file__).resolve().parents[1]
ASSET = ROOT / 'Models' / 'Architecture' / 'StudioApartment'
SOURCE = ASSET / 'Source'
TEXTURES = ASSET / 'Textures'
RENDERS = ROOT / 'Reports' / 'StudioApartment'
for folder in (SOURCE, TEXTURES, RENDERS):
    folder.mkdir(parents=True, exist_ok=True)
(SOURCE / '.gdignore').write_text('', encoding='utf-8')
(TEXTURES / '.gdignore').write_text('', encoding='utf-8')
(RENDERS / '.gdignore').write_text('', encoding='utf-8')

parser = argparse.ArgumentParser()
parser.add_argument('--samples', type=int, default=128)
parser.add_argument('--width', type=int, default=1800)
parser.add_argument('--views', default='cutaway,living,entry,bathroom')
arguments = sys.argv[sys.argv.index('--') + 1:] if '--' in sys.argv else []
args = parser.parse_args(arguments)

bpy.ops.wm.read_factory_settings(use_empty=True)
scene = bpy.context.scene
scene.unit_settings.system = 'METRIC'
scene.unit_settings.scale_length = 1.0
preferences = bpy.context.preferences
preferences.filepaths.save_version = 0
scene.render.engine = 'CYCLES'
scene.cycles.samples = args.samples
scene.cycles.use_denoising = True
scene.cycles.adaptive_threshold = .025
scene.cycles.max_bounces = 10
scene.cycles.transparent_max_bounces = 8
scene.cycles.volume_step_rate = .1
scene.render.image_settings.file_format = 'PNG'
scene.render.image_settings.color_mode = 'RGB'
scene.render.image_settings.color_depth = '8'
scene.view_settings.view_transform = 'AgX'
scene.view_settings.look = 'AgX - Medium High Contrast'
scene.view_settings.exposure = .25
scene.render.film_transparent = False

preferences = bpy.context.preferences.addons['cycles'].preferences
try:
    preferences.compute_device_type = 'OPTIX'
    preferences.refresh_devices()
    available = [d for d in preferences.devices if d.type == 'OPTIX']
    for device in preferences.devices:
        device.use = device in available
    scene.cycles.device = 'GPU' if available else 'CPU'
except Exception:
    scene.cycles.device = 'CPU'
print('APARTMENT render device:', scene.cycles.device, flush=True)

architecture = bpy.data.collections.new('APARTMENT | permanent architecture')
presentation = bpy.data.collections.new('PRESENTATION | cameras, lights, backdrop')
scene.collection.children.link(architecture)
scene.collection.children.link(presentation)
groups = {}


def put(obj, collection=architecture, group='structure'):
    for old in list(obj.users_collection):
        old.objects.unlink(obj)
    collection.objects.link(obj)
    if collection == architecture:
        groups.setdefault(group, []).append(obj)
    return obj


def wave_noise(u, v, seed=1, octaves=6):
    rng = np.random.default_rng(seed)
    result = np.zeros_like(u, dtype=np.float32)
    for octave in range(octaves):
        frequency = 2 ** octave
        for _ in range(3):
            a, b = rng.integers(max(1, frequency), max(2, frequency * 3), 2)
            result += np.sin(2 * np.pi * (a * u + b * v) + rng.random() * 6.28) / (frequency * 3)
    return result


def soft_noise(u, v, seed=1, octaves=6):
    """Tileable isotropic noise for plaster, without directional wave bands."""
    rng = np.random.default_rng(seed)
    result = np.zeros_like(u, dtype=np.float32)
    for octave in range(octaves):
        frequency = 4 * 2 ** octave
        grid = rng.uniform(-1, 1, (frequency, frequency)).astype(np.float32)
        x, y = u * frequency, v * frequency
        ix, iy = x.astype(int), y.astype(int)
        tx, ty = x - ix, y - iy
        tx = tx * tx * (3 - 2 * tx)
        ty = ty * ty * (3 - 2 * ty)
        a = grid[iy % frequency, ix % frequency]
        b = grid[iy % frequency, (ix + 1) % frequency]
        c = grid[(iy + 1) % frequency, ix % frequency]
        d = grid[(iy + 1) % frequency, (ix + 1) % frequency]
        result += ((a * (1 - tx) + b * tx) * (1 - ty) + (c * (1 - tx) + d * tx) * ty) / 2 ** octave
    return result


def image_map(name, pixels, colorspace='sRGB'):
    h, w = pixels.shape[:2]
    image = bpy.data.images.new(name, w, h, alpha=False)
    # Configure before writing: changing colour space invalidates generated pixels.
    image.colorspace_settings.name = colorspace
    image.filepath_raw = str(TEXTURES / (name + '.png'))
    image.file_format = 'PNG'
    rgba = np.ones((h, w, 4), dtype=np.float32)
    rgba[:, :, :3] = np.clip(pixels, 0, 1)
    image.pixels.foreach_set(rgba.ravel())
    image.update()
    image.save()
    if max(image.pixels[:3]) < .01:
        raise RuntimeError('Texture pixel data was lost: ' + name)
    return image


def normal_map(name, height, strength):
    dy = (np.roll(height, -1, axis=0) - np.roll(height, 1, axis=0)) * strength
    dx = (np.roll(height, -1, axis=1) - np.roll(height, 1, axis=1)) * strength
    xyz = np.stack((-dx, -dy, np.ones_like(height)), axis=2)
    xyz /= np.linalg.norm(xyz, axis=2)[:, :, None]
    return image_map(name, xyz * .5 + .5, 'Non-Color')


def textured(name, color, normal, roughness=.6, normal_strength=.5):
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    nodes = mat.node_tree.nodes
    links = mat.node_tree.links
    shader = nodes.get('Principled BSDF')
    shader.inputs['Roughness'].default_value = roughness
    texture = nodes.new('ShaderNodeTexImage')
    texture.image = color
    links.new(texture.outputs['Color'], shader.inputs['Base Color'])
    if normal:
        tex = nodes.new('ShaderNodeTexImage')
        tex.image = normal
        tex.label = 'Baked tangent-space normal (portable glTF)'
        nm = nodes.new('ShaderNodeNormalMap')
        nm.inputs['Strength'].default_value = normal_strength
        links.new(tex.outputs['Color'], nm.inputs['Color'])
        links.new(nm.outputs['Normal'], shader.inputs['Normal'])
    mat.diffuse_color = (*color.pixels[:3], 1)
    return mat


def plain(name, color, roughness=.6, metallic=0):
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    shader = mat.node_tree.nodes.get('Principled BSDF')
    shader.inputs['Base Color'].default_value = (*color, 1)
    shader.inputs['Roughness'].default_value = roughness
    shader.inputs['Metallic'].default_value = metallic
    mat.diffuse_color = (*color, 1)
    return mat


size = 768
u, v = np.meshgrid(np.linspace(0, 1, size, endpoint=False, dtype=np.float32), np.linspace(0, 1, size, endpoint=False, dtype=np.float32))
woods = []
for index in range(4):
    rng = np.random.default_rng(140 + index)
    warp = .10 * np.sin(2 * np.pi * v) + .04 * np.sin(6 * np.pi * v + index)
    grain = np.sin(2 * np.pi * (u * 44 + warp * 7))
    fibers = np.sin(2 * np.pi * (u * 160 + warp * 16))
    slow = wave_noise(u, v, 70 + index)
    knot = np.cos(2 * np.pi * (u * 18 + .15 * np.sin(2 * np.pi * v)))
    knot *= np.exp(-((v - (.28 + index * .12)) / .09) ** 2)
    tone = .028 * grain + .009 * fibers + .025 * slow + .018 * knot
    tone += rng.normal(0, .004, u.shape)
    base = np.array([.49, .38, .265]) + (index - 1.5) * .021
    color = image_map('oak_%02d_albedo' % index, base + tone[:, :, None])
    norm = normal_map('oak_%02d_normal' % index, grain * .08 + fibers * .012, 1.6)
    woods.append(textured('Oak / board tone %02d' % index, color, norm, .49, .24))

plaster_noise = soft_noise(u, v, 38, 7)
plaster_color = image_map('lime_plaster_albedo', np.array([.78, .758, .695]) + plaster_noise[:, :, None] * .013)
plaster_normal = normal_map('lime_plaster_normal', plaster_noise, 1.3)
plaster = textured('Warm lime plaster / fine texture', plaster_color, plaster_normal, .86, .22)
tile_noise = wave_noise(u, v, 84)
tile_color = image_map('sage_ceramic_albedo', np.array([.43, .48, .405]) + tile_noise[:, :, None] * .017)
tile_normal = normal_map('sage_ceramic_normal', tile_noise, 2.8)
sage = textured('Bathroom / muted sage ceramic', tile_color, tile_normal, .28, .22)
stone_color = image_map('porcelain_albedo', np.array([.58, .59, .555]) + wave_noise(u, v, 60)[:, :, None] * .025)
stone_normal = normal_map('porcelain_normal', wave_noise(u, v, 60), 1.8)
stone = textured('Bathroom / limestone porcelain', stone_color, stone_normal, .65, .25)
concrete_color = image_map('concrete_albedo', np.array([.38, .39, .37]) + wave_noise(u, v, 9)[:, :, None] * .027)
concrete_normal = normal_map('concrete_normal', wave_noise(u, v, 9), 2.5)
concrete = textured('Slab / concrete', concrete_color, concrete_normal, .9, .35)
paper_normal = normal_map('newspaper_normal', soft_noise(u, v, 572, 7), 2.0)
newspapers = []
for index in range(3):
    path = TEXTURES / ('newspaper_%02d_albedo.png' % index)
    if not path.is_file():
        raise FileNotFoundError('Generate original print maps with Tools/make_apartment_newspaper.py first: ' + str(path))
    image = bpy.data.images.load(str(path), check_existing=True)
    newspapers.append(textured('Newspaper / edition %02d' % index, image, paper_normal, .96, .18))
tape = plain('Window tape / aged masking paper', (.40, .35, .23), .83)
ivory = plain('Trim / bone-white enamel', (.69, .69, .63), .43)
black = plain('Windows / charcoal powdercoat', (.035, .042, .039), .34, .25)
metal = plain('Door hardware / brushed nickel', (.32, .35, .34), .25, .8)
grout = plain('Tile grout / light mineral', (.47, .48, .435), .9)
ceiling_mat = plain('Ceiling / soft white', (.78, .77, .73), .88)
glass = plain('Windows / clear architectural glass', (.8, .91, .94), .045)
glass.node_tree.nodes.get('Principled BSDF').inputs['Transmission Weight'].default_value = 1
glass.node_tree.nodes.get('Principled BSDF').inputs['IOR'].default_value = 1.45
emission = plain('Recessed luminaire / warm diffuser', (.95, .81, .59), .5)
emission.node_tree.nodes.get('Principled BSDF').inputs['Emission Color'].default_value = (1, .79, .52, 1)
emission.node_tree.nodes.get('Principled BSDF').inputs['Emission Strength'].default_value = 3.0


def box(name, location, dimensions, material, bevel=.012, group='structure', uv_scale=None, collection=architecture):
    bpy.ops.mesh.primitive_cube_add(size=1, location=location)
    obj = bpy.context.object
    obj.name = name
    obj.dimensions = dimensions
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    obj.data.materials.append(material)
    uv = obj.data.uv_layers.active
    for polygon in obj.data.polygons:
        axis = max(range(3), key=lambda n: abs(polygon.normal[n]))
        first, second = (0, 1) if axis == 2 else ((0, 2) if axis == 1 else (1, 2))
        for loop_index in polygon.loop_indices:
            point = obj.data.vertices[obj.data.loops[loop_index].vertex_index].co
            if uv_scale:
                uv.data[loop_index].uv = ((point[first] + location[first]) / uv_scale, (point[second] + location[second]) / uv_scale)
            else:
                uv.data[loop_index].uv = (point[first] / dimensions[first] + .5, point[second] / dimensions[second] + .5)
    if bevel:
        modifier = obj.modifiers.new('Small finished edges', 'BEVEL')
        modifier.width = min(bevel, min(dimensions) * .2)
        modifier.segments = 2
        modifier.harden_normals = True
        obj.modifiers.new('Weighted surface normals', 'WEIGHTED_NORMAL')
    put(obj, collection, group)
    return obj


def segment_x(name, x1, x2, y, z1, z2, group='north', mat=plaster, thickness=.18):
    return box(name, ((x1 + x2) / 2, y, (z1 + z2) / 2), (x2 - x1, thickness, z2 - z1), mat, group=group, uv_scale=1.0)


def segment_y(name, y1, y2, x, z1, z2, group='west', mat=plaster, thickness=.18):
    return box(name, (x, (y1 + y2) / 2, (z1 + z2) / 2), (thickness, y2 - y1, z2 - z1), mat, group=group, uv_scale=1.0)


def consolidate(group, name):
    objects = [o for o in groups[group] if o.type == 'MESH']
    bpy.ops.object.select_all(action='DESELECT')
    for obj in objects:
        bpy.context.view_layer.objects.active = obj
        for modifier in list(obj.modifiers):
            bpy.ops.object.modifier_apply(modifier=modifier.name)
        obj.select_set(True)
    bpy.context.view_layer.objects.active = objects[0]
    bpy.ops.object.join()
    # Bake the active piece's rotation after joining. Otherwise a joined tape
    # strip grid keeps a rotated frame and its engine AABB inflates unnecessarily.
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=False)
    joined = bpy.context.object
    joined.name = name
    groups[group] = [joined]
    return joined


# Clear interior: 7.8 x 6.2 metres. Bathroom: 2.5 x 2.3 metres in northwest.
X, Y, H = 3.9, 3.1, 2.8
box('Continuous structural floor slab', (0, 0, -.14), (8.16, 6.56, .22), concrete, .018, 'slab', 1)
rng = np.random.default_rng(53)
board_width, board_length = .195, 1.58
for column in range(40):
    x = -X + board_width * (column + .5)
    y = -Y - (column % 3) * .49
    while y < Y:
        start, end = max(-Y, y), min(Y, y + board_length)
        # Do not run timber through the separate tiled bathroom.
        if x < -1.28 and end > .72:
            end = min(end, .72)
        if end > start + .02:
            box('Oak floor board', (x, (start + end) / 2, -.014), (board_width - .0018, end - start - .0018, .028), woods[int(rng.integers(4))], .0015, 'oak_floor')
        y += board_length
consolidate('oak_floor', 'Oak floor | staggered individual boards')
box('Bathroom grout bed', (-2.595, 1.925, -.013), (2.59, 2.35, .025), grout, .001, 'bath_floor')
for ix in range(9):
    for iy in range(8):
        x1, x2 = -X + ix * .30, min(-1.30, -X + (ix + 1) * .30)
        y1, y2 = .75 + iy * .30, min(Y, .75 + (iy + 1) * .30)
        if x2 > x1 and y2 > y1:
            box('Porcelain floor tile', ((x1 + x2) / 2, (y1 + y2) / 2, -.002), (x2 - x1 - .004, y2 - y1 - .004, .018), stone, .0015, 'bath_floor')
consolidate('bath_floor', 'Bathroom floor | porcelain and grout')

# Windows are real wall apertures, assembled from solids rather than fake decals.
segment_x('North wall / bathroom and pier', -X - .09, -.45, Y + .09, 0, H)
segment_x('North window / below sill', -.45, 3.25, Y + .09, 0, .72)
segment_x('North window / lintel', -.45, 3.25, Y + .09, 2.52, H)
segment_x('North window / east pier', 3.25, X + .09, Y + .09, 0, H)
segment_y('West exterior wall', -Y - .18, Y + .18, -X - .09, 0, H)
segment_y('East exterior / southern pier', -Y - .18, -.70, X + .09, 0, H, 'east')
segment_y('East window / below sill', -.70, 1.80, X + .09, 0, .90, 'east')
segment_y('East window / lintel', -.70, 1.80, X + .09, 2.52, H, 'east')
segment_y('East exterior / northern pier', 1.80, Y + .18, X + .09, 0, H, 'east')
segment_x('South entry / west wall', -X - .09, 1.25, -Y - .09, 0, H, 'south')
segment_x('South entry / east wall', 2.27, X + .09, -Y - .09, 0, H, 'south')
segment_x('South entry / lintel', 1.25, 2.27, -Y - .09, 2.23, H, 'south')
segment_y('Bathroom / side partition', .75, Y, -1.30, 0, H, 'bath_partition', thickness=.13)
segment_x('Bathroom doorway / west pier', -X, -2.98, .75, 0, H, 'bath_partition', thickness=.13)
segment_x('Bathroom doorway / east pier', -2.04, -1.30, .75, 0, H, 'bath_partition', thickness=.13)
segment_x('Bathroom doorway / lintel', -2.98, -2.04, .75, 2.16, H, 'bath_partition', thickness=.13)
box('Complete ceiling slab', (0, 0, H + .09), (8.16, 6.56, .18), ceiling_mat, .01, 'ceiling')

# Recessed window frames: jambs, sill, rails, mullions and separate panes.
def window(name, center, width, height, side='north', bays=3):
    if side == 'east':
        center = Vector(center)
    def element(label, a, b, dims, mat):
        pos = (center[0] + a, center[1], center[2] + b)
        if side == 'east':
            pos = (center[0], center[1] + a, center[2] + b)
            dims = (dims[1], dims[0], dims[2])
        return box(name + ' / ' + label, pos, dims, mat, .003, side)
    for a in (-width / 2, width / 2):
        element('outer jamb', a, 0, (.055, .11, height + .055), black)
    for b in (-height / 2, height / 2):
        element('outer rail', 0, b, (width, .11, .055), black)
    for i in range(bays):
        a = -width / 2 + width / bays * (i + .5)
        pane = element('glass pane %d' % (i + 1), a, 0, (width / bays - .048, .008, height - .06), glass)
        # Cycles does not transmit direct sun reliably through refractive panes
        # without caustics. This rendering-only visibility flag admits sun rays;
        # the exported glass retains its ordinary glTF transmission material.
        pane.visible_shadow = False
        if i:
            element('mullion', -width / 2 + width / bays * i, 0, (.04, .09, height), black)
    element('stone interior sill', 0, -height / 2 - .025, (width + .17, .27, .045), stone)
window('Living room picture window', (1.40, Y + .05, 1.62), 3.65, 1.76, bays=3)
window('Side window', (X + .05, .55, 1.71), 2.46, 1.58, 'east', 2)


def newspaper_window(name, start, end, bottom, top, fixed, side, columns, seams):
    """Opaque, UV-mapped sheets with actual open seams in metres, not painted light.

    Adjacent sheets overlap except at the specified column seams. Wrinkles move
    in depth only, so they never accidentally seal the narrow light apertures.
    """
    step = (end - start) / columns
    middle = (bottom + top) / 2
    tape_group = side + '_newspaper_tape'
    for column in range(columns):
        left = start + column * step
        right = start + (column + 1) * step
        left += seams.get(column, -.012) / 2 if column else -.017
        right -= seams.get(column + 1, -.012) / 2 if column + 1 < columns else -.017
        for row in range(2):
            low, high = (bottom - .017, middle + .019) if row == 0 else (middle - .011, top + .017)
            # A shallow ruled grid adds folds and curled paper instead of rigid boxes.
            vertices, faces = [], []
            nu, nv = 8, 8
            for j in range(nv + 1):
                for i in range(nu + 1):
                    a, b = i / nu, j / nv
                    along, z = left + a * (right - left), low + b * (high - low)
                    ripple = .0025 * math.sin(a * 19 + column) * math.sin(b * 14 + row)
                    curl = .008 * (max(0, 1 - b * 8) ** 2) * math.sin(a * math.pi) ** 2
                    depth = fixed - row * .003 - ripple - curl
                    vertices.append((along, depth, z) if side == 'north' else (depth, along, z))
            for j in range(nv):
                for i in range(nu):
                    p = j * (nu + 1) + i
                    # North normal points inward (-Y); east inward (-X).
                    quad = (p, p + 1, p + nu + 2, p + nu + 1)
                    faces.append(quad if side == 'north' else tuple(reversed(quad)))
            mesh = bpy.data.meshes.new(name + ' / sheet mesh')
            mesh.from_pydata(vertices, [], faces)
            mesh.update()
            obj = bpy.data.objects.new(name + ' / newspaper %d-%d' % (column + 1, row + 1), mesh)
            architecture.objects.link(obj)
            put(obj, group=side)
            mesh.materials.append(newspapers[(column + row * 2 + (side == 'east')) % 3])
            uv = mesh.uv_layers.new(name='Print layout')
            for polygon in mesh.polygons:
                polygon.use_smooth = True
                for loop_index in polygon.loop_indices:
                    vi = mesh.loops[loop_index].vertex_index
                    a, b = vi % (nu + 1) / nu, vi // (nu + 1) / nv
                    # A person looking east sees increasing Y from right to left.
                    uv.data[loop_index].uv = (a if side == 'north' else 1 - a, b)
            solid = obj.modifiers.new('Paper thickness / opaque sunlight barrier', 'SOLIDIFY')
            solid.thickness = .0006
            obj['window_covering'] = 'Newspaper; actual gaps between sheets admit sunlight'
            obj['print_faces_room'] = True
            for a, z in ((left + .10, high - .045), (right - .10, high - .045)):
                pos = (a, fixed - .006 - row * .003, z) if side == 'north' else (fixed - .006 - row * .003, a, z)
                dims = (.115, .0015, .032) if side == 'north' else (.0015, .115, .032)
                tab = box(name + ' / masking tape tab', pos, dims, tape, 0, tape_group)
                tab.rotation_euler[1 if side == 'north' else 0] = math.radians((-1 if column % 2 else 1) * 9)
    tape_mesh = consolidate(tape_group, name + ' / all tape tabs')
    # Include tape with the window when temporarily removing the east cutaway wall.
    groups[side].append(tape_mesh)


# Two narrow vertical seams in the picture window, one in the side window.
# All other joins overlap; sheets cover the glazing edge-to-edge.
newspaper_window('Living room picture window', -.425, 3.225, .74, 2.50, 3.064, 'north', 4, {1: .023, 3: .018})
newspaper_window('Side window', -.68, 1.78, .92, 2.50, 3.864, 'east', 3, {2: .025})

# Ceramic wainscot belongs to the bathroom only; top remains plaster.
def ceramic_wall(group, name, start, end, fixed, side):
    width = end - start
    rows, columns = 15, math.ceil(width / .20)
    for row in range(rows):
        offset = .10 if row % 2 else 0
        for column in range(-1, columns + 1):
            low = max(start, start + column * .20 + offset)
            high = min(end, start + (column + 1) * .20 + offset)
            if high - low < .008:
                continue
            z = .09 + row * .12
            location = ((low + high) / 2, fixed, z) if side == 'x' else (fixed, (low + high) / 2, z)
            dims = (high - low - .004, .014, .116) if side == 'x' else (.014, high - low - .004, .116)
            box(name, location, dims, sage, .002, group)
    consolidate(group, name)
ceramic_wall('tile_north', 'Bathroom / north sage tile wainscot', -X + .025, -1.37, Y - .012, 'x')
ceramic_wall('tile_west', 'Bathroom / west sage tile wainscot', .83, Y - .025, -X + .012, 'y')
ceramic_wall('tile_east', 'Bathroom / east sage tile wainscot', .83, Y - .025, -1.38, 'y')

# Continuous base trim and cap rails, broken at all doors.
for name, a, b, y, group in [('north', -1.27, X, Y - .03, 'north'), ('south_left', -X, 1.22, -Y + .03, 'south'), ('south_right', 2.30, X, -Y + .03, 'south'), ('bath_front_left', -X, -3.02, .665, 'bath_partition'), ('bath_front_right', -2, -1.23, .665, 'bath_partition')]:
    box('Baseboard / ' + name, ((a + b) / 2, y, .055), (b - a, .035, .11), ivory, .003, group)
for name, a, b, x, group in [('west', -Y, .69, -X + .03, 'west'), ('east', -Y, Y, X - .03, 'east'), ('bathroom external side', .75, Y, -1.205, 'bath_partition')]:
    box('Baseboard / ' + name, (x, (a + b) / 2, .055), (.035, b - a, .11), ivory, .003, group)
box('Bathroom tile top cap / north', (-2.60, Y - .025, 1.84), (2.5, .034, .038), ivory, .005, 'bath_partition')
box('Bathroom tile top cap / west', (-X + .025, 1.925, 1.84), (.034, 2.24, .038), ivory, .005, 'bath_partition')
box('Bathroom tile top cap / east', (-1.385, 1.925, 1.84), (.034, 2.24, .038), ivory, .005, 'bath_partition')


def cylinder(name, location, radius, depth, material, group, rotation=(0, 0, 0)):
    bpy.ops.mesh.primitive_cylinder_add(vertices=32, radius=radius, depth=depth, location=location, rotation=rotation)
    obj = bpy.context.object
    obj.name = name
    obj.data.materials.append(material)
    for face in obj.data.polygons:
        face.use_smooth = len(face.vertices) == 4
    put(obj, group=group)
    return obj


def door(name, x1, x2, y, height, angle, group, inward=1):
    width = x2 - x1
    for x in (x1 - .025, x2 + .025):
        box(name + ' / jamb', (x, y, height / 2), (.065, .185, height), ivory, .005, group)
        box(name + ' / architrave', (x, y - .107, height / 2), (.072, .024, height + .045), ivory, .005, group)
    box(name + ' / head', ((x1 + x2) / 2, y, height + .027), (width + .12, .185, .065), ivory, .005, group)
    box(name + ' / head casing', ((x1 + x2) / 2, y - .107, height + .027), (width + .17, .026, .075), ivory, .005, group)
    pivot = bpy.data.objects.new(name + ' / hinged leaf', None)
    architecture.objects.link(pivot)
    groups.setdefault(group, []).append(pivot)
    pivot.location = (x1 + .024, y, 0)
    leaf_width = width - .047
    parts = [box(name + ' / panel', (leaf_width / 2, 0, height / 2), (leaf_width, .045, height - .028), ivory if group == 'bath_door' else woods[2], .004, group)]
    # Architectural panel reveals and a real lever handle, no loose props.
    if group == 'bath_door':
        parts.append(box(name + ' / recessed panel', (leaf_width / 2, -.026, height * .52), (leaf_width - .18, .009, height - .29), ceiling_mat, .005, group))
    parts.append(cylinder(name + ' / handle rose', (leaf_width - .09, -.042, 1.02), .024, .025, metal, group, (math.pi / 2, 0, 0)))
    parts.append(box(name + ' / lever', (leaf_width - .133, -.068, 1.02), (.115, .018, .018), metal, .006, group))
    for part in parts:
        part.parent = pivot
    pivot.rotation_euler.z = math.radians(angle * inward)
    box(name + ' / threshold', ((x1 + x2) / 2, y, -.001), (width, .20, .018), stone, .002, group)
door('Apartment entrance', 1.25, 2.27, -Y -.075, 2.20, 24, 'entry_door')
door('Bathroom door', -2.98, -2.04, .75, 2.13, 72, 'bath_door')

# Fixed electrical plates and ceiling luminaires.
for x, y, z, side in [(-3.87, -.4, .3, 'west'), (3.87, -1.8, .3, 'east'), (.2, 3.07, .3, 'north'), (-1.22, 1.2, .3, 'bath_partition')]:
    dims = (.014, .07, .105) if side in ('west', 'east', 'bath_partition') else (.07, .014, .105)
    box('Fixed electrical outlet plate', (x, y, z), dims, ivory, .004, side)
box('Entrance light switch', (1.1, -3.06, 1.13), (.075, .018, .10), ivory, .004, 'south')
box('Bathroom light switch', (-1.93, .665, 1.13), (.075, .018, .10), ivory, .004, 'bath_partition')
for x, y in [(0, -1.25), (2.6, -1.25), (.05, 1.8), (2.6, 1.8), (-2.6, 1.9)]:
    cylinder('Recessed light / white rim', (x, y, H -.012), .071, .02, ivory, 'ceiling')
    cylinder('Recessed light / diffuser', (x, y, H -.025), .055, .004, emission, 'ceiling')

box('Bathroom ceiling ventilation grille', (-2.55, 2.30, H -.025), (.23, .23, .018), ivory, .004, 'ceiling')
for i in range(8):
    box('Ventilation grille slot', (-2.55, 2.225 + i * .02, H -.036), (.18, .006, .003), black, .001, 'ceiling')

# Separate presentation rig; only architecture is selected for glTF export.
world = bpy.data.worlds.new('Soft exterior daylight')
world.use_nodes = True
scene.world = world
world.node_tree.nodes['Background'].inputs['Color'].default_value = (.66, .75, .87, 1)
world.node_tree.nodes['Background'].inputs['Strength'].default_value = .09


def light(name, location, target, energy, color, size=4, kind='AREA'):
    data = bpy.data.lights.new(name, kind)
    data.energy = energy
    data.color = color
    if kind == 'AREA':
        data.shape = 'DISK'
        data.size = size
    if kind == 'SUN':
        data.angle = .012
    obj = bpy.data.objects.new(name, data)
    presentation.objects.link(obj)
    obj.visible_camera = False
    obj.visible_glossy = False
    obj.visible_transmission = False
    obj.location = location
    obj.rotation_euler = (Vector(target) - obj.location).to_track_quat('-Z', 'Y').to_euler()
    return obj
light('Sun / narrow newspaper seams', (9, 11, 9), (-2, -3, 0), 12.0, (1, .87, .66), kind='SUN')
light('North window daylight', (1.4, 3.45, 2.2), (0, 0, 1.0), 150, (.78, .87, 1), 3.8)
light('East window daylight', (4.3, .55, 2.1), (0, 0, 1), 90, (.80, .88, 1), 2.4)
light('Soft interior bounce', (0, -.3, 2.68), (0, 0, 0), 20, (1, .91, .77), 4.0)
light('Bathroom ceiling illumination', (-2.6, 1.9, 2.73), (-2.6, 1.9, 0), 65, (1, .90, .77), 1.3)
# Render-only dust makes shafts visible in air. It is never exported as geometry.
dust = bpy.data.materials.new('Presentation / subtle airborne dust')
dust.use_nodes = True
dust.node_tree.nodes.clear()
volume_output = dust.node_tree.nodes.new('ShaderNodeOutputMaterial')
scatter = dust.node_tree.nodes.new('ShaderNodeVolumeScatter')
scatter.inputs['Density'].default_value = .12
scatter.inputs['Anisotropy'].default_value = .25
dust.node_tree.links.new(scatter.outputs['Volume'], volume_output.inputs['Volume'])
atmosphere = box('Presentation dust volume (not exported)', (0, 0, H / 2), (7.79, 6.19, 2.79), dust, 0, collection=presentation)
atmosphere.display_type = 'WIRE'
backdrop = plain('Presentation ground / warm studio', (.32, .33, .30), .93)
box('Presentation ground (not exported)', (0, 0, -.43), (200, 200, .08), backdrop, 0, collection=presentation)


def camera(name, position, target, lens=22, ortho=None):
    data = bpy.data.cameras.new(name)
    data.lens = lens
    data.clip_start = .06
    data.clip_end = 300
    if ortho:
        data.type = 'ORTHO'
        data.ortho_scale = ortho
    obj = bpy.data.objects.new(name, data)
    presentation.objects.link(obj)
    obj.location = position
    obj.rotation_euler = (Vector(target) - obj.location).to_track_quat('-Z', 'Y').to_euler()
    return obj


views = {
    'cutaway': camera('01 / complete floorplan cutaway', (11, -13, 12), (0, 0, .9), ortho=11.8),
    'living': camera('02 / entry towards daylight', (-2.85, -2.7, 1.55), (1.35, 2.65, 1.30), 22),
    'entry': camera('03 / windows towards entry', (2.95, 2.5, 1.58), (-1.4, -1.4, 1.26), 20),
    'bathroom': camera('04 / inside bathroom', (-1.62, 1.08, 1.58), (-3.25, 2.65, 1.00), 20),
}
scene.camera = views['living']
scene.render.resolution_x = args.width
scene.render.resolution_y = round(args.width * 2 / 3)
scene.render.resolution_percentage = 100

# Preserve editable walls and remove backup clutter; textures are packed and portable.
for image in bpy.data.images:
    if image.source == 'FILE':
        image.pack()
bpy.ops.wm.save_as_mainfile(filepath=str(SOURCE / 'studio_apartment.blend'))
bpy.ops.object.select_all(action='DESELECT')
for obj in architecture.objects:
    obj.select_set(True)
bpy.ops.export_scene.gltf(filepath=str(ASSET / 'studio_apartment.glb'), export_format='GLB', use_selection=True, export_apply=True, export_animations=False, export_cameras=False, export_lights=False, export_extras=True, export_yup=True)

mesh_count = sum(obj.type == 'MESH' for obj in architecture.objects)
triangles = 0
for obj in architecture.objects:
    if obj.type == 'MESH':
        evaluated = obj.evaluated_get(bpy.context.evaluated_depsgraph_get())
        mesh = evaluated.to_mesh()
        mesh.calc_loop_triangles()
        triangles += len(mesh.loop_triangles)
        evaluated.to_mesh_clear()
manifest = {'blender': bpy.app.version_string, 'dimensions_m': [7.8, 6.2, 2.8], 'bathroom_m': [2.5, 2.3], 'architecture_meshes': mesh_count, 'triangles': triangles, 'render_samples': args.samples, 'furniture': False, 'render_device': scene.cycles.device, 'textures': 'Original albedo, tangent normal maps and newspaper typography; packed into native file and GLB', 'window_coverings': {'sheets': 14, 'material': 'Opaque wrinkled newspaper with original print and masking tape', 'north_seams_m': [.023, .018], 'east_seams_m': [.025], 'beams': 'Sunlight through real open gaps; dust volume belongs to presentation only'}, 'export': 'Y up, metre scale, only permanent architecture including newspaper/tape; no cameras/presentation lights/backdrop/dust', 'views': list(views)}
(ASSET / 'asset_manifest.json').write_text(json.dumps(manifest, indent=2) + '\n', encoding='utf-8')
print('APARTMENT geometry:', mesh_count, 'meshes,', triangles, 'triangles', flush=True)

for key in args.views.split(','):
    if key not in views:
        raise ValueError('Unknown view: ' + key)
    hidden = ('south', 'east', 'ceiling', 'entry_door') if key == 'cutaway' else ()
    atmosphere.hide_render = key == 'cutaway'
    for group in hidden:
        for obj in groups[group]:
            obj.hide_render = True
    scene.camera = views[key]
    scene.render.resolution_x = args.width
    scene.render.resolution_y = round(args.width * (.78 if key == 'cutaway' else 2 / 3))
    scene.render.resolution_percentage = 100
    scene.render.filepath = str(RENDERS / (key + '.png'))
    print('APARTMENT rendering:', key, flush=True)
    bpy.ops.render.render(write_still=True)
    for group in hidden:
        for obj in groups[group]:
            obj.hide_render = False
print('APARTMENT complete:', ASSET, RENDERS, flush=True)
