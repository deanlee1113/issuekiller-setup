#!/bin/bash
# =====================================================================
#  이슈킬러 쇼츠 제작 환경 설치 도우미 v3 · 영상 제작 전용 (macOS 13 이상, Apple Silicon/Intel)
#
#  Xcode · Homebrew · 관리자 비밀번호 없이 설치합니다.
#  모든 도구는  ~/issuekiller-tools  한 폴더에만 들어갑니다. (지우면 원상복구)
#
#  실행 방법: 터미널을 열고  bash  를 입력한 뒤 이 파일을 창에 끌어다 놓고 Enter
#  여러 번 실행해도 안전합니다. 이미 설치된 항목은 건너뜁니다.
#  로그: ~/issuekiller-tools/install-mac.log
# =====================================================================
set -u

SETUP_DIR="$(cd "$(dirname "$0")/.." && pwd)"
COMMON_DIR="$SETUP_DIR/common"
TOOLS_DIR="$HOME/issuekiller-tools"
BIN_DIR="$TOOLS_DIR/bin"
NODE_DIR="$TOOLS_DIR/node"
VENV_DIR="$TOOLS_DIR/venv"
DL_DIR="$TOOLS_DIR/downloads"
LOG_FILE="$TOOLS_DIR/install-mac.log"
NODE_LINE="latest-v24.x"          # Node.js LTS 계열
mkdir -p "$TOOLS_DIR" "$BIN_DIR" "$DL_DIR"
exec > >(tee -a "$LOG_FILE") 2>&1

# 이 스크립트 안에서만 쓰는 경로 (터미널 영구 등록은 8단계에서)
export PATH="$BIN_DIR:$NODE_DIR/bin:$HOME/.local/bin:$PATH"
export UV_PYTHON_INSTALL_DIR="$TOOLS_DIR/python"
export UV_CACHE_DIR="$TOOLS_DIR/uv-cache"
export UV_PYTHON_PREFERENCE="only-managed"

TOTAL=8
FAILED=()
step() { printf '\n\033[1;34m[%s/%s] %s\033[0m\n' "$1" "$TOTAL" "$2"; }
ok()   { printf '  ✅ %s\n' "$*"; }
warn() { printf '  ⚠️  %s\n' "$*"; }
fail() { printf '  ❌ %s\n' "$*"; FAILED+=("$*"); }
finish() {
  rm -rf "$DL_DIR"
  echo
  if [ ${#FAILED[@]} -eq 0 ]; then
    printf '\033[1;32m설치가 모두 끝났습니다.\033[0m\n'
  else
    printf '\033[1;31m다음 항목이 실패했습니다:\033[0m\n'
    for f in "${FAILED[@]}"; do echo "  - $f"; done
    echo "이 창을 캡처해서 보내주세요. 로그: $LOG_FILE"
  fi
  echo
  echo "남은 수동 단계 (하나뿐입니다)"
  echo "  터미널 창을 완전히 닫고 새로 연 뒤  claude  를 입력 → 브라우저에서 Claude 계정으로 로그인"
  if [ -t 0 ]; then read -r -p "Enter 키를 누르면 창을 닫아도 됩니다... "; fi
}
download() { # download <url> <저장경로>
  curl -fL --retry 3 --retry-delay 3 --connect-timeout 20 --progress-bar -o "$2" "$1"
}
find_project() {
  local c
  for c in "${ISSUEKILLER_PROJECT:-}" "$SETUP_DIR/.." "$HOME/issuekiller" "$HOME/Desktop/issuekiller" "$HOME/Downloads/issuekiller"; do
    if [ -n "$c" ] && [ -f "$c/package.json" ] && grep -q '"remotion"' "$c/package.json" 2>/dev/null; then
      (cd "$c" && pwd); return 0
    fi
  done
  return 1
}

# 실제 CPU 종류 (Rosetta 터미널에서 실행해도 Apple Silicon 이면 arm64 로 판단)
if [ "$(sysctl -n hw.optional.arm64 2>/dev/null)" = "1" ]; then
  CPU="Apple Silicon"; NODE_ARCH="darwin-arm64"; FF_ARCH="arm64"
else
  CPU="Intel"; NODE_ARCH="darwin-x64"; FF_ARCH="amd64"
fi
MACOS_VER="$(sw_vers -productVersion)"
echo "설치 시작: $(date '+%Y-%m-%d %H:%M:%S')  (macOS $MACOS_VER, $CPU)"
echo "설치 도우미 위치: $SETUP_DIR"
echo "설치 폴더: $TOOLS_DIR"
if [ "${MACOS_VER%%.*}" -lt 13 ] 2>/dev/null; then
  fail "macOS 13(Ventura) 이상이 필요합니다. 현재: $MACOS_VER"; finish; exit 1
fi

# ---------------------------------------------------------------------
step 1 "인터넷 연결 확인"
if curl -fsSL --connect-timeout 15 -o /dev/null "https://nodejs.org/dist/$NODE_LINE/SHASUMS256.txt"; then
  ok "nodejs.org 접속 확인"
else
  fail "인터넷에 연결되지 않았거나 다운로드가 차단되어 있습니다 (nodejs.org)"; finish; exit 1
fi

# ---------------------------------------------------------------------
step 2 "Node.js LTS (공식 배포판, 약 50MB)"
if "$NODE_DIR/bin/node" -v >/dev/null 2>&1 && "$NODE_DIR/bin/npm" -v >/dev/null 2>&1; then
  ok "이미 설치됨: node $("$NODE_DIR/bin/node" -v), npm $("$NODE_DIR/bin/npm" -v)"
else
  SHAS="$(curl -fsSL "https://nodejs.org/dist/$NODE_LINE/SHASUMS256.txt")"
  NODE_TGZ="$(printf '%s\n' "$SHAS" | grep -o "node-v[0-9.]*-$NODE_ARCH\.tar\.gz" | head -1)"
  NODE_SHA="$(printf '%s\n' "$SHAS" | grep " $NODE_TGZ\$" | cut -d' ' -f1)"
  if [ -z "$NODE_TGZ" ] || ! download "https://nodejs.org/dist/$NODE_LINE/$NODE_TGZ" "$DL_DIR/$NODE_TGZ"; then
    fail "Node.js 다운로드 실패 (https://nodejs.org/dist/$NODE_LINE/)"
  elif ! printf '%s  %s\n' "$NODE_SHA" "$DL_DIR/$NODE_TGZ" | shasum -a 256 -c --status; then
    fail "Node.js 파일 검증(SHA256) 실패 — 다시 실행해 주세요"
  else
    rm -rf "$NODE_DIR"; mkdir -p "$NODE_DIR"
    if tar -xzf "$DL_DIR/$NODE_TGZ" -C "$NODE_DIR" --strip-components=1 && "$NODE_DIR/bin/node" -v >/dev/null 2>&1; then
      ok "설치 완료: node $("$NODE_DIR/bin/node" -v), npm $("$NODE_DIR/bin/npm" -v) → $NODE_DIR"
    else
      fail "Node.js 압축 해제 실패"
    fi
  fi
fi

# ---------------------------------------------------------------------
step 3 "ffmpeg · ffprobe (정적 빌드, 약 60MB)"
ff_ok() { "$BIN_DIR/ffmpeg" -hide_banner -filters 2>/dev/null | grep -qE '^ *[A-Z.]+ +tile ' && "$BIN_DIR/ffprobe" -version >/dev/null 2>&1; }
if ff_ok; then
  ok "이미 설치됨: $("$BIN_DIR/ffmpeg" -version 2>/dev/null | head -1 | cut -d' ' -f1-3)"
else
  for b in ffmpeg ffprobe; do
    rm -f "$DL_DIR/$b.zip"; rm -rf "$DL_DIR/$b"
    if download "https://ffmpeg.martin-riedl.de/redirect/latest/macos/$FF_ARCH/release/$b.zip" "$DL_DIR/$b.zip" \
       && unzip -oq "$DL_DIR/$b.zip" -d "$DL_DIR/$b" && [ -f "$DL_DIR/$b/$b" ]; then
      mv -f "$DL_DIR/$b/$b" "$BIN_DIR/$b"; chmod +x "$BIN_DIR/$b"
    else
      warn "$b 기본 다운로드 실패 → 예비 서버(evermeet.cx, Intel 빌드)로 재시도"
      if download "https://evermeet.cx/ffmpeg/getrelease/$b/zip" "$DL_DIR/$b.zip" \
         && unzip -oq "$DL_DIR/$b.zip" -d "$DL_DIR/$b" && [ -f "$DL_DIR/$b/$b" ]; then
        mv -f "$DL_DIR/$b/$b" "$BIN_DIR/$b"; chmod +x "$BIN_DIR/$b"
      fi
    fi
  done
  if ff_ok; then
    ok "설치 완료: $("$BIN_DIR/ffmpeg" -version 2>/dev/null | head -1 | cut -d' ' -f1-3) → $BIN_DIR"
  else
    fail "ffmpeg/ffprobe 설치 실패 (실행되지 않거나 tile 필터가 없음)"
  fi
fi

# ---------------------------------------------------------------------
step 4 "Python 3.12 + 가상환경 + 음성 합성/검증 패키지 (약 1GB, 3~5분)"
if [ ! -x "$BIN_DIR/uv" ]; then
  if curl -LsSf https://astral.sh/uv/install.sh | env UV_UNMANAGED_INSTALL="$BIN_DIR" sh >/dev/null; then
    ok "uv(파이썬 설치 도구) 준비: $("$BIN_DIR/uv" --version 2>/dev/null)"
  else
    fail "uv 다운로드 실패 (https://astral.sh/uv/install.sh)"
  fi
fi
if [ -x "$BIN_DIR/uv" ]; then
  if "$BIN_DIR/uv" python install 3.12 --no-progress >/dev/null 2>&1 || "$BIN_DIR/uv" python install 3.12; then
    ok "Python 3.12 준비 → $UV_PYTHON_INSTALL_DIR"
  else
    fail "Python 3.12 다운로드 실패 (uv python install 3.12)"
  fi
  if [ ! -x "$VENV_DIR/bin/python" ]; then
    "$BIN_DIR/uv" venv --seed --python 3.12 "$VENV_DIR" >/dev/null 2>&1 || "$BIN_DIR/uv" venv --seed --python 3.12 "$VENV_DIR"
  fi
  if [ -x "$VENV_DIR/bin/python" ]; then
    if "$BIN_DIR/uv" pip install --python "$VENV_DIR/bin/python" -r "$COMMON_DIR/requirements.txt"; then
      ok "패키지 설치 완료 → $VENV_DIR ($("$VENV_DIR/bin/python" --version 2>/dev/null))"
    else
      fail "Python 패키지 설치 실패 (uv pip install -r common/requirements.txt)"
    fi
  else
    fail "Python 가상환경을 만들지 못했습니다 (uv venv)"
  fi
fi

# ---------------------------------------------------------------------
step 5 "Claude Code"
CLAUDE_BIN="$(command -v claude 2>/dev/null || true)"
if [ "${SKIP_CLAUDE:-0}" = "1" ]; then
  warn "건너뜀 (SKIP_CLAUDE=1)"
elif [ -n "$CLAUDE_BIN" ]; then
  ok "이미 설치됨: $("$CLAUDE_BIN" --version 2>/dev/null | head -1)"
else
  if curl -fsSL https://claude.ai/install.sh | bash; then
    ok "설치 완료 (로그인은 강의 안내에 따라 진행)"
  else
    fail "Claude Code 설치 실패 (curl -fsSL https://claude.ai/install.sh | bash)"
  fi
fi
# git 이 없는 맥에서 'git' 을 부르면 Xcode 도구 설치 창이 뜨는 것을 막는 대체 파일
if ! xcode-select -p >/dev/null 2>&1 && [ ! -x /opt/homebrew/bin/git ] && [ ! -x /usr/local/bin/git ]; then
  cat > "$BIN_DIR/git" <<'SHIM'
#!/bin/sh
# 이슈킬러 설치 도우미가 만든 파일: git 이 없을 때 Xcode 도구 설치 창이 뜨지 않게 합니다.
if xcode-select -p >/dev/null 2>&1; then exec /usr/bin/git "$@"; fi
for g in /opt/homebrew/bin/git /usr/local/bin/git; do [ -x "$g" ] && exec "$g" "$@"; done
echo "git 은 설치되어 있지 않습니다. (이슈킬러 영상 제작에는 필요 없습니다)" >&2
exit 127
SHIM
  chmod +x "$BIN_DIR/git"
  ok "git 대체 파일 생성 (Xcode 설치 창 방지)"
fi

# ---------------------------------------------------------------------
step 6 "음성 모델 다운로드 + 시험 합성/인식 (약 850MB, 5~10분)"
if [ -x "$VENV_DIR/bin/python" ]; then
  if "$VENV_DIR/bin/python" "$COMMON_DIR/warmup_tts.py" "$TOOLS_DIR/test-voice.wav"; then
    ok "Supertonic 음성 합성 성공"
    if "$VENV_DIR/bin/python" "$COMMON_DIR/warmup_asr.py" "$TOOLS_DIR/test-voice.wav"; then
      ok "faster-whisper 음성 인식 성공"
    else
      fail "faster-whisper 시험 인식 실패"
    fi
  else
    fail "Supertonic 시험 합성 실패"
  fi
else
  fail "가상환경이 없어 모델 단계를 건너뜀"
fi

# ---------------------------------------------------------------------
step 7 "영상 프로젝트(Remotion) 패키지 + 렌더용 브라우저 + 시험 렌더 (약 1.5GB, 5~15분)"
PROJECT_DIR=""
if ! "$NODE_DIR/bin/node" -v >/dev/null 2>&1; then
  fail "Node.js 가 없어 프로젝트 단계를 건너뜀"
elif PROJECT_DIR="$(find_project)"; then
  echo "  프로젝트 폴더: $PROJECT_DIR"
  if (cd "$PROJECT_DIR" && if [ -f package-lock.json ]; then npm ci --no-audit --no-fund; else npm install --no-audit --no-fund; fi); then
    ok "npm 패키지 설치 완료"
  else
    fail "npm 패키지 설치 실패 (프로젝트 폴더에서 npm install)"
  fi
  if (cd "$PROJECT_DIR" && npx remotion browser ensure); then
    ok "렌더용 브라우저 준비 완료"
  else
    fail "Remotion 브라우저 다운로드 실패 (npx remotion browser ensure)"
  fi
  # 2초짜리 확인용 영상을 실제로 렌더해 본다 (설치가 끝까지 동작하는지 가장 확실한 검사)
  rm -f "$TOOLS_DIR/test-render.mp4"
  if (cd "$PROJECT_DIR" && npx remotion render src/index.ts TestShort "$TOOLS_DIR/test-render.mp4" --log=warn) \
     && "$BIN_DIR/ffprobe" -v error -select_streams v:0 -show_entries stream=codec_name -of csv=p=0 "$TOOLS_DIR/test-render.mp4" 2>/dev/null | grep -q h264; then
    ok "시험 렌더 완료: $TOOLS_DIR/test-render.mp4"
  else
    fail "시험 렌더 실패 (npx remotion render src/index.ts TestShort)"
  fi
else
  warn "프로젝트 폴더(package.json)를 찾지 못해 건너뜁니다."
  warn "다운로드한 zip 을 다시 압축 해제한 뒤(권장 위치: ~/issuekiller) 이 파일을 다시 실행하세요."
fi

# ---------------------------------------------------------------------
step 8 "터미널 경로 등록 + 설치 결과 확인"
cat > "$TOOLS_DIR/env.sh" <<'ENV'
# 이슈킬러 쇼츠 제작 도구 경로 (설치 도우미 v3 가 생성). 지우려면 이 파일과 ~/.zprofile 의 관련 줄을 삭제하세요.
case ":$PATH:" in
  *":$HOME/issuekiller-tools/bin:"*) ;;
  *) export PATH="$HOME/issuekiller-tools/bin:$HOME/issuekiller-tools/node/bin:$HOME/.local/bin:$PATH" ;;
esac
ENV
RC_LINE='[ -f "$HOME/issuekiller-tools/env.sh" ] && . "$HOME/issuekiller-tools/env.sh"'
for rc in "$HOME/.zprofile" "$HOME/.zshrc" "$HOME/.bash_profile"; do
  if ! grep -qsF 'issuekiller-tools/env.sh' "$rc"; then
    printf '\n# 이슈킬러 쇼츠 제작 도구\n%s\n' "$RC_LINE" >> "$rc"
  fi
done
ok "터미널 설정에 경로 등록 (~/.zprofile, ~/.zshrc, ~/.bash_profile)"
[ -x "$BIN_DIR/uv" ] && "$BIN_DIR/uv" cache clean >/dev/null 2>&1 && rm -rf "$UV_CACHE_DIR"
cat > "$TOOLS_DIR/env.json" <<JSON
{
  "platform": "mac",
  "tools_dir": "$TOOLS_DIR",
  "venv_python": "$VENV_DIR/bin/python",
  "node": "$NODE_DIR/bin/node",
  "ffmpeg": "$BIN_DIR/ffmpeg",
  "ffprobe": "$BIN_DIR/ffprobe",
  "project_dir": "$PROJECT_DIR",
  "test_render": "$TOOLS_DIR/test-render.mp4",
  "installed_at": "$(date '+%Y-%m-%dT%H:%M:%S')"
}
JSON
bash "$SETUP_DIR/mac/check.command" --no-pause
finish
