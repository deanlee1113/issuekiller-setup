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

## 내 것으로 바꾸기 (수강생 맞춤)

이 키트는 완성품이 아니라 출발점이다. 수강생은 이 AI 앱에게 **말로** 시켜 자기 채널에 맞게 고쳐 나간다.
수강생이 고쳐도 되는 것(= 수강생 파일)은 아래 넷뿐이다. 설치 명령을 다시 실행해도 이 파일들은 지워지지 않는다.

| 수강생 파일 | 무엇 | 이런 말이 오면 |
|---|---|---|
| `channel.json` | 채널 이름, 오른쪽 위 문구 | "채널 이름 바꿔 줘", "오른쪽 위 문구를 ~로" |
| `theme.json` | 화면 색·글씨 크기 | "배지 색", "자막 상자", "제목 크게" (아래 "화면 모양 바꾸기") |
| `my-rules.md` | 내 규칙 메모 | "앞으로는 ~ 해 줘", "다음부터 ~", "이건 하지 마" |
| `.agents/skills/my-shorts/` + `.claude/skills/my-shorts/` | 내 스킬(원본 스킬의 복사본) | "스킬을 내 채널에 맞게 바꿔 줘", 주제·말투·장면 수·길이처럼 작업 방식 자체를 바꾸는 큰 변경 |

따르는 순서: **아래 "절대 규칙" > `my-rules.md` > 스킬**(`my-shorts` 가 있으면 그것, 없으면 `issuekiller-shorts`).

- **규칙 쌓기**: "앞으로는 ~", "다음부터 ~", "이건 하지 마"라는 말을 들으면 `my-rules.md` 의 `## 규칙` 아래에
  `- YYYY-MM-DD: (쉬운 말 한 줄)` 로 추가하고 "내 규칙에 저장했어요"라고 알려준다. `(아직 없음)` 줄은 첫 규칙을 넣을 때 지운다.
  절대 규칙과 부딪히는 요청(저작권·사실 확인·무단 업로드 등)은 저장하지 않고 이유를 쉬운 말로 설명한다.
- **내 스킬 만들기**: 작업 방식 자체를 바꾸고 싶어 하면, `my-shorts` 가 없을 때 먼저 원본을 복사한다.
  1. `.agents/skills/issuekiller-shorts/` 의 `SKILL.md` 와 `references/` 를 `.agents/skills/my-shorts/` 와 `.claude/skills/my-shorts/` 두 곳에 복사한다(두 곳은 항상 같은 내용).
  2. 복사본 `SKILL.md` 맨 위의 `name:` 을 `my-shorts` 로, `description:` 맨 앞에 "수강생 맞춤 스킬. issuekiller-shorts 보다 우선한다." 를 붙인다.
  3. 복사본의 설명·규칙만 고친다. 스크립트(`scripts/`)는 복사하지 않고 원본 경로(`.agents/skills/issuekiller-shorts/scripts/...`)를 그대로 쓴다.
  4. 무엇을 바꿨는지 세 줄 이내로 알려 주고, 연습 영상 한 편으로 확인하자고 제안한다.
- **원본 스킬로 돌아가기**: "원래 스킬로 돌려 줘"라고 하면 `my-shorts` 두 폴더를 지우지 말고 프로젝트 폴더의 `보관/my-shorts-YYYYMMDD/` 로 옮긴다.
- **확인 요청**: "내 규칙 보여 줘", "원본이랑 뭐가 달라?"에는 해당 파일을 읽고 쉬운 말로 짧게 답한다.

## 화면 모양 바꾸기 (색 · 글씨 크기 · 배지 · 자막 상자 · 문구)

수강생이 "배지 색을 초록색으로", "제목 글씨를 더 크게", "자막 상자를 흰 바탕에 검은 글씨로",
"오른쪽 위 문구를 바꿔 줘"처럼 **화면 틀의 모양**을 바꿔 달라고 하면 거절하지 말고 아래대로 한다.

1. **`theme.json` 만 고친다.** (오른쪽 위 문구 글자 자체는 `channel.json` 의 `tagline`, 채널 이름은 `name`)
   `src/NewsTemplate.tsx` 등 키트 파일은 절대 고치지 않는다. 화면 템플릿이 `theme.json` 을 읽어 모든 영상에 적용한다.
2. 바꿀 키만 고치고 나머지는 그대로 둔다. JSON 형식을 지킨다: 큰따옴표, 키 사이 쉼표, 마지막 키 뒤에는 쉼표 없음, 주석 금지.
   색은 `"#2E7D32"` 같은 6자리 색 코드나 `"rgba(0,0,0,0.8)"` 로 쓴다 (`"green"` 같은 색 이름은 무시되고 기본색이 나온다).
3. 바로 미리보기 한 장을 뽑아 수강생에게 보여 준다 (수십 초). 기존 파일은 덮어쓰지 않고 `qc/<asset-root>/theme-preview-01.jpg`, `-02` … 로 쌓인다.
   `bash scripts/py.sh .agents/skills/issuekiller-shorts/scripts/preview_still.py`
   (가장 최근 영상의 2초 화면. 다른 영상은 `--composition-id <ID>`, 다른 시점은 `--seconds 5`.
   훅 카드 화면은 `--seconds 0.4`. 아직 만든 영상이 없으면 첫 영상을 만든 뒤 확인한다.)
4. 수강생이 마음에 들어 하면, 영상 파일에도 반영할지 묻고 원하면 새 이름으로 다시 렌더한다
   (`render_short.py ... --output output/<asset-root>-v2.mp4`, 기존 MP4 는 덮어쓰지 않는다). 이후 새 영상에도 같은 모양이 자동으로 적용된다.

| 키 (theme.json) | 바뀌는 곳 | 기본값 |
|---|---|---|
| `backgroundColor` | 화면 바탕과 사진 위아래 어두운 그림자 색 | `"#0d0f13"` |
| `titleColor` | 위쪽 큰 제목 글씨 색 | `"#ffffff"` |
| `titleSizeAdjust` | 제목 글씨 크기 조절 (영상 기본 크기에 더함. `10` = 10만큼 크게, `-8` = 작게, 범위 -40~60) | `0` |
| `badgeColor` | 왼쪽 위 채널 이름 배지 바탕색 | `"#ffcc4d"` |
| `badgeTextColor` | 채널 이름 배지 글씨 색 | `"#111318"` |
| `taglineColor` | 오른쪽 위 문구(channel.json 의 tagline) 글씨 색 | `"rgba(255,255,255,0.94)"` |
| `taglineSize` | 오른쪽 위 문구 글씨 크기 (14~60) | `25` |
| `sceneLabelColor` | 사진 왼쪽 위 장면 이름표 바탕색 + 사진 왼쪽 세로 줄 색. 비우면(`""`) 장면마다 다른 색 | `""` |
| `sceneLabelTextColor` | 장면 이름표 글씨 색 | `"#111318"` |
| `captionBoxColor` | 아래쪽 자막 상자 바탕색 | `"rgba(7,9,12,0.94)"` |
| `captionTextColor` | 자막 글씨 색 (어두운 색이면 글씨 그림자가 자동으로 빠진다) | `"#fffdf6"` |
| `captionSizeAdjust` | 자막 글씨 크기 조절 (영상 기본 크기에 더함, 범위 -40~60) | `0` |
| `highlightColor` | 자막·훅 문구의 강조 단어 바탕색 (형광펜) | `"#ffdf63"` |
| `highlightTextColor` | 강조 단어 글씨 색 | `"#111318"` |
| `fontFamily` | 글꼴 이름 (컴퓨터에 설치된 글꼴만. 없으면 기본 글꼴로 그려진다). 비우면 기본 글꼴 | `""` |

| 수강생 요청 | 고칠 곳 |
|---|---|
| "배지 색을 초록색으로 바꿔 줘" | `theme.json` → `"badgeColor": "#2E7D32"`, `"badgeTextColor": "#ffffff"` (초록 바탕에는 흰 글씨) |
| "제목 글씨를 더 크게" | `theme.json` → `"titleSizeAdjust": 8` (한 번 더 크게면 16) |
| "자막 상자를 흰 바탕에 검은 글씨로" | `theme.json` → `"captionBoxColor": "#ffffff"`, `"captionTextColor": "#111111"` |
| "오른쪽 위 문구를 '매주 금요일 새 영상'으로" | `channel.json` → `"tagline": "매주 금요일 새 영상"` (색·크기는 `taglineColor`·`taglineSize`) |
| "강조 단어를 분홍색으로" / "장면 이름표를 빨간색으로" | `"highlightColor": "#ff8fb1"` / `"sceneLabelColor": "#e53935"`, `"sceneLabelTextColor": "#ffffff"` |

- **원래 모양으로 되돌리기**: 그 키를 지우거나 위 표의 기본값으로 되돌린다. "전부 처음대로"면 `theme.json` 을 위 표의 기본값 그대로 다시 쓴다.
  (`theme.json` 파일 자체는 지우지 않는다. 지워져 있으면 렌더·미리보기 스크립트가 기본값으로 다시 만든다.)
- 글씨 색과 바탕색이 비슷해 읽기 어려우면 수강생에게 알려 주고 대비가 큰 색을 함께 제안한다.
- 사진 위치·화면 배치(어디에 무엇이 놓이는지)는 바꿀 수 없다고 쉬운 말로 안내한다. 영상 한 편의 제목 내용·장면 이름표 글자·
  강조 단어는 그 영상의 `src/<ID>Composition.tsx` 에서 바꾼다 (스킬 안내 참고).

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
- 채널 설정: `channel.json` · 화면 모양(색·글씨 크기): `theme.json`
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
- 수강생이 만든 영상(`src/*Composition.tsx`, `public/`, `output/`)과 `channel.json`, `theme.json`, `my-rules.md`, `my-shorts` 를 지우거나 덮어쓰지 않는다
  (수강생이 요청한 키만 고친다).
- 강의 키트 파일(`AGENTS.md`, `CLAUDE.md`, `.agents/skills/issuekiller-shorts/`, `.claude/skills/issuekiller-shorts/`, `.codex/`, `scripts/`, `src/NewsTemplate.tsx`)은 고치지 않는다.
  수강생이 바꾸고 싶어 하는 것은 위 "내 것으로 바꾸기"의 수강생 파일(`channel.json`, `theme.json`, `my-rules.md`, `my-shorts`)로 처리한다.
  화면 모양 요청은 `theme.json` 으로 처리한다 (위 "화면 모양 바꾸기").
