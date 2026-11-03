#!/usr/bin/env python3
"""Generates every AMEER brand asset from the approved logo (single source).

Source of truth : apps/nexa_example/assets/new_logo.png   (RGBA, never edited)
Run             : python3 tool/branding/generate_ameer_assets.py [--preview DIR]
Needs           : Pillow (pip install pillow)

Rules (docs/mobile/AMEER_BRANDING.md): the logo is not redrawn, recoloured,
distorted or given effects. Only these operations are applied: trim the
invisible margin (alpha < 8), scale uniformly, centre on a transparent or
solid canvas, and derive an alpha-only silhouette for monochrome uses.
"""
import argparse
import math
import os
import sys

from PIL import Image, ImageChops, ImageDraw

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..'))
APP = os.path.join(ROOT, 'apps', 'nexa_example')
SRC = os.path.join(APP, 'assets', 'new_logo.png')
RES = os.path.join(APP, 'android', 'app', 'src', 'main', 'res')

# Deep brown from the existing palette (LabeebPalette.light.onPrimaryContainer).
ICON_BG = (0x2E, 0x1C, 0x13)

DENSITY = {'mdpi': 1.0, 'hdpi': 1.5, 'xhdpi': 2.0, 'xxhdpi': 3.0, 'xxxhdpi': 4.0}


def load_trimmed():
    im = Image.open(SRC).convert('RGBA')
    bbox = im.split()[3].point(lambda v: 255 if v >= 8 else 0).getbbox()
    if bbox is None:
        sys.exit('The source logo has no visible pixels.')
    return im.crop(bbox)


LOGO = load_trimmed()  # the visible symbol with its glow, nothing else
LW, LH = LOGO.size


def radius_from_center():
    """Largest distance of a visible pixel (alpha >= 24) from the logo's
    bounding-box centre, in source pixels (for circular safe-zone fitting)."""
    a = LOGO.split()[3]
    w, h = a.size
    cx, cy = w / 2, h / 2
    px = a.load()
    best = 0.0
    for y in range(0, h, 2):
        for x in range(0, w, 2):
            if px[x, y] >= 24:
                best = max(best, math.hypot(x - cx, y - cy))
    return best


R_SRC = radius_from_center()


def place(canvas_px, circle_diameter_px, base=None):
    """The logo scaled so every visible pixel lies inside a circle of
    [circle_diameter_px], centred on a [canvas_px] square canvas."""
    scale = (circle_diameter_px / 2) / R_SRC
    w, h = max(1, round(LW * scale)), max(1, round(LH * scale))
    logo = LOGO.resize((w, h), Image.LANCZOS)
    out = base.copy() if base else Image.new('RGBA', (canvas_px, canvas_px), (0, 0, 0, 0))
    out.alpha_composite(logo, ((canvas_px - w) // 2, (canvas_px - h) // 2))
    return out


def silhouette(img, crisp=False):
    """White, alpha-only copy for monochrome slots (themed icon, notification).
    Alpha follows the logo's own alpha and, inside the symbol, its brightness,
    so the ribbon structure survives instead of becoming a flat blob: only the
    deepest shadow fold turns see-through. [crisp] snaps the result to solid or
    empty (small icons must not look blurry)."""
    r, g, b, a = img.split()
    luma = Image.merge('RGB', (r, g, b)).convert('L')
    lift = luma.point(lambda v: 0 if v < 52 else min(255, int((v - 52) * 255 / 70)))
    alpha = ImageChops.multiply(a, lift)
    if crisp:
        alpha = alpha.point(lambda v: 255 if v >= 96 else 0)
    else:
        alpha = alpha.point(lambda v: 0 if v < 24 else min(255, int(v * 1.2)))
    out = Image.new('RGBA', img.size, (255, 255, 255, 0))
    out.putalpha(alpha)
    return out


def save(img, rel):
    path = os.path.join(RES, rel) if not os.path.isabs(rel) else rel
    os.makedirs(os.path.dirname(path), exist_ok=True)
    img.save(path, optimize=True)
    return path


def rounded_mask(size, radius):
    m = Image.new('L', (size * 4, size * 4), 0)
    ImageDraw.Draw(m).rounded_rectangle((0, 0, size * 4 - 1, size * 4 - 1), radius * 4, fill=255)
    return m.resize((size, size), Image.LANCZOS)


def circle_mask(size):
    m = Image.new('L', (size * 4, size * 4), 0)
    ImageDraw.Draw(m).ellipse((0, 0, size * 4 - 1, size * 4 - 1), fill=255)
    return m.resize((size, size), Image.LANCZOS)


def generate(preview_dir=None):
    written = []

    # 1. In-app logo: square transparent canvas, symbol at native resolution.
    side = 1024
    app_logo = Image.new('RGBA', (side, side), (0, 0, 0, 0))
    app_logo.alpha_composite(LOGO, ((side - LW) // 2, (side - LH) // 2))
    written.append(save(app_logo, os.path.join(APP, 'assets', 'brand', 'ameer_logo.png')))

    for name, d in DENSITY.items():
        # 2. Adaptive icon layers: 108 dp canvas, safe zone = 66 dp circle.
        canvas = round(108 * d)
        safe = 66 * d * 0.98
        fg = place(canvas, safe)
        written.append(save(fg, f'drawable-{name}/ic_launcher_foreground.png'))
        written.append(save(silhouette(fg), f'drawable-{name}/ic_launcher_monochrome.png'))

        # 3. Legacy launcher icons (API < 26): 48 dp, rounded square and round.
        px = round(48 * d)
        for suffix, mask in (('', rounded_mask(px, round(px * 0.22))), ('_round', circle_mask(px))):
            base = Image.new('RGBA', (px, px), ICON_BG + (255,))
            icon = place(px, px * 0.66, base)
            icon.putalpha(mask)
            written.append(save(icon, f'mipmap-{name}/ic_launcher{suffix}.png'))

        # 4. Splash icon: 288 dp canvas, logo inside the 192 dp circle.
        sp = round(288 * d)
        written.append(save(place(sp, 192 * d * 0.98), f'drawable-{name}/ic_splash_icon.png'))

        # 5. Notification small icon: 24 dp, white silhouette, ~20 dp box.
        n = round(24 * d)
        small = Image.new('RGBA', (n, n), (0, 0, 0, 0))
        sil = silhouette(LOGO, crisp=True)
        scale = (n * 0.88) / max(LW, LH)
        sil = sil.resize((max(1, round(LW * scale)), max(1, round(LH * scale))), Image.LANCZOS)
        small.alpha_composite(sil, ((n - sil.width) // 2, (n - sil.height) // 2))
        written.append(save(small, f'drawable-{name}/nexa_notification_icon.png'))

    # 6. Store icon (512 px, full bleed).
    store = Image.new('RGBA', (512, 512), ICON_BG + (255,))
    written.append(save(place(512, 512 * 0.66, store).convert('RGB'),
                        os.path.join(APP, 'android', 'app', 'src', 'main', 'ic_launcher-playstore.png')))

    if preview_dir:
        preview(preview_dir)
    return written


def preview(out_dir):
    """Contact sheets to check safe-zone cropping, splash and notification."""
    os.makedirs(out_dir, exist_ok=True)
    d = 4
    canvas = 108 * d
    bg = Image.new('RGBA', (canvas, canvas), ICON_BG + (255,))
    fg = place(canvas, 66 * d * 0.98)
    full = bg.copy()
    full.alpha_composite(fg)
    sheet = Image.new('RGBA', (canvas * 4 + 50, canvas + 20), (200, 200, 200, 255))
    shapes = [
        ('circle', circle_mask(canvas)),
        ('squircle', rounded_mask(canvas, round(canvas * 0.30))),
        ('rounded', rounded_mask(canvas, round(canvas * 0.15))),
    ]
    x = 10
    for _, m in shapes:
        tile = full.copy()
        tile.putalpha(ImageChops.multiply(tile.split()[3], m))
        sheet.alpha_composite(tile, (x, 10))
        x += canvas + 10
    # full 108 dp canvas with the 66 dp safe circle outlined
    g = full.copy()
    dr = ImageDraw.Draw(g)
    m = (canvas - 66 * d) // 2
    dr.ellipse((m, m, canvas - m, canvas - m), outline=(255, 0, 0, 255), width=3)
    sheet.alpha_composite(g, (x, 10))
    sheet.convert('RGB').save(os.path.join(out_dir, 'adaptive_masks.png'))

    # monochrome themed icon on two tints
    mono = silhouette(fg)
    row = Image.new('RGBA', (canvas * 2 + 30, canvas + 20), (255, 255, 255, 255))
    for i, (tint, back) in enumerate((((60, 40, 30), (235, 220, 210)), ((235, 220, 210), (50, 35, 28)))):
        t = Image.new('RGBA', (canvas, canvas), back + (255,))
        solid = Image.new('RGBA', (canvas, canvas), tint + (255,))
        solid.putalpha(mono.split()[3])
        t.alpha_composite(solid)
        row.alpha_composite(t, (10 + i * (canvas + 10), 10))
    row.convert('RGB').save(os.path.join(out_dir, 'monochrome_themed.png'))

    # splash on light and dark
    sp = 288 * 2
    sheet2 = Image.new('RGBA', (sp * 2 + 30, sp + 20), (255, 255, 255, 255))
    for i, back in enumerate(((0xF7, 0xF3, 0xF0), (0x11, 0x0D, 0x0B))):
        t = Image.new('RGBA', (sp, sp), back + (255,))
        t.alpha_composite(place(sp, 192 * 2 * 0.98))
        sheet2.alpha_composite(t, (10 + i * (sp + 10), 10))
    sheet2.convert('RGB').save(os.path.join(out_dir, 'splash_light_dark.png'))

    # notification icons at 4x, on a light and a dark status area
    n = 24 * 4
    sheet3 = Image.new('RGBA', (n * 2 + 30, n + 20), (255, 255, 255, 255))
    for i, (back, tint) in enumerate((((240, 240, 240), (60, 60, 60)), ((40, 40, 40), (255, 255, 255)))):
        t = Image.new('RGBA', (n, n), back + (255,))
        small = Image.new('RGBA', (n, n), (0, 0, 0, 0))
        sil = silhouette(LOGO, crisp=True)
        sc = (n * 0.88) / max(LW, LH)
        sil = sil.resize((round(LW * sc), round(LH * sc)), Image.LANCZOS)
        small.alpha_composite(sil, ((n - sil.width) // 2, (n - sil.height) // 2))
        solid = Image.new('RGBA', (n, n), tint + (255,))
        solid.putalpha(small.split()[3])
        t.alpha_composite(solid)
        sheet3.alpha_composite(t, (10 + i * (n + 10), 10))
    sheet3.convert('RGB').save(os.path.join(out_dir, 'notification_icon.png'))


if __name__ == '__main__':
    ap = argparse.ArgumentParser()
    ap.add_argument('--preview', help='write contact sheets to this folder')
    args = ap.parse_args()
    files = generate(args.preview)
    print(f'visible symbol {LW}x{LH}px, farthest pixel {R_SRC:.0f}px from centre')
    print(f'wrote {len(files)} files')
