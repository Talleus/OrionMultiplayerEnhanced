"""Compose the repository cover from local original-game artwork."""

import argparse
import hashlib
import json
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont, PngImagePlugin


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--background", type=Path, required=True)
    parser.add_argument("--logo", type=Path, required=True)
    parser.add_argument("--font", type=Path, required=True)
    parser.add_argument("--output", type=Path, default=Path("docs/assets/banner.png"))
    args = parser.parse_args()

    width, height = 1280, 720
    background = Image.open(args.background).convert("RGB")
    scaled_height = round(background.height * width / background.width)
    background = background.resize((width, scaled_height), Image.Resampling.LANCZOS)
    top = min(100, max(0, scaled_height - height))
    cover = background.crop((0, top, width, top + height)).convert("RGBA")

    logo = Image.open(args.logo).convert("RGBA")
    bounds = logo.getchannel("A").getbbox()
    if not bounds:
        raise SystemExit("Logo has no visible pixels.")
    logo = logo.crop(bounds)
    logo_width = 940
    logo = logo.resize((logo_width, round(logo.height * logo_width / logo.width)), Image.Resampling.LANCZOS)
    cover.alpha_composite(logo, ((width - logo.width) // 2, 12))

    text = "МУЛЬТИПЛЕЕР"
    size = 91
    draw = ImageDraw.Draw(cover)
    while True:
        font = ImageFont.truetype(str(args.font), size)
        box = draw.textbbox((0, 0), text, font=font, stroke_width=5)
        if box[2] - box[0] <= width - 136:
            break
        size -= 1
    x = (width - draw.textlength(text, font=font)) / 2
    y = 625 - (box[1] + box[3]) / 2
    # Match the game's bold lettering: a short solid extrusion and quiet outline.
    for offset in range(7, 0, -1):
        draw.text((x, y + offset), text, font=font, fill="#063b48", stroke_width=5, stroke_fill="#063b48")
    draw.text((x, y), text, font=font, fill="#ffffff", stroke_width=4, stroke_fill="#0b5663")

    args.output.parent.mkdir(parents=True, exist_ok=True)
    metadata = PngImagePlugin.PngInfo()
    metadata.add_itxt("Description", "Original Orion Sandbox Enhanced menu artwork with the added label МУЛЬТИПЛЕЕР")
    metadata.add_text("Rights", "Original game artwork and lettering remain with their respective owners; outside the project MIT license")
    cover.convert("RGB").save(args.output, optimize=True, pnginfo=metadata)
    report = {
        "file": args.output.name,
        "size": [width, height],
        "text": text,
        "sources": {
            "background": {"swf_character_id": 1190, "symbol": "assets.Images_LOBBY_BACKGROUND_CLASS", "sha256": hashlib.sha256(args.background.read_bytes()).hexdigest()},
            "logo": {"swf_character_id": 164, "source": "main_screen.main_menu_gamename, frame 1 at 2x", "sha256": hashlib.sha256(args.logo.read_bytes()).hexdigest()},
            "lettering": {"swf_character_id": 1278, "name": "ZantrokeRuFrEs", "font_file_bundled": False},
        },
        "edits": "Crop and resize the original background; composite the original logo; add the exact Cyrillic label. No generated artwork.",
        "rights": "Original game artwork and lettering are outside MIT; see THIRD_PARTY_NOTICES.md",
        "sha256": hashlib.sha256(args.output.read_bytes()).hexdigest(),
    }
    args.output.with_suffix(".json").write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(json.dumps({"output": str(args.output), "size": [width, height], "text": text, "bytes": args.output.stat().st_size}, ensure_ascii=False))


if __name__ == "__main__":
    main()
