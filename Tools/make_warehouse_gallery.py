"""Self-contained, phone-friendly gallery of the actual reviewed Blender renders."""
from pathlib import Path
import base64
import html
import io
import json
from PIL import Image

ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'Reports/Warehouse'
BASE=ROOT/'Models/Interiors/WarehouseMachinery'
GH='https://github.com/CoolBeanGames/Remnant-GD/tree/main/'
LABELS={'HydraulicPress':'Broken hydraulic press','IndustrialLathe':'Abandoned industrial lathe',
        'AirCompressor':'Failed air compressor','ControlCabinet':'Open electrical cabinet',
        'OfficeDesk':'Production office desk','DebrisKit':'Pallet, barrel and scattered debris'}
ROOM_VIEWS=[('production_floor','Production floor / tall trusses, broken glazing and the elevated office'),
            ('catwalk','Upper catwalk / weathered rails and the office entrance'),
            ('office','Production office / old paperwork and a view over the floor'),
            ('machines','Broken machinery / oxidized metal, exposed parts and oil stains'),
            ('exterior','Exterior / factory brickwork, broken window bays and corrugated roofing'),
            ('overview','Temporary architectural cutaway / the full layout, stair and mezzanine')]


def embed(path,width=1400):
    im=Image.open(path).convert('RGB')
    if im.width>width:im=im.resize((width,round(im.height*width/im.width)),Image.Resampling.LANCZOS)
    stream=io.BytesIO();im.save(stream,format='JPEG',quality=89,optimize=True)
    return 'data:image/jpeg;base64,'+base64.b64encode(stream.getvalue()).decode()


def figure(path,caption,width=1400):
    return f'<figure><img loading="lazy" src="{embed(path,width)}" alt="{html.escape(caption)}"><figcaption>{html.escape(caption)}</figcaption></figure>'


manifests=sorted(BASE.glob('*/asset_manifest.json'))
assert len(manifests)==6
room=''.join(figure(OUT/f'{v}.png',caption) for v,caption in ROOM_VIEWS)
cards=[];rows=[]
for path in manifests:
    info=json.loads(path.read_text());key=path.parent.name;title=LABELS[key]
    dimensions=' × '.join(str(v) for v in info['dimensions_blender_m'])+' m'
    pictures=[figure(OUT/key/f'{view}.png',title+' / '+view,1000) for view in ('front','rear','detail')]
    cards.append(f'<article class="asset" id="{key}" data-title="{title.lower()}"><header><span class="eyebrow">INDEPENDENT PROP / {len(cards)+1:02d}</span><h3>{title}</h3><p>{dimensions} · {info["triangles"]:,} triangles</p></header>'+pictures[0]+'<details><summary>Opposite and construction views</summary>'+''.join(pictures[1:])+f'</details><p class="links"><a href="{GH+info["native"]}">Editable Blender</a><a href="{GH+info["export"]}">Separate GLB</a></p></article>')
    rows.append(f'| {title} | [{Path(info["native"]).name}]({key}/Source/{Path(info["native"]).name}) | [{Path(info["export"]).name}]({key}/{Path(info["export"]).name}) | {dimensions} |')
css='''*{box-sizing:border-box}html{scroll-behavior:smooth}body{margin:0;background:#171713;color:#dedace;font:16px/1.6 system-ui,sans-serif}main{max-width:1350px;margin:auto;padding:40px 26px}a{color:#ce9671;text-underline-offset:5px}h1{font-size:clamp(54px,8vw,110px);line-height:.95;letter-spacing:-.065em;max-width:1050px;margin:28px 0}h2{font-size:36px;font-weight:500;letter-spacing:-.025em}h3{font-size:24px;font-weight:500;margin:12px 0}.eyebrow{font:12px ui-monospace,monospace;letter-spacing:.16em;color:#ae947b}.lead{max-width:800px;font-size:20px;color:#b9b7aa}.stats{display:flex;flex-wrap:wrap;gap:38px;border-block:1px solid #45453a;padding:22px 0;margin:36px 0}.stats b{display:block;font-size:31px;font-weight:500}.stats span{font-size:13px;color:#b9b7aa}nav{display:flex;gap:24px;flex-wrap:wrap}.room{display:grid;grid-template-columns:1fr 1fr;gap:24px}.room figure:first-child{grid-column:1/-1}figure{margin:0}img{width:100%;height:auto;display:block;background:#35362d}figcaption{font:12px/1.5 ui-monospace,monospace;color:#aeaa98;padding:10px 0}.catalog{display:grid;grid-template-columns:repeat(3,minmax(0,1fr));gap:25px}.asset{border-top:1px solid #555044;padding-top:20px}.asset header p{font:12px/1.5 ui-monospace,monospace;min-height:36px;color:#aaa999}.asset details{border-top:1px solid #555044;padding-top:6px}summary{cursor:pointer;padding:12px 0}.links{display:flex;flex-wrap:wrap;gap:18px;font-size:13px}input{width:100%;font:inherit;color:#dedace;background:#24241c;border:1px solid #6b6251;padding:15px;margin:15px 0 28px}footer{border-top:1px solid #555044;margin-top:45px;padding-top:25px;color:#aaa999}.hidden{display:none}@media(max-width:1000px){.catalog{grid-template-columns:1fr 1fr}}@media(max-width:650px){main{padding:25px 16px}.room,.catalog{grid-template-columns:1fr}.lead{font-size:18px}.stats{gap:24px}h2{font-size:29px}}'''
page='<!doctype html><html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>Remnant / Dilapidated warehouse</title><style>'+css+'</style></head><body><main><div class="eyebrow">REMNANT · BLENDER ENVIRONMENT · 11 OCTOBER 2026</div><h1>The last shift never ended.</h1><p class="lead">A neglected production hall. Broken windows, oxidized steel and stained concrete. Above the abandoned machines, a catwalk leads to the old production office.</p><nav><a href="#room">Tour the warehouse</a><a href="#catalog">Separate machines and props</a><a href="'+GH+'Models/Interiors/DilapidatedWarehouse/warehouse_assembly.blend">Editable assembly</a><a href="../index.html">Development summary</a></nav><div class="stats"><div><b>24 × 36 m</b><span>Production hall / 11.1 m roof ridge</span></div><div><b>4.2 m</b><span>Catwalk and production office level</span></div><div><b>6 + 18</b><span>Actual Cycles environment + prop views</span></div><div><b>7</b><span>Separate native assets and GLBs</span></div></div><section id="room"><h2>Inside the warehouse</h2><p>Real window openings with missing panes and jagged glass, a damaged rooflight, rolled-steel trusses, stairs and guardrails. Dirt, damp and oil collect around worn machinery. The complete architecture remains separate from every loose prop.</p><div class="room">'+room+'</div><p><a href="'+GH+'Models/Architecture/DilapidatedWarehouse/Source/dilapidated_warehouse.blend">Independent architectural source</a> · <a href="'+GH+'Models/Architecture/DilapidatedWarehouse/dilapidated_warehouse.glb">Warehouse GLB</a></p></section><section id="catalog"><h2>What the shift left behind</h2><p>Each new prop has its own packed Blender source, engine export and three reviewed angles. The office also reuses existing independent chair, phone, mail and bin assets.</p><input id="search" type="search" placeholder="Find a machine or prop…" aria-label="Filter warehouse props"><div class="catalog">'+''.join(cards)+'</div></section><footer><p>Blender 4.5.1 LTS · Cycles / OptiX · 128 samples at 1800 × 1200 for the environment; 80 samples at 1000 × 1000 for props. Original textured PBR surfaces, packed images and embedded Y-up exports. A linked assembly preserves all source assets.</p><p>Standalone art collection. Gameplay placement and collisions need engine scene setup. Daylight, exterior paving and airborne dust belong to the Blender presentation and are excluded from GLBs. The overview is a temporary cutaway; the saved source retains every wall and roof panel.</p></footer></main><script>document.querySelector("#search").addEventListener("input",e=>{const q=e.target.value.trim().toLowerCase();document.querySelectorAll(".asset").forEach(a=>a.classList.toggle("hidden",!a.dataset.title.includes(q)))})</script></body></html>'
(OUT/'index.html').write_text(page+'\n',encoding='utf-8',newline='\n')
(BASE/'README.md').write_text('''# Warehouse machinery and props

Six independent editable assets for the dilapidated warehouse. Blender Z up,
front -Y, metre scale and contact pivots at floor Z=0. GLBs convert to engine Y up.
All used PBR images are packed into the native sources and embedded into exports.

| Asset | Editable source | Separate engine export | Blender X × Y × Z |
| --- | --- | --- | --- |
'''+ '\n'.join(rows)+'''

ControlCabinet retains a five-child door assembly under a named hinge pivot.
Machines have separately modelled rams, chucks, rails, motors and damaged hoses;
these are art subparts, not runtime simulations. DebrisKit keeps its pallet,
barrel, rubble and timber separately selectable within its own reusable collection.
OfficeDesk includes fixed stationery; phone, chair, mail and bin remain separate
existing assets in the linked preview. No lights/backdrop/cameras enter the GLBs.

Run Tools/make_warehouse_textures.py using Python/Pillow/NumPy, then run
Tools/model_warehouse_machinery.py with Blender --background --python-exit-code 1.
Defaults: --assets all --samples 80 --width 1000. --assets accepts comma-separated
keys; --no-render rebuilds sources/exports without PNGs. Every new asset has
front/rear/detail PNGs in Reports/Warehouse/<Key>/ and the responsive gallery.

Tools/model_dilapidated_warehouse.py builds the separate shell and links these
assets into ../DilapidatedWarehouse/warehouse_assembly.blend. Preserve relative
folders. See the architecture README for structure, verification and engine limits.
''',encoding='utf-8',newline='\n')
print('Warehouse gallery: 24 embedded actual renders; six independently searchable props')
