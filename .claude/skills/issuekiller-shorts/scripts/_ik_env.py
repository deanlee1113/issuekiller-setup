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


# 화면 모양 설정(theme.json)의 기본값. 강의 키트의 theme.json · src/NewsTemplate.tsx 의 DEFAULT_THEME 과 같다.
# (tools/build.py 가 세 곳이 같은지 확인한다)
DEFAULT_THEME = {
    "backgroundColor": "#0d0f13",
    "titleColor": "#ffffff",
    "titleSizeAdjust": 0,
    "badgeColor": "#ffcc4d",
    "badgeTextColor": "#111318",
    "taglineColor": "rgba(255,255,255,0.94)",
    "taglineSize": 25,
    "sceneLabelColor": "",
    "sceneLabelTextColor": "#111318",
    "captionBoxColor": "rgba(7,9,12,0.94)",
    "captionTextColor": "#fffdf6",
    "captionSizeAdjust": 0,
    "highlightColor": "#ffdf63",
    "highlightTextColor": "#111318",
    "fontFamily": "",
}


def check_theme(project: Path) -> None:
    """렌더 전에 theme.json 을 확인한다.

    - 파일이 없으면 기본값으로 새로 만든다 (화면 템플릿이 이 파일을 읽으므로 없으면 렌더가 멈춘다).
    - JSON 형식이 깨졌으면 어디가 틀렸는지 알려주고 멈춘다. (값이 틀린 것은 템플릿이 기본값으로 대신한다)
    """
    path = project / "theme.json"
    if not path.exists():
        path.write_text(json.dumps(DEFAULT_THEME, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
        print(f"theme.json 이 없어 기본 화면 모양으로 새로 만들었습니다: {path}", flush=True)
        return
    try:
        data = json.loads(path.read_text(encoding="utf-8-sig"))
    except json.JSONDecodeError as error:
        raise SystemExit(
            f"theme.json 형식이 깨졌습니다 ({error.lineno}번째 줄 {error.colno}번째 글자: {error.msg}). "
            "쉼표·큰따옴표·중괄호를 고친 뒤 다시 실행하세요. "
            "모르겠으면 키 이름과 기본값은 AGENTS.md 의 '화면 모양 바꾸기' 표를 보세요."
        )
    if not isinstance(data, dict):
        raise SystemExit("theme.json 은 { 로 시작하고 } 로 끝나는 설정 묶음이어야 합니다. AGENTS.md 의 '화면 모양 바꾸기' 표를 보세요.")
    unknown = sorted(set(data) - set(DEFAULT_THEME))
    if unknown:
        print(f"참고: theme.json 에 쓰이지 않는 키가 있습니다 (무시됨): {', '.join(unknown)}", flush=True)
