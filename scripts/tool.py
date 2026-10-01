#!/usr/bin/env python3
"""이슈킬러 도구 실행기: ffmpeg / ffprobe / npx / node / npm 을 ~/issuekiller-tools 에서 찾아 실행한다.

AI 앱(ChatGPT·Claude·Antigravity)은 터미널 설정(PATH)을 읽지 않을 수 있으므로, 도구를 이름만으로 부르지 않고
이 실행기를 거친다. 프로젝트 폴더에서:
  Mac / Windows Git Bash:      bash scripts/py.sh scripts/tool.py ffmpeg -v error -ss 2 -i in.mp4 -frames:v 1 out.jpg
  Windows PowerShell / cmd:    scripts\\py.cmd scripts/tool.py ffmpeg -v error -ss 2 -i in.mp4 -frames:v 1 out.jpg
  미리보기:                     bash scripts/py.sh scripts/tool.py npx remotion studio --no-open
"""

import os
import shutil
import subprocess
import sys
from pathlib import Path

TOOLS = Path.home() / "issuekiller-tools"
ALLOWED = ("ffmpeg", "ffprobe", "npx", "node", "npm")


def main() -> int:
    for stream in (sys.stdout, sys.stderr):
        try:
            stream.reconfigure(encoding="utf-8", errors="replace")
        except Exception:
            pass
    if len(sys.argv) < 2 or sys.argv[1] not in ALLOWED:
        print(f"사용: tool.py <{'|'.join(ALLOWED)}> [인자...]", file=sys.stderr)
        return 2
    name, args = sys.argv[1], sys.argv[2:]
    extra = [TOOLS / "bin", TOOLS / "node" / "bin", TOOLS / "node"]
    found = [str(p) for p in extra if p.is_dir()]
    os.environ["PATH"] = os.pathsep.join(found + [os.environ.get("PATH", "")])
    exe = shutil.which(name)   # Windows 에서는 PATHEXT 로 ffmpeg.exe, npx.cmd 를 찾는다
    if not exe:
        print(f"{name} 을(를) 찾지 못했습니다 ({TOOLS}). 설치 도우미를 다시 실행하세요.", file=sys.stderr)
        return 127
    try:
        return subprocess.run([exe, *args]).returncode
    except KeyboardInterrupt:
        return 130


if __name__ == "__main__":
    sys.exit(main())
