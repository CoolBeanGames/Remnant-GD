"""Rebuild a self-contained phone gallery from actual Blender render outputs."""
from pathlib import Path
import base64
import html
import io
import json
from PIL import Image, ImageDraw, ImageFont

ROOT=Path(__file__).resolve().parents[1]
BASE=ROOT/'Models/Interiors/StudioFurniture'
OUT=ROOT/'Reports/StudioFurniture'
GITHUB='https://github.com/CoolBeanGames/Remnant-GD/tree/main/'


def embed(path, width=1000):
    im=Image.open(path).convert('RGB')
    if im.width>width:
        im=im.resize((width,round(im.height*width/im.width)),Image.Resampling.LANCZOS)
    stream=io.BytesIO()
    im.save(stream,format='JPEG',quality=88,optimize=True)
    return 'data:image/jpeg;base64,'+base64.b64encode(stream.getvalue()).decode()


manifests=[json.loads(p.read_text()) for p in sorted(BASE.glob('*/asset_manifest.json'))]
assert len(manifests)==18
labels={'TableAndChairs':'Table and two dining chairs','Chair':'Armchair','CoffeePot':'Coffee pot / drip maker',
        'LandlinePhone':'Landline phone','EntertainmentCenter':'Entertainment center',
        'PottedPlant':'Potted plant','PileOfMail':'Pile of mail','FamilyPhoto':'Family photo',
        'Kitchenette':'Kitchenette cabinetry and counter','TrashCan':'Trash can'}
room=[]
for view,caption in [('living','Living area / newspaper-filtered daylight'),('entry','Across the room / entry and old electronics'),('kitchen','Kitchenette / aged appliances and real sink opening'),('cutaway','Complete arrangement / temporary architectural cutaway')]:
    room.append('<figure><img loading="lazy" src="'+embed(ROOT/'Reports/FurnishedStudio'/(view+'.png'),1400)+'" alt="'+caption+'"><figcaption>'+caption+'</figcaption></figure>')
cards=[]
rows=[]
for i in manifests:
    key=i['key']
    title=labels.get(key,key)
    dims=' × '.join(str(v) for v in i['dimensions_blender_m'])+' m'
    images=[]
    for view in ('front','rear','detail'):
        images.append('<figure><img loading="lazy" src="'+embed(OUT/key/(view+'.png'))+'" alt="'+title+' / '+view+'"><figcaption>'+view.title()+'</figcaption></figure>')
    cards.append('<article class="asset" id="'+key+'" data-title="'+title.lower()+'"><header><span class="index">PROP / '+str(len(cards)+1).zfill(2)+'</span><h3>'+title+'</h3><p>'+dims+' · '+f"{i['triangles']:,}"+' triangles</p></header>'+images[0]+'<details><summary>Rear and detail views</summary>'+''.join(images[1:])+'</details><p class="links"><a href="'+GITHUB+i['native']+'">Editable .blend</a><a href="'+GITHUB+i['export']+'">Separate GLB</a></p></article>')
    rows.append('| '+title+' | ['+Path(i['native']).name+']('+key+'/Source/'+Path(i['native']).name+') | ['+Path(i['export']).name+']('+key+'/'+Path(i['export']).name+') | '+dims+' |')
css='''*{box-sizing:border-box}html{scroll-behavior:smooth}body{margin:0;background:#151710;color:#e1dbc9;font:16px/1.55 system-ui,sans-serif}main{max-width:1260px;margin:auto;padding:40px 24px}a{color:#e2c594;text-underline-offset:4px}h1{font-size:clamp(46px,7vw,96px);line-height:.98;letter-spacing:-.06em;max-width:900px;margin:22px 0}h2{font-size:34px;font-weight:500}.eyebrow,.index{font:12px ui-monospace,monospace;letter-spacing:.15em;color:#b7ac91}.lead{max-width:750px;color:#bcb7a7;font-size:19px}.stats{display:flex;gap:32px;flex-wrap:wrap;border-block:1px solid #4a4b3a;padding:20px 0;margin:30px 0}.stats b{font-size:28px;display:block}.stats span{font-size:13px;color:#bcb7a7}nav{display:flex;gap:22px;flex-wrap:wrap}figure{margin:0}img{width:100%;display:block;background:#777b70}figcaption{font:12px ui-monospace,monospace;padding:10px 0;color:#b7ac91}.room{display:grid;gap:24px;margin:24px 0}.room figure:first-child{grid-column:1/-1}.catalog{display:grid;grid-template-columns:repeat(3,minmax(0,1fr));gap:24px}.asset{border-top:1px solid #4a4b3a;padding-top:18px}.asset h3{font-size:23px;margin:7px 0}.asset header p{font:12px ui-monospace;color:#bcb7a7;min-height:30px}.asset details{border-top:1px solid #4a4b3a;padding-top:8px}summary{cursor:pointer;padding:8px 0}.links{display:flex;gap:20px;font-size:13px}input{width:100%;border:1px solid #75745e;background:#20231a;color:#e1dbc9;padding:15px;font:inherit;margin:10px 0 30px}footer{border-top:1px solid #4a4b3a;margin-top:50px;padding-top:24px;color:#bcb7a7}.hidden{display:none}@media(min-width:800px){.room{grid-template-columns:1fr 1fr}}@media(max-width:950px){.catalog{grid-template-columns:1fr 1fr}}@media(max-width:600px){main{padding:25px 16px}.catalog{grid-template-columns:1fr}.lead{font-size:17px}.stats{gap:22px}h2{font-size:29px}}'''
page='<!doctype html><html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>Remnant / Worn studio and furniture</title><style>'+css+'</style></head><body><main><div class="eyebrow">REMNANT · BLENDER ASSET STUDY · 11 OCTOBER 2026</div><h1>Someone lived here.</h1><p class="lead">A neglected studio: stained plaster, scuffed timber, newspaper-covered windows and a compact kitchenette. Seventeen requested furniture assets and one cabinetry asset stay independent and reusable.</p><nav><a href="#room">The furnished room</a><a href="#catalog">All furniture / three angles each</a><a href="'+GITHUB+'Models/Interiors/StudioFurniture">Asset files</a><a href="../index.html">Development summary</a></nav><div class="stats"><div><b>18</b><span>Separate furniture sources + exports</span></div><div><b>54 + 4</b><span>Actual Blender prop + room renders</span></div><div><b>19</b><span>Linked assets in the room preview</span></div></div><section id="room"><h2>The worn apartment</h2><p>Room shell and furniture are separate Blender libraries. The assembly contains instances, so editing a source updates its presentation. Paper seams still admit sunlight.</p><div class="room">'+''.join(room)+'</div><p><a href="'+GITHUB+'Models/Interiors/FurnishedStudio/studio_apartment_furnished.blend">Open the linked furnished assembly</a> · <a href="'+GITHUB+'Models/Architecture/StudioApartment/Source/studio_apartment.blend">Independent room shell</a></p></section><section id="catalog"><h2>The furniture collection</h2><p>Front, opposite and construction/detail view for every asset. Select “Rear and detail views” to see the additional angles.</p><input id="search" type="search" aria-label="Filter furniture" placeholder="Find an item…"><div class="catalog">'+''.join(cards)+'</div></section><footer><p>Blender 4.5.1 LTS · Cycles / OptiX · 64 samples for props, 128 for the assembled room. Finished UVs and packed PBR maps; separate metre-scale Y-up GLBs. Fictional family-photo bitmap generated for the frame; other maps and paper artwork are original procedural/type work.</p><p>These are reusable art assets. The Blender preview uses its own lighting and dust; engine colliders, interactions and equivalent lighting need game scene setup. Keep the repository’s relative folder layout for the linked assembly.</p></footer></main><script>document.querySelector("#search").addEventListener("input",e=>{const q=e.target.value.toLowerCase();document.querySelectorAll(".asset").forEach(x=>x.classList.toggle("hidden",!x.dataset.title.includes(q)))})</script></body></html>'
(OUT/'index.html').write_text(page+'\n',encoding='utf-8',newline='\n')
readme='''# Worn studio furniture

Seventeen requested furniture assets plus a separate kitchenette cabinet/counter
unit. Every asset has its own editable native file, packed maps and metre-scale
Y-up GLB. Front is Blender -Y; up is Z. Origins are bottom-centred, except the sink
which inserts at countertop height and extends below that plane.

| Asset | Editable Blender source | Engine export | Blender bounds (X × Y × Z) |
| --- | --- | --- | --- |
'''+ '\n'.join(rows)+'''

The [linked furnished preview](../FurnishedStudio/studio_apartment_furnished.blend)
instances all 18 items and the independent architectural shell. Preserve the
repository directory layout so relative Blender library links resolve. Furniture
is never joined into the room. Presentation lights/cameras/floor/dust are excluded
from the individual GLBs. Doors, the telephone receiver and frame stand retain
local pivots for later animation; no runtime animations or collisions are added.

Materials use original albedo, tangent-normal and roughness PNGs in Textures/,
packed into each native source and embedded into GLB. Metal and glass have deliberate
Principled PBR settings. Mail print and product labels are original typography.
family_photo.png is an AI-generated fictional photograph, used only as the framed
picture texture. No external licensed models or downloaded texture libraries.

Rebuild with Tools/make_studio_furniture_textures.py (Python/Pillow/NumPy), then
Tools/model_studio_furniture.py in Blender. --assets all, --samples 64 and --width
1000 reproduce the delivered assets and three view PNGs per item. --no-render is
available for export-only rebuilds. Tools/assemble_worn_studio.py ages the room
shell and links the furniture into its native preview, then renders four room views
at 1800 pixels wide. Rebuild the room shell first with model_studio_apartment.py
when structural changes are desired. The assembly ageing pass is idempotent.

Before first engine import, run Tools/configure_studio_imports.py to keep embedded
maps inside the imported resources and preserve existing sidecars and UIDs.
Run Tools/verify_studio_furniture.py for file/GLB/UV/material/render checks and
Tools/verify_studio_native.py through Blender for packed-source, pivot/library and
complete-visibility checks. Tests/studio_asset_import_test.gd checks imported mesh
counts, textured surfaces and metre-scale bounds after the Y-up conversion.
Godot editor import and Windows release/startup checks
are also part of delivery. Successful import does not make these props physics-ready.

Reports/StudioFurniture/index.html is a self-contained responsive gallery of every
item and all four room angles. Full PNGs are under Reports/StudioFurniture/<Asset>/
and Reports/FurnishedStudio/. Earlier Reports/StudioApartment renders retain the
unfurnished newspaper-window study as development history.
'''
(BASE/'README.md').write_text(readme,encoding='utf-8',newline='\n')
# A compact visual index complements the full-resolution three-angle gallery.
sheet=Image.new('RGB',(1920,1080),'#151710')
draw=ImageDraw.Draw(sheet)
try:
    font=ImageFont.truetype('C:/Windows/Fonts/arial.ttf',17)
except OSError:
    font=ImageFont.load_default()
for n,info in enumerate(manifests):
    x,y=(n%6)*320,(n//6)*360
    thumb=Image.open(OUT/info['key']/'front.png').convert('RGB')
    thumb=thumb.resize((320,320),Image.Resampling.LANCZOS)
    sheet.paste(thumb,(x,y))
    draw.text((x+10,y+331),labels.get(info['key'],info['key']),font=font,fill='#e1dbc9')
sheet.save(OUT/'collection.jpg',quality=92)
print('STUDIO GALLERY: 18 assets / 58 embedded actual Blender render images')
