#!/usr/bin/env python3
"""Regenerates every Fermata brand asset from the geometry defined here.

The mark is a fermata ("hold") glyph drawn from scratch: a bold arc with
round caps above a solid dot. Run from the repository root:

    python3 branding/generate_icons.py

Requires: python3-cairosvg, python3-pil (Pillow).
"""
import io
import os
import xml.etree.ElementTree as ET

import cairosvg
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

BG = '#0C0C0E'
GOLD = '#E9B44C'
WARM_WHITE = '#F3F1EC'
INK = '#17161A'
LIGHT_BG = '#F6F4EF'

# Geometry on a 512 canvas. Arc: radius 148 around (256, 304), 200° sweep,
# stroke 58 with round caps. Dot: radius 44 at (256, 318).
ARC_PATH = 'M110.25,330.10 A148,148 0 1,1 401.75,330.10'
STROKE = 58
DOT = (256, 318, 44)


def mark_group(color, scale=1.0, dx=0.0, dy=0.0):
    cx, cy, r = DOT
    return (
        f'<g transform="translate({dx} {dy}) scale({scale})">'
        f'<path d="{ARC_PATH}" fill="none" stroke="{color}" stroke-width="{STROKE}" stroke-linecap="round"/>'
        f'<circle cx="{cx}" cy="{cy}" r="{r}" fill="{color}"/>'
        '</g>'
    )


def svg(content, w=512, h=512):
    return f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {w} {h}" width="{w}" height="{h}">{content}</svg>\n'


# The mark's visual bounds (incl. stroke) are y ≈ 127..362; shift to centre.
CENTER_DY = 256 - (127 + 362) / 2


def mark_svg(color):
    return svg(mark_group(color, dy=CENTER_DY))


def app_icon_svg(size=512, radius=116, mark_scale=0.66):
    off = size * (1 - mark_scale) / 2
    return svg(
        f'<rect width="{size}" height="{size}" rx="{radius}" fill="{BG}"/>'
        + mark_group(GOLD, mark_scale, off, off + CENTER_DY * mark_scale),
        size,
        size,
    )


def full_logo_svg(mark_color, text_color, bg=None):
    # Mark (scaled to 96 px tall) + lowercase wordmark in Manrope ExtraBold.
    bgrect = f'<rect width="760" height="200" fill="{bg}"/>' if bg else ''
    return svg(
        bgrect
        + mark_group(mark_color, 0.34, 18, 13 + CENTER_DY * 0.34)
        + f'<text x="212" y="132" font-family="Manrope" font-weight="800" font-size="104" '
        f'letter-spacing="-3" fill="{text_color}">fermata</text>',
        760,
        200,
    )


def png(svg_text, size, out=None, background=None):
    data = cairosvg.svg2png(bytestring=svg_text.encode(), output_width=size, output_height=size, background_color=background)
    img = Image.open(io.BytesIO(data)).convert('RGBA')
    if out:
        os.makedirs(os.path.dirname(out), exist_ok=True)
        img.save(out)
    return img


def write(path, text):
    full = os.path.join(ROOT, path)
    os.makedirs(os.path.dirname(full), exist_ok=True)
    with open(full, 'w', encoding='utf-8') as f:
        f.write(text)


def p(*parts):
    return os.path.join(ROOT, *parts)


def ico(svg_text, sizes, out):
    imgs = [png(svg_text, s) for s in sizes]
    os.makedirs(os.path.dirname(out), exist_ok=True)
    imgs[-1].save(out, format='ICO', sizes=[(s, s) for s in sizes], append_images=imgs[:-1])


def tiny_mark_svg(color):
    # Thicker strokes for ≤ 24 px so the arc survives downsampling.
    return svg(
        f'<g transform="translate(0 {CENTER_DY})">'
        f'<path d="{ARC_PATH}" fill="none" stroke="{color}" stroke-width="74" stroke-linecap="round"/>'
        f'<circle cx="{DOT[0]}" cy="{DOT[1]}" r="54" fill="{color}"/></g>'
    )


def android_vector(color_attr, viewport=108, inset=0.0, scale=None):
    """Vector drawable of the mark on a [viewport] canvas."""
    s = scale if scale is not None else (viewport - 2 * inset) / 512
    tx = inset if scale is None else (viewport - 512 * s) / 2
    ty = tx + CENTER_DY * s
    cx, cy, r = DOT
    return f'''<?xml version="1.0" encoding="utf-8"?>
<vector xmlns:android="http://schemas.android.com/apk/res/android"
    android:width="{viewport}dp" android:height="{viewport}dp"
    android:viewportWidth="{viewport}" android:viewportHeight="{viewport}">
    <group android:translateX="{tx:.3f}" android:translateY="{ty:.3f}" android:scaleX="{s:.5f}" android:scaleY="{s:.5f}">
        <path android:pathData="{ARC_PATH}" android:fillColor="#00000000"
            android:strokeColor="{color_attr}" android:strokeWidth="{STROKE}" android:strokeLineCap="round"/>
        <path android:pathData="M{cx - r},{cy} a{r},{r} 0 1,0 {2 * r},0 a{r},{r} 0 1,0 -{2 * r},0" android:fillColor="{color_attr}"/>
    </group>
</vector>
'''


def main():
    # --- Source SVGs -------------------------------------------------------
    write('branding/logo-mark.svg', mark_svg(GOLD))
    write('branding/logo-mark-mono.svg', mark_svg('#000000'))
    write('branding/logo-mark-white.svg', mark_svg('#FFFFFF'))
    write('branding/app-icon.svg', app_icon_svg())
    write('branding/logo-full-dark.svg', full_logo_svg(GOLD, WARM_WHITE))
    write('branding/logo-full-light.svg', full_logo_svg(INK, INK))
    write('branding/splash.svg', svg(f'<rect width="512" height="512" fill="{BG}"/>' + mark_group(GOLD, 0.5, 128, 128 + CENTER_DY * 0.5)))

    # --- Flutter assets ----------------------------------------------------
    write('assets/branding/logo_mark.svg', mark_svg(GOLD))
    write('assets/branding/logo_mark_mono.svg', mark_svg('#000000'))
    write('assets/branding/logo_full_dark.svg', full_logo_svg(GOLD, WARM_WHITE))
    write('assets/branding/logo_full_light.svg', full_logo_svg(INK, INK))
    png(app_icon_svg(), 512, p('assets/branding/app_icon_512.png'))
    tray = app_icon_svg(radius=120, mark_scale=0.74)
    png(tray, 32, p('assets/branding/tray_icon.png'))
    png(tiny_mark_svg('#FFFFFF'), 32, p('assets/branding/tray_icon_mono.png'))
    ico(tray, [16, 20, 24, 32, 48], p('assets/branding/tray_icon.ico'))

    # --- Windows -------------------------------------------------------------
    win_sizes = [16, 20, 24, 32, 40, 48, 64, 96, 128, 256]
    ico(app_icon_svg(), win_sizes, p('windows/runner/resources/app_icon.ico'))
    ico(app_icon_svg(), win_sizes, p('packaging/windows/installer_icon.ico'))
    wiz = Image.new('RGB', (164, 314), BG)
    wiz.paste(png(mark_svg(GOLD), 112), (26, 101), png(mark_svg(GOLD), 112))
    wiz.save(p('packaging/windows/wizard_image.bmp'))
    small = Image.new('RGB', (55, 55), BG)
    m = png(mark_svg(GOLD), 43)
    small.paste(m, (6, 6), m)
    small.save(p('packaging/windows/wizard_small.bmp'))

    # --- Linux (hicolor) -----------------------------------------------------
    for s in [16, 22, 24, 32, 48, 64, 128, 256, 512]:
        src = tray if s <= 24 else app_icon_svg()
        png(src, s, p(f'packaging/linux/icons/hicolor/{s}x{s}/apps/app.fermata.player.png'))
    write('packaging/linux/icons/hicolor/scalable/apps/app.fermata.player.svg', app_icon_svg())
    write('packaging/linux/icons/hicolor/symbolic/apps/app.fermata.player-symbolic.svg', tiny_mark_svg('#000000'))

    # --- Android ------------------------------------------------------------
    res = 'android/app/src/main/res'
    for name, s in {'mdpi': 48, 'hdpi': 72, 'xhdpi': 96, 'xxhdpi': 144, 'xxxhdpi': 192}.items():
        png(app_icon_svg(radius=116), s, p(f'{res}/mipmap-{name}/ic_launcher.png'))
        round_svg = svg(f'<circle cx="256" cy="256" r="256" fill="{BG}"/>' + mark_group(GOLD, 0.6, 102.4, 102.4 + CENTER_DY * 0.6))
        png(round_svg, s, p(f'{res}/mipmap-{name}/ic_launcher_round.png'))
    # Adaptive icon: mark inside the 66 dp safe zone of the 108 dp canvas.
    write(f'{res}/drawable/ic_launcher_foreground.xml', android_vector(GOLD, scale=50 / 512))
    write(f'{res}/drawable/ic_launcher_monochrome.xml', android_vector('#FFFFFFFF', scale=50 / 512))
    adaptive = '''<?xml version="1.0" encoding="utf-8"?>
<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">
    <background android:drawable="@color/ic_launcher_background"/>
    <foreground android:drawable="@drawable/ic_launcher_foreground"/>
    <monochrome android:drawable="@drawable/ic_launcher_monochrome"/>
</adaptive-icon>
'''
    write(f'{res}/mipmap-anydpi-v26/ic_launcher.xml', adaptive)
    write(f'{res}/mipmap-anydpi-v26/ic_launcher_round.xml', adaptive)
    # Status-bar icon: white only, 24 dp.
    write(f'{res}/drawable/ic_stat_fermata.xml', android_vector('#FFFFFFFF', viewport=24, scale=21 / 512))
    write(f'{res}/values/colors.xml', f'''<?xml version="1.0" encoding="utf-8"?>
<resources>
    <color name="ic_launcher_background">{BG}</color>
    <color name="fermata_background">{BG}</color>
    <color name="fermata_gold">{GOLD}</color>
</resources>
''')
    launch = '''<?xml version="1.0" encoding="utf-8"?>
<layer-list xmlns:android="http://schemas.android.com/apk/res/android">
    <item android:drawable="@color/fermata_background"/>
    <item android:width="96dp" android:height="96dp" android:gravity="center"
        android:drawable="@drawable/ic_launcher_foreground"/>
</layer-list>
'''
    write(f'{res}/drawable/launch_background.xml', launch)
    write(f'{res}/drawable-v21/launch_background.xml', launch)

    # Validate XML we wrote.
    for d, _, files in os.walk(p(res)):
        for f in files:
            if f.endswith('.xml'):
                ET.parse(os.path.join(d, f))

    # --- Contact sheet for visual review ------------------------------------
    sheet = Image.new('RGB', (900, 300), LIGHT_BG)
    sheet.paste(Image.new('RGB', (900, 150), '#2A2A30'), (0, 0))
    x = 20
    for s in [16, 24, 32, 48, 128]:
        src = tray if s <= 24 else app_icon_svg()
        for row, y in ((0, 75), (1, 225)):
            im = png(src, s)
            sheet.paste(im, (x, y - s // 2), im)
        x += s + 40
    big = png(app_icon_svg(), 256)
    sheet.paste(big.resize((140, 140)), (720, 5), big.resize((140, 140)))
    sheet.save(p('branding/preview-contact-sheet.png'))
    print('Brand assets regenerated.')


if __name__ == '__main__':
    main()
