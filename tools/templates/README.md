# 이슈킬러 쇼츠 제작 환경 설치

강의 실습에 쓸 영상 제작 환경(Node.js · ffmpeg · Python 음성 도구 · Claude Code · Remotion 프로젝트)을
**명령어 한 줄**로 설치합니다. 관리자 비밀번호, Xcode, Homebrew 는 필요 없고,
설치되는 것은 모두 `issuekiller-tools` 폴더와 이 프로젝트 폴더 안에만 들어갑니다.

안내 페이지: **https://__GH_PAGES__/**

## Mac

macOS 13 (Ventura) 이상 · Apple Silicon / Intel · 여유 공간 8GB

터미널(⌘ + Space → "터미널")을 열고 아래 한 줄을 붙여넣은 뒤 Enter:

```bash
curl -fsSL https://raw.githubusercontent.com/__GH_REPO__/main/get.sh | bash
```

## Windows

Windows 10 (1809 이상) · Windows 11 · 64비트 (ARM 노트북 지원 안 함) · 여유 공간 8GB

시작 메뉴에서 **PowerShell** 을 열고 (관리자 권한 불필요) 아래 한 줄을 붙여넣은 뒤 Enter:

```powershell
irm https://raw.githubusercontent.com/__GH_REPO__/main/get.ps1 | iex
```

## 무슨 일이 일어나나요

1. 이 저장소를 내려받아 `~/issuekiller` (Windows: `C:\Users\내이름\issuekiller`) 폴더를 만듭니다.
   이미 있으면 그대로 두고 `setup/` 폴더와 강의 키트 파일(쇼츠 제작 스킬·`AGENTS.md`·화면 템플릿 등,
   `setup/common/kit-files.txt` 목록)만 최신으로 바꿉니다. 직접 만든 영상과 `channel.json`(채널 이름)은 건드리지 않고,
   내용이 바뀐 키트 파일의 이전 버전은 `issuekiller-backup-<시각>` 폴더에 보관합니다.
2. `setup/` 안의 설치 도우미가 아래 프로그램(약 3GB)을 받아 `~/issuekiller-tools` 에 설치합니다. 10~30분 걸립니다.

| 항목 | 용도 | 크기 |
|---|---|---|
| Node.js | 영상 프로젝트 실행 | 50MB |
| ffmpeg | 영상·음성 변환 | 160MB |
| Python 3.12 + 음성 패키지 | 나레이션 합성·검증 | 300MB |
| 음성 모델 2종 | 한국어 음성 합성(Supertonic), 음성 검증(Whisper) | 850MB |
| Claude Code (선택) | 터미널용 AI 작업 도구 (AI 앱을 쓰면 없어도 됨) | 100MB |
| Git Bash (Windows 만) | Claude Code 실행에 필요 | 300MB |
| 영상 프로젝트 패키지 + 렌더용 브라우저 | Remotion, Chrome Headless Shell | 1.5GB |

3. 마지막에 2초짜리 `test-render.mp4` 를 실제로 렌더해 전체 과정이 동작하는지 확인하고 결과표를 보여줍니다.
   `✅`(Windows: `[OK]`) 만 보이면 완료입니다.
4. 설치 끝. 강의 날: 쓰시는 AI 앱(ChatGPT·Claude·Gemini용 Antigravity)을 열고 홈 폴더의 issuekiller 폴더를 여세요.

## 설치 후 쇼츠 만들기

AI 앱 하나를 열고 `issuekiller` 폴더(Mac `~/issuekiller`, Windows `C:\Users\내이름\issuekiller`)를 엽니다.

| 앱 | 여는 곳 | 읽는 안내 · 스킬 |
|---|---|---|
| ChatGPT 앱 | Codex → 폴더 선택 (폴더 신뢰) | `AGENTS.md`, `.agents/skills/`, `.codex/` |
| Claude 앱 | Code 탭 → 폴더 선택 | `CLAUDE.md`(→ `AGENTS.md`), `.claude/skills/`, `.claude/settings.json` |
| Antigravity (Gemini) | 폴더 열기 | `AGENTS.md`, `.agents/skills/` |

AI 에게 **"쇼츠 만들어줘"** 라고 말하면 `issuekiller-shorts` 스킬대로
소재 조사 → 교차 검증 → 대본 → 이미지 → Supertonic 음성 → Remotion 렌더 → 자동 검수까지 진행합니다.
처음 한 번은 유튜브 채널 이름을 묻고 `channel.json` 에 저장합니다 (영상 왼쪽 위 배지와 해시태그에 쓰임).
결과 영상은 `output/` 에 저장되며, 직접 요청하기 전에는 유튜브에 올리지 않습니다 (올릴 때도 기본은 비공개).
사진 없이 연습해 보려면 "연습으로 아무 주제나 쇼츠 만들어줘" 라고 하면 연습용 이미지로 끝까지 만들어 봅니다.

## 자주 묻는 것

- **중간에 실패했어요** — 같은 명령어를 다시 붙여넣어 실행하세요. 끝난 항목은 건너뜁니다.
- **상태만 확인하고 싶어요** — Mac: `bash ~/issuekiller/setup/mac/check.command` · Windows: `issuekiller\setup\windows\check.bat` 더블클릭
- **명령어 방식이 안 돼요** — 안내 페이지에서 zip 을 받아 압축을 풀고 `설치안내.txt` 대로 하세요.
- **이미 Node·Python 이 있어요** — 건드리지 않습니다. 이 환경은 별도 폴더에서 자기 것만 씁니다.
- **다 지우려면** — `issuekiller-tools` 폴더, 이 프로젝트 폴더, `~/.cache/supertonic3`, `~/.cache/huggingface` 를 지우고
  Mac 은 `~/.zprofile` 의 "# 이슈킬러 쇼츠 제작 도구" 아래 한 줄, Windows 는 사용자 Path 의 `issuekiller-tools` 항목 4개와 `CLAUDE_CODE_GIT_BASH_PATH` 를 지웁니다.

## 저장소 구성

```
get.sh, get.ps1        한 줄 설치 스크립트 (저장소를 내려받아 setup/ 의 설치 도우미를 실행)
setup/mac, setup/windows, setup/common   설치 도우미 본체
package.json, src/, …  Remotion 영상 프로젝트 (설치 확인용 TestShort, 쇼츠 화면 템플릿 src/NewsTemplate.tsx)
AGENTS.md, .agents/    AI 공통 작업 안내와 쇼츠 제작 스킬 원본 (issuekiller-shorts)
CLAUDE.md, .claude/    Claude 용 안내(AGENTS.md 불러옴)·스킬 사본·권한 설정
.codex/                ChatGPT Codex 프로젝트 설정·명령 허용 규칙
channel.json           채널 이름 (수강생마다 다름, 업데이트해도 유지)
scripts/               Supertonic 음성 생성기, 실행기(py.sh·py.cmd), 도구 실행기(tool.py)
docs/                  안내 페이지(GitHub Pages)와 zip 대안  ← 수강생 폴더에는 들어가지 않음
tools/                 빌드 스크립트와 템플릿              ← 수강생 폴더에는 들어가지 않음
```

문제가 생기면 설치 창을 캡처해 강사에게 보내주세요.
