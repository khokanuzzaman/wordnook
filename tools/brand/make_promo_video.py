"""Builds a short 16:9 promo video (for the Play listing's YouTube slot) from the
real phone captures in store/raw/01..05.png.

Run from the repo root:  python3 tools/brand/make_promo_video.py
Output: store/play/promo_1920x1080.mp4 (H.264, 30 fps, silent; add music in
YouTube Studio's audio library if you like).

Requires Pillow and ffmpeg on PATH.
"""
import math
import subprocess
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = Path(__file__).resolve().parents[2]
RAW = ROOT / "store" / "raw"
SRC = ROOT / "store" / "source"
FONT = ROOT / "assets" / "fonts" / "Fredoka-Variable.ttf"
OUT = ROOT / "store" / "play" / "promo_1920x1080.mp4"

W, H, FPS = 1920, 1080, 30
CREAM = (244, 241, 236)
AMBER = (255, 214, 140)
SOFT = (214, 200, 182)

# Same claims as the store screenshots (keep them true).
SLIDES = [
    ("One cozy word", "puzzle a day", "cozy", "Guess the hidden 5-letter word in six tries."),
    ("No pop-up ads", "in your Daily", "No", "Your daily solve stays calm."),
    ("So close? Keep", "going, one more row", "Keep", "Out of guesses? Finish the word your way."),
    ("Warm up with", "easy words first", "easy", "New to word games? Start gently."),
    ("Share your streak", "with friends", "streak", "Spoiler-free results, every day."),
]
INTRO, SLIDE, OUTRO, FADE = 3.0, 3.4, 3.4, 0.5


def font(size, weight=600):
    f = ImageFont.truetype(str(FONT), size)
    try:
        f.set_variation_by_axes([weight])
    except Exception:
        pass
    return f


def ease(x):
    x = max(0.0, min(1.0, x))
    return 1 - (1 - x) ** 3


def background():
    bg = Image.open(SRC / "feature_graphic_master.png").convert("RGB")
    # Right part only: the lamp/tea scene, without the wordmark.
    bg = bg.crop((int(bg.width * 0.5), 0, bg.width, bg.height))
    scale = max(W / bg.width, H / bg.height)
    bg = bg.resize((math.ceil(bg.width * scale), math.ceil(bg.height * scale)), Image.LANCZOS)
    left, top = (bg.width - W) // 2, (bg.height - H) // 2
    bg = bg.crop((left, top, left + W, top + H)).filter(ImageFilter.GaussianBlur(26))
    shade = Image.new("RGB", (W, H), (18, 12, 8))
    return Image.blend(bg, shade, 0.55)


def phone_card(path, height=940):
    shot = Image.open(path).convert("RGB")
    w = round(shot.width * height / shot.height)
    shot = shot.resize((w, height), Image.LANCZOS)
    pad = 60
    card = Image.new("RGBA", (w + pad * 2, height + pad * 2), (0, 0, 0, 0))
    shadow = Image.new("RGBA", card.size, (0, 0, 0, 0))
    ImageDraw.Draw(shadow).rounded_rectangle(
        (pad + 6, pad + 22, pad + w + 6, pad + height + 22), radius=48, fill=(0, 0, 0, 170))
    card = Image.alpha_composite(card, shadow.filter(ImageFilter.GaussianBlur(24)))
    mask = Image.new("L", shot.size, 0)
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, w - 1, height - 1), radius=44, fill=255)
    rim = Image.new("RGBA", card.size, (0, 0, 0, 0))
    ImageDraw.Draw(rim).rounded_rectangle(
        (pad - 3, pad - 3, pad + w + 2, pad + height + 2), radius=47,
        outline=(224, 168, 87, 110), width=3)
    card = Image.alpha_composite(card, rim)
    card.paste(shot, (pad, pad), mask)
    return card


def text_layer(lines, accent, sub, x, y, big=92, align="left", alpha=1.0, dy=0):
    layer = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    f, fs = font(big), font(44, 500)
    a = int(255 * alpha)
    yy = y + dy
    for line in lines:
        words = line.split(" ")
        sp = d.textlength(" ", font=f)
        widths = [d.textlength(wd, font=f) for wd in words]
        total = sum(widths) + sp * (len(words) - 1)
        xx = x if align == "left" else x - total / 2
        for wd, ww in zip(words, widths):
            col = AMBER if wd.strip(".,?!") == accent else CREAM
            d.text((xx, yy), wd, font=f, fill=col + (a,))
            xx += ww + sp
        yy += int(big * 1.18)
    if sub:
        tw = d.textlength(sub, font=fs)
        sx = x if align == "left" else x - tw / 2
        d.text((sx, yy + 22), sub, font=fs, fill=SOFT + (a,))
    return layer


def icon(size):
    ic = Image.open(SRC / "icon_master.png").convert("RGBA").resize((size, size), Image.LANCZOS)
    mask = Image.new("L", ic.size, 0)
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, size - 1, size - 1), radius=int(size * 0.24), fill=255)
    out = Image.new("RGBA", ic.size, (0, 0, 0, 0))
    out.paste(ic, (0, 0), mask)
    return out


BG = background()
CARDS = [phone_card(RAW / f"{i:02d}.png") for i in range(1, 6)]
ICON = icon(300)


def with_alpha(img, a):
    if a >= 1:
        return img
    r = img.copy()
    r.putalpha(r.getchannel("A").point(lambda v: int(v * a)))
    return r


def brand_frame(t, dur, tagline, accent, sub):
    f = BG.convert("RGBA")
    k = ease(t / 0.8)
    ic = with_alpha(ICON, k)
    f.alpha_composite(ic, ((W - ICON.width) // 2, int(170 + 30 * (1 - k))))
    f = Image.alpha_composite(f, text_layer(["Wordnook"], "", None, W // 2, 520, big=120,
                                            align="center", alpha=ease((t - 0.3) / 0.8)))
    f = Image.alpha_composite(f, text_layer([tagline], accent, sub, W // 2, 690,
                                            big=64, align="center", alpha=ease((t - 0.7) / 0.8)))
    return f


def slide_frame(i, t):
    f = BG.convert("RGBA")
    l1, l2, accent, sub = SLIDES[i]
    k = ease(t / 0.7)
    card = CARDS[i]
    cx = 1080 + int(60 * (1 - k))
    cy = (H - card.height) // 2 + int(10 * math.sin(t * 1.2))
    f.alpha_composite(with_alpha(card, k), (cx, cy))
    f = Image.alpha_composite(f, text_layer([l1, l2], accent, sub, 150, 330,
                                            alpha=ease((t - 0.2) / 0.6), dy=int(24 * (1 - ease((t - 0.2) / 0.6)))))
    return f


def timeline():
    segs = [("intro", INTRO)] + [("slide", SLIDE)] * len(SLIDES) + [("outro", OUTRO)]
    return segs


def render(seg_idx, kind, t, dur):
    if kind == "intro":
        return brand_frame(t, dur, "One cozy word puzzle a day", "cozy", None)
    if kind == "outro":
        return brand_frame(t, dur, "Free on Google Play", "Free", "Download Wordnook and start your streak today.")
    return slide_frame(seg_idx - 1, t)


def main():
    segs = timeline()
    starts, acc = [], 0.0
    for _, d in segs:
        starts.append(acc)
        acc += d - FADE
    total = acc + FADE
    n = int(total * FPS)
    OUT.parent.mkdir(parents=True, exist_ok=True)
    proc = subprocess.Popen([
        "ffmpeg", "-y", "-loglevel", "error", "-f", "rawvideo", "-pix_fmt", "rgb24",
        "-s", f"{W}x{H}", "-r", str(FPS), "-i", "-",
        "-c:v", "libx264", "-preset", "slow", "-crf", "18", "-pix_fmt", "yuv420p",
        "-movflags", "+faststart", str(OUT)], stdin=subprocess.PIPE)
    for fi in range(n):
        t = fi / FPS
        active = [(i, t - s) for i, s in enumerate(starts) if 0 <= t - s < segs[i][1]]
        frame = None
        for i, lt in active:
            img = render(i, segs[i][0], lt, segs[i][1])
            dur = segs[i][1]
            a = 1.0
            if i > 0 and lt < FADE:
                a = lt / FADE
            if frame is None:
                frame = img
            else:
                frame = Image.blend(frame, img, a)
        if frame is None:
            frame = BG.convert("RGBA")
        # Fade from/to black at the very start and end.
        edge = min(t / 0.4, (total - t) / 0.6, 1.0)
        if edge < 1:
            frame = Image.blend(Image.new("RGBA", (W, H), (0, 0, 0, 255)), frame, max(edge, 0))
        proc.stdin.write(frame.convert("RGB").tobytes())
    proc.stdin.close()
    proc.wait()
    print("wrote", OUT, f"{total:.1f}s")


if __name__ == "__main__":
    main()
