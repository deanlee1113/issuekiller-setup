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
  (이미 `package.json` 이 있으면 `setup/` 만 교체, 다른 내용이 있으면 `issuekiller-old-<시각>` 으로 옮김)
  → `setup/mac/install.command` 를 `/dev/tty` 를 물려 실행. `curl | bash` 안전을 위해 `main()` 으로 감싸 전체 파싱 후 실행.
- `get.ps1`: 64비트 검사 → `Invoke-WebRequest` → `Expand-Archive` → 같은 배치 규칙 →
  `powershell.exe -NoProfile -ExecutionPolicy Bypass -File setup\windows\install.ps1`. `irm | iex` 는 실행 정책의 영향을 받지 않는다.
- 환경변수로 바꿀 수 있는 것: `ISSUEKILLER_REPO`, `ISSUEKILLER_REF`, `ISSUEKILLER_ZIP_URL`, `ISSUEKILLER_PROJECT`, `SKIP_CLAUDE=1`.

## 로컬에서 끝까지 시험하기 (Mac)

```bash
python3 tools/build.py
git archive --format=zip --prefix=issuekiller-setup-main/ -o /tmp/ik/main.zip HEAD   # 커밋 전이면 $(git write-tree)
cp get.sh /tmp/ik/ && (cd /tmp/ik && python3 -m http.server 8765 --bind 127.0.0.1 &)
curl -fsSL http://127.0.0.1:8765/get.sh | env -i HOME=/tmp/ik/home PATH=/usr/bin:/bin:/usr/sbin:/sbin \
  ISSUEKILLER_ZIP_URL=http://127.0.0.1:8765/main.zip SKIP_CLAUDE=1 bash
```

## 검증 상태

- Mac: `get.sh` → `install.command` → 시험 렌더까지 격리된 HOME 에서 통과 (2026-09-30, macOS 15 / Apple Silicon).
- Windows: `install.ps1`/`get.ps1` 은 문법·인코딩만 확인. **실제 Windows PC 에서 한 번 돌려 본 뒤 배포**할 것.

## 강의 당일

- 수강생 폴더는 `~/issuekiller` 뼈대(TestShort 만 있음). 실습용 컴포지션·스크립트·에셋은 당일 별도 zip 으로 나눠 주고
  `~/issuekiller` 에 덮어 넣게 한다 (Python 경로는 `~/issuekiller-tools/venv` 기준으로 맞출 것).
