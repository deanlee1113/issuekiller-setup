#!/usr/bin/env python3
"""완성된 쇼츠 자산과 MP4 를 자동 검수한다 (장면·자막 수, 중복 이미지, 해상도, 무음, 검은 화면).

실행 (프로젝트 폴더에서):
  bash scripts/py.sh .claude/skills/issuekiller-shorts/scripts/validate_short.py \\
    --asset-root 20261001-topic --mp4 output/20261001-topic-final.mp4
"""

from __future__ import annotations

import argparse
import hashlib
import json
import math
import re
import subprocess
import sys
from fractions import Fraction
from pathlib import Path

import numpy as np
from PIL import Image, ImageOps

import _ik_env


def run(command: list[str]) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        command, check=True, capture_output=True, text=True, encoding="utf-8", errors="replace"
    )


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for block in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def dhash(image: Image.Image) -> np.ndarray:
    gray = image.convert("L").resize((9, 8), Image.Resampling.LANCZOS)
    values = np.asarray(gray, dtype=np.int16)
    return (values[:, 1:] > values[:, :-1]).reshape(-1)


def color_histogram(image: Image.Image) -> np.ndarray:
    rgb = np.asarray(image.convert("RGB").resize((128, 128)), dtype=np.uint8)
    parts = []
    for channel in range(3):
        hist, _ = np.histogram(rgb[:, :, channel], bins=16, range=(0, 256))
        parts.append(hist.astype(np.float64))
    vector = np.concatenate(parts)
    norm = np.linalg.norm(vector)
    return vector / norm if norm else vector


def cosine(a: np.ndarray, b: np.ndarray) -> float:
    denom = np.linalg.norm(a) * np.linalg.norm(b)
    return float(np.dot(a, b) / denom) if denom else 0.0


def probe_video(path: Path) -> dict:
    result = run(
        [
            _ik_env.tool("ffprobe"),
            "-v",
            "error",
            "-show_streams",
            "-show_format",
            "-of",
            "json",
            str(path),
        ]
    )
    return json.loads(result.stdout)


def create_contact_sheet(video: Path, output: Path) -> None:
    output.parent.mkdir(parents=True, exist_ok=True)
    subprocess.run(
        [
            _ik_env.tool("ffmpeg"),
            "-y",
            "-v",
            "error",
            "-i",
            str(video),
            "-vf",
            "fps=1/5,scale=270:-1,tile=3x3:padding=4:margin=4",
            "-frames:v",
            "1",
            str(output),
        ],
        check=True,
    )


def main() -> None:
    _ik_env.setup()
    parser = argparse.ArgumentParser(description="Validate a Shorts asset folder and rendered MP4.")
    parser.add_argument("--asset-root", required=True)
    parser.add_argument("--mp4", type=Path)
    parser.add_argument("--project", "--workspace", dest="project", type=Path, default=None,
                        help="Project folder (default: the folder that contains .claude/)")
    args = parser.parse_args()

    project = _ik_env.project_dir(args.project)
    asset_dir = project / "public" / args.asset_root
    video_path = args.mp4.resolve() if args.mp4 else None
    failures: list[str] = []
    warnings: list[str] = []
    passes: list[str] = []

    if not asset_dir.is_dir():
        raise SystemExit(f"Missing asset directory: {asset_dir}")

    try:
        script = json.loads((asset_dir / "voice-script.json").read_text(encoding="utf-8"))
        timings = json.loads((asset_dir / "voice-timings.json").read_text(encoding="utf-8"))
        captions = json.loads((asset_dir / "captions-voiced.json").read_text(encoding="utf-8"))
    except FileNotFoundError as error:
        raise SystemExit(f"Missing generated voice file: {error.filename}") from error

    counts = (len(script), len(timings), len(captions))
    if len(set(counts)) != 1:
        failures.append(f"Script/timing/caption counts differ: {counts}")
    else:
        passes.append(f"Script, timing, and caption counts match: {counts[0]}")

    previous_end = 0
    for index, (segment, timing, caption) in enumerate(
        zip(script, timings, captions), start=1
    ):
        start_ms = int(timing["startMs"])
        end_ms = int(timing["endMs"])
        if start_ms != previous_end:
            failures.append(
                f"Segment {index} begins at {start_ms} ms after previous end {previous_end} ms"
            )
        if end_ms <= start_ms:
            failures.append(f"Segment {index} has invalid duration")
        if int(caption["startMs"]) != start_ms or int(caption["endMs"]) != end_ms:
            failures.append(f"Caption timing differs at segment {index}")
        if caption["text"] != segment["displayText"]:
            failures.append(f"Caption text differs at segment {index}")
        previous_end = end_ms

    images = sorted(asset_dir.glob("scene-*-framed.*"))
    if len(images) != len(script):
        failures.append(
            f"Expected {len(script)} framed scene images, found {len(images)}"
        )
    else:
        passes.append(f"Framed scene image count matches: {len(images)}")

    exact_hashes: dict[str, Path] = {}
    features = []
    for image_path in images:
        digest = sha256(image_path)
        if digest in exact_hashes:
            failures.append(
                f"Exact duplicate images: {exact_hashes[digest].name} and {image_path.name}"
            )
        exact_hashes[digest] = image_path
        with Image.open(image_path) as image:
            normal = dhash(image)
            mirrored = dhash(ImageOps.mirror(image))
            histogram = color_histogram(image)
        features.append((image_path, normal, mirrored, histogram))

    for left_index in range(len(features)):
        left_path, left_hash, left_mirror, left_hist = features[left_index]
        for right_index in range(left_index + 1, len(features)):
            right_path, right_hash, right_mirror, right_hist = features[right_index]
            hamming = min(
                int(np.count_nonzero(left_hash != right_hash)),
                int(np.count_nonzero(left_hash != right_mirror)),
                int(np.count_nonzero(left_mirror != right_hash)),
            )
            histogram_similarity = cosine(left_hist, right_hist)
            if hamming <= 10 and histogram_similarity >= 0.92:
                warnings.append(
                    f"Visually similar images need review: {left_path.name} / "
                    f"{right_path.name} (dHash={hamming}, color={histogram_similarity:.3f})"
                )

    if len(exact_hashes) == len(images):
        passes.append("No exact duplicate scene images")

    if video_path:
        if not video_path.is_file():
            failures.append(f"Missing MP4: {video_path}")
        else:
            info = probe_video(video_path)
            streams = info.get("streams", [])
            video_streams = [stream for stream in streams if stream.get("codec_type") == "video"]
            audio_streams = [stream for stream in streams if stream.get("codec_type") == "audio"]
            if not video_streams:
                failures.append("MP4 has no video stream")
            else:
                video = video_streams[0]
                width = int(video.get("width", 0))
                height = int(video.get("height", 0))
                if (width, height) != (1080, 1920):
                    failures.append(f"Wrong resolution: {width}x{height}")
                else:
                    passes.append("Resolution is 1080x1920")
                fps = float(Fraction(video.get("avg_frame_rate", "0/1")))
                if not math.isclose(fps, 30.0, abs_tol=0.05):
                    failures.append(f"Wrong frame rate: {fps:.3f}")
                else:
                    passes.append("Frame rate is 30fps")
            if not audio_streams:
                failures.append("MP4 has no audio stream")
            else:
                passes.append("Audio stream is present")

            duration = float(info.get("format", {}).get("duration", 0))
            if duration < 20 or duration > 60:
                failures.append(f"Duration is outside safe range: {duration:.2f}s")
            elif duration < 30 or duration > 48:
                warnings.append(f"Duration is outside the normal 30-48s target: {duration:.2f}s")
            else:
                passes.append(f"Duration is in target range: {duration:.2f}s")

            silence = run(
                [
                    _ik_env.tool("ffmpeg"),
                    "-hide_banner",
                    "-i",
                    str(video_path),
                    "-af",
                    "silencedetect=noise=-45dB:d=0.25",
                    "-f",
                    "null",
                    "-",
                ]
            )
            silence_durations = [
                float(value)
                for value in re.findall(r"silence_duration:\s*([0-9.]+)", silence.stderr)
            ]
            if silence_durations:
                failures.append(
                    f"Detected silence >=0.25s, longest {max(silence_durations):.3f}s"
                )
            else:
                passes.append("No silence interval >=0.25s")

            black = run(
                [
                    _ik_env.tool("ffmpeg"),
                    "-hide_banner",
                    "-i",
                    str(video_path),
                    "-vf",
                    "blackdetect=d=0.3:pix_th=0.10",
                    "-an",
                    "-f",
                    "null",
                    "-",
                ]
            )
            black_durations = [
                float(value)
                for value in re.findall(r"black_duration:([0-9.]+)", black.stderr)
            ]
            if black_durations:
                failures.append(
                    f"Detected black frame interval >=0.3s, longest {max(black_durations):.3f}s"
                )
            else:
                passes.append("No black interval >=0.3s")

            contact = project / "qc" / args.asset_root / "contact.jpg"
            create_contact_sheet(video_path, contact)
            passes.append(f"Contact sheet created: {contact}")

    for message in passes:
        print(f"[PASS] {message}")
    for message in warnings:
        print(f"[WARN] {message}")
    for message in failures:
        print(f"[FAIL] {message}")

    if failures:
        print(f"Validation failed with {len(failures)} error(s).", file=sys.stderr)
        raise SystemExit(1)
    print(f"Validation passed with {len(warnings)} warning(s).")


if __name__ == "__main__":
    main()
