#!/usr/bin/env python3
"""연습용 자리표시 이미지를 만든다 (실제 사진 없이 전체 과정을 시험할 때).

  public/<asset-root>/scene-01-framed.jpg ... (1080x1528, 장면마다 다른 색·도형)
  public/<asset-root>/hook.jpg                (1080x1920)

실제 영상에는 쓰지 않는다. 실제 영상은 장면마다 서로 다른 원본 사진으로 바꾼다.
이미 있는 파일은 덮어쓰지 않는다 (--force 를 주면 덮어씀).

실행 (프로젝트 폴더에서):
  bash scripts/py.sh .agents/skills/issuekiller-shorts/scripts/make_placeholders.py --asset-root 20261001-topic --scenes 4
"""

from __future__ import annotations

import argparse
import colorsys
import json
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

import _ik_env

FONT_CANDIDATES = [
    "/System/Library/Fonts/AppleSDGothicNeo.ttc",
    "/System/Library/Fonts/Supplemental/AppleGothic.ttf",
    "C:/Windows/Fonts/malgunbd.ttf",
    "C:/Windows/Fonts/malgun.ttf",
    "/usr/share/fonts/truetype/nanum/NanumGothicBold.ttf",
]


def load_font(size: int):
    for path in FONT_CANDIDATES:
        if Path(path).is_file():
            try:
                return ImageFont.truetype(path, size), True
            except OSError:
                continue
    try:
        return ImageFont.load_default(size=size), False
    except TypeError:
        return ImageFont.load_default(), False


def rgb(h: float, s: float, v: float) -> tuple[int, int, int]:
    r, g, b = colorsys.hsv_to_rgb(h % 1.0, s, v)
    return int(r * 255), int(g * 255), int(b * 255)


def make_image(index: int, total: int, size: tuple[int, int], label: str) -> Image.Image:
    width, height = size
    hue = index / max(total, 1)
    image = Image.new("RGB", size)
    draw = ImageDraw.Draw(image)
    top, bottom = rgb(hue, 0.55, 0.85), rgb(hue + 0.08, 0.75, 0.35)
    # 장면마다 그라디언트 방향을 바꿔 서로 다른 그림이 되게 한다
    for y in range(height):
        t = y / (height - 1)
        if index % 2:
            t = 1 - t
        color = tuple(int(top[c] * (1 - t) + bottom[c] * t) for c in range(3))
        draw.line([(0, y), (width, y)], fill=color)
    accent = rgb(hue + 0.5, 0.6, 0.95)
    shape = index % 4
    cx, cy = width // 2, int(height * 0.42)
    if shape == 0:
        draw.ellipse([cx - 300, cy - 300, cx + 300, cy + 300], fill=accent)
    elif shape == 1:
        draw.rectangle([90, 160, width - 90, cy + 220], fill=accent)
    elif shape == 2:
        draw.polygon([(cx, cy - 360), (cx + 380, cy + 280), (cx - 380, cy + 280)], fill=accent)
    else:
        for k in range(6):
            draw.rectangle([60 + k * 165, 120 + (k % 2) * 220, 180 + k * 165, cy + 300], fill=accent)
    font, korean = load_font(96)
    small, _ = load_font(48)
    text = label if korean else f"SAMPLE {index + 1}"
    draw.text((cx, cy), text, fill=(255, 255, 255), font=font, anchor="mm",
              stroke_width=6, stroke_fill=(0, 0, 0))
    note = "연습용 이미지 (실제 영상에는 교체)" if korean else "practice placeholder"
    draw.text((cx, cy + 150), note, fill=(255, 255, 255), font=small, anchor="mm",
              stroke_width=4, stroke_fill=(0, 0, 0))
    return image


def main() -> None:
    _ik_env.setup()
    parser = argparse.ArgumentParser(description="Create practice placeholder images for a Short.")
    parser.add_argument("--asset-root", required=True)
    parser.add_argument("--scenes", type=int, default=None,
                        help="Number of scene images (default: number of rows in voice-script.json)")
    parser.add_argument("--project", type=Path, default=None)
    parser.add_argument("--force", action="store_true")
    args = parser.parse_args()

    project = _ik_env.project_dir(args.project)
    asset_dir = project / "public" / args.asset_root
    if not asset_dir.is_dir():
        raise SystemExit(f"Missing asset directory (run scaffold_short.py first): {asset_dir}")
    count = args.scenes
    if count is None:
        count = len(json.loads((asset_dir / "voice-script.json").read_text(encoding="utf-8")))

    targets = [(asset_dir / f"scene-{i + 1:02d}-framed.jpg", i, (1080, 1528), f"장면 {i + 1}")
               for i in range(count)]
    targets.append((asset_dir / "hook.jpg", count, (1080, 1920), "훅 이미지"))
    for path, index, size, label in targets:
        if path.exists() and not args.force:
            print(f"skip (exists): {path.name}")
            continue
        make_image(index, count + 1, size, label).save(path, quality=92)
        print(f"created: {path}")


if __name__ == "__main__":
    main()
