"""Original portable maps for the worn studio set; run with Python/Pillow/NumPy.

The family photograph is a separately generated fictional bitmap. All other maps,
paper typography and labels are deterministic original artwork, not downloaded art.
"""
from pathlib import Path
import numpy as np
from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'Models/Interiors/StudioFurniture/Textures'
OUT.mkdir(parents=True, exist_ok=True)
(OUT / '.gdignore').write_text('')
N = 768
y, x = np.mgrid[0:N, 0:N].astype(float) / N
rng = np.random.default_rng(427)


def noise(seed, frequencies=(4, 12, 40, 140)):
    random = np.random.default_rng(seed)
    result = np.zeros((N, N))
    for i, f in enumerate(frequencies):
        small = (random.random((f, f)) * 255).astype('uint8')
        result += np.asarray(Image.fromarray(small).resize((N, N), Image.Resampling.BICUBIC)) / 255 / (2 ** i)
    return result / sum(1 / 2 ** i for i in range(len(frequencies)))


def maps(name, base, height, variation=.08, rough=.7, metallic=False):
    h = height - .5
    scratches = (rng.random((N, N)) > .997) * .12
    tone = h * variation - scratches
    colour = np.clip(np.array(base) + tone[:, :, None], .015, .98)
    Image.fromarray((colour * 255).astype('uint8')).save(OUT / f'{name}_albedo.png')
    dy, dx = np.gradient(height)
    normals = np.stack((-dx * 14, -dy * 14, np.ones_like(dx)), axis=-1)
    normals /= np.linalg.norm(normals, axis=-1)[..., None]
    Image.fromarray(((normals * .5 + .5) * 255).astype('uint8')).save(OUT / f'{name}_normal.png')
    r = np.clip(rough + h * .25 + scratches, .12, .98)
    Image.fromarray((r * 255).astype('uint8')).save(OUT / f'{name}_roughness.png')


grain_rng = np.random.default_rng(914)
fibres = (grain_rng.random((32, N)) * 255).astype('uint8')
fibres = np.asarray(Image.fromarray(fibres).resize((N, N), Image.Resampling.BICUBIC)) / 255
wood = .5 + (fibres - .5) * .32 + (noise(14) - .5) * .40
maps('walnut', [.255, .155, .08], wood, .14, .61)
weave = .5 + .1 * np.sin(x * N * 2.1) * np.sin(y * N * 2.1) + .4 * (noise(8) - .5)
maps('olive_cloth', [.285, .30, .195], weave, .17, .92)
maps('ochre_cloth', [.42, .285, .135], weave, .19, .92)
maps('black_plastic', [.053, .058, .05], noise(18), .06, .52)
maps('aged_cream', [.69, .655, .51], noise(29), .18, .45)
maps('steel', [.36, .37, .32], noise(3) * .98 + .004 * np.sin(y * N * .7), .08, .39, True)
maps('rust', [.29, .155, .065], noise(71), .35, .9)
maps('ceramic', [.34, .17, .085], noise(39), .1, .61)
maps('leaf', [.105, .20, .061], .5 + .2 * np.sin(x * 36 + y * 41) + (noise(43) - .5) * .25, .12, .62)
maps('plaster_dirty', [.68, .645, .535], noise(66), .31, .94)
maps('tile_dirty', [.49, .47, .365], noise(92), .21, .55)
maps('paper', [.75, .69, .52], noise(138), .15, .96)
maps('soil', [.065, .045, .022], noise(137), .1, .97)

# Transparent grime patch: softened perimeter, upward damp blooms and drips.
edge = np.sin(np.pi * x) ** 1.8 * np.sin(np.pi * y) ** 1.3
drips = np.clip(.42 + noise(143) * .8 + np.sin(x * 73) * .22, 0, 1)
alpha = edge * drips * .57
rgba = np.zeros((N, N, 4), dtype='uint8')
rgba[..., :3] = [58, 49, 30]
rgba[..., 3] = (alpha * 255).astype('uint8')
Image.fromarray(rgba).save(OUT / 'damp_stain.png')


def font(size, bold=False):
    path = Path('C:/Windows/Fonts') / ('timesbd.ttf' if bold else 'times.ttf')
    return ImageFont.truetype(str(path), size) if path.exists() else ImageFont.load_default()


for i in range(3):
    im = Image.open(OUT / 'paper_albedo.png').convert('RGB')
    d = ImageDraw.Draw(im)
    d.rectangle((22, 22, N-22, N-22), outline=(133, 118, 88), width=2)
    d.text((60, 65), ['FINAL NOTICE', 'A LETTER FROM HOME', 'DISTRICT SERVICES'][i], font=font(43, True), fill=(46, 41, 34))
    d.text((65, 160), ['ACCOUNT 0719 / PLEASE RESPOND', 'Dear you,', 'REGARDING YOUR TENANCY'][i], font=font(25), fill=(63, 53, 40))
    for j in range(12):
        length = int(rng.integers(310, 590))
        d.line((65, 225+j*27, 65+length, 225+j*27), fill=(119, 106, 83), width=3)
    d.rectangle((560, 600, 686, 680), outline=(109, 48, 37), width=4)
    d.text((580, 622), 'PAID' if i == 1 else 'DUE', font=font(34, True), fill=(109, 48, 37))
    im.save(OUT / f'mail_{i}.png')
im = Image.new('RGB', (768, 512), (10, 17, 16))
a = np.asarray(im).copy()
scan = rng.integers(0, 18, (512, 768, 1))
a = np.clip(a + scan, 0, 255).astype('uint8')
Image.fromarray(a).save(OUT / 'crt_screen.png')
print('STUDIO textures complete:', OUT)
