#!/usr/bin/env python3
"""새 쇼츠의 자산 폴더와 Remotion Composition 을 만들고 등록부에 등록한다.

실행 (프로젝트 폴더 ~/issuekiller 에서):
  bash scripts/py.sh .agents/skills/issuekiller-shorts/scripts/scaffold_short.py \\
    --asset-root 20261001-topic --composition-id Auto20261001Topic --title '첫 줄\\n둘째 줄' --scenes 9
"""

from __future__ import annotations

import argparse
import json
import math
import re
import shutil
from pathlib import Path

import _ik_env

SKILL_DIR = _ik_env.SKILL_DIR
TEMPLATE_MODULE = "./NewsTemplate"


def constant_prefix(name: str) -> str:
    value = re.sub(r"(?<!^)(?=[A-Z])", "_", name).upper()
    return re.sub(r"[^A-Z0-9]+", "_", value).strip("_")


def assert_identifier(value: str, label: str) -> None:
    if not re.fullmatch(r"[A-Za-z][A-Za-z0-9]*", value):
        raise SystemExit(f"{label} must be an alphanumeric TypeScript identifier: {value}")


def build_voice_script(scene_count: int) -> list[dict[str, str]]:
    example_path = SKILL_DIR / "assets" / "voice-script.example.json"
    examples = json.loads(example_path.read_text(encoding="utf-8"))
    rows = []
    for index in range(scene_count):
        if index < len(examples):
            rows.append(examples[index])
        else:
            rows.append(
                {
                    "spokenText": f"장면 {index + 1}의 확인된 사실을 자연스럽게 작성합니다.",
                    "displayText": f"장면 {index + 1}의 핵심 내용을\n두 줄로 작성",
                }
            )
    return rows


def build_composition(
    asset_root: str,
    composition_id: str,
    title: str,
    scene_count: int,
    duration_seconds: float,
) -> str:
    fps = 30
    duration_ms = round(duration_seconds * 1000)
    duration_frames = math.ceil(duration_seconds * fps) + 1
    prefix = constant_prefix(composition_id)
    component_name = f"{composition_id}Composition"
    timings = []
    for index in range(scene_count):
        start_ms = round((duration_ms * index) / scene_count)
        end_ms = round((duration_ms * (index + 1)) / scene_count)
        timings.append({"startMs": start_ms, "endMs": end_ms})

    timing_lines = ",\n".join(
        f"  {{startMs: {row['startMs']}, endMs: {row['endMs']}}}"
        for row in timings
    )
    labels = ",\n".join(
        f"  {json.dumps(f'장면 {index + 1}', ensure_ascii=False)}"
        for index in range(scene_count)
    )
    title_literal = json.dumps(title.replace("\\n", "\n"), ensure_ascii=False)

    return f'''import {{createNewsComposition, type NewsConfig}} from "{TEMPLATE_MODULE}";

export const {prefix}_WIDTH = 1080;
export const {prefix}_HEIGHT = 1920;
export const {prefix}_FPS = 30;
export const {prefix}_DURATION_IN_FRAMES = {duration_frames};

const accents = [
  "#ffcc4d",
  "#75d6ff",
  "#a7f3d0",
  "#ff8ba6",
  "#f8df76",
  "#c8a5ff",
  "#ff9f6d",
  "#6fd3ff",
  "#ffcc4d",
  "#75d6ff",
];

// ISSUEKILLER_TIMINGS_START
const timings = [
{timing_lines},
] as const;
// ISSUEKILLER_TIMINGS_END

const sceneLabels = [
{labels},
];

const config: NewsConfig = {{
  assetRoot: {json.dumps(asset_root)},
  voiceFile: "voiceover-f1.wav",
  title: {title_literal},
  titleSize: 82,
  captionSize: 82,
  layoutPreset: "shorts-safe-v2",
  showProgress: false,
  maskBroadcastCorners: false,
  durationInFrames: {prefix}_DURATION_IN_FRAMES,
  highlightTerms: ["핵심어", "댓글로 남겨주세요"],
  scenes: timings.map((timing, index) => ({{
    ...timing,
    image: `scene-${{String(index + 1).padStart(2, "0")}}-framed.jpg`,
    accent: accents[index % accents.length],
    label: sceneLabels[index] ?? `장면 ${{index + 1}}`,
    position: "center center" as const,
    zoom: 1.004,
  }})),
}};

export const {component_name} = createNewsComposition(config);
'''


def register_composition(project: Path, composition_id: str) -> None:
    registry_path = project / "src" / "ClaudeGeneratedCompositions.tsx"
    registry = registry_path.read_text(encoding="utf-8")
    if f'id="{composition_id}"' in registry:
        raise SystemExit(f"Composition is already registered: {composition_id}")
    imports_end = "// ISSUEKILLER_GENERATED_IMPORTS_END"
    compositions_end = "      {/* ISSUEKILLER_GENERATED_COMPOSITIONS_END */}"
    if imports_end not in registry or compositions_end not in registry:
        raise SystemExit(
            f"Registry markers not found in {registry_path}. "
            "Restore the ISSUEKILLER_GENERATED_* marker lines."
        )

    prefix = constant_prefix(composition_id)
    component_name = f"{composition_id}Composition"
    module_name = f"{composition_id}Composition"
    import_block = f'''import {{
  {prefix}_DURATION_IN_FRAMES,
  {prefix}_FPS,
  {prefix}_HEIGHT,
  {prefix}_WIDTH,
  {component_name},
}} from "./{module_name}";
'''
    composition_block = f'''      <Composition
        id="{composition_id}"
        component={{{component_name}}}
        durationInFrames={{{prefix}_DURATION_IN_FRAMES}}
        fps={{{prefix}_FPS}}
        width={{{prefix}_WIDTH}}
        height={{{prefix}_HEIGHT}}
      />
'''

    if 'import {Composition} from "remotion";' not in registry:
        registry = registry.replace(
            'import React from "react";\n',
            'import React from "react";\nimport {Composition} from "remotion";\n',
            1,
        )
    registry = registry.replace(imports_end, import_block + imports_end, 1)
    registry = registry.replace(compositions_end, composition_block + compositions_end, 1)
    registry_path.write_text(registry, encoding="utf-8")


def main() -> None:
    _ik_env.setup()
    parser = argparse.ArgumentParser(
        description="Create an asset directory and a registered Remotion composition for a new Short."
    )
    parser.add_argument("--asset-root", required=True)
    parser.add_argument("--composition-id", required=True)
    parser.add_argument("--title", required=True)
    parser.add_argument("--scenes", type=int, default=9)
    parser.add_argument("--duration-seconds", type=float, default=40.0)
    parser.add_argument("--project", "--workspace", dest="project", type=Path, default=None,
                        help="Project folder (default: the folder that contains .agents/)")
    parser.add_argument("--force", action="store_true")
    args = parser.parse_args()

    assert_identifier(args.composition_id, "--composition-id")
    if not re.fullmatch(r"[a-zA-Z0-9][a-zA-Z0-9._-]*", args.asset_root):
        raise SystemExit("--asset-root contains unsupported characters (use letters, digits, - . _)")
    if args.scenes < 3 or args.scenes > 12:
        raise SystemExit("--scenes must be between 3 and 12 (8~10 recommended)")

    project = _ik_env.project_dir(args.project)
    asset_dir = project / "public" / args.asset_root
    composition_path = project / "src" / f"{args.composition_id}Composition.tsx"

    if asset_dir.exists() and not args.force:
        raise SystemExit(f"Asset directory already exists: {asset_dir}")
    if composition_path.exists() and not args.force:
        raise SystemExit(f"Composition already exists: {composition_path}")

    channel = _ik_env.load_channel(project)

    asset_dir.mkdir(parents=True, exist_ok=True)
    voice_script = build_voice_script(args.scenes)
    (asset_dir / "voice-script.json").write_text(
        json.dumps(voice_script, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )
    shutil.copyfile(
        SKILL_DIR / "assets" / "source-info.template.md",
        asset_dir / "source-info.md",
    )
    upload = (SKILL_DIR / "assets" / "youtube-upload.template.md").read_text(encoding="utf-8")
    upload = upload.replace("{{CHANNEL_NAME}}", channel["name"]).replace(
        "{{CHANNEL_HASHTAG}}", channel["hashtag"]
    )
    (asset_dir / "youtube-upload.md").write_text(upload, encoding="utf-8")
    composition_path.write_text(
        build_composition(
            args.asset_root,
            args.composition_id,
            args.title,
            args.scenes,
            args.duration_seconds,
        ),
        encoding="utf-8",
    )
    register_composition(project, args.composition_id)

    print(f"Created asset directory: {asset_dir}")
    print(f"Created composition: {composition_path}")
    print(f"Registered composition ID: {args.composition_id}")
    if channel["is_default"]:
        print('NOTE: channel.json 의 채널 이름이 아직 "내 채널"입니다. 수강생에게 채널 이름을 물어 channel.json 을 고치세요.')
    print("Next: edit voice-script.json, add unique scene images, generate TTS, then run sync_timing.py.")


if __name__ == "__main__":
    main()
