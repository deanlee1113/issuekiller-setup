#!/bin/bash
# =====================================================================
#  이슈킬러 쇼츠 제작 환경 확인표 v3 (macOS)
#  실행: 터미널에  bash  입력 → 이 파일을 끌어다 놓고 Enter
#  결과에 ❌ 가 있으면 화면을 캡처해서 보내주세요.
# =====================================================================
set -u
SETUP_DIR="$(cd "$(dirname "$0")/.." && pwd)"
TOOLS_DIR="$HOME/issuekiller-tools"
BIN_DIR="$TOOLS_DIR/bin"
NODE_DIR="$TOOLS_DIR/node"
VENV_PY="$TOOLS_DIR/venv/bin/python"
export PATH="$BIN_DIR:$NODE_DIR/bin:$HOME/.local/bin:$PATH"

NG=0
row() { # row <상태 0/1> <항목> <설명>
  if [ "$1" -eq 0 ]; then printf '  ✅ %s  —  %s\n' "$2" "$3"; else printf '  ❌ %s  —  %s\n' "$2" "$3"; NG=$((NG + 1)); fi
}
ver() { "$@" 2>/dev/null | head -1; }

find_project() {
  local c
  for c in "${ISSUEKILLER_PROJECT:-}" "$SETUP_DIR/.." "$HOME/issuekiller" "$HOME/Desktop/issuekiller" "$HOME/Downloads/issuekiller"; do
    if [ -n "$c" ] && [ -f "$c/package.json" ] && grep -q '"remotion"' "$c/package.json" 2>/dev/null; then (cd "$c" && pwd); return 0; fi
  done
  return 1
}

if [ "$(sysctl -n hw.optional.arm64 2>/dev/null)" = "1" ]; then CPU="Apple Silicon"; else CPU="Intel"; fi
echo
echo "이슈킬러 제작 환경 확인  —  $(date '+%Y-%m-%d %H:%M')"
echo "  macOS $(sw_vers -productVersion) / $CPU / 여유 디스크 $(df -h "$HOME" | awk 'NR==2{print $4}')"
echo "  설치 폴더: $TOOLS_DIR ($(du -sh "$TOOLS_DIR" 2>/dev/null | cut -f1))"
echo

"$NODE_DIR/bin/node" -v >/dev/null 2>&1;  row $? "Node.js"      "$(ver "$NODE_DIR/bin/node" -v) ($NODE_DIR)"
"$NODE_DIR/bin/npm" -v >/dev/null 2>&1;   row $? "npm"          "$(ver "$NODE_DIR/bin/npm" -v)"
"$BIN_DIR/ffmpeg" -hide_banner -filters 2>/dev/null | grep -qE '^ *[A-Z.]+ +tile '; row $? "ffmpeg" "$("$BIN_DIR/ffmpeg" -version 2>/dev/null | head -1 | cut -d' ' -f1-3) (tile 필터 포함)"
"$BIN_DIR/ffprobe" -version >/dev/null 2>&1; row $? "ffprobe"    "$("$BIN_DIR/ffprobe" -version 2>/dev/null | head -1 | cut -d' ' -f1-3)"
[ -x "$BIN_DIR/uv" ];                      row $? "uv (파이썬 설치 도구)" "$(ver "$BIN_DIR/uv" --version)"
# Claude Code(터미널용)는 선택 항목: 없어도 ❌ 로 세지 않는다 (AI 앱으로 실습)
if command -v claude >/dev/null 2>&1; then row 0 "Claude Code (선택)" "$(ver claude --version)"
else printf '  ℹ️  %s  —  %s\n' "Claude Code (선택)" "없음 · AI 앱(ChatGPT·Claude·Antigravity)으로 실습하면 필요 없습니다"; fi

[ -x "$VENV_PY" ];                    row $? "Python 가상환경"   "$TOOLS_DIR/venv ($("$VENV_PY" --version 2>/dev/null))"
"$VENV_PY" -c "import supertonic, onnxruntime, numpy, soundfile" 2>/dev/null;  row $? "  supertonic 패키지" "$("$VENV_PY" -c 'import onnxruntime;print("supertonic 1.3.1, onnxruntime", onnxruntime.__version__)' 2>/dev/null)"
"$VENV_PY" -c "import faster_whisper" 2>/dev/null;                              row $? "  faster-whisper"    "$("$VENV_PY" -c 'import faster_whisper;print(faster_whisper.__version__)' 2>/dev/null)"
"$VENV_PY" -c "import PIL" 2>/dev/null;                                         row $? "  pillow"            "$("$VENV_PY" -c 'import PIL;print(PIL.__version__)' 2>/dev/null)"
[ -d "$HOME/.cache/supertonic3/onnx" ];                                         row $? "Supertonic 모델"     "~/.cache/supertonic3 ($(du -shL "$HOME/.cache/supertonic3" 2>/dev/null | cut -f1))"
[ -d "$HOME/.cache/huggingface/hub/models--Systran--faster-whisper-small" ];    row $? "Whisper small 모델"  "~/.cache/huggingface/hub ($(du -sh "$HOME/.cache/huggingface/hub" 2>/dev/null | cut -f1))"
[ -s "$TOOLS_DIR/test-voice.wav" ];                                             row $? "시험 합성 음성"      "$TOOLS_DIR/test-voice.wav"

if PROJECT_DIR="$(find_project)"; then
  row 0 "프로젝트 폴더" "$PROJECT_DIR"
  [ -d "$PROJECT_DIR/node_modules/remotion" ]; row $? "  Remotion 패키지" "$("$NODE_DIR/bin/node" -p "require('$PROJECT_DIR/node_modules/remotion/package.json').version" 2>/dev/null)"
  [ -d "$HOME/.remotion/chrome-headless-shell" ] || [ -d "$PROJECT_DIR/node_modules/.remotion" ]; row $? "  렌더용 브라우저" "~/.remotion/chrome-headless-shell"
else
  row 1 "프로젝트 폴더" "package.json 을 찾지 못함 (다운로드한 zip 을 ~/issuekiller 에 압축 해제)"
fi
grep -qsF 'issuekiller-tools/env.sh' "$HOME/.zprofile"; row $? "터미널 경로 등록" "~/.zprofile 에 issuekiller-tools/env.sh 포함"
TR="$TOOLS_DIR/test-render.mp4"
[ -s "$TR" ] && "$BIN_DIR/ffprobe" -v error -select_streams v:0 -show_entries stream=codec_name -of csv=p=0 "$TR" 2>/dev/null | grep -q h264; row $? "시험 렌더 영상" "$TR ($("$BIN_DIR/ffprobe" -v error -show_entries format=duration -of csv=p=0 "$TR" 2>/dev/null | cut -c1-3)초, 1080x1920 H.264)"

echo
if [ "$NG" -eq 0 ]; then
  printf '\033[1;32m모든 항목 준비 완료. 강의 당일 바로 실습할 수 있습니다.\033[0m\n'
else
  printf '\033[1;31m❌ %d개 항목이 준비되지 않았습니다. install.command 를 다시 실행하거나 이 화면을 캡처해서 보내주세요.\033[0m\n' "$NG"
fi
if [ "${1:-}" != "--no-pause" ] && [ -t 0 ]; then read -r -p "Enter 키를 누르면 창을 닫아도 됩니다... "; fi
exit "$NG"
