#!/bin/bash
# =====================================================================
#  이슈킬러 쇼츠 제작 환경 · Mac 한 줄 설치
#
#    curl -fsSL https://raw.githubusercontent.com/__GH_REPO__/main/get.sh | bash
#
#  하는 일
#    1) 프로젝트 폴더를 내려받아  ~/issuekiller  에 놓는다
#    2) setup/mac/install.command 를 실행한다 (10~30분)
#  관리자 비밀번호 · Xcode · Homebrew 없이, ~/issuekiller-tools 한 폴더에만 설치합니다.
#  여러 번 실행해도 안전합니다. 이미 있는 폴더는 지우지 않습니다.
# =====================================================================
set -u

GET_TMP=""
cleanup() { [ -n "$GET_TMP" ] && rm -rf "$GET_TMP"; }
trap cleanup EXIT

main() {
  local REPO="${ISSUEKILLER_REPO:-__GH_REPO__}"
  local REF="${ISSUEKILLER_REF:-main}"
  local ZIP_URL="${ISSUEKILLER_ZIP_URL:-https://github.com/$REPO/archive/refs/heads/$REF.zip}"
  local DEST="${ISSUEKILLER_PROJECT:-$HOME/issuekiller}"

  printf '\n\033[1m이슈킬러 설치 도우미 v3 · Mac 한 줄 설치\033[0m\n'
  if [ "$(uname -s)" != "Darwin" ]; then
    echo "❌ 이 명령은 Mac 전용입니다. Windows 는 PowerShell 에서 get.ps1 명령을 사용하세요."
    return 1
  fi

  local TMPBASE="${TMPDIR:-/tmp}"
  { [ -d "$TMPBASE" ] && [ -w "$TMPBASE" ]; } || TMPBASE=/tmp
  GET_TMP="$(mktemp -d "$TMPBASE/issuekiller-get.XXXXXX")" || { echo "❌ 임시 폴더를 만들 수 없습니다."; return 1; }

  echo "1) 프로젝트 폴더 내려받는 중..."
  if ! curl -fsSL --retry 3 --retry-delay 3 --connect-timeout 20 -o "$GET_TMP/kit.zip" "$ZIP_URL"; then
    echo "❌ 내려받기 실패: $ZIP_URL"
    echo "   인터넷 연결을 확인한 뒤 같은 명령을 다시 실행하세요."
    return 1
  fi
  if ! ditto -x -k "$GET_TMP/kit.zip" "$GET_TMP/x"; then
    echo "❌ 압축을 풀 수 없습니다. 같은 명령을 다시 실행하세요."
    return 1
  fi
  local TOP
  TOP="$(find "$GET_TMP/x" -mindepth 1 -maxdepth 1 -type d | head -1)"
  if [ -z "$TOP" ] || [ ! -f "$TOP/setup/mac/install.command" ]; then
    echo "❌ 받은 파일 안에 설치 도우미가 없습니다. 강사에게 알려주세요."
    return 1
  fi

  if [ -f "$DEST/package.json" ]; then
    # 이미 프로젝트 폴더가 있으면 그대로 두고 설치 스크립트만 최신으로 덮어쓴다.
    echo "2) 기존 폴더 유지: $DEST (설치 도우미만 최신으로 교체)"
    mkdir -p "$DEST/setup" && cp -R "$TOP/setup/." "$DEST/setup/" || { echo "❌ 설치 도우미를 복사하지 못했습니다."; return 1; }
  elif [ -d "$DEST" ] && [ -n "$(ls -A "$DEST" 2>/dev/null)" ]; then
    # 다른 내용이 든 폴더는 지우지 않고 이름을 바꿔 둔다.
    local OLD="$DEST-old-$(date +%Y%m%d-%H%M%S)"
    echo "2) $DEST 에 다른 내용이 있어 $OLD 로 옮기고 새로 만듭니다."
    mv "$DEST" "$OLD" && cp -R "$TOP" "$DEST" || { echo "❌ 폴더를 만들지 못했습니다."; return 1; }
  else
    echo "2) 프로젝트 폴더 만드는 중: $DEST"
    rmdir "$DEST" 2>/dev/null
    cp -R "$TOP" "$DEST" || { echo "❌ 폴더를 만들지 못했습니다."; return 1; }
  fi
  chmod 755 "$DEST"/setup/mac/*.command 2>/dev/null

  echo "3) 설치 도우미 실행 (10~30분, 비밀번호는 묻지 않습니다)"
  echo
  # curl | bash 로 실행되면 표준입력이 파이프라서, 설치 도우미에는 터미널을 직접 물려준다.
  if ( : </dev/tty ) 2>/dev/null; then
    bash "$DEST/setup/mac/install.command" </dev/tty
  else
    bash "$DEST/setup/mac/install.command" </dev/null
  fi
}

main "$@"
