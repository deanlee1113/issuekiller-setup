#!/bin/bash
# 이슈킬러 Python 실행기: 설치 도우미가 만든 가상환경의 Python 으로 실행한다.
#   사용: bash scripts/py.sh <파이썬 파일> [인자...]
#   Mac:     ~/issuekiller-tools/venv/bin/python
#   Windows: ~/issuekiller-tools/venv/Scripts/python.exe  (Claude Code 의 Git Bash 에서)
TOOLS="$HOME/issuekiller-tools"
export PATH="$TOOLS/bin:$TOOLS/node/bin:$TOOLS/node:$PATH"
export PYTHONIOENCODING=utf-8
for p in "$TOOLS/venv/bin/python" "$TOOLS/venv/Scripts/python.exe"; do
  if [ -x "$p" ]; then exec "$p" "$@"; fi
done
echo "issuekiller-tools 의 Python 가상환경을 찾지 못했습니다 ($TOOLS/venv)." >&2
echo "설치 도우미(setup/mac/install.command 또는 setup/windows/install.bat)를 다시 실행하세요." >&2
exit 127
