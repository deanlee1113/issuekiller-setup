#!/usr/bin/env python3
"""voice-timings.json 의 음성 구간을 Composition 의 장면 타이밍과 길이에 반영한다.

실행 (프로젝트 폴더에서):
  bash scripts/py.sh .claude/skills/issuekiller-shorts/scripts/sync_timing.py \\
    --asset-root 20261001-topic --composition-id Auto20261001Topic
"""

from __future__ import annotations

import argparse
import json
import math
import re
from pathlib import Path

import _ik_env


def constant_prefix(name: str) -> str:
    value = re.sub(r"(?<!^)(?=[A-Z])", "_", name).upper()
    return re.sub(r"[^A-Z0-9]+", "_", value).strip("_")


def main() -> None:
    _ik_env.setup()
    parser = argparse.ArgumentParser(
        description="Sync Supertonic segment timings into a generated Remotion composition."
    )
    parser.add_argument("--asset-root", required=True)
    parser.add_argument("--composition-id", required=True)
    parser.add_argument("--project", "--workspace", dest="project", type=Path, default=None,
                        help="Project folder (default: the folder that contains .claude/)")
    args = parser.parse_args()

    project = _ik_env.project_dir(args.project)
    asset_dir = project / "public" / args.asset_root
    composition_path = project / "src" / f"{args.composition_id}Composition.tsx"
    timing_path = asset_dir / "voice-timings.json"
    script_path = asset_dir / "voice-script.json"

    timings = json.loads(timing_path.read_text(encoding="utf-8"))
    script = json.loads(script_path.read_text(encoding="utf-8"))
    if not timings:
        raise SystemExit("voice-timings.json is empty")
    if len(timings) != len(script):
        raise SystemExit(
            f"Timing count {len(timings)} does not match script count {len(script)}"
        )

    rows = []
    previous_end = 0
    for index, timing in enumerate(timings, start=1):
        start_ms = int(timing["startMs"])
        end_ms = int(timing["endMs"])
        if start_ms != previous_end or end_ms <= start_ms:
            raise SystemExit(f"Invalid or non-contiguous timing at segment {index}")
        rows.append(f"  {{startMs: {start_ms}, endMs: {end_ms}}}")
        previous_end = end_ms

    duration_frames = math.ceil((previous_end / 1000) * 30) + 1
    prefix = constant_prefix(args.composition_id)
    source = composition_path.read_text(encoding="utf-8")
    source, duration_replacements = re.subn(
        rf"(export const {re.escape(prefix)}_DURATION_IN_FRAMES = )\d+(;)",
        rf"\g<1>{duration_frames}\g<2>",
        source,
        count=1,
    )
    timing_block = (
        "// ISSUEKILLER_TIMINGS_START\n"
        "const timings = [\n"
        + ",\n".join(rows)
        + ",\n] as const;\n"
        "// ISSUEKILLER_TIMINGS_END"
    )
    source, timing_replacements = re.subn(
        r"// ISSUEKILLER_TIMINGS_START.*?// ISSUEKILLER_TIMINGS_END",
        timing_block,
        source,
        count=1,
        flags=re.DOTALL,
    )
    if duration_replacements != 1 or timing_replacements != 1:
        raise SystemExit("Composition markers or duration constant were not found")
    composition_path.write_text(source, encoding="utf-8")

    print(f"Synced {len(rows)} scenes")
    print(f"Duration: {previous_end} ms / {duration_frames} frames")
    print(f"Updated: {composition_path}")


if __name__ == "__main__":
    main()
