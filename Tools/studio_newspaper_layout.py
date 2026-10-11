"""Ragged, overlapping newspaper clippings with geometric daylight holes.

Shared by the structural room builder and the in-place art revision. The atlas is
a generated fictional newspaper scan; geometry, crop choices and folds are seeded.
Blender -Y faces the north window; -X faces the east window. No painted light.
"""
import math
import random
from pathlib import Path

import bpy

ROOT = Path(__file__).resolve().parents[1]
TEXTURES = ROOT / 'Models/Architecture/StudioApartment/Textures'


def paper_material():
    name = 'Newspaper / faded photographic clippings'
    material = bpy.data.materials.get(name) or bpy.data.materials.new(name)
    material.use_nodes = True
    nodes, links = material.node_tree.nodes, material.node_tree.links
    nodes.clear()
    output = nodes.new('ShaderNodeOutputMaterial')
    shader = nodes.new('ShaderNodeBsdfPrincipled')
    shader.inputs['Roughness'].default_value = .97
    image = bpy.data.images.load(str(TEXTURES/'newsprint_scan_atlas.png'), check_existing=True)
    image.pack()
    texture = nodes.new('ShaderNodeTexImage')
    texture.image = image
    links.new(texture.outputs['Color'], shader.inputs['Base Color'])
    normal_image = bpy.data.images.load(str(TEXTURES/'newspaper_normal.png'), check_existing=True)
    normal_image.colorspace_settings.name = 'Non-Color'
    normal_image.pack()
    normal_texture = nodes.new('ShaderNodeTexImage')
    normal_texture.image = normal_image
    normal = nodes.new('ShaderNodeNormalMap')
    normal.inputs['Strength'].default_value = .12
    links.new(normal_texture.outputs['Color'], normal.inputs['Color'])
    links.new(normal.outputs['Normal'], shader.inputs['Normal'])
    links.new(shader.outputs['BSDF'], output.inputs['Surface'])
    return material


def cover_window(collection, name, start, end, bottom, top, fixed, side):
    rng = random.Random(618 if side == 'north' else 922)
    width, height = end-start, top-bottom
    columns, rows = (5 if side == 'north' else 4), 4
    material = paper_material()
    objects = []
    # Shared masks cut every overlapping layer, keeping these openings real.
    openings = [(.11,.145,.17,.32),(.285,.33,.64,.71),
                (.475,.493,.08,.34),(.478,.501,.47,.73),
                (.70,.738,.31,.40),(.85,.884,.80,.87)]
    if side == 'east':
        openings = [(.16,.19,.12,.39),(.38,.435,.57,.65),
                    (.61,.632,.26,.55),(.81,.858,.74,.82)]

    def open_at(x, z):
        u, v = (x-start)/width, (z-bottom)/height
        return any(a < u < b and c < v < d for a,b,c,d in openings)

    recipes = []
    for row in range(rows):
        for column in range(columns):
            cx=start+(column+.5)*width/columns+rng.uniform(-.024,.024)
            cz=bottom+(row+.5)*height/rows+rng.uniform(-.022,.022)
            recipes.append((cx,cz,width/columns*rng.uniform(1.10,1.22),
                            height/rows*rng.uniform(1.12,1.24),rng.uniform(-4.5,4.5),row%2))
    # Smaller pasted-over repairs break up the base page edges and editorial grids.
    for _ in range(7 if side == 'north' else 5):
        recipes.append((rng.uniform(start+.16,end-.16),rng.uniform(bottom+.15,top-.15),
                        rng.uniform(.22,.48),rng.uniform(.16,.34),rng.uniform(-10,10),3))

    tape_vertices, tape_faces = [], []
    for index,(cx,cz,w,h,angle,layer) in enumerate(recipes):
        nu,nv=12,14
        vertices, uv_points, faces = [], [], []
        theta=math.radians(angle)
        # Crop an inside-page article, instead of repeating whole front pages.
        quadrant=index%4
        crop_w,crop_h=rng.uniform(.26,.46),rng.uniform(.22,.45)
        crop_x=(quadrant%2)*.5+rng.uniform(.012,.48-crop_w)
        crop_y=(quadrant//2)*.5+rng.uniform(.012,.48-crop_h)
        for j in range(nv+1):
            for i in range(nu+1):
                a,b=i/nu,j/nv
                x,z=(a-.5)*w,(b-.5)*h
                if i in (0,nu): x+=rng.uniform(-.011,.011)
                if j in (0,nv): z+=rng.uniform(-.010,.010)
                along=cx+x*math.cos(theta)-z*math.sin(theta)
                high=cz+x*math.sin(theta)+z*math.cos(theta)
                along=max(start-.018,min(end+.018,along))
                high=max(bottom-.018,min(top+.018,high))
                wrinkle=.0015*math.sin(a*29+index)*math.sin(b*21+index*.3)
                crease=.003*math.exp(-((a-.38)*40)**2)
                curl=.008*(max(0,1-b*6)**2)*(math.sin(a*math.pi)**2)
                depth=fixed-.005-layer*.011-wrinkle-crease-curl
                vertices.append((along,depth,high) if side=='north' else (depth,along,high))
                # East is mirrored in world space so the print reads from inside.
                uv_points.append((crop_x+(a if side=='north' else 1-a)*crop_w,crop_y+b*crop_h))
        for j in range(nv):
            for i in range(nu):
                p=j*(nu+1)+i
                ids=(p,p+1,p+nu+2,p+nu+1)
                centre=[sum(vertices[k][axis] for k in ids)/4 for axis in range(3)]
                along=centre[0 if side=='north' else 1]
                if open_at(along,centre[2]): continue
                # A few missing edge cells create small torn corner notches.
                if (i in (0,nu-1) or j in (0,nv-1)) and rng.random()<.025: continue
                faces.append(ids if side=='north' else tuple(reversed(ids)))
        mesh=bpy.data.meshes.new(name+' / clipping mesh')
        mesh.from_pydata(vertices,[],faces)
        mesh.update()
        uv=mesh.uv_layers.new(name='Cropped newsprint')
        for poly in mesh.polygons:
            poly.use_smooth=True
            for li in poly.loop_indices:
                uv.data[li].uv=uv_points[mesh.loops[li].vertex_index]
        obj=bpy.data.objects.new(f'{name} / newspaper clipping {index+1:02d}',mesh)
        collection.objects.link(obj)
        mesh.materials.append(material)
        solid=obj.modifiers.new('Thin paper edges','SOLIDIFY')
        solid.thickness=.00035
        obj['window_covering']='Overlapping torn newspaper clipping; geometric light openings'
        obj['print_faces_room']=True
        obj['atlas_crop']=[crop_x,crop_y,crop_w,crop_h]
        objects.append(obj)
        if index%3==0:
            along=cx+rng.uniform(-w*.25,w*.25)
            high=min(top-.02,cz+h*.44)
            tw,th=rng.uniform(.035,.075),rng.uniform(.022,.037)
            depth=fixed-.010-layer*.011
            p=len(tape_vertices)
            tape_vertices.extend([(along-tw/2,depth,high-th/2),(along+tw/2,depth,high-th/2),
                                  (along+tw/2,depth,high+th/2),(along-tw/2,depth,high+th/2)] if side=='north' else
                                 [(depth,along-tw/2,high-th/2),(depth,along+tw/2,high-th/2),
                                  (depth,along+tw/2,high+th/2),(depth,along-tw/2,high+th/2)])
            ids=(p,p+1,p+2,p+3)
            tape_faces.append(ids if side=='north' else tuple(reversed(ids)))
    tape=bpy.data.materials.get('Window tape / grey aged adhesive') or bpy.data.materials.new('Window tape / grey aged adhesive')
    tape.use_nodes=True
    tape.node_tree.nodes['Principled BSDF'].inputs['Base Color'].default_value=(.27,.255,.22,1)
    tape.node_tree.nodes['Principled BSDF'].inputs['Roughness'].default_value=.96
    mesh=bpy.data.meshes.new(name+' / adhesive tabs')
    mesh.from_pydata(tape_vertices,[],tape_faces)
    uv=mesh.uv_layers.new(name='Adhesive tabs')
    for poly in mesh.polygons:
        for n,li in enumerate(poly.loop_indices):
            uv.data[li].uv=((0,0),(1,0),(1,1),(0,1))[n]
    mesh.materials.append(tape)
    obj=bpy.data.objects.new(name+' / all tape tabs',mesh)
    collection.objects.link(obj)
    objects.append(obj)
    return objects


def replace_coverings(collection):
    for obj in list(collection.objects):
        if obj.get('window_covering') or '/ all tape tabs' in obj.name:
            mesh=obj.data if obj.type=='MESH' else None
            bpy.data.objects.remove(obj,do_unlink=True)
            if mesh and mesh.users==0:
                bpy.data.meshes.remove(mesh)
    north=cover_window(collection,'Living room picture window',-.425,3.225,.74,2.50,3.064,'north')
    east=cover_window(collection,'Side window',-.68,1.78,.92,2.50,3.864,'east')
    return north+east
