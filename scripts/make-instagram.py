#!/usr/bin/env python3
"""Builds the Instagram kit into instagram/: a 9:16 Reel and a 4:5 photo carousel.

Reuses the transparent frames the app renders itself (scripts/make-media.py fills
.build/media/<style>/raw), so nothing from a real desktop appears.

Needs: the raw frames (run scripts/make-media.py first), Pillow, ffmpeg.
Usage: scripts/make-instagram.py
"""
import subprocess
import sys
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = Path(__file__).resolve().parent.parent
WORK = ROOT / ".build" / "media"
OUT = ROOT / "instagram"
ICON = ROOT / "docs" / "media" / "icon.png"
FPS = 30

W = 1080
REEL_H, POST_H = 1920, 1350
SCALE = 2                    # raw frames are 2x
SCENE_W_PT, SCENE_H_PT = 440, 300
NOTCH_W, NOTCH_H = 220, 38
CARD_W = 960                 # screen card width on the 1080 canvas

CORAL = (255, 90, 95)
WHITE = (255, 255, 255)
SOFT = (200, 205, 225)

REEL_STYLES = [  # (style, label)
    ("classic", "Classic eye"),
    ("sleepy", "Sleepy eye"),
    ("countdown", "Countdown"),
    ("buffering", "Buffering eye"),
    ("shutter", "Camera shutter"),
    ("bouncingEyeball", "Bouncing eyeball"),
]
ALL_STYLES = ["classic", "pillEye", "lashes", "slowCat", "twoEyes", "countdown",
              "wiper", "shutter", "sleepy", "buffering", "bouncingEyeball"]
STILL_AT = {  # second of the still photo, same as make-media.py
    "classic": 1.39, "pillEye": 3.0, "lashes": 1.39, "slowCat": 2.0, "twoEyes": 1.7,
    "countdown": 3.5, "wiper": 1.45, "shutter": 1.39, "sleepy": 2.0, "buffering": 2.0,
    "bouncingEyeball": 3.0,
}


# ---------- fonts ----------
def avenir(size, weight="Bold"):
    idx = {"Bold": 0, "Demi": 2, "Medium": 5, "Regular": 7, "Heavy": 8}[weight]
    return ImageFont.truetype("/System/Library/Fonts/Avenir Next.ttc", size, index=idx)


def mono(size, bold=False):
    return ImageFont.truetype("/System/Library/Fonts/Menlo.ttc", size, index=1 if bold else 0)


# ---------- drawing helpers ----------
def gradient(w, h, top, bottom):
    img = Image.new("RGB", (w, h))
    d = ImageDraw.Draw(img)
    for y in range(h):
        t = y / (h - 1)
        d.line([(0, y), (w, y)], fill=tuple(round(top[i] + (bottom[i] - top[i]) * t) for i in range(3)))
    return img


def page_bg(h):
    return gradient(W, h, (0x14, 0x18, 0x2B), (0x3B, 0x22, 0x4A))


def wrap(draw, text, font, max_w):
    lines = []
    for para in text.split("\n"):
        line = ""
        for word in para.split():
            trial = (line + " " + word).strip()
            if draw.textlength(trial, font=font) <= max_w:
                line = trial
            else:
                lines.append(line)
                line = word
        lines.append(line)
    return lines


def text_block(draw, xy, text, font, fill, max_w=None, align="center", spacing=1.18):
    """Draws wrapped text. xy = (center x or left x, top y). Returns bottom y."""
    x, y = xy
    lines = wrap(draw, text, font, max_w) if max_w else text.split("\n")
    lh = round(font.size * spacing)
    for line in lines:
        w = draw.textlength(line, font=font)
        draw.text((x - w / 2 if align == "center" else x, y), line, font=font, fill=fill)
        y += lh
    return y


def pill_label(draw, cx, y, text, font, fill=(78, 66, 112, 255), color=WHITE, pad=(34, 16)):
    w = draw.textlength(text, font=font)
    box = [cx - w / 2 - pad[0], y, cx + w / 2 + pad[0], y + font.size + pad[1] * 2]
    draw.rounded_rectangle(box, radius=(box[3] - box[1]) / 2, fill=fill)
    draw.text((cx - w / 2, y + pad[1] - 2), text, font=font, fill=color)
    return box[3]


# ---------- the fake screen card ----------
def scene_backdrop():
    w, h = SCENE_W_PT * SCALE, SCENE_H_PT * SCALE
    img = Image.new("RGB", (w, h))
    px = img.load()
    top, bottom = (0x27, 0x32, 0x4D), (0x5A, 0x3A, 0x66)
    for y in range(h):
        for x in range(w):
            t = 0.65 * y / h + 0.35 * x / w
            px[x, y] = tuple(round(top[i] + (bottom[i] - top[i]) * t) for i in range(3))
    d = ImageDraw.Draw(img, "RGBA")
    d.rectangle([0, 0, w, 38 * SCALE], fill=(0, 0, 0, 120))
    for i, x in enumerate((300, 330, 360, 390)):
        d.ellipse([x * SCALE, 12 * SCALE, (x + 14) * SCALE, 26 * SCALE], fill=(255, 255, 255, 150 if i else 210))
    d.rounded_rectangle([40 * SCALE, 13 * SCALE, 100 * SCALE, 25 * SCALE], radius=4 * SCALE, fill=(255, 255, 255, 60))
    x0 = (SCENE_W_PT - NOTCH_W) / 2 * SCALE
    d.rounded_rectangle([x0, -20 * SCALE, x0 + NOTCH_W * SCALE, NOTCH_H * SCALE], radius=10 * SCALE, fill=(0, 0, 0, 255))
    return img.convert("RGBA")


SCENE = scene_backdrop()
REEL_PT, POST_PT = 214, 160   # card heights in points: the Reel needs room for the bouncing eyeball


def card_h(h_pt):
    return round(h_pt * SCALE * CARD_W / SCENE.width)


def card_mask(h_pt, radius=40):
    m = Image.new("L", (CARD_W, card_h(h_pt)), 0)
    ImageDraw.Draw(m).rounded_rectangle([0, 0, CARD_W - 1, card_h(h_pt) - 1], radius=radius, fill=255)
    return m


REEL_MASK = card_mask(REEL_PT)
POST_MASK = card_mask(POST_PT)


def scene_frame(frame_path, h_pt):
    """Scene with one transparent app frame composited at the top centre, cropped and scaled to the card."""
    canvas = SCENE.copy()
    if frame_path is not None:
        fg = Image.open(frame_path).convert("RGBA")
        canvas.alpha_composite(fg, ((canvas.width - fg.width) // 2, 0))
    canvas = canvas.crop((0, 0, canvas.width, h_pt * SCALE))
    return canvas.resize((CARD_W, card_h(h_pt)), Image.LANCZOS)


def with_shadow(base, x, y, h_pt):
    """Paints a soft shadow for the card onto base (in place)."""
    sh = Image.new("RGBA", base.size, (0, 0, 0, 0))
    ImageDraw.Draw(sh).rounded_rectangle([x, y + 24, x + CARD_W, y + card_h(h_pt) + 24], radius=40, fill=(0, 0, 0, 150))
    sh = sh.filter(ImageFilter.GaussianBlur(34))
    base.alpha_composite(sh)


def frames_of(style):
    return sorted((WORK / style / "raw").glob("frame-*.png"))


def frame_at(style, seconds):
    return frames_of(style)[round(seconds * FPS)]


def still(style):
    return frame_at(style, STILL_AT[style])


# ---------- Reel ----------
def reel_base(label_line, label_sub, footer):
    """Static layer for one reel segment. Returns (RGBA image, card position)."""
    img = page_bg(REEL_H).convert("RGBA")
    d = ImageDraw.Draw(img)
    text_block(d, (W / 2, 290), "Your Mac now\nreminds you\nto blink.", avenir(92, "Heavy"), WHITE)
    card_x, card_y = (W - CARD_W) // 2, 700
    with_shadow(img, card_x, card_y, REEL_PT)
    d = ImageDraw.Draw(img)
    y = card_y + card_h(REEL_PT) + 80
    if label_line:
        y = pill_label(d, W / 2, y, label_line, avenir(46, "Bold"))
    if label_sub:
        text_block(d, (W / 2, y + 34), label_sub, avenir(40, "Medium"), SOFT)
    text_block(d, (W / 2, 1530), footer, avenir(40, "Demi"), SOFT)
    return img, (card_x, card_y)


def start_encoder(path):
    return subprocess.Popen(
        ["ffmpeg", "-y", "-loglevel", "error", "-f", "rawvideo", "-pix_fmt", "rgb24", "-s", f"{W}x{REEL_H}",
         "-r", str(FPS), "-i", "-", "-c:v", "libx264", "-pix_fmt", "yuv420p", "-crf", "18",
         "-movflags", "+faststart", str(path)],
        stdin=subprocess.PIPE)


def push(enc, base, pos, frame_path):
    card = scene_frame(frame_path, REEL_PT)
    out = base.copy()
    out.paste(card, pos, REEL_MASK)
    enc.stdin.write(out.convert("RGB").tobytes())


def outro_frame():
    img = page_bg(REEL_H).convert("RGBA")
    d = ImageDraw.Draw(img)
    icon = Image.open(ICON).convert("RGBA").resize((360, 360), Image.LANCZOS)
    img.alpha_composite(icon, ((W - 360) // 2, 420))
    text_block(d, (W / 2, 840), "Blink Notch", avenir(120, "Heavy"), WHITE)
    text_block(d, (W / 2, 1000), "Free. Open source. MIT.", avenir(56, "Medium"), SOFT)
    pill_label(d, W / 2, 1150, "Link in bio", avenir(60, "Heavy"), fill=CORAL + (255,), pad=(56, 24))
    text_block(d, (W / 2, 1360), "github.com/lefotugrapher/blink-notch", mono(34), SOFT)
    return img.convert("RGB")


def build_reel():
    path = OUT / "reel.mp4"
    enc = start_encoder(path)
    # intro: empty desktop, hook text
    base, pos = reel_base("Pssst.", "Blink.", "11 animations · never the same twice")
    for _ in range(round(2.2 * FPS)):
        push(enc, base, pos, None)
    for style, label in REEL_STYLES:
        print("reel:", style, flush=True)
        base, pos = reel_base(label, "fake new mail, real reminder", "Blink Notch · free & open source")
        for f in frames_of(style):
            push(enc, base, pos, f)
    outro = outro_frame().tobytes()
    for _ in range(round(3.5 * FPS)):
        enc.stdin.write(outro)
    enc.stdin.close()
    if enc.wait() != 0:
        sys.exit("ffmpeg failed")
    # cover image for the Reel (1080x1920)
    base, pos = reel_base("Classic eye", "fake new mail, real reminder", "Blink Notch · free & open source")
    cover = base.copy()
    cover.paste(scene_frame(still("classic"), REEL_PT), pos, REEL_MASK)
    cover.convert("RGB").save(OUT / "reel-cover.jpg", quality=95)
    print("reel done:", path)


# ---------- Carousel ----------
def post_canvas():
    return page_bg(POST_H).convert("RGBA")


def paste_card(img, y, frame_path):
    x = (W - CARD_W) // 2
    with_shadow(img, x, y, POST_PT)
    img.paste(scene_frame(frame_path, POST_PT), (x, y), POST_MASK)
    return y + card_h(POST_PT)


def save_post(img, n, name):
    img.convert("RGB").save(OUT / f"carousel-{n:02d}-{name}.jpg", quality=95)


def slide_cover():
    img = post_canvas()
    d = ImageDraw.Draw(img)
    text_block(d, (W / 2, 190), "I built a Mac app that\nreminds me to blink.", avenir(88, "Heavy"), WHITE)
    bottom = paste_card(img, 540, frame_at("classic", 1.05))
    d = ImageDraw.Draw(img)
    text_block(d, (W / 2, bottom + 70), "A fake new-mail notification\ndrops out of the notch.", avenir(42, "Medium"), SOFT)
    pill_label(d, W / 2, 1190, "swipe", avenir(36, "Bold"))
    save_post(img, 1, "cover")


def slide_how():
    img = post_canvas()
    d = ImageDraw.Draw(img)
    text_block(d, (W / 2, 130), "Every 20 minutes,\nthe notch pops a joke.", avenir(78, "Heavy"), WHITE)
    bottom = paste_card(img, 430, still("pillEye"))
    d = ImageDraw.Draw(img)
    text_block(d, (W / 2, bottom + 80),
               "A circle drops out, grows into a pill, an eye slams its eyelid at you, then it rises away. About 6 seconds. You can't click it and it never steals focus.",
               avenir(38, "Medium"), SOFT, max_w=900)
    save_post(img, 2, "how-it-works")


def slide_gallery():
    img = post_canvas()
    d = ImageDraw.Draw(img)
    text_block(d, (W / 2, 80), "11 animations.\nNever the same one twice.", avenir(72, "Heavy"), WHITE)
    cols, tw = 3, 330
    th = round(tw * 214 / 440)
    gap = 18
    x0 = (W - (cols * tw + (cols - 1) * gap)) // 2
    y0 = 360
    for i, s in enumerate(ALL_STYLES):
        thumb = Image.open(ROOT / "docs" / "media" / "stills" / f"{s}.png").convert("RGB").resize((tw, th), Image.LANCZOS)
        m = Image.new("L", (tw, th), 0)
        ImageDraw.Draw(m).rounded_rectangle([0, 0, tw - 1, th - 1], radius=18, fill=255)
        img.paste(thumb, (x0 + (i % cols) * (tw + gap), y0 + (i // cols) * (th + gap)), m)
    d = ImageDraw.Draw(img)
    text_block(d, (W / 2, y0 + 4 * (th + gap) + 50),
               "Classic eye, sleepy eye, countdown, buffering, camera shutter, a bouncing eyeball and more.",
               avenir(38, "Medium"), SOFT, max_w=880)
    save_post(img, 3, "all-styles")


def slide_private():
    img = post_canvas()
    d = ImageDraw.Draw(img)
    text_block(d, (W / 2, 150), "The email is fake.", avenir(96, "Heavy"), WHITE)
    bottom = paste_card(img, 360, still("countdown"))
    d = ImageDraw.Draw(img)
    y = bottom + 110
    for line in ("Never reads your mail", "Never touches the network", "No accounts, no analytics"):
        d.ellipse([170, y + 14, 202, y + 46], fill=CORAL)
        d.text((232, y), line, font=avenir(50, "Bold"), fill=WHITE)
        y += 92
    save_post(img, 4, "privacy")


def slide_install():
    img = post_canvas()
    d = ImageDraw.Draw(img)
    text_block(d, (W / 2, 90), "Install it in a minute.", avenir(82, "Heavy"), WHITE)
    text_block(d, (W / 2, 210), "macOS 14+. No full Xcode needed.", avenir(40, "Medium"), SOFT)
    steps = [
        ("1", "Get Apple's free command line tools", "xcode-select --install"),
        ("2", "Get the code", "git clone https://github.com/\nlefotugrapher/blink-notch.git\ncd blink-notch"),
        ("3", "Build and install", "scripts/build-app.sh --install"),
    ]
    y = 320
    for n, title, code in steps:
        d.ellipse([70, y, 130, y + 60], fill=CORAL)
        d.text((100 - d.textlength(n, font=avenir(38, "Heavy")) / 2, y + 6), n, font=avenir(38, "Heavy"), fill=WHITE)
        d.text((160, y + 8), title, font=avenir(42, "Bold"), fill=WHITE)
        lines = code.split("\n")
        bh = 36 + len(lines) * 44
        d.rounded_rectangle([70, y + 84, W - 70, y + 84 + bh], radius=22, fill=(8, 10, 20, 235))
        cy = y + 84 + 20
        for line in lines:
            d.text((100, cy), line, font=mono(31), fill=(170, 235, 190))
            cy += 44
        y += 84 + bh + 44
    save_post(img, 5, "install")


def slide_cta():
    img = post_canvas()
    d = ImageDraw.Draw(img)
    icon = Image.open(ICON).convert("RGBA").resize((300, 300), Image.LANCZOS)
    img.alpha_composite(icon, ((W - 300) // 2, 190))
    text_block(d, (W / 2, 540), "Blink Notch", avenir(112, "Heavy"), WHITE)
    text_block(d, (W / 2, 680), "Free. Open source. MIT license.", avenir(48, "Medium"), SOFT)
    pill_label(d, W / 2, 820, "Link in bio", avenir(58, "Heavy"), fill=CORAL + (255,), pad=(54, 22))
    text_block(d, (W / 2, 1010), "github.com/lefotugrapher/blink-notch", mono(33), SOFT)
    text_block(d, (W / 2, 1150), "Blink. You goof.", avenir(44, "Demi"), WHITE)
    save_post(img, 6, "get-it")


def build_carousel():
    for f in (slide_cover, slide_how, slide_gallery, slide_private, slide_install, slide_cta):
        print("carousel:", f.__name__, flush=True)
        f()


def main():
    if not frames_of("classic"):
        sys.exit("No raw frames. Run scripts/make-media.py first.")
    OUT.mkdir(exist_ok=True)
    only = sys.argv[1] if len(sys.argv) > 1 else "all"
    if only in ("all", "carousel"):
        build_carousel()
    if only in ("all", "reel"):
        build_reel()
    print("done:", OUT)


if __name__ == "__main__":
    main()
