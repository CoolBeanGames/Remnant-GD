"""Author original newspaper print maps for the Blender apartment (Pillow/NumPy).

No downloaded photographs or newspaper scans. Fonts are discovered locally; the
maps are versioned, so rebuilding the Blender scene does not require Pillow.
"""
from pathlib import Path
import textwrap

import numpy as np
from PIL import Image, ImageDraw, ImageFont


ROOT = Path(__file__).resolve().parents[1]
OUTPUT = ROOT / 'Models/Architecture/StudioApartment/Textures'
OUTPUT.mkdir(parents=True, exist_ok=True)


def font(size, bold=False):
    for path in (
        Path('C:/Windows/Fonts') / ('timesbd.ttf' if bold else 'times.ttf'),
        Path('/usr/share/fonts/truetype/dejavu') / ('DejaVuSerif-Bold.ttf' if bold else 'DejaVuSerif.ttf'),
    ):
        if path.is_file():
            return ImageFont.truetype(str(path), size)
    return ImageFont.load_default(size=size)


editions = [
    ('THE DAILY RECORD', 'City prepares for a quieter season', 'Work continues as the days grow shorter'),
    ('THE EVENING POST', 'A change in the weather', 'Residents wait for the afternoon forecast'),
    ('DISTRICT JOURNAL', 'Repairs planned across the district', 'A report from the local services office'),
]
body = (
    'The district office issued its regular report yesterday. Local residents '
    'are advised to check the notice board for details of the coming schedule. '
    'The work is expected to continue throughout the week, with further '
    'information available in the next edition. Officials thanked residents '
    'for their patience. Several streets will remain open while the repairs '
    'are carried out. The committee will meet again on Thursday afternoon. '
)
ink = (46, 43, 37)
for index, (masthead, headline, subheading) in enumerate(editions):
    width, height = 1024, 1024
    y, x = np.mgrid[0:height, 0:width]
    rng = np.random.default_rng(825 + index)
    fold = np.exp(-((x - width * .51) / 12) ** 2) * 7
    age = 10 * ((x / width - .5) ** 2 + (y / height - .5) ** 2)
    grain = rng.normal(0, 1.5, (height, width)) - fold - age
    paper = np.clip(np.array([208, 199, 175]) + grain[:, :, None], 0, 255).astype(np.uint8)
    image = Image.fromarray(paper)
    draw = ImageDraw.Draw(image)
    draw.text((width / 2, 36), masthead, fill=ink, font=font(63, True), anchor='mt')
    draw.line((36, 113, 988, 113), fill=ink, width=3)
    draw.text((40, 125), 'LOCAL EDITION  /  WEDNESDAY  /  TWELVE PAGES', fill=ink, font=font(17))
    draw.text((984, 125), 'PRICE 20', fill=ink, font=font(17), anchor='rt')
    draw.line((36, 156, 988, 156), fill=ink, width=1)
    draw.text((width / 2, 172), headline, fill=ink, font=font(38, True), anchor='mt')
    draw.text((width / 2, 225), subheading, fill=ink, font=font(23), anchor='mt')
    draw.line((36, 269, 988, 269), fill=ink, width=2)
    # Original halftone illustration: rooflines, no borrowed images or prose.
    px, py, pw, ph = 365, 293, 286, 218
    illustration = Image.new('RGB', (pw, ph), (184, 178, 161))
    art = ImageDraw.Draw(illustration)
    for building in range(6):
        bx = building * 50 - 5
        top = int(rng.integers(25, 95))
        art.rectangle((bx, top, bx + 43, ph), fill=(96, 93, 84))
        for row in range(4):
            for column in range(3):
                art.rectangle((bx + 6 + column * 12, top + 13 + row * 32, bx + 11 + column * 12, top + 25 + row * 32), fill=(164, 157, 138))
    for dot_y in range(0, ph, 4):
        for dot_x in range(0, pw, 4):
            art.point((dot_x, dot_y), fill=ink)
    image.paste(illustration, (px, py))
    draw = ImageDraw.Draw(image)
    draw.text((px, py + ph + 8), 'From the district / staff illustration', fill=ink, font=font(14))
    for column in range(3):
        left = 38 + column * 326
        text_y = 294 if column != 1 else 554
        lines = textwrap.wrap(body * 5, width=39)
        draw.text((left, text_y), ['THE WEEK AHEAD', 'PUBLIC NOTICES', 'IN BRIEF'][column], fill=ink, font=font(21, True))
        text_y += 36
        for line_number, line in enumerate(lines):
            if text_y > 964:
                break
            draw.text((left, text_y), line, fill=ink, font=font(16))
            text_y += 21
            if line_number % 13 == 12:
                text_y += 11
        if column < 2:
            draw.line((left + 312, 294, left + 312, 966), fill=(115, 107, 93), width=1)
    draw.line((36, 981, 988, 981), fill=ink, width=1)
    draw.text((width / 2, 989), 'Printed for the district. Please retain this edition.', fill=ink, font=font(13), anchor='mt')
    image.save(OUTPUT / ('newspaper_%02d_albedo.png' % index), optimize=True)
print('Original newspaper maps authored:', len(editions))
