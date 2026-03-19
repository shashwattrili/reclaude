#!/usr/bin/env python3
"""Generate Reclaude app icon — pixel art creature filling the full tile."""

from PIL import Image, ImageDraw
import os
import subprocess
import shutil

# Claude brand colors
PEACH      = (244, 194, 142)  # #f4c28e — body
DARK_PEACH = (210, 150, 100)  # darker peach — snout/shading
BROWN      = (160, 110, 70)   # brown — legs
DARK_BROWN = (120, 80, 50)    # dark brown — nostrils
EYE_COLOR  = (45, 35, 30)     # near-black — eyes
BG_COLOR   = (50, 48, 56)     # dark charcoal background
BLUSH      = (244, 180, 180)  # cheek blush

SIZE = 1024
P = SIZE // 32  # pixel size = 32px per grid cell


def rect(draw, gx1, gy1, gx2, gy2, fill):
    """Draw a rectangle in grid coordinates."""
    draw.rectangle([gx1 * P, gy1 * P, (gx2 + 1) * P - 1, (gy2 + 1) * P - 1], fill=fill)


def point(draw, gx, gy, fill):
    """Draw a single grid pixel."""
    rect(draw, gx, gy, gx, gy, fill)


def create_icon():
    img = Image.new('RGBA', (SIZE, SIZE), BG_COLOR)
    draw = ImageDraw.Draw(img)

    # Body — large, fills most of the canvas (cols 3-28, rows 6-22)
    rect(draw, 3, 8, 28, 22, PEACH)

    # Head top — full width across the top (cols 3-28, rows 6-8)
    rect(draw, 3, 6, 28, 8, PEACH)

    # Ears — stick up from head
    rect(draw, 1, 4, 5, 6, PEACH)   # left ear
    rect(draw, 26, 4, 30, 6, PEACH)  # right ear

    # Ear inner shading
    rect(draw, 2, 5, 4, 6, DARK_PEACH)   # left ear inner
    rect(draw, 27, 5, 29, 6, DARK_PEACH)  # right ear inner

    # Snout — slightly different shade, centered bottom
    rect(draw, 11, 22, 20, 25, DARK_PEACH)

    # Nostrils
    rect(draw, 13, 23, 14, 24, DARK_BROWN)
    rect(draw, 17, 23, 18, 24, DARK_BROWN)

    # Eyes — 3x4 grid cells each
    rect(draw, 9, 12, 12, 16, EYE_COLOR)    # left eye
    rect(draw, 19, 12, 22, 16, EYE_COLOR)   # right eye

    # Eye highlights — 1x1 white in top-left of each eye
    point(draw, 9, 12, (255, 255, 255, 200))
    point(draw, 10, 12, (255, 255, 255, 140))
    point(draw, 19, 12, (255, 255, 255, 200))
    point(draw, 20, 12, (255, 255, 255, 140))

    # Cheek blush — subtle pink spots below eyes
    rect(draw, 7, 17, 8, 18, (*BLUSH, 90))
    rect(draw, 23, 17, 24, 18, (*BLUSH, 90))

    # Legs — 4 legs hanging below body
    rect(draw, 5, 22, 8, 28, BROWN)     # front left
    rect(draw, 11, 22, 14, 27, BROWN)   # inner left
    rect(draw, 17, 22, 20, 27, BROWN)   # inner right
    rect(draw, 23, 22, 26, 28, BROWN)   # front right

    # Body bottom shading
    rect(draw, 3, 21, 28, 22, DARK_PEACH)

    return img


def create_icns(img, output_dir):
    iconset_dir = os.path.join(output_dir, "AppIcon.iconset")
    os.makedirs(iconset_dir, exist_ok=True)

    sizes = [16, 32, 64, 128, 256, 512, 1024]
    for s in sizes:
        resized = img.resize((s, s), Image.NEAREST)
        resized.save(os.path.join(iconset_dir, f"icon_{s}x{s}.png"))
        if s <= 512:
            resized_2x = img.resize((s * 2, s * 2), Image.NEAREST)
            resized_2x.save(os.path.join(iconset_dir, f"icon_{s}x{s}@2x.png"))

    icns_path = os.path.join(output_dir, "AppIcon.icns")
    subprocess.run(["iconutil", "-c", "icns", iconset_dir, "-o", icns_path], check=True)
    shutil.rmtree(iconset_dir)
    return icns_path


if __name__ == "__main__":
    script_dir = os.path.dirname(os.path.abspath(__file__))
    project_dir = os.path.dirname(script_dir)
    resources_dir = os.path.join(project_dir, "Reclaude", "Resources")
    os.makedirs(resources_dir, exist_ok=True)

    print("Generating Reclaude icon...")
    icon = create_icon()

    preview_path = os.path.join(resources_dir, "AppIcon.png")
    icon.save(preview_path)
    print(f"  PNG saved: {preview_path}")

    icns_path = create_icns(icon, resources_dir)
    print(f"  ICNS saved: {icns_path}")
    print("Done!")
