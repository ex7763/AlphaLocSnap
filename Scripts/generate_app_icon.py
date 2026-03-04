#!/usr/bin/env python3
"""Generate app icon for AlphaLocSnap app.

Usage:
    pip install Pillow
    python Scripts/generate_app_icon.py

Outputs 1024x1024 PNG icons to Assets.xcassets/AppIcon.appiconset/
"""
import os
from pathlib import Path

from PIL import Image, ImageDraw

SIZE = 1024
PROJECT_ROOT = Path(__file__).resolve().parent.parent
ICON_DIR = PROJECT_ROOT / "AlphaLocSnap" / "Assets.xcassets" / "AppIcon.appiconset"


def draw_icon() -> Image.Image:
    """Draw the app icon: camera + Bluetooth + GPS pin on blue gradient."""
    img = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)

    # Background - deep blue vertical gradient
    for y in range(SIZE):
        ratio = y / SIZE
        r = int(25 + ratio * 10)
        g = int(85 + ratio * 25)
        b = int(185 - ratio * 30)
        draw.line([(0, y), (SIZE, y)], fill=(r, g, b, 255))

    # Camera body
    cam_x, cam_y = 180, 300
    cam_w, cam_h = 660, 440
    draw.rounded_rectangle(
        [cam_x, cam_y, cam_x + cam_w, cam_y + cam_h],
        radius=50,
        fill=(255, 255, 255, 240),
    )

    # Viewfinder bump
    draw.rounded_rectangle([380, 240, 560, 310], radius=20, fill=(255, 255, 255, 240))

    # Shutter button
    draw.rounded_rectangle([580, 260, 660, 300], radius=15, fill=(230, 230, 230, 255))

    # Camera lens
    lens_cx, lens_cy = 510, 510
    draw.ellipse(
        [lens_cx - 140, lens_cy - 140, lens_cx + 140, lens_cy + 140],
        fill=(50, 55, 65, 255),
        outline=(70, 75, 85, 255),
        width=5,
    )
    draw.ellipse(
        [lens_cx - 105, lens_cy - 105, lens_cx + 105, lens_cy + 105],
        fill=(35, 38, 48, 255),
        outline=(65, 68, 78, 255),
        width=3,
    )
    draw.ellipse(
        [lens_cx - 70, lens_cy - 70, lens_cx + 70, lens_cy + 70],
        fill=(45, 48, 58, 255),
    )
    # Glass reflection
    draw.ellipse(
        [lens_cx - 35, lens_cy - 50, lens_cx + 15, lens_cy - 10],
        fill=(80, 85, 100, 150),
    )

    # GPS Location Pin - bottom-right of camera
    pin_cx, pin_cy = 730, 580
    pin_r = 85

    # Pin shadow
    draw.ellipse(
        [pin_cx - 50, pin_cy + 130, pin_cx + 50, pin_cy + 155],
        fill=(15, 60, 130, 80),
    )
    # Circle part
    draw.ellipse(
        [pin_cx - pin_r, pin_cy - pin_r, pin_cx + pin_r, pin_cy + pin_r],
        fill=(235, 65, 55, 255),
    )
    # Point
    draw.polygon(
        [(pin_cx - 52, pin_cy + 60), (pin_cx, pin_cy + 150), (pin_cx + 52, pin_cy + 60)],
        fill=(235, 65, 55, 255),
    )
    # White inner circle
    draw.ellipse(
        [pin_cx - 38, pin_cy - 38, pin_cx + 38, pin_cy + 38],
        fill=(255, 255, 255, 255),
    )
    # Red dot
    draw.ellipse(
        [pin_cx - 16, pin_cy - 16, pin_cx + 16, pin_cy + 16],
        fill=(235, 65, 55, 255),
    )

    # Bluetooth icon - on camera body top-left
    bt_cx, bt_cy = 300, 430
    bt_color = (50, 130, 220, 200)
    lw = 7
    draw.line([(bt_cx, bt_cy - 45), (bt_cx, bt_cy + 45)], fill=bt_color, width=lw)
    draw.line([(bt_cx, bt_cy - 45), (bt_cx + 28, bt_cy - 18)], fill=bt_color, width=lw)
    draw.line([(bt_cx + 28, bt_cy - 18), (bt_cx - 22, bt_cy + 18)], fill=bt_color, width=lw)
    draw.line([(bt_cx, bt_cy + 45), (bt_cx + 28, bt_cy + 18)], fill=bt_color, width=lw)
    draw.line([(bt_cx + 28, bt_cy + 18), (bt_cx - 22, bt_cy - 18)], fill=bt_color, width=lw)

    return img


def main():
    os.makedirs(ICON_DIR, exist_ok=True)
    icon = draw_icon()

    # Light mode (default)
    path = ICON_DIR / "AppIcon.png"
    icon.save(path, "PNG")
    print(f"Saved: {path}")

    # Dark mode (same icon; iOS handles tinting)
    dark_path = ICON_DIR / "AppIcon-Dark.png"
    icon.save(dark_path, "PNG")
    print(f"Saved: {dark_path}")

    # Tinted mode
    tinted_path = ICON_DIR / "AppIcon-Tinted.png"
    icon.save(tinted_path, "PNG")
    print(f"Saved: {tinted_path}")


if __name__ == "__main__":
    main()
