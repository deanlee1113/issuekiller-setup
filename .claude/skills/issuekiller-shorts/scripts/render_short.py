#!/usr/bin/env python3
"""타입 검사 → Remotion 렌더 → 자동 검수(validate_short.py)를 한 번에 실행한다.

실행 (프로젝트 폴더에서):
  bash scripts/py.sh .claude/skills/issuekiller-shorts/scripts/render_short.py \\
    --asset-root 20261001-topic --composition-id Auto20261001Topic
기본 출력: output/<asset-root>-final.mp4, qc/<asset-root>/contact.jpg
"""

from __future__ import annotations

import argparse
import subprocess
import sys
from pathlib import Path

import _ik_env

VALIDATOR = Path(__file__).resolve().with_name("validate_short.py")


def main() -> None:
    _ik_env.setup()
    parser = argparse.ArgumentParser(
        description="Type-check, render, and validate a Remotion Shorts composition."
    )
    parser.add_argument("--asset-root", required=True)
    parser.add_argument("--composition-id", required=True)
    parser.add_argument("--output", type=Path)
    parser.add_argument("--project", "--workspace", dest="project", type=Path, default=None,
                        help="Project folder (default: the folder that contains .claude/)")
    parser.add_argument("--force", action="store_true")
    args = parser.parse_args()

    project = _ik_env.project_dir(args.project)
    output = (
        args.output.resolve()
        if args.output
        else project / "output" / f"{args.asset_root}-final.mp4"
    )
    output.parent.mkdir(parents=True, exist_ok=True)
    if output.exists():
        if not args.force:
            raise SystemExit(f"Output exists; pass --force to replace it (or use --output with a new name): {output}")
        output.unlink()

    npx = _ik_env.tool("npx")

    print("[1/3] TypeScript check", flush=True)
    subprocess.run([npx, "tsc", "--noEmit"], cwd=project, check=True)

    print("[2/3] Remotion render", flush=True)
    subprocess.run(
        [
            npx,
            "remotion",
            "render",
            "src/index.ts",
            args.composition_id,
            str(output),
            "--codec=h264",
            "--crf=18",
            "--audio-codec=aac",
        ],
        cwd=project,
        check=True,
    )

    print("[3/3] Automated QC", flush=True)
    subprocess.run(
        [
            sys.executable,
            str(VALIDATOR),
            "--project",
            str(project),
            "--asset-root",
            args.asset_root,
            "--mp4",
            str(output),
        ],
        check=True,
    )
    print(f"Final MP4: {output}")


if __name__ == "__main__":
    main()
