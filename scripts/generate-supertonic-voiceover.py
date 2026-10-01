#!/usr/bin/env python3
"""Supertonic 으로 voice-script.json 의 문장을 하나씩 합성해 나레이션을 만든다.

입력:  public/<asset-root>/voice-script.json   ([{"spokenText": ..., "displayText": ...}, ...])
출력:  public/<asset-root>/voiceover-f1.wav, voice-timings.json, captions-voiced.json, used-captions.md

실행 (프로젝트 폴더에서):
  Mac / Windows(Git Bash):  bash scripts/py.sh scripts/generate-supertonic-voiceover.py public/<asset-root> --voice F1 --speed 1.22
  Windows(PowerShell/cmd):  scripts\\py.cmd scripts/generate-supertonic-voiceover.py public/<asset-root> --voice F1 --speed 1.22
"""

import argparse
import json
import os
import shutil
import subprocess
import sys
from pathlib import Path

import numpy as np
from supertonic import TTS


def use_issuekiller_tools() -> None:
    """~/issuekiller-tools 의 ffmpeg·node 를 PATH 앞에 둔다 (터미널 설정과 무관하게 동작)."""
    tools = Path.home() / "issuekiller-tools"
    extra = [tools / "bin", tools / "node" / "bin", tools / "node"]
    found = [str(p) for p in extra if p.is_dir()]
    if found:
        os.environ["PATH"] = os.pathsep.join(found + [os.environ.get("PATH", "")])
    for stream in (sys.stdout, sys.stderr):
        try:
            stream.reconfigure(encoding="utf-8", errors="replace")
        except Exception:
            pass


def tool(name: str) -> str:
    path = shutil.which(name)
    if not path:
        raise SystemExit(f"{name} 을(를) 찾지 못했습니다. ~/issuekiller-tools/bin 에 설치되어 있는지 확인하세요.")
    return path


def probe_duration(path: Path) -> float:
    result = subprocess.run(
        [
            tool("ffprobe"),
            "-v",
            "error",
            "-show_entries",
            "format=duration",
            "-of",
            "default=noprint_wrappers=1:nokey=1",
            str(path),
        ],
        check=True,
        capture_output=True,
        text=True,
        encoding="utf-8",
        errors="replace",
    )
    return float(result.stdout.strip())


def main() -> None:
    use_issuekiller_tools()
    parser = argparse.ArgumentParser()
    parser.add_argument("asset_dir", type=Path)
    parser.add_argument("--voice", default="F1")
    parser.add_argument("--speed", type=float, default=1.22)
    args = parser.parse_args()

    asset_dir = args.asset_dir.resolve()
    script_path = asset_dir / "voice-script.json"
    segment_dir = asset_dir / "voice-segments-f1"
    concat_path = segment_dir / "concat.txt"
    final_path = asset_dir / "voiceover-f1.wav"

    segments = json.loads(script_path.read_text(encoding="utf-8"))
    segment_dir.mkdir(parents=True, exist_ok=True)

    tts = TTS(auto_download=True)
    voice_style = tts.get_voice_style(voice_name=args.voice)

    timing_rows = []
    caption_rows = []
    concat_rows = []
    cursor_ms = 0

    for index, segment in enumerate(segments, start=1):
        raw_path = segment_dir / f"{index:02d}-raw.wav"
        clean_path = segment_dir / f"{index:02d}.wav"
        wav, model_duration = tts.synthesize(
            text=segment["spokenText"],
            lang="ko",
            voice_style=voice_style,
            total_steps=8,
            speed=args.speed,
        )
        tts.save_audio(wav, str(raw_path))

        subprocess.run(
            [
                tool("ffmpeg"),
                "-y",
                "-v",
                "error",
                "-i",
                str(raw_path),
                "-af",
                (
                    "silenceremove="
                    "start_periods=1:start_silence=0.03:start_threshold=-45dB:"
                    "stop_periods=-1:stop_silence=0.04:stop_threshold=-45dB,"
                    "loudnorm=I=-16:TP=-1.5:LRA=11"
                ),
                "-ar",
                "44100",
                "-ac",
                "1",
                str(clean_path),
            ],
            check=True,
        )
        raw_path.unlink(missing_ok=True)

        duration_ms = round(probe_duration(clean_path) * 1000)
        end_ms = cursor_ms + duration_ms
        # concat.txt 와 같은 폴더의 파일 이름만 적는다 (Windows 경로·한글 사용자 이름에도 안전)
        concat_rows.append(f"file '{clean_path.name}'")
        timing_rows.append(
            {
                "index": index,
                "voice": args.voice,
                "speed": args.speed,
                "spokenText": segment["spokenText"],
                "startMs": cursor_ms,
                "voiceStartMs": cursor_ms,
                "voiceEndMs": end_ms,
                "endMs": end_ms,
                "speechDurationSeconds": float(
                    np.asarray(model_duration).reshape(-1)[0]
                ),
            }
        )
        caption_rows.append(
            {
                "text": segment["displayText"],
                "startMs": cursor_ms,
                "endMs": end_ms,
                "timestampMs": None,
                "confidence": None,
            }
        )
        cursor_ms = end_ms
        print(f"  [{index}/{len(segments)}] {duration_ms} ms  {segment['spokenText'][:30]}", flush=True)

    concat_path.write_text("\n".join(concat_rows) + "\n", encoding="utf-8")
    subprocess.run(
        [
            tool("ffmpeg"),
            "-y",
            "-v",
            "error",
            "-f",
            "concat",
            "-safe",
            "0",
            "-i",
            str(concat_path),
            "-c:a",
            "pcm_s16le",
            "-ar",
            "44100",
            "-ac",
            "1",
            str(final_path),
        ],
        check=True,
    )

    (asset_dir / "voice-timings.json").write_text(
        json.dumps(timing_rows, ensure_ascii=False, indent=2),
        encoding="utf-8",
    )
    (asset_dir / "captions-voiced.json").write_text(
        json.dumps(caption_rows, ensure_ascii=False, indent=2),
        encoding="utf-8",
    )
    (asset_dir / "used-captions.md").write_text(
        "# 사용 자막\n\n"
        + "\n\n".join(
            f"{index}. {segment['displayText'].replace(chr(10), ' / ')}"
            for index, segment in enumerate(segments, start=1)
        )
        + "\n",
        encoding="utf-8",
    )
    print(json.dumps({"durationMs": cursor_ms, "output": str(final_path)}, ensure_ascii=False))


if __name__ == "__main__":
    main()
