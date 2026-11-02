"""Build the CurseForge upload: dist/DialogueUI_UALL-<version>.zip with one top-level
DialogueUI_UALL/ folder (CurseForge needs the TOC name to match its folder).

python3 tools/make_zip.py   (WSL or Windows; standard library only)
"""
import re
import zipfile
from pathlib import Path

HERE = Path(__file__).resolve().parent
ADDON = HERE.parent / "DialogueUI_UALL"
FILES = ["DialogueUI_UALL.toc", "Core.lua", "Window.lua", "Logo.tga", "LICENSE.txt", "CHANGELOG.md"]

version = re.search(r"^## Version:\s*(\S+)", (ADDON / FILES[0]).read_text(encoding="utf-8"), re.M).group(1)
extra = sorted(p.name for p in ADDON.iterdir() if p.name not in FILES)
if extra:
    raise SystemExit(f"unexpected files in the addon folder, add them to FILES or remove: {extra}")

out = HERE.parent / "dist" / f"DialogueUI_UALL-{version}.zip"
out.parent.mkdir(exist_ok=True)
with zipfile.ZipFile(out, "w", zipfile.ZIP_DEFLATED) as z:
    for name in FILES:
        z.write(ADDON / name, f"DialogueUI_UALL/{name}")
print(out, out.stat().st_size, "bytes")
