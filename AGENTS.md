# 쇼츠 제작 프로젝트 안내 (이슈킬러 강의 실습)

이 파일이 모든 AI 앱(ChatGPT Codex · Claude · Gemini Antigravity)의 공통 작업 안내다. (`CLAUDE.md` 는 이 파일을 불러온다)

이 폴더는 수강생 본인 YouTube 채널의 한국어 연예·공감형 Shorts를 조사, 제작, 검수하는 프로젝트다.
사용자는 40~50대 비개발자 수강생이다. 명령은 AI 가 직접 실행하고, 진행 상황은 쉬운 말로 짧게 알려준다.
수강생에게 터미널 명령을 입력하라고 하지 않는다.

"쇼츠 만들어줘", "영상 만들어줘", 뉴스 소재 선정, Remotion, Supertonic, 쇼츠 자막, YouTube 업로드 요청을 받으면
반드시 먼저 다음 스킬을 읽고 따른다.

- `.agents/skills/issuekiller-shorts/SKILL.md` (같은 내용의 사본: `.claude/skills/issuekiller-shorts/SKILL.md`)

## 처음 한 번

- `channel.json` 의 `name` 이 `내 채널` 이면, 영상 작업 전에 수강생에게 유튜브 채널 이름을 묻고 `name` 만 바꿔 저장한다.
  채널 이름은 이 파일 한 곳에서만 관리한다 (화면 배지·해시태그가 모두 여기서 나온다).

## 명령 실행 (중요)

AI 앱은 터미널 설정(PATH)을 읽지 않을 수 있다. `python3`, `python`, `ffmpeg`, `ffprobe`, `npx` 를 이름만으로 부르지 말고
항상 프로젝트 폴더에서 아래 실행기로 부른다. 실행기가 `~/issuekiller-tools` 의 Python 가상환경과 도구 경로를 붙인다.

| 셸 | Python 스크립트 | ffmpeg · ffprobe · npx |
|---|---|---|
| Mac (zsh/bash), Windows Git Bash | `bash scripts/py.sh <파일.py> [인자]` | `bash scripts/py.sh scripts/tool.py ffmpeg [인자]` |
| Windows PowerShell, cmd | `scripts\py.cmd <파일.py> [인자]` | `scripts\py.cmd scripts/tool.py ffmpeg [인자]` |

- 스킬 문서의 예시는 `bash scripts/py.sh ...` 한 줄 형식이다. Windows PowerShell 이면 맨 앞만 `scripts\py.cmd` 로 바꾼다.
- 인자에 공백·한글이 있으면 큰따옴표로 감싼다. 한 번에 한 명령씩 실행한다.

## 고정 경로 (모두 이 프로젝트 폴더 기준)

- 프로젝트 폴더: Mac `~/issuekiller` · Windows `%USERPROFILE%\issuekiller`
- 채널 설정: `channel.json`
- 공통 화면 템플릿 (고치지 않음): `src/NewsTemplate.tsx`, `src/Root.tsx`
- 영상 등록부: `src/ClaudeGeneratedCompositions.tsx` (이름과 달리 모든 AI 공용. scaffold_short.py 가 자동 수정)
- 영상별 자산: `public/<asset-root>/` · 결과 영상: `output/` · 검수 이미지: `qc/`
- TTS 생성기: `scripts/generate-supertonic-voiceover.py`
- 도구 설치 위치: `~/issuekiller-tools` (`bin` = ffmpeg·ffprobe, `node` = node·npx, `venv` = Python)

## 절대 규칙

- 사실은 신뢰할 수 있는 출처 2개 이상으로 교차 검증한다.
- 같은 사진의 크롭, 확대, 좌우 반전을 서로 다른 이미지로 계산하지 않는다.
- 1080x1920, 30fps, 약 30~48초를 기본으로 한다.
- 상단 제목과 본문 자막은 Shorts UI 안전 영역을 지킨다.
- 하단 진행선은 사용하지 않는다.
- 문장 사이 0.25초 이상의 불필요한 무음을 만들지 않는다.
- 수강생이 명시적으로 요청하기 전에는 YouTube 에 업로드하지 않는다.
- 영상 파일만 YouTube에 업로드한다. Markdown, JSON, 이미지 파일은 업로드하지 않는다.
- 수강생이 공개를 명시하지 않으면 비공개로 둔다.
- 저작권 검사에 문제가 있으면 공개하지 않고 문제 자산을 교체한다.
- 출처와 AI 활용·검수 문구를 설명에 남긴다.
- 계정 비밀번호, 쿠키, 토큰을 묻거나 코드·문서에 기록하지 않는다.
- 수강생이 만든 영상(`src/*Composition.tsx`, `public/`, `output/`)과 `channel.json` 을 지우거나 덮어쓰지 않는다.
- 강의 키트 파일(`AGENTS.md`, `CLAUDE.md`, `.agents/`, `.claude/`, `.codex/`, `scripts/`, `src/NewsTemplate.tsx`)은 고치지 않는다.
