# 제작 파이프라인

## 기준 경로

| 항목 | 위치 (프로젝트 폴더 기준) |
|---|---|
| 프로젝트 폴더 | Mac `~/issuekiller` · Windows `%USERPROFILE%\issuekiller` |
| 채널 설정 | `channel.json` (`name`, `tagline`) |
| 화면 템플릿 (고치지 않음) | `src/NewsTemplate.tsx` (`createNewsComposition`, `NewsConfig`, `Scene`) |
| 영상 등록부 (스크립트가 자동 수정) | `src/ClaudeGeneratedCompositions.tsx` |
| 영상별 Composition | `src/<ID>Composition.tsx` |
| 영상별 자산 | `public/<asset-root>/` |
| 음성 생성기 | `scripts/generate-supertonic-voiceover.py` |
| Python 실행기 | `scripts/py.sh` → `~/issuekiller-tools/venv` 의 Python |
| 결과 영상 | `output/<asset-root>-final.mp4` |
| 콘택트시트 | `qc/<asset-root>/contact.jpg` |
| 도구 (설치 도우미가 설치) | `~/issuekiller-tools/bin` (ffmpeg, ffprobe, uv), `~/issuekiller-tools/node` |

모든 명령은 **프로젝트 폴더에서** 실행한다. 아래 예시는 Mac 터미널과 Windows 의 Git Bash(Claude Code 가 쓰는 셸)에서
그대로 동작한다. Windows PowerShell 에서 실행해야 할 때만 맨 아래 "Windows PowerShell 형식"을 쓴다.

```bash
cd ~/issuekiller
# 명령을 못 찾는다고 나오면 (새 터미널이 아닐 때) 도구 경로를 붙인다
export PATH="$HOME/issuekiller-tools/bin:$HOME/issuekiller-tools/node/bin:$HOME/issuekiller-tools/node:$PATH"
```

Python 은 항상 `bash scripts/py.sh` 로 실행한다. (Mac: `~/issuekiller-tools/venv/bin/python`,
Windows: `~/issuekiller-tools/venv/Scripts/python.exe` 를 자동으로 고른다. 시스템 `python3` 는 쓰지 않는다.)

예시의 `20261001-topic` / `Auto20261001Topic` 은 실제 날짜와 소재로 바꾼다.
`--composition-id` 는 영문자로 시작하는 영문·숫자만, `--asset-root` 는 영문·숫자·`-`·`.`·`_` 만 쓴다.

## 0. 채널 이름 확인

```bash
cat channel.json
```

`"name": "내 채널"` 이면 수강생에게 채널 이름을 묻고 `name` 값만 바꿔 저장한다 (SKILL.md "처음 한 번: 채널 이름").

## 1. 스캐폴딩

```bash
bash scripts/py.sh .claude/skills/issuekiller-shorts/scripts/scaffold_short.py \
  --asset-root 20261001-topic \
  --composition-id Auto20261001Topic \
  --title '첫 줄\n둘째 줄' \
  --scenes 9
```

생성 항목:

- `public/<asset-root>/voice-script.json` (예시 문장 — 대본으로 바꿔 쓴다)
- `public/<asset-root>/source-info.md`
- `public/<asset-root>/youtube-upload.md` (채널 해시태그가 채워져 있음)
- `src/<composition-id>Composition.tsx`
- `src/ClaudeGeneratedCompositions.tsx` 등록

이미 같은 이름이 있으면 멈춘다. 새 이름을 쓴다 (`--force` 는 수강생이 덮어쓰기를 원할 때만).

## 2. 이미지 준비

장면별 파일명 (모두 `public/<asset-root>/` 안):

```text
scene-01-framed.jpg
scene-02-framed.jpg
...
hook.jpg
```

원본을 함께 보존할 때는 `raw-01.jpg`처럼 이름을 구분한다. 프레임 이미지는 1080x1528 이상을 권장한다. 원본 자막과 기사 UI가 본문 자막 뒤에 겹치지 않게 크롭하되 권리 표시 회피를 목적으로 편집하지 않는다.

연습 모드(실제 사진 없이 시험)일 때는 연습용 이미지를 만든다. 이미 있는 파일은 건너뛴다.

```bash
bash scripts/py.sh .claude/skills/issuekiller-shorts/scripts/make_placeholders.py --asset-root 20261001-topic
```

## 3. 음성 생성

`voice-script.json`의 각 항목은 다음 필드를 가진다. 장면 수만큼 항목을 둔다.

```json
{
  "spokenText": "TTS가 읽을 자연스러운 문장",
  "displayText": "화면에 보일 2줄 자막"
}
```

실행 (처음 한 번은 모델 확인에 수십 초 걸린다):

```bash
bash scripts/py.sh scripts/generate-supertonic-voiceover.py public/20261001-topic --voice F1 --speed 1.22
```

결과: `voiceover-f1.wav`, `voice-timings.json`, `captions-voiced.json`, `used-captions.md`, `voice-segments-f1/`.
마지막 줄의 `durationMs` 가 30000~48000 이 아니면 대본 길이나 `--speed`(1.18~1.22)를 조정해 다시 만든다.

## 4. 타이밍 동기화

```bash
bash scripts/py.sh .claude/skills/issuekiller-shorts/scripts/sync_timing.py \
  --asset-root 20261001-topic \
  --composition-id Auto20261001Topic
```

동기화 후 `src/<ID>Composition.tsx` 의 `sceneLabels`, `highlightTerms`, 이미지 `position`, `zoom`을 장면에 맞게 다듬고,
`highlightTerms` 아래에 `hook` 설정을 넣는다 (아래 "훅 카드와 썸네일").
`// ISSUEKILLER_TIMINGS_START` ~ `END` 사이와 `..._DURATION_IN_FRAMES` 줄은 손으로 고치지 않는다 (다시 동기화하면 덮어씀).

## 5. 미리보기 (선택)

```bash
npx remotion studio --no-open
```

표시되는 주소(보통 http://localhost:3000)를 수강생에게 알려준다. 파일 감시 오류가 나면:

```bash
npx remotion studio --no-open --webpack-poll 1000
```

## 6. 렌더·자동 검수

```bash
bash scripts/py.sh .claude/skills/issuekiller-shorts/scripts/render_short.py \
  --asset-root 20261001-topic \
  --composition-id Auto20261001Topic
```

TypeScript 검사 → 렌더 → `validate_short.py` 를 차례로 실행한다. 출력:

```text
output/20261001-topic-final.mp4
qc/20261001-topic/contact.jpg
```

결과 파일이 이미 있으면 멈춘다. 고친 뒤 다시 렌더할 때는 `--output output/20261001-topic-v2.mp4` 처럼 새 이름을 쓴다.
검수만 다시 돌릴 때:

```bash
bash scripts/py.sh .claude/skills/issuekiller-shorts/scripts/validate_short.py \
  --asset-root 20261001-topic --mp4 output/20261001-topic-final.mp4
```

`[FAIL]` 이 있으면 고친 뒤 다시 렌더한다. `[WARN]` 은 직접 보고 판단한다.

## 7. 수동 검수

- 콘택트시트(`qc/<asset-root>/contact.jpg`)를 직접 열어 같은 사진·구도가 반복되지 않는지 확인
- 0초, 2초, 중간, 마지막 프레임에서 제목과 자막이 잘리지 않는지, 왼쪽 위 배지에 채널 이름이 맞게 보이는지 확인
- 얼굴이 자막에 완전히 가려지지 않는지 확인
- 원본 자막이나 기사 UI가 새 자막 뒤에서 어지럽게 보이지 않는지 확인
- 음성을 처음부터 끝까지 들어 사람 이름과 숫자 발음을 확인 (어색하면 `spokenText` 를 소리 나는 대로 고쳐 다시 생성)

프레임 한 장 뽑기:

```bash
ffmpeg -v error -ss 2 -i output/20261001-topic-final.mp4 -frames:v 1 -q:v 2 qc/20261001-topic/frame-2s.jpg
```

## 훅 카드와 썸네일

### 1. 훅 이미지 만들기

원본 프레임을 9:16으로 크롭해 얼굴이 화면을 채우게 한다.

```bash
ffmpeg -y -i <원본프레임> \
  -vf "crop=ih*9/16:ih:(iw-ih*9/16)/2:0,scale=1080:1920:flags=lanczos,unsharp=5:5:0.6" \
  -q:v 2 public/<asset-root>/hook.jpg
```

### 2. Composition에 훅 설정

`highlightTerms` 아래에 넣는다.

```ts
  hook: {
    text: "52살에 아빠 됐는데\n입덧을 한다",
    highlight: "입덧을 한다",
    image: "hook.jpg",
    position: "center 32%",
    durationMs: 1100,
  },
```

- `text`는 두 줄, 각 줄 8자 이내
- `highlight`는 `text` 안에 그대로 들어 있는 문자열이어야 노란 배경이 적용된다
- `position`으로 얼굴이 잘리지 않게 맞춘다
- 훅 카드에도 왼쪽 위에 채널 배지(`channel.json` 의 이름)가 자동으로 나온다

### 3. 썸네일 뽑기

렌더 후 훅 구간 한가운데 프레임을 쓴다.

```bash
ffmpeg -y -ss 0.4 -i output/<asset-root>-final.mp4 -frames:v 1 \
  -q:v 2 public/<asset-root>/thumbnail.jpg
```

업로드 시 `썸네일 → 파일 업로드`로 이 파일을 지정한다.

### 훅 이미지: 원본 해상도에 따라 방식이 다르다

원본이 작으면(방송 캡처는 보통 가로 650px 안팎) 9:16으로 자른 뒤 1080으로 늘리면
가로가 200px 남짓이 되어 심하게 뭉갠다. 원본 가로 크기를 먼저 확인한다.

```bash
ffprobe -v error -select_streams v:0 -show_entries stream=width,height -of csv=p=0 <원본>
```

**가로 900px 이상 (화보, 보도용 사진 등) — 9:16 크롭**

```bash
ffmpeg -y -i <원본> \
  -vf "crop=iw:ih*0.86:0:0,crop=ih*9/16:ih:(iw-ih*9/16)/2:0,scale=1080:1920:flags=lanczos,unsharp=5:5:0.6" \
  -q:v 2 public/<asset-root>/hook.jpg
```

**가로 900px 미만 (방송 캡처) — 원본 비율 유지 + 블러 배경**

가로만 1080으로 늘리고 위쪽에 배치한다. 훅 문구는 하단 300px 위에 오므로 겹치지 않는다.

```bash
# band = round(1080 * (원본높이*0.72) / 원본가로)
ffmpeg -y -i <원본> -i <원본> -filter_complex \
 "[0:v]crop=iw:ih*0.72:0:0,scale=1080:<band>:flags=lanczos,unsharp=5:5:0.5[fg];\
  [1:v]crop=iw:ih*0.72:0:0,scale=1080:1920:force_original_aspect_ratio=increase,crop=1080:1920,boxblur=44:2,eq=brightness=-0.16:saturation=1.1[bg];\
  [bg][fg]overlay=0:560[out]" -map "[out]" -q:v 2 public/<asset-root>/hook.jpg
```

이 경우 Composition의 `position`은 `"center center"`로 둔다.

### 장면 이미지가 어두울 때

원본이 어두우면 화면이 죽는다. 렌더 전에 장면 밴드의 평균 밝기를 재고, 100 미만이면 보정한다.

```bash
# 밝기 측정 (100 미만이면 보정 필요)
ffmpeg -v error -i public/<asset-root>/scene-03-framed.jpg -vf "crop=1080:470:0:430,format=gray,scale=1:1" \
  -f rawvideo - | od -An -tu1

# 보정본을 새 이름으로 만든 뒤 원본은 raw-03.jpg 로 보관하고 교체한다 (gamma 1.3~1.8)
ffmpeg -v error -i public/<asset-root>/scene-03-framed.jpg -vf "eq=brightness=0.10:gamma=1.35:saturation=1.05" \
  -q:v 2 public/<asset-root>/scene-03-bright.jpg
```

## Windows PowerShell 형식

Claude Code 는 Windows 에서도 Git Bash 로 명령을 실행하므로 보통 위 형식을 그대로 쓴다.
PowerShell 창에서 직접 실행해야 할 때만 아래처럼 바꾼다 (`\` 줄바꿈 대신 한 줄로, Python 은 전체 경로로).

```powershell
cd $env:USERPROFILE\issuekiller
$py = "$env:USERPROFILE\issuekiller-tools\venv\Scripts\python.exe"
& $py .claude\skills\issuekiller-shorts\scripts\scaffold_short.py --asset-root 20261001-topic --composition-id Auto20261001Topic --title "첫 줄\n둘째 줄" --scenes 9
& $py scripts\generate-supertonic-voiceover.py public\20261001-topic --voice F1 --speed 1.22
& $py .claude\skills\issuekiller-shorts\scripts\sync_timing.py --asset-root 20261001-topic --composition-id Auto20261001Topic
& $py .claude\skills\issuekiller-shorts\scripts\render_short.py --asset-root 20261001-topic --composition-id Auto20261001Topic
```
