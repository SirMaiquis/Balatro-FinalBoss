"""Render icon.png (256x256, Thunderstore) and thumbnail.jpg (1920x1080) from the game's own
background shader, showdown boss chips and m6x11 font, plus the Steamodded mod-list icon
assets/1x/icon.png (34x34) and assets/2x/icon.png (68x68): the Crimson Heart chip, exact pixels.

    uv run --with pillow --with numpy tools/make_art.py [path/to/Balatro/source]

The Balatro source folder must contain resources/ (textures/1x and 2x/BlindChips.png, fonts/m6x11plus.ttf).
"""
import os
import sys

import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont

GAME = sys.argv[1] if len(sys.argv) > 1 else os.environ.get('BALATRO_SRC', r'I:\backup\Backup 2\Balatro\SouceCode')
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

CHIP_PX = 68  # BlindChips.png at 2x: 34px chips
CHIPS = {  # showdown bosses: atlas row, boss colour
    'heart': (25, '#ac3232'),
    'bell': (26, '#009cfd'),
    'acorn': (27, '#fda200'),
    'leaf': (28, '#56a786'),
    'vessel': (29, '#8a71e1'),
}
TEXT = (239, 248, 255)
SHADOW = (40, 26, 44)


def hex_rgb(h):
    h = h.lstrip('#')
    return np.array([int(h[i:i + 2], 16) / 255 for i in (0, 2, 4)])


def swirl(w, h, c1, c2, c3, contrast=2.0, spin=0.6, t=7.0, pixel_fac=700.0):
    """numpy port of resources/shaders/background.fs."""
    diag = np.hypot(w, h)
    px = diag / pixel_fac
    ys, xs = np.mgrid[0:h, 0:w].astype(np.float64)
    xs = np.floor(xs / px) * px
    ys = np.floor(ys / px) * px
    u = (xs - 0.5 * w) / diag - 0.12
    v = (ys - 0.5 * h) / diag
    r = np.hypot(u, v)
    speed = t * 0.5 * 0.2 + 302.2
    ang = np.arctan2(v, u) + speed - 0.5 * 20 * (spin * r + (1 - spin))
    mx, my = (w / diag) / 2, (h / diag) / 2
    u = (r * np.cos(ang) + mx) - mx
    v = (r * np.sin(ang) + my) - my
    u, v = u * 30, v * 30
    speed = t * 2
    u2 = u + v
    v2 = u + v
    for _ in range(5):
        m = np.sin(np.maximum(u, v))
        u2, v2 = u2 + m + u, v2 + m + v
        u = u + 0.5 * np.cos(5.1123314 + 0.353 * v2 + speed * 0.131121)
        v = v + 0.5 * np.sin(u2 - 0.113 * speed)
        k = np.cos(u + v) - np.sin(u * 0.711 - v)
        u, v = u - k, v - k
    cm = 0.25 * contrast + 0.5 * spin + 1.2
    paint = np.clip(np.hypot(u, v) * 0.035 * cm, 0, 2)
    c1p = np.maximum(0, 1 - cm * np.abs(1 - paint))
    c2p = np.maximum(0, 1 - cm * np.abs(paint))
    c3p = 1 - np.minimum(1, c1p + c2p)
    base = 0.3 / contrast
    out = base * c1 + (1 - base) * (c1 * c1p[..., None] + c2 * c2p[..., None] + c3 * c3p[..., None])
    return Image.fromarray((np.clip(out, 0, 1) * 255).astype(np.uint8), 'RGB')


def background(w, h, blur):
    c1 = hex_rgb('#ac3232')  # Crimson Heart
    c2 = hex_rgb('#5a3a9e')  # deep violet
    c3 = hex_rgb('#1a0f1f')  # near black
    return swirl(w, h, c1, c2, c3).filter(ImageFilter.GaussianBlur(blur))


def chip(name, size):
    row = CHIPS[name][0]
    atlas = Image.open(os.path.join(GAME, 'resources', 'textures', '2x', 'BlindChips.png')).convert('RGBA')
    img = atlas.crop((0, row * CHIP_PX, CHIP_PX, (row + 1) * CHIP_PX))
    return img.resize((size, size), Image.NEAREST)


def paste_shadowed(canvas, img, x, y, offset, blur=0):
    shadow = Image.new('RGBA', img.size, SHADOW + (0,))
    shadow.putalpha(img.split()[3].point(lambda a: int(a * 0.75)))
    if blur:
        shadow = shadow.filter(ImageFilter.GaussianBlur(blur))
    canvas.alpha_composite(shadow, (x + offset, y + offset))
    canvas.alpha_composite(img, (x, y))


def pixel_text(text, scale):
    """m6x11 rendered at its native size without anti-aliasing, then scaled up with hard pixels."""
    font = ImageFont.truetype(os.path.join(GAME, 'resources', 'fonts', 'm6x11plus.ttf'), 18)
    left, top, right, bottom = font.getbbox(text)
    small = Image.new('L', (right - left + 2, bottom - top + 2), 0)
    d = ImageDraw.Draw(small)
    d.fontmode = '1'
    d.text((1 - left, 1 - top), text, font=font, fill=255)
    mask = small.resize((small.width * scale, small.height * scale), Image.NEAREST)
    out = Image.new('RGBA', mask.size, TEXT + (0,))
    out.putalpha(mask)
    return out


def make_icon():
    size = 256
    canvas = background(size, size, blur=3).convert('RGBA')
    c = chip('heart', 204)
    paste_shadowed(canvas, c, (size - 204) // 2 - 3, (size - 204) // 2 - 3, 8)
    canvas.convert('RGB').save(os.path.join(ROOT, 'icon.png'))


def make_thumbnail():
    w, h = 1920, 1080
    canvas = background(w, h, blur=14).convert('RGBA')
    # Five showdown chips on an arc above the title, Crimson Heart in the middle and largest.
    layout = [('bell', 220, 960 - 720, 340), ('vessel', 220, 960 + 720, 340),
              ('acorn', 280, 960 - 440, 250), ('leaf', 280, 960 + 440, 250),
              ('heart', 440, 960, 110)]  # (chip, size, centre x, top y)
    for name, size, cx, y in layout:
        paste_shadowed(canvas, chip(name, size), cx - size // 2, y, max(8, size // 24))
    title = pixel_text('FINAL BOSS', 12)
    tx, ty = (w - title.width) // 2, 640
    paste_shadowed(canvas, title, tx, ty, 14)
    sub = pixel_text('SHOWDOWN', 5)
    paste_shadowed(canvas, sub, (w - sub.width) // 2, ty + title.height + 30, 7)
    canvas.convert('RGB').save(os.path.join(ROOT, 'thumbnail.jpg'), quality=92)


def make_modicon():
    """assets/{1x,2x}/icon.png: frame 0 of the Crimson Heart chip, exact pixels (Steamodded's mod list icon)."""
    row = CHIPS['heart'][0]
    for scale in (1, 2):
        px = 34 * scale
        atlas = Image.open(os.path.join(GAME, 'resources', 'textures', f'{scale}x', 'BlindChips.png')).convert('RGBA')
        out_dir = os.path.join(ROOT, 'assets', f'{scale}x')
        os.makedirs(out_dir, exist_ok=True)
        atlas.crop((0, row * px, px, (row + 1) * px)).save(os.path.join(out_dir, 'icon.png'))


if __name__ == '__main__':
    make_icon()
    make_thumbnail()
    make_modicon()
    print('wrote icon.png, thumbnail.jpg and assets/{1x,2x}/icon.png')
