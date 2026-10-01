"""이슈킬러 스킬 스크립트 공통: 프로젝트 경로, 도구 경로, 채널 설정.

프로젝트 폴더(~/issuekiller)는 이 파일 기준으로 찾는다 (두 사본 모두 깊이가 같다):
  <프로젝트>/.agents/skills/issuekiller-shorts/scripts/_ik_env.py  →  parents[4]
  <프로젝트>/.claude/skills/issuekiller-shorts/scripts/_ik_env.py  →  parents[4]
"""

from __future__ import annotations

import json
import os
import shutil
import sys
from pathlib import Path

PROJECT_DIR = Path(__file__).resolve().parents[4]
SKILL_DIR = Path(__file__).resolve().parents[1]
TOOLS_DIR = Path.home() / "issuekiller-tools"
DEFAULT_CHANNEL_NAME = "내 채널"


def setup() -> None:
    """~/issuekiller-tools 의 ffmpeg·node 를 PATH 앞에 두고, 한글 출력이 깨지지 않게 한다."""
    extra = [TOOLS_DIR / "bin", TOOLS_DIR / "node" / "bin", TOOLS_DIR / "node"]
    found = [str(p) for p in extra if p.is_dir()]
    current = os.environ.get("PATH", "")
    missing = [p for p in found if p not in current.split(os.pathsep)]
    if missing:
        os.environ["PATH"] = os.pathsep.join(missing + [current])
    for stream in (sys.stdout, sys.stderr):
        try:
            stream.reconfigure(encoding="utf-8", errors="replace")
        except Exception:
            pass


def tool(name: str) -> str:
    """ffmpeg / ffprobe / npx 등의 실제 경로 (Windows 의 npx.cmd 도 찾는다)."""
    path = shutil.which(name)
    if not path:
        raise SystemExit(
            f"{name} 을(를) 찾지 못했습니다. 설치 도우미를 다시 실행하거나 ~/issuekiller-tools 를 확인하세요."
        )
    return path


def project_dir(value: Path | None) -> Path:
    return (value or PROJECT_DIR).resolve()


def load_channel(project: Path) -> dict:
    path = project / "channel.json"
    try:
        data = json.loads(path.read_text(encoding="utf-8"))
    except FileNotFoundError:
        data = {}
    name = str(data.get("name") or "").strip() or DEFAULT_CHANNEL_NAME
    return {
        "name": name,
        "tagline": str(data.get("tagline") or ""),
        "hashtag": "#" + "".join(name.split()),
        "is_default": name == DEFAULT_CHANNEL_NAME,
    }
