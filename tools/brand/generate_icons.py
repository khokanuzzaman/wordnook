"""Regenerates every app icon + store graphic from the masters in store/source.

Run from the repo root:  python3 tools/brand/generate_icons.py
Requires Pillow (pip install pillow).
"""
from pathlib import Path

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[2]
SRC = ROOT / "store" / "source"
RES = ROOT / "android" / "app" / "src" / "main" / "res"
IOS = ROOT / "ios" / "Runner" / "Assets.xcassets" / "AppIcon.appiconset"

master = Image.open(SRC / "icon_master.png").convert("RGB")


def square(px: int) -> Image.Image:
    return master.resize((px, px), Image.LANCZOS)


def rounded(px: int, radius_ratio: float = 0.22) -> Image.Image:
    img = square(px).convert("RGBA")
    mask = Image.new("L", (px, px), 0)
    ImageDraw.Draw(mask).rounded_rectangle(
        (0, 0, px - 1, px - 1), radius=int(px * radius_ratio), fill=255)
    img.putalpha(mask)
    return img


# Android: legacy launcher (API 24-25) and adaptive foreground (API 26+).
# The adaptive foreground is a 108dp canvas; the full icon art is drawn at
# 72dp in the middle so every launcher mask shows the whole nook.
DENSITIES = {"mdpi": 1, "hdpi": 1.5, "xhdpi": 2, "xxhdpi": 3, "xxxhdpi": 4}
for name, scale in DENSITIES.items():
    folder = RES / f"mipmap-{name}"
    folder.mkdir(parents=True, exist_ok=True)
    rounded(round(48 * scale)).save(folder / "ic_launcher.png", optimize=True)
    canvas_px = round(108 * scale)
    art_px = round(72 * scale)
    fg = Image.new("RGBA", (canvas_px, canvas_px), (0, 0, 0, 0))
    offset = (canvas_px - art_px) // 2
    fg.paste(square(art_px).convert("RGBA"), (offset, offset))
    fg.save(folder / "ic_launcher_foreground.png", optimize=True)

# iOS: every size listed in Contents.json, opaque (App Store rejects alpha).
import json  # noqa: E402

contents = json.loads((IOS / "Contents.json").read_text())
for entry in contents["images"]:
    size = float(entry["size"].split("x")[0])
    scale = int(entry["scale"].rstrip("x"))
    px = round(size * scale)
    square(px).save(IOS / entry["filename"], optimize=True)

# In-app brand mark (About screen, menu drawer).
square(512).save(ROOT / "assets" / "brand" / "app_icon.png", optimize=True)

# Google Play listing assets.
out = ROOT / "store" / "play"
out.mkdir(parents=True, exist_ok=True)
square(512).save(out / "icon_512.png", optimize=True)
Image.open(SRC / "feature_graphic_master.png").convert("RGB").resize(
    (1024, 500), Image.LANCZOS).save(out / "feature_graphic_1024x500.png",
                                     optimize=True)
Image.open(SRC / "screenshot_background_master.png").convert("RGB").resize(
    (1080, 1920), Image.LANCZOS).save(out / "screenshot_background_1080x1920.png",
                                      optimize=True)
print("Icons and store graphics regenerated.")
