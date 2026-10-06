#!/usr/bin/env python3
"""화면 모양(theme.json)을 바꾼 뒤 영상 한 장면을 사진 한 장(jpg)으로 빠르게 뽑아 본다.

영상 전체를 다시 렌더하지 않으므로 수십 초 안에 끝난다. 기존 파일은 덮어쓰지 않는다.

실행 (프로젝트 폴더에서):
  bash scripts/py.sh .agents/skills/issuekiller-shorts/scripts/preview_still.py
  bash scripts/py.sh .agents/skills/issuekiller-shorts/scripts/preview_still.py --composition-id Auto20261001Topic --seconds 3
  (--composition-id 를 빼면 가장 최근에 만든 영상을 쓴다)
기본 출력: qc/<asset-root>/theme-preview-01.jpg (이미 있으면 -02, -03 ...)
"""

from __future__ import annotations

import argparse
import re
import subprocess
from pathlib import Path

import _ik_env

FPS = 30


def latest_composition(project: Path) -> str:
    registry = project / "src" / "ClaudeGeneratedCompositions.tsx"
    ids = re.findall(r'id="([A-Za-z][A-Za-z0-9]*)"', registry.read_text(encoding="utf-8")) if registry.exists() else []
    if not ids:
        raise SystemExit("아직 만든 영상이 없습니다. 먼저 쇼츠를 하나 만든 뒤 미리보기를 뽑으세요.")
    return ids[-1]


def asset_root_of(project: Path, composition_id: str) -> str:
    path = project / "src" / f"{composition_id}Composition.tsx"
    if not path.exists():
        raise SystemExit(f"영상 파일을 찾지 못했습니다: {path}")
    match = re.search(r'assetRoot:\s*"([^"]+)"', path.read_text(encoding="utf-8"))
    return match.group(1) if match else composition_id


def main() -> None:
    _ik_env.setup()
    parser = argparse.ArgumentParser(description="Render one preview frame (jpg) of a composition.")
    parser.add_argument("--composition-id", default=None, help="default: the most recently registered composition")
    parser.add_argument("--seconds", type=float, default=2.0, help="time of the frame (default 2.0, after the hook card)")
    parser.add_argument("--output", type=Path, default=None)
    parser.add_argument("--project", "--workspace", dest="project", type=Path, default=None,
                        help="Project folder (default: the folder that contains .agents/)")
    args = parser.parse_args()

    project = _ik_env.project_dir(args.project)
    composition_id = args.composition_id or latest_composition(project)
    asset_root = asset_root_of(project, composition_id)

    if args.output:
        output = args.output if args.output.is_absolute() else project / args.output
        if output.exists():
            raise SystemExit(f"이미 있는 파일입니다. 다른 이름을 쓰세요: {output}")
    else:
        folder = project / "qc" / asset_root
        number = 1
        while (folder / f"theme-preview-{number:02d}.jpg").exists():
            number += 1
        output = folder / f"theme-preview-{number:02d}.jpg"
    output.parent.mkdir(parents=True, exist_ok=True)

    _ik_env.check_theme(project)
    npx = _ik_env.tool("npx")
    frame = max(0, round(args.seconds * FPS))
    print(f"미리보기 뽑는 중: {composition_id} {args.seconds:g}초 (프레임 {frame})", flush=True)
    subprocess.run(
        [
            npx,
            "remotion",
            "still",
            "src/index.ts",
            composition_id,
            str(output),
            f"--frame={frame}",
            "--image-format=jpeg",
            "--jpeg-quality=90",
        ],
        cwd=project,
        check=True,
    )
    print(f"Preview: {output}")


if __name__ == "__main__":
    main()
