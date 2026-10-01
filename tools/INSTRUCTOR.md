# 강사용 메모 (수강생에게는 보이지 않아도 되는 내용)

## 처음 한 번: 저장소 이름 넣기

1. `tools/build.py` 의 `GH_REPO = "__GH_REPO__"` 를 실제 값(예: `deanlee/issuekiller-setup`)으로 바꾼다. (바꿀 곳은 이 한 줄뿐)
2. `python3 tools/build.py` → 루트의 `get.sh`/`get.ps1`/`README.md`, `docs/index.html`, `docs/*.zip` 이 다시 만들어진다.
3. (없음)
4. 커밋 → `main` 에 push.
5. GitHub → Settings → Pages → Source: **Deploy from a branch**, Branch: `main`, Folder: `/docs` → Save.
   (gh CLI: `gh api -X POST repos/<USER>/issuekiller-setup/pages -f build_type=legacy -f "source[branch]=main" -f "source[path]=/docs"`)
6. 몇 분 뒤 `https://<USER>.github.io/issuekiller-setup/` 이 열리면 끝.

## 고칠 때

- 설치 도우미(`setup/`)나 한 줄 스크립트 템플릿(`tools/templates/get.*`)을 고쳤으면 **반드시 `python3 tools/build.py` 를 다시 실행**한 뒤 커밋한다.
  루트의 `get.sh`/`get.ps1`/`README.md` 와 `docs/` 는 손으로 고치지 않는다 (`tools/templates/` 에서 생성됨).
- `setup/windows/*.ps1` 은 UTF-8 BOM + CRLF, `*.bat` 은 ASCII CRLF 를 유지한다 (`.gitattributes` 로 변환을 막아 둠).
- 수강생이 받는 것은 GitHub 의 branch archive(`archive/refs/heads/main.zip`)다. `docs/`, `tools/`, `.github/` 는
  `.gitattributes` 의 `export-ignore` 로 빠진다. 새 폴더를 추가할 때 수강생에게 필요 없는 것이면 여기에도 추가한다.

## 동작 요약

- `get.sh`: Mac 전용 검사 → branch zip 다운로드(`curl`) → `ditto` 로 풀기 → `~/issuekiller` 에 배치
  (이미 `package.json` 이 있으면 `setup/` 교체 + `setup/common/kit-files.txt` 의 강의 키트 파일 갱신,
  다른 내용이 있으면 `issuekiller-old-<시각>` 으로 옮김)
  → `setup/mac/install.command` 를 `/dev/tty` 를 물려 실행. `curl | bash` 안전을 위해 `main()` 으로 감싸 전체 파싱 후 실행.
- `get.ps1`: 64비트 검사 → `Invoke-WebRequest` → `Expand-Archive` → 같은 배치 규칙 →
  `powershell.exe -NoProfile -ExecutionPolicy Bypass -File setup\windows\install.ps1`. `irm | iex` 는 실행 정책의 영향을 받지 않는다.
- 환경변수로 바꿀 수 있는 것: `ISSUEKILLER_REPO`, `ISSUEKILLER_REF`, `ISSUEKILLER_ZIP_URL`, `ISSUEKILLER_PROJECT`, `SKIP_CLAUDE=1`.

## 로컬에서 끝까지 시험하기 (Mac)

```bash
python3 tools/build.py
git archive --format=zip --prefix=issuekiller-setup-main/ -o /tmp/ik/main.zip HEAD
# 커밋 전 변경(새 파일 포함)까지 넣으려면 실제 index 를 건드리지 않는 임시 index 로 tree 를 만든다:
#   GIT_INDEX_FILE=/tmp/ik/idx git read-tree HEAD && GIT_INDEX_FILE=/tmp/ik/idx git add -A \
#   && git archive --format=zip --prefix=issuekiller-setup-main/ -o /tmp/ik/main.zip $(GIT_INDEX_FILE=/tmp/ik/idx git write-tree)
cp get.sh /tmp/ik/ && (cd /tmp/ik && python3 -m http.server 8765 --bind 127.0.0.1 &)
curl -fsSL http://127.0.0.1:8765/get.sh | env -i HOME=/tmp/ik/home PATH=/usr/bin:/bin:/usr/sbin:/sbin \
  ISSUEKILLER_ZIP_URL=http://127.0.0.1:8765/main.zip SKIP_CLAUDE=1 bash
```

## 검증 상태

- Mac: `get.sh` → `install.command` → 시험 렌더까지 격리된 HOME 에서 통과 (2026-09-30, macOS 15 / Apple Silicon).
- Windows: `install.ps1`/`get.ps1` 은 문법·인코딩만 확인. **실제 Windows PC 에서 한 번 돌려 본 뒤 배포**할 것.

## 제작 키트 (설치하면 함께 들어감)

- `CLAUDE.md`, `.claude/skills/issuekiller-shorts/` (원본 스킬을 수강생 경로로 고친 것), `src/NewsTemplate.tsx`
  (원본 TripleNews0721Composition 에서 실존 인물 예시를 뺀 화면 템플릿), `src/ClaudeGeneratedCompositions.tsx`(빈 등록부),
  `scripts/generate-supertonic-voiceover.py`, `scripts/py.sh`(venv Python 실행기), `channel.json`(채널 이름, 기본 "내 채널").
- 채널 이름은 `channel.json` 한 곳. 스킬이 처음 사용할 때 수강생에게 묻고 저장한다. 템플릿 배지와 업로드 문서 해시태그가 여기서 나온다.
- 수강생 흐름: `cd ~/issuekiller` → `claude` → "쇼츠 만들어줘" (사진 없이 시험: "연습으로 아무 주제나 쇼츠 만들어줘").
- 키트 파일을 고치면 `setup/common/kit-files.txt` 에 올라 있는지 확인한다. `kit` 은 재설치 때 교체(바뀐 파일은
  `~/issuekiller-backup-<시각>/` 에 보관), `seed` 는 없을 때만 넣는다. 수강생이 고치는 파일은 반드시 `seed` 로 둔다.
- 실존 인물 사진·뉴스 자산·완성 컴포지션은 저장소에 넣지 않는다 (공개 저장소).

## 강의 당일

- 이미 설치한 수강생은 같은 한 줄 명령을 다시 실행하면 키트가 최신으로 바뀐다 (만든 영상·채널 이름은 유지).
- 로컬 시험 기록: 2026-10-01 격리 HOME 에서 갱신 경로·새 폴더 경로 모두 설치 → 연습 쇼츠(4장면) 스캐폴드 → 음성 →
  타이밍 → 렌더 → validate_short.py 통과 (Mac). Windows 는 실기 미검증.
