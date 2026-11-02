"""Cut the Codex logo (logo-1024.png, flat black background) into the published sizes.

WSL: python3 make_icons.py   (Pillow only)
- logo-400.png / logo-256.png: CurseForge project avatar, black background kept.
- ../../DialogueUI_UALL/Logo.tga: 64x64 in-game icon (TOC IconTexture), background made
  transparent. The background is whatever dark area is connected to the image border
  (flood fill), so the dark outline inside the bubble stays opaque; the outer glow keeps
  a soft alpha taken from its brightness.
"""
from pathlib import Path
from PIL import Image, ImageDraw

HERE = Path(__file__).resolve().parent
SRC = HERE / "logo-1024.png"
ICON = HERE.parent.parent / "DialogueUI_UALL" / "Logo.tga"   # TGA: what the client finds for an IconTexture without extension
DARK = 120     # max(r, g, b) below this, connected to the border, is background or glow
GLOW = 120     # brightness at which the glow becomes fully opaque

src = Image.open(SRC).convert("RGB")
for size in (400, 256):
    src.resize((size, size), Image.LANCZOS).save(HERE / f"logo-{size}.png")

w, h = src.size
mask = Image.new("L", (w, h))
mask.putdata([255 if max(p) >= DARK else 0 for p in src.getdata()])
# mark background: flood from every border pixel that is dark
for x, y in [(x, 0) for x in range(0, w, 16)] + [(x, h - 1) for x in range(0, w, 16)] \
        + [(0, y) for y in range(0, h, 16)] + [(w - 1, y) for y in range(0, h, 16)]:
    if mask.getpixel((x, y)) == 0:
        ImageDraw.floodfill(mask, (x, y), 128)

rgba = []
for p, m in zip(src.getdata(), mask.getdata()):
    if m == 128:   # background or faint glow: alpha from brightness, colour un-premultiplied
        a = min(255, int(max(p) * 255 / GLOW))
        rgba.append((*(min(255, c * 255 // a) for c in p), a) if a else (0, 0, 0, 0))
    else:
        rgba.append((*p, 255))
out = Image.new("RGBA", (w, h))
out.putdata(rgba)
out.resize((64, 64), Image.LANCZOS).save(ICON)
out.resize((256, 256), Image.LANCZOS).save(HERE / "logo-transparent-256.png")
print("ok", ICON)
