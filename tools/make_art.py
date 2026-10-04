"""Render icon.png (256x256, Thunderstore) and thumbnail.jpg (1920x1080) from the game's own
background shader, showdown boss chips and m6x11 font, plus the Steamodded mod-list icon
assets/1x/icon.png (34x34) and assets/2x/icon.png (68x68): the Crimson Heart chip, exact pixels; and
the curse marks atlas assets/1x|2x/curse_marks.png (card-sized pixel-art frames, see make_curse_marks).

    uv run --with pillow --with numpy tools/make_art.py [path/to/Balatro/source]

The Balatro source folder must contain resources/ (textures/1x and 2x/BlindChips.png, Enhancers.png,
ui_assets.png, ui_assets_opt2.png, fonts/m6x11plus.ttf).
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


# Curse marks atlas (src/curse.lua, the Needle in src/effects.lua) ------------------------------------
# One 71 x 95 frame per mark (the playing-card frame: vanilla 'centers'/'cards_1' atlases are px 71,
# py 95, game.lua:1014-1016), drawn at 1x and scaled up 2x with hard pixels (the vanilla 2x textures
# are exact 2x copies of the 1x ones). Everything stays inside the card's own silhouette (the alpha of
# the Base card, Enhancers.png at c_base pos 1,0). Column order = logic.MARK_FRAMES (src/logic.lua);
# row 0 holds the low-contrast suit colours, row 1 the high-contrast ones.
MARK_W, MARK_H = 71, 95
MARK_COLUMNS = ['Hearts', 'Diamonds', 'Clubs', 'Spades', 'suit', 'vine', 'crack', 'needle']
# The suit badges: 9-pixel suit glyphs (the 16-pixel UI icons do not fit the corner at 1x).
SUIT_GLYPHS = {
    'Hearts': ['.##...##.', '####.####', '#########', '#########', '.#######.', '..#####..', '...###...',
               '....#....'],
    'Diamonds': ['....#....', '...###...', '..#####..', '.#######.', '#########', '.#######.', '..#####..',
                 '...###...', '....#....'],
    'Clubs': ['...###...', '..#####..', '..#####..', '.##.#.##.', '#########', '#########', '.##.#.##.',
              '....#....', '..#####..'],
    'Spades': ['....#....', '...###...', '..#####..', '.#######.', '#########', '#########', '.##.#.##.',
               '....#....', '..#####..'],
}
SUIT_LC = {'Hearts': '#f03464', 'Diamonds': '#f06b3f', 'Spades': '#403995', 'Clubs': '#235955'}  # G.C.SO_1
SUIT_HC = {'Hearts': '#f83b2f', 'Diamonds': '#e29000', 'Spades': '#4f31b9', 'Clubs': '#008ee6'}  # G.C.SO_2
PLANT, PILLAR, CURSE_RED = '#709284', '#7e6752', '#a83232'  # boss_colour of The Plant / The Pillar (game.lua)
NEEDLE_THREAD = '#fe5f55'  # G.C.RED

# Vines (The Plant) and cracks (The Pillar) in card units (x across, y down, 0..1): polylines, flat
# x1, y1, x2, y2, ...; vine leaves {x, y, angle (radians)}. The shapes of the 1.1 primitive marks.
VINE_STROKES = [
    [0.06, 1.0, 0.1, 0.84, 0.05, 0.68, 0.12, 0.52, 0.06, 0.36, 0.14, 0.2, 0.1, 0.07, 0.24, 0.03],
    [0.94, 1.0, 0.88, 0.86, 0.95, 0.72, 0.87, 0.58, 0.94, 0.44, 0.86, 0.32],
    [0.1, 0.84, 0.26, 0.8, 0.36, 0.86, 0.5, 0.82],
    [0.88, 0.58, 0.74, 0.62, 0.66, 0.56],
    [0.06, 0.36, 0.2, 0.4, 0.28, 0.34],
]
VINE_LEAVES = [(0.12, 0.6, -0.6), (0.05, 0.28, 0.5), (0.18, 0.06, -0.3), (0.9, 0.79, 0.6), (0.92, 0.5, -0.5),
               (0.42, 0.85, 0.2), (0.68, 0.56, -0.8), (0.27, 0.35, 0.9)]
CRACK_STROKES = [
    [0.62, 0.0, 0.55, 0.14, 0.6, 0.27, 0.47, 0.42, 0.53, 0.55, 0.42, 0.7, 0.48, 0.84, 0.4, 1.0],
    [0.47, 0.42, 0.33, 0.47, 0.24, 0.43, 0.1, 0.5, 0.0, 0.48],
    [0.53, 0.55, 0.66, 0.6, 0.76, 0.56, 0.9, 0.63, 1.0, 0.61],
    [0.6, 0.27, 0.72, 0.24, 0.8, 0.3],
    [0.42, 0.7, 0.3, 0.76, 0.26, 0.86],
]


def rgb(h, k=1.0, a=255):
    """'#rrggbb' scaled by k (vanilla darken(c, 1 - k)), with alpha a."""
    h = h.lstrip('#')
    return tuple(int(int(h[i:i + 2], 16) * k) for i in (0, 2, 4)) + (a,)


def texture(scale, name):
    return Image.open(os.path.join(GAME, 'resources', 'textures', f'{scale}x', name)).convert('RGBA')


def card_depth():
    """Per pixel of the 1x card frame: how many pixels inside the card's silhouette it lies (0 = on the
    edge, -1 = outside), by repeated 3x3 erosion of the Base card's alpha, so bands follow its corners."""
    alpha = np.array(texture(1, 'Enhancers.png'))[0:MARK_H, MARK_W:2 * MARK_W, 3] > 0
    depth = np.full(alpha.shape, -1, dtype=int)
    cur, d = alpha.copy(), 0
    while cur.any():
        depth[cur] = d
        p = np.pad(cur, 1, constant_values=False)
        nxt = np.ones_like(cur)
        for dy in (0, 1, 2):
            for dx in (0, 1, 2):
                nxt &= p[dy:dy + MARK_H, dx:dx + MARK_W]
        cur, d = nxt, d + 1
    return depth


def clip(img, depth, inset):
    """Keep only the pixels at least `inset` pixels inside the card."""
    a = np.array(img)
    a[depth < inset] = 0
    return Image.fromarray(a, 'RGBA')


def suit_frame(depth, colour, suit):
    """A dark band in the suit colour hugging the card's edge, a thin inner line in the suit colour and,
    for a known suit, its badge (the suit glyph in a ringed disc) in the top-right corner, the corner the
    card's own rank and pip leave free."""
    a = np.zeros((MARK_H, MARK_W, 4), dtype=np.uint8)
    a[(depth >= 0) & (depth <= 3)] = rgb(colour, 0.6, 235)
    a[depth == 5] = rgb(colour, 1.0, 217)
    img = Image.fromarray(a, 'RGBA')
    if suit:
        d = ImageDraw.Draw(img)
        cx, cy, r = 58, 13, 10  # disc box x 48..68, y 3..23: inside the band's inner edge at the corner
        d.ellipse((cx - r, cy - r, cx + r, cy + r), fill=rgb(colour, 0.6))
        d.ellipse((cx - r + 2, cy - r + 2, cx + r - 2, cy + r - 2), fill=rgb(colour, 1.0))
        d.ellipse((cx - r + 3, cy - r + 3, cx + r - 3, cy + r - 3), fill=(239, 248, 255, 255))
        glyph = SUIT_GLYPHS[suit]
        gx, gy = cx - len(glyph[0]) // 2, cy - len(glyph) // 2
        for j, row in enumerate(glyph):
            for i, ch in enumerate(row):
                if ch == '#':
                    d.point((gx + i, gy + j), fill=rgb(colour))
    return clip(img, depth, 0)


def polyline_px(stroke):
    return [(round(stroke[i] * (MARK_W - 1)), round(stroke[i + 1] * (MARK_H - 1))) for i in range(0, len(stroke), 2)]


def vine_frame(depth):
    """The Plant: dark stems climb from the bottom corners and creep across the face, leaves in the
    boss colour along them."""
    img = Image.new('RGBA', (MARK_W, MARK_H), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    for s in VINE_STROKES:
        d.line(polyline_px(s), fill=rgb(PLANT, 0.45, 242), width=3, joint='curve')
    for x, y, ang in VINE_LEAVES:
        cx, cy = x * (MARK_W - 1), y * (MARK_H - 1)
        ca, sa = np.cos(ang), np.sin(ang)
        pts = []
        for t in np.linspace(0, 2 * np.pi, 16, endpoint=False):
            ex, ey = 5.5 * np.cos(t), 3.0 * np.sin(t)
            pts.append((round(cx + ex * ca - ey * sa), round(cy + ex * sa + ey * ca)))
        d.polygon(pts, fill=rgb(PLANT, 1.0, 255), outline=rgb(PLANT, 0.45, 255))
        d.line([(round(cx - 4 * ca), round(cy - 4 * sa)), (round(cx + 4 * ca), round(cy + 4 * sa))],
               fill=rgb(PLANT, 0.45, 255), width=1)
    return clip(img, depth, 1)


def crack_frame(depth):
    """The Pillar: dark fractures across the card, each with a pale edge on one side so it reads as a
    split in the card, not a drawn line; they stop at the card's border."""
    img = Image.new('RGBA', (MARK_W, MARK_H), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    for s in CRACK_STROKES:
        d.line([(x + 2, y + 1) for x, y in polyline_px(s)], fill=(255, 255, 255, 150), width=1)
    for s in CRACK_STROKES:
        d.line(polyline_px(s), fill=rgb(PILLAR, 0.4, 242), width=3, joint='curve')
    return clip(img, depth, 2)


NEEDLE_TIP = (12, 84)  # 1x pixel of the needle's point in its frame (src/effects.lua lands it there)


def needle_frame():
    """The Needle: a steel needle at 45 degrees, point down-left, a red thread trailing from its eye."""
    img = Image.new('RGBA', (MARK_W, MARK_H), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    tx, ty = NEEDLE_TIP
    ex, ey = tx + 50, ty - 50  # the eye end
    thread = [(ex - 1, ey + 1), (ex + 3, ey - 6), (ex + 1, ey - 14), (ex - 5, ey - 20), (ex - 3, ey - 28),
              (ex + 2, ey - 33)]
    d.line(thread, fill=rgb(NEEDLE_THREAD), width=2, joint='curve')
    outline, steel, shine = (38, 40, 52, 255), (176, 186, 200, 255), (239, 248, 255, 255)
    d.line([(tx + 3, ty - 3), (ex, ey)], fill=outline, width=5)
    d.line([(tx, ty), (tx + 6, ty - 6)], fill=outline, width=3)  # the point tapers
    d.line([(tx + 4, ty - 4), (ex - 1, ey + 1)], fill=steel, width=3)
    d.line([(tx + 1, ty - 1), (tx + 5, ty - 5)], fill=steel, width=1)
    d.line([(tx + 6, ty - 7), (ex - 3, ey + 2)], fill=shine, width=1)
    d.rectangle((ex - 3, ey - 1, ex - 2, ey + 1), fill=outline)  # the eye
    d.point([(tx, ty)], fill=outline)
    return img


def make_curse_marks():
    """assets/{1x,2x}/curse_marks.png: the curse marks and the Needle's needle (SMODS.Atlas
    'curse_marks', px 71, py 95, main.lua)."""
    depth = card_depth()
    sheet = Image.new('RGBA', (MARK_W * len(MARK_COLUMNS), MARK_H * 2), (0, 0, 0, 0))
    for row, palette in enumerate((SUIT_LC, SUIT_HC)):
        for suit, colour in palette.items():
            col = MARK_COLUMNS.index(suit)
            sheet.alpha_composite(suit_frame(depth, colour, suit), (col * MARK_W, row * MARK_H))
    frames = {'suit': suit_frame(depth, CURSE_RED, None), 'vine': vine_frame(depth),
              'crack': crack_frame(depth), 'needle': needle_frame()}
    for name, img in frames.items():
        sheet.alpha_composite(img, (MARK_COLUMNS.index(name) * MARK_W, 0))
    for scale in (1, 2):
        out_dir = os.path.join(ROOT, 'assets', f'{scale}x')
        os.makedirs(out_dir, exist_ok=True)
        img = sheet if scale == 1 else sheet.resize((sheet.width * scale, sheet.height * scale), Image.NEAREST)
        img.save(os.path.join(out_dir, 'curse_marks.png'))


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
    make_curse_marks()
    print('wrote icon.png, thumbnail.jpg, assets/{1x,2x}/icon.png and assets/{1x,2x}/curse_marks.png')
