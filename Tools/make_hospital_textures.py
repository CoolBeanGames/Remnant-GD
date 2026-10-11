"""Original clinical surfaces and dried-blood decals; deterministic, no downloads."""
from pathlib import Path
import numpy as np
from PIL import Image, ImageDraw, ImageFilter

ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'Models/Architecture/DilapidatedHospital/Textures'
OUT.mkdir(parents=True,exist_ok=True);(OUT/'.gdignore').write_text('')
N=1024
y,x=np.mgrid[0:N,0:N]/N


def noise(seed,frequencies=(5,17,55,190)):
    rng=np.random.default_rng(seed);out=np.zeros((N,N))
    for i,f in enumerate(frequencies):
        a=np.pad(rng.random((f,f)),1,mode='wrap')
        im=Image.fromarray(np.uint8(a*255)).resize((N+2*N//f,N+2*N//f),Image.Resampling.BICUBIC)
        s=N//f;out+=np.asarray(im)[s:s+N,s:s+N]/255/2**i
    return out/sum(1/2**i for i in range(len(frequencies)))


def save(key,colour,height,rough,metal=None):
    colour=np.broadcast_to(colour,(N,N,3))
    Image.fromarray(np.uint8(np.clip(colour,.007,.98)*255)).save(OUT/f'{key}_albedo.png')
    dy,dx=np.gradient(height);normal=np.stack((-dx*28,-dy*28,np.ones_like(dx)),axis=-1)
    normal/=np.linalg.norm(normal,axis=-1)[...,None]
    Image.fromarray(np.uint8((normal*.5+.5)*255)).save(OUT/f'{key}_normal.png')
    Image.fromarray(np.uint8(np.clip(rough+np.zeros((N,N)),.08,.99)*255)).save(OUT/f'{key}_roughness.png')
    if metal is not None:Image.fromarray(np.uint8(np.clip(metal+np.zeros((N,N)),0,1)*255)).save(OUT/f'{key}_metallic.png')


fine=noise(509,(30,90,260,480));macro=noise(510)
for key,base,seed in [('plaster',[.58,.565,.48],511),('sage',[.27,.37,.32],512),('cream',[.61,.59,.47],513)]:
    h=noise(seed);chips=np.clip((noise(seed+30)-.54)*10,0,1)
    dirt=np.clip((macro-.53)*5,0,.7)
    col=np.array(base)+(h-.5)[...,None]*.16
    col=col*(1-chips[...,None])+np.array([.34,.32,.28])*chips[...,None]
    col*=1-dirt[...,None]*.45
    save(key,col,h*.4+chips*.7,.79+chips*.16)

# A one-metre tile repeat: four 25cm tiles with dark grout, stains and fine cracks.
joint=((x*4)%1<.016)|((y*4)%1<.016)
tiles=np.floor(x*4)+4*np.floor(y*4)
tilevar=np.random.default_rng(77).uniform(-.055,.055,16)[tiles.astype(int)]
crack_im=Image.new('L',(N,N));d=ImageDraw.Draw(crack_im);rng=np.random.default_rng(64)
for start in [(140,0),(N,750),(320,N)]:
    points=[start]
    for i in range(20):
        a=rng.uniform(-1,1)+i*.13
        points.append((points[-1][0]+np.cos(a)*22,points[-1][1]-np.sin(a)*30))
    d.line(points,fill=210,width=2)
crack=np.asarray(crack_im)/255
col=np.array([.47,.49,.43])+(fine-.5)[...,None]*.1+tilevar[...,None]
col-=np.clip((macro-.45)*.35,0,.15)[...,None]+crack[...,None]*.25
col[joint]=[.12,.135,.12]
save('tile',col,fine*.2+(~joint)*.2-crack*.12,.68+(macro-.5)*.25)
col=np.array([.28,.32,.29])+(macro-.5)[...,None]*.18+(fine-.5)[...,None]*.1
scuffs=np.sin(x*130+y*19)*.5+.5
save('vinyl',col-scuffs[...,None]*.015,fine*.17,.83)
save('concrete',np.array([.33,.325,.30])+(macro-.5)[...,None]*.2,fine*.7+macro*.4,.94)
oxide=noise(640)
rust=np.array([.25,.115,.047])+(oxide-.5)[...,None]*np.array([.31,.13,.055])
save('rust',rust,oxide,.88,.14)
chips=np.clip((noise(645)-.54)*12,0,1)
paint=np.array([.60,.62,.55])+(fine-.5)[...,None]*.1
save('enamel',paint*(1-chips[...,None])+rust*chips[...,None],fine*.15+chips*.5,.48+chips*.42,chips*.4)
save('steel',np.array([.34,.365,.35])+(fine-.5)[...,None]*.08,fine*.18,.44+(macro-.5)*.25,.9)
save('rubber',np.array([.024,.030,.027])+(fine-.5)[...,None]*.025,fine*.22,.82)
cloth=noise(811,(8,32,140,350));weave=(np.sin(x*1024*1.7)+np.sin(y*1024*1.7))*.009
save('fabric',np.array([.50,.48,.38])+(cloth-.5)[...,None]*.25,cloth*.25+weave,.96)

for key,colour,seed in [('damp',[31,35,26],50),('dust',[80,75,56],55)]:
    alpha=np.clip((np.sin(np.pi*x)*np.sin(np.pi*y))**1.1*(noise(seed)*1.1+.12),0,.9)
    rgba=np.zeros((N,N,4),dtype=np.uint8);rgba[...,:3]=colour;rgba[...,3]=np.uint8(alpha*255)
    Image.fromarray(rgba).save(OUT/f'{key}_decal.png')

# Separate pool, directional wall smear and footprints prevent repeated identical splats.
for key in ('blood_pool','blood_smear','blood_steps'):
    mask=Image.new('L',(N,N));d=ImageDraw.Draw(mask);rng=np.random.default_rng(922+len(key))
    if key=='blood_pool':
        for i in range(110):
            cx,cy=rng.normal(500,130,2);rx,ry=rng.uniform(20,160,2)
            d.ellipse((cx-rx,cy-ry,cx+rx,cy+ry),fill=int(rng.uniform(100,235)))
        for i in range(90):
            cx,cy=rng.uniform(90,930,2);r=rng.uniform(2,10)
            d.ellipse((cx-r,cy-r,cx+r,cy+r),fill=170)
    elif key=='blood_smear':
        for i in range(80):
            cx=rng.uniform(180,820);cy=rng.uniform(420,770)
            d.line([(cx,cy),(cx+rng.uniform(-50,80),cy-rng.uniform(80,390))],fill=int(rng.uniform(80,220)),width=int(rng.uniform(4,19)))
        for i in range(7):
            cx=340+i*42;d.ellipse((cx,470,cx+80,690),fill=200)
    else:
        for i in range(5):
            cx=360 if i%2 else 620;cy=90+i*165
            d.ellipse((cx-45,cy-55,cx+45,cy+75),fill=150)
            d.ellipse((cx-32,cy+95,cx+32,cy+125),fill=130)
            for j in range(3):d.line([(cx-50,cy+j*25),(cx+50,cy+j*25)],fill=45,width=7)
    alpha=np.asarray(mask.filter(ImageFilter.GaussianBlur(1.4)))/255
    alpha*=np.clip((noise(201)-.28)*2,0,1)
    rgba=np.zeros((N,N,4),dtype=np.uint8)
    rgba[...,:3]=np.uint8(np.clip(np.array([.34,.038,.021])+(noise(311)-.5)[...,None]*np.array([.13,.022,.018]),0,1)*255)
    rgba[...,3]=np.uint8(np.clip(alpha*1.15,0,.95)*255)
    Image.fromarray(rgba).save(OUT/f'{key}_decal.png')
(OUT/'PROVENANCE.md').write_text('# Hospital texture provenance\n\nOriginal deterministic NumPy/Pillow maps authored for this wing by Tools/make_hospital_textures.py. No downloaded images or models. Eleven portable PBR surfaces: clinical plaster, sage paint, cream laminate, dirty tile, worn vinyl, concrete, oxidized metal, chipped enamel, steel, rubber and aged mattress fabric. Five localized RGBA decals include damp, dust, dried blood pools, directional wall smears and faded shoe prints. Blood is environmental staining; no bodies or anatomical content. Maps are packed into native sources and embedded in standalone GLBs.\n')
print('Hospital original PBR textures:',OUT)
