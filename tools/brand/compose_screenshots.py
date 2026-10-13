"""Builds the Google Play phone screenshots: real app captures framed on the
brand background with a headline.

1. Capture 5 real screens from the app (portrait, any phone size), e.g.
     adb exec-out screencap -p > store/raw/01.png
   Order must match HEADLINES below.
2. Run from the repo root:  python3 tools/brand/compose_screenshots.py
3. Upload store/play/screenshots/01..05.png in Play Console (1080x1920).

Requires Pillow (pip install pillow).
"""
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = Path(__file__).resolve().parents[2]
RAW = ROOT / "store" / "raw"
OUT = ROOT / "store" / "play" / "screenshots"
BG = ROOT / "store" / "play" / "screenshot_background_1080x1920.png"
FONT = ROOT / "assets" / "fonts" / "Fredoka-Variable.ttf"

CREAM = (244, 241, 236)
AMBER = (255, 214, 140)  # lighter than the UI amber so it pops on the lamp glow

# (headline line 1, line 2, the word to colour amber). Keep claims true:
# the Daily has no pop-up (interstitial) ads; rewarded ads are opt-in only.
HEADLINES = [
    ("One cozy word", "puzzle a day", "cozy"),
    ("No pop-up ads", "in your Daily", "No"),
    ("So close? Keep going", "with one more row", "Keep"),
    ("Warm up with", "easy words first", "easy"),
    ("Share your streak", "with friends", "streak"),
]

W, H = 1080, 1920


def font(size: int, weight: int = 600) -> ImageFont.FreeTypeFont:
    f = ImageFont.truetype(str(FONT), size)
    try:
        f.set_variation_by_axes([weight])
    except Exception:  # static font or no variation support
        pass
    return f


def draw_line(draw: ImageDraw.ImageDraw, y: int, text: str, accent: str,
              f: ImageFont.FreeTypeFont) -> None:
    """Centered line; the accent word (if present) is drawn in amber."""
    words = text.split(" ")
    space = draw.textlength(" ", font=f)
    widths = [draw.textlength(w, font=f) for w in words]
    total = sum(widths) + space * (len(words) - 1)
    x = (W - total) / 2
    for word, width in zip(words, widths):
        colour = AMBER if word.strip(".,?!") == accent else CREAM
        draw.text((x, y), word, font=f, fill=colour)
        x += width + space


def frame(shot: Image.Image) -> Image.Image:
    """Scales a phone capture into a rounded card with a soft shadow."""
    target_h = 1340
    scale = target_h / shot.height
    target_w = round(shot.width * scale)
    if target_w > 760:  # very wide phones: fit width instead
        target_w = 760
        target_h = round(shot.height * target_w / shot.width)
    shot = shot.convert("RGB").resize((target_w, target_h), Image.LANCZOS)
    radius = 54
    mask = Image.new("L", shot.size, 0)
    ImageDraw.Draw(mask).rounded_rectangle(
        (0, 0, shot.width - 1, shot.height - 1), radius=radius, fill=255)
    card = Image.new("RGBA", shot.size)
    card.paste(shot, (0, 0), mask)
    return card


def compose(index: int, shot_path: Path) -> Path:
    canvas = Image.open(BG).convert("RGBA").resize((W, H))
    card = frame(Image.open(shot_path))
    x = (W - card.width) // 2
    y = 490

    shadow = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    ImageDraw.Draw(shadow).rounded_rectangle(
        (x + 6, y + 24, x + card.width + 6, y + card.height + 24),
        radius=60, fill=(0, 0, 0, 150))
    canvas = Image.alpha_composite(canvas, shadow.filter(ImageFilter.GaussianBlur(28)))

    rim = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    ImageDraw.Draw(rim).rounded_rectangle(
        (x - 3, y - 3, x + card.width + 2, y + card.height + 2),
        radius=57, outline=(224, 168, 87, 90), width=3)
    canvas = Image.alpha_composite(canvas, rim)
    canvas.alpha_composite(card, (x, y))

    line1, line2, accent = HEADLINES[index]
    f = font(84)
    # Soft dark halo behind the headline keeps it legible over the lamp glow.
    halo = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    hd = ImageDraw.Draw(halo)
    for yy, line in ((190, line1), (295, line2)):
        tw = hd.textlength(line, font=f)
        hd.rounded_rectangle(((W - tw) / 2 - 30, yy - 6, (W + tw) / 2 + 30, yy + 100),
                             radius=50, fill=(20, 12, 8, 150))
    canvas = Image.alpha_composite(canvas, halo.filter(ImageFilter.GaussianBlur(30)))
    draw = ImageDraw.Draw(canvas)
    draw_line(draw, 190, line1, accent, f)
    draw_line(draw, 295, line2, accent, f)

    OUT.mkdir(parents=True, exist_ok=True)
    out = OUT / f"{index + 1:02d}.png"
    canvas.convert("RGB").save(out, optimize=True)
    return out


def main() -> None:
    shots = sorted(RAW.glob("*.png"))
    if not shots:
        raise SystemExit(f"No captures in {RAW}. See the steps at the top.")
    for i, path in enumerate(shots[: len(HEADLINES)]):
        print("wrote", compose(i, path))


if __name__ == "__main__":
    main()
