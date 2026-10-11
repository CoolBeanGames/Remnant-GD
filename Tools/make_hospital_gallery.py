"""Build a self-contained mobile gallery from real final hospital renders."""
from pathlib import Path
import base64
import html
import io
import json
from PIL import Image
ROOT=Path(__file__).resolve().parents[1];OUT=ROOT/'Reports/Hospital'
PROPS=ROOT/'Models/Interiors/HospitalProps'
GH='https://github.com/CoolBeanGames/Remnant-GD/tree/main/'
LABELS={'HospitalBed':'Rusted ward bed','BedsideCabinet':'Bedside cabinet','Wheelchair':'Abandoned wheelchair',
        'IVStand':'Empty IV stand','MedicalTrolley':'Instrument trolley','NursingCounter':'Nursing station counter',
        'HospitalDoor':'Open hospital door','WaitingBench':'Three-seat waiting bench'}
VIEWS=[('hallway','Long corridor / ward doors, grime and faded bloody footprints'),
       ('nursing_station','Nursing station / worn counter, old records and staff access'),
       ('cross_hall','Cross corridor / connected passages and waiting benches'),
       ('patient_room','South patient ward / two beds, IV stand and broken glazing'),
       ('treatment','Treatment room / examination bed and abandoned instruments'),
       ('north_ward','North patient ward / rusted furniture and dried floor staining'),
       ('windows','Broken windows / jagged shards, missing panes and wall smears'),
       ('overview','Temporary cutaway / six wards, treatment room, nursing station and both halls')]


def embed(path,width=1400):
    im=Image.open(path).convert('RGB')
    if im.width>width:im=im.resize((width,round(im.height*width/im.width)),Image.Resampling.LANCZOS)
    data=io.BytesIO();im.save(data,format='JPEG',quality=89,optimize=True)
    return 'data:image/jpeg;base64,'+base64.b64encode(data.getvalue()).decode()


def figure(path,caption,width=1400):
    return f'<figure><img loading="lazy" src="{embed(path,width)}" alt="{html.escape(caption)}"><figcaption>{html.escape(caption)}</figcaption></figure>'


def main():
    cards=[];rows=[];manifests=sorted(PROPS.glob('*/asset_manifest.json'));assert len(manifests)==8
    for path in manifests:
        info=json.loads(path.read_text());key=path.parent.name;title=LABELS[key]
        dims=' × '.join(str(v) for v in info['dimensions_blender_m'])+' m'
        pictures=[figure(OUT/key/f'{v}.png',title+' / '+v,1000) for v in ('front','rear','detail')]
        cards.append(f'<article class="asset" id="{key}" data-title="{title.lower()}"><header><span class="eyebrow">INDEPENDENT PROP / {len(cards)+1:02d}</span><h3>{title}</h3><p>{dims} · {info["triangles"]:,} triangles</p></header>'+pictures[0]+'<details><summary>Opposite and construction views</summary>'+''.join(pictures[1:])+f'</details><p class="links"><a href="{GH+info["native"]}">Editable Blender</a><a href="{GH+info["export"]}">Separate GLB</a></p></article>')
        rows.append(f'| {title} | [{Path(info["native"]).name}]({key}/Source/{Path(info["native"]).name}) | [{Path(info["export"]).name}]({key}/{Path(info["export"]).name}) | {dims} |')
    room=''.join(figure(OUT/f'{v}.png',caption) for v,caption in VIEWS)
    css='''*{box-sizing:border-box}html{scroll-behavior:smooth}body{margin:0;background:#131b18;color:#dadfd1;font:16px/1.6 system-ui,sans-serif}main{max-width:1350px;margin:auto;padding:40px 26px}a{color:#d79b90;text-underline-offset:5px}h1{font-size:clamp(54px,8vw,110px);line-height:.95;letter-spacing:-.065em;max-width:1050px;margin:28px 0}h2{font-size:36px;font-weight:500;letter-spacing:-.025em}h3{font-size:24px;font-weight:500;margin:12px 0}.eyebrow{font:12px ui-monospace,monospace;letter-spacing:.16em;color:#8ea397}.lead{max-width:800px;font-size:20px;color:#b5bfb3}.stats{display:flex;flex-wrap:wrap;gap:38px;border-block:1px solid #415249;padding:22px 0;margin:36px 0}.stats b{display:block;font-size:31px;font-weight:500}.stats span{font-size:13px;color:#b5bfb3}nav{display:flex;gap:24px;flex-wrap:wrap}.room{display:grid;grid-template-columns:1fr 1fr;gap:24px}.room figure:first-child{grid-column:1/-1}figure{margin:0}img{width:100%;height:auto;display:block;background:#283c31}figcaption{font:12px/1.5 ui-monospace,monospace;color:#a4b3a4;padding:10px 0}.catalog{display:grid;grid-template-columns:repeat(3,minmax(0,1fr));gap:25px}.asset{border-top:1px solid #4a6053;padding-top:20px}.asset header p{font:12px/1.5 ui-monospace,monospace;min-height:36px;color:#a4b3a4}.asset details{border-top:1px solid #4a6053;padding-top:6px}summary{cursor:pointer;padding:12px 0}.links{display:flex;flex-wrap:wrap;gap:18px;font-size:13px}input{width:100%;font:inherit;color:#dadfd1;background:#1d2c24;border:1px solid #596e61;padding:15px;margin:15px 0 28px}footer{border-top:1px solid #4a6053;margin-top:45px;padding-top:25px;color:#a4b3a4}.hidden{display:none}@media(max-width:1000px){.catalog{grid-template-columns:1fr 1fr}}@media(max-width:650px){main{padding:25px 16px}.room,.catalog{grid-template-columns:1fr}.lead{font-size:18px}.stats{gap:24px}h2{font-size:29px}}'''
    page='<!doctype html><html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>Remnant / Dilapidated hospital</title><style>'+css+'</style></head><body><main><div class="eyebrow">REMNANT · WARD C · BLENDER ENVIRONMENT · 11 OCTOBER 2026</div><h1>No one is on call.</h1><p class="lead">An abandoned hospital wing. Six wards open onto connected hallways, a treatment room and a nursing station. Broken glass, rusted medical equipment, damp plaster and dried blood mark what remains.</p><nav><a href="#room">Tour the hospital</a><a href="#catalog">Separate medical props</a><a href="'+GH+'Models/Interiors/DilapidatedHospital/hospital_assembly.blend">Editable assembly</a><a href="../index.html">Development summary</a></nav><div class="stats"><div><b>18 × 26 m</b><span>Hospital wing / 3.35 m ceilings</span></div><div><b>6 wards</b><span>Plus treatment room and nursing station</span></div><div><b>8 + 24</b><span>Actual environment and prop views</span></div><div><b>9</b><span>Separate native assets and GLBs</span></div></div><section id="room"><h2>Walk the wing</h2><p>Two intersecting 3.2 m hallways, seven ward/treatment doorways, a rear staff entrance and level floors keep the layout connected. Forty-eight window cells have physically open missing or broken centres. Original textured clinical surfaces carry damp, dust, dried pools, wall smears and faded shoe prints.</p><div class="room">'+room+'</div><p><a href="'+GH+'Models/Architecture/DilapidatedHospital/Source/dilapidated_hospital.blend">Independent architecture</a> · <a href="'+GH+'Models/Architecture/DilapidatedHospital/dilapidated_hospital.glb">Hospital shell GLB</a></p></section><section id="catalog"><h2>What the staff left behind</h2><p>Eight separate medical furniture sources, each with its own packed textures, GLB and three actual angles. The assembly uses 50 relative collection instances and reuses the existing independent telephone, mail and bin.</p><input id="search" type="search" placeholder="Find a medical prop…" aria-label="Filter hospital props"><div class="catalog">'+''.join(cards)+'</div></section><footer><p>Blender 4.5.1 LTS · Cycles / OptiX · Environment: 128 samples at 1800 × 1200. Props: 80 samples at 1000 × 1000. Original PBR image maps, packed native images and embedded Y-up engine exports. All final images were visually opened and reviewed.</p><p>Reusable art assets. Gameplay placement, collision and engine lighting require scene setup. Cameras, exterior paving and presentation lighting stay outside exports. The overview removes ceilings and two perimeter walls temporarily; the saved model remains complete.</p></footer></main><script>document.querySelector("#search").addEventListener("input",e=>{const q=e.target.value.trim().toLowerCase();document.querySelectorAll(".asset").forEach(a=>a.classList.toggle("hidden",!a.dataset.title.includes(q)))})</script></body></html>'
    (OUT/'index.html').write_text(page+'\n',encoding='utf-8',newline='\n')
    (PROPS/'README.md').write_text('# Independent hospital props\n\nEight textured metre-scale assets; Blender Z up, local front -Y, floor-contact pivots. GLBs use engine Y up. Each native source packs its used original hospital PBR maps and retains a useful default camera.\n\n| Asset | Editable source | Separate engine export | Blender X × Y × Z |\n| --- | --- | --- | --- |\n'+'\n'.join(rows)+'\n\nHospitalDoor has a named hinge with ten child parts, open 78 degrees by default. Frame and leaf remain independent meshes. Set the hinge rotation to zero for a closed door. The door is art; gameplay interaction and collision are not attached. Wheelchairs use actual tyre/rim/spoke geometry; bed frames and IV bases have separate casters and tubing. NursingCounter keeps the register and chart rack as local parts. Phone, loose mail and bin are linked separately in the assembled hospital.\n\nRebuild original maps with Tools/make_hospital_textures.py, then author with Blender Tools/model_hospital_props.py. Defaults: --assets all --samples 80 --width 1000. --assets accepts a comma-separated subset; --no-render writes sources and exports only. Reports/Hospital/<Key>/ contains front/rear/detail PNGs. Preserve sibling source folders for the relative linked hospital_assembly.blend.\n',encoding='utf-8',newline='\n')
    print('Hospital gallery: 32 embedded actual renders; eight searchable independent props')


if __name__=='__main__':main()
