#!/usr/bin/env python3
"""Builds the README media (stills, GIFs, MP4s) into docs/media/.

The app renders its own transparent frames (`--render-frames`), so nothing from
your desktop ever appears in the media. Frames are composited onto a clean fake
desktop with a menu bar and a notch.

Needs: the built app (scripts/build-app.sh), Pillow (`pip3 install pillow`), ffmpeg.
Usage: scripts/make-media.py [style ...]   (default: all styles)
"""
import os
import shutil
import subprocess
import sys
from pathlib import Path

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parent.parent
APP = ROOT / "build" / "Blink Notch.app" / "Contents" / "MacOS" / "BlinkNotch"
OUT = ROOT / "docs" / "media"
WORK = ROOT / ".build" / "media"
FPS = 30
GIF_FPS = 15
SCALE = 2  # the app renders at 2x

# style -> second at which the still photo is taken
STILLS = {
    "classic": 1.39, "pillEye": 3.0, "lashes": 1.39, "slowCat": 2.0, "twoEyes": 1.7,
    "countdown": 3.5, "wiper": 1.45, "shutter": 1.39, "sleepy": 2.0, "buffering": 2.0,
    "bouncingEyeball": 3.0,
}

CANVAS_W, CANVAS_H = 440, 214  # points
NOTCH_W, NOTCH_H = 220, 38     # this MacBook's notch, in points


def backdrop():
    w, h = CANVAS_W * SCALE, CANVAS_H * SCALE
    img = Image.new("RGB", (w, h))
    px = img.load()
    top, bottom = (0x27, 0x32, 0x4D), (0x5A, 0x3A, 0x66)
    for y in range(h):
        for x in range(w):
            t = (0.65 * y / h + 0.35 * x / w)
            px[x, y] = tuple(round(top[i] + (bottom[i] - top[i]) * t) for i in range(3))
    d = ImageDraw.Draw(img, "RGBA")
    d.rectangle([0, 0, w, 38 * SCALE], fill=(0, 0, 0, 120))            # menu bar
    for i, x in enumerate((300, 330, 360, 390)):                         # placeholder menu icons
        d.ellipse([x * SCALE, 12 * SCALE, (x + 14) * SCALE, 26 * SCALE], fill=(255, 255, 255, 150 if i else 210))
    d.rounded_rectangle([40 * SCALE, 13 * SCALE, 100 * SCALE, 25 * SCALE], radius=4 * SCALE, fill=(255, 255, 255, 60))
    x0 = (CANVAS_W - NOTCH_W) / 2 * SCALE                                 # notch
    d.rounded_rectangle([x0, -20 * SCALE, x0 + NOTCH_W * SCALE, NOTCH_H * SCALE], radius=10 * SCALE, fill=(0, 0, 0, 255))
    return img


def render(style):
    raw = WORK / style / "raw"
    shutil.rmtree(raw, ignore_errors=True)
    subprocess.run([str(APP), "--style", style, "--message", "0", "--render-frames", str(raw), "--fps", str(FPS)],
                   check=True, stdout=subprocess.DEVNULL)
    return sorted(raw.glob("frame-*.png"))


def compose(frames, bg):
    out = []
    for f in frames:
        fg = Image.open(f).convert("RGBA")
        canvas = bg.copy().convert("RGBA")
        canvas.alpha_composite(fg, ((canvas.width - fg.width) // 2, 0))
        out.append(canvas.convert("RGB"))
    return out


def main():
    if not APP.exists():
        sys.exit("Build the app first: scripts/build-app.sh")
    styles = sys.argv[1:] or list(STILLS)
    for d in ("stills", "gifs", "videos"):
        (OUT / d).mkdir(parents=True, exist_ok=True)
    bg = backdrop()
    for style in styles:
        print("rendering", style, flush=True)
        composed = compose(render(style), bg)

        composed[round(STILLS[style] * FPS)].save(OUT / "stills" / f"{style}.png", optimize=True)

        small = [f.resize((CANVAS_W, CANVAS_H), Image.LANCZOS) for f in composed[:: FPS // GIF_FPS]]
        small[0].save(OUT / "gifs" / f"{style}.gif", save_all=True, append_images=small[1:],
                      duration=round(1000 / GIF_FPS), loop=0, optimize=True)

        frames_dir = WORK / style / "composed"
        shutil.rmtree(frames_dir, ignore_errors=True)
        frames_dir.mkdir(parents=True)
        for i, f in enumerate(composed):
            f.save(frames_dir / f"f-{i:04d}.png")
        subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-framerate", str(FPS), "-i", str(frames_dir / "f-%04d.png"),
                        "-c:v", "libx264", "-pix_fmt", "yuv420p", "-crf", "20", "-movflags", "+faststart",
                        str(OUT / "videos" / f"{style}.mp4")], check=True)

    if not sys.argv[1:]:  # the reel and the contact sheet only when everything was built
        listing = WORK / "reel.txt"
        listing.write_text("".join(f"file '{OUT / 'videos' / s}.mp4'\n" for s in STILLS))
        subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-f", "concat", "-safe", "0", "-i", str(listing),
                        "-c", "copy", str(OUT / "videos" / "all-styles.mp4")], check=True)
        cols, w, h = 3, CANVAS_W, CANVAS_H
        rows = -(-len(STILLS) // cols)
        sheet = Image.new("RGBA", (cols * w, rows * h), (0, 0, 0, 0))
        for i, s in enumerate(STILLS):
            sheet.paste(Image.open(OUT / "stills" / f"{s}.png").resize((w, h), Image.LANCZOS), ((i % cols) * w, (i // cols) * h))
        sheet.save(OUT / "stills" / "all-styles.png", optimize=True)
    print("done:", OUT)


if __name__ == "__main__":
    main()
