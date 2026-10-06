#!/usr/bin/env python3
"""이슈킬러 설치 저장소 빌드.

  1) get.sh / get.ps1 / README.md : tools/templates/ 의 템플릿에 GH_REPO 를 채워 저장소 루트에 쓴다.
  2) docs/*.zip              : 명령어 방식이 안 되는 사람을 위한 Mac/Windows zip (프로젝트 + setup + 설치안내.txt)
  3) docs/index.html         : GitHub Pages 안내 페이지 (zip 은 base64 로 안에 넣고, 같은 폴더의 zip 으로도 연결)
  4) docs/practice/, docs/guide/ index.html: tools/templates/practice.html, guide.html 이 있으면 GH_REPO 를 채워 쓴다 (없으면 건너뜀)
  0) (먼저) 쇼츠 제작 스킬 원본 .agents/skills/issuekiller-shorts 를 .claude/skills/issuekiller-shorts 로 복사하고
     두 사본이 같은지, scripts/py.cmd 가 ASCII + CRLF 인지, kit-files.txt 의 경로가 모두 있는지,
     화면 모양 기본값(theme.json · NewsTemplate.tsx · _ik_env.py)이 서로 같은지 확인한다.
     스킬은 .agents/ 쪽만 고친다 (.claude/ 쪽은 빌드가 덮어씀. Windows 때문에 심볼릭 링크는 쓰지 않는다).

  실행: python3 tools/build.py      (저장소 어디서 실행해도 됨)
  GH_REPO 는 아래 상수 하나만 바꾸면 스크립트·페이지·README 링크에 모두 반영된다.
"""
import ast, base64, datetime, json, pathlib, re, shutil, stat, zipfile

GH_REPO = "deanlee1113/issuekiller-setup"          # 예: "deanlee/issuekiller-setup"  ← 계정이 정해지면 여기만 바꾼다
ZIP_TOP = "issuekiller"          # zip 안 최상위 폴더 이름
EXEC = {".command", ".sh"}       # 실행 권한을 줄 확장자
STAMP = (2026, 9, 30, 12, 0, 0)  # zip 안 파일 날짜 (빌드마다 바뀌지 않게 고정)

ROOT = pathlib.Path(__file__).resolve().parent.parent
TPL, DOCS = ROOT / "tools" / "templates", ROOT / "docs"
PROJECT_FILES = ["package.json", "package-lock.json", "remotion.config.ts", "tsconfig.json",
                 "AGENTS.md", "CLAUDE.md", "channel.json", "theme.json", "my-rules.md", ".gitignore"]
# .agents = 공통 스킬(Codex·Antigravity), .claude = Claude 용 사본·설정, .codex = Codex 설정 (점으로 시작하는 폴더도 포함)
PROJECT_DIRS = ["src", "public", "scripts", ".agents", ".claude", ".codex"]
SKIP_NAMES = {".DS_Store", "settings.local.json"}   # settings.local.json = 강사 개인 Claude 설정
SKIP_DIRS = {"__pycache__", "node_modules"}
SKILL_SRC = ROOT / ".agents" / "skills" / "issuekiller-shorts"      # 스킬 원본 (여기만 고친다)
SKILL_COPIES = [ROOT / ".claude" / "skills" / "issuekiller-shorts"]  # 빌드가 원본으로 덮어쓰는 사본


def add(zf, src: pathlib.Path, arc: str, data: bytes | None = None):
    info = zipfile.ZipInfo(arc, date_time=STAMP)
    info.compress_type = zipfile.ZIP_DEFLATED
    mode = 0o755 if src.suffix in EXEC else 0o644
    info.external_attr = (stat.S_IFREG | mode) << 16
    zf.writestr(info, src.read_bytes() if data is None else data)


def add_tree(zf, folder: pathlib.Path, arc_prefix: str):
    for p in sorted(folder.rglob("*")):
        rel = p.relative_to(folder)
        if p.is_file() and p.name not in SKIP_NAMES and not SKIP_DIRS.intersection(rel.parts):
            add(zf, p, f"{arc_prefix}/{rel.as_posix()}")


def skill_files(folder: pathlib.Path) -> dict:
    if not folder.is_dir():
        return {}
    return {p.relative_to(folder).as_posix(): p for p in sorted(folder.rglob("*"))
            if p.is_file() and p.name not in SKIP_NAMES and not SKIP_DIRS.intersection(p.relative_to(folder).parts)}


def sync_skill():
    """.agents/skills 원본 → .claude/skills 사본. 원본에 없는 파일은 사본에서도 지운다. 끝나면 같은지 확인."""
    src = skill_files(SKILL_SRC)
    assert "SKILL.md" in src, f"스킬 원본이 없습니다: {SKILL_SRC}"
    for dest in SKILL_COPIES:
        for rel, p in skill_files(dest).items():
            if rel not in src:
                p.unlink()
        for rel, p in src.items():
            target = dest / rel
            if not target.exists() or target.read_bytes() != p.read_bytes():
                target.parent.mkdir(parents=True, exist_ok=True)
                shutil.copy2(p, target)
        for d in sorted((x for x in dest.rglob("*") if x.is_dir()), reverse=True):
            if not any(d.iterdir()):
                d.rmdir()
        after = skill_files(dest)
        assert after.keys() == src.keys() and all(after[r].read_bytes() == src[r].read_bytes() for r in src), \
            f"스킬 사본이 원본과 다릅니다: {dest}"
    return len(src)


def check_kit():
    """키트 파일 점검: py.cmd 는 ASCII + CRLF, kit-files.txt 의 경로는 모두 존재."""
    data = (ROOT / "scripts" / "py.cmd").read_bytes()
    data.decode("ascii")
    assert b"\r\n" in data and data.count(b"\n") == data.count(b"\r\n"), "scripts/py.cmd 는 CRLF 여야 합니다"
    for line in (ROOT / "setup" / "common" / "kit-files.txt").read_text(encoding="utf-8").splitlines():
        parts = line.split()
        if len(parts) >= 2 and parts[0] in ("kit", "seed"):
            assert (ROOT / parts[1]).exists(), f"kit-files.txt 의 경로가 없습니다: {parts[1]}"
    check_theme_defaults()


def check_theme_defaults():
    """theme.json(키트 기본값) = NewsTemplate.tsx 의 DEFAULT_THEME = _ik_env.py 의 DEFAULT_THEME 인지 확인."""
    seed = json.loads((ROOT / "theme.json").read_text(encoding="utf-8"))
    env_src = (SKILL_SRC / "scripts" / "_ik_env.py").read_text(encoding="utf-8")
    env = next(ast.literal_eval(node.value) for node in ast.parse(env_src).body
               if isinstance(node, ast.Assign) and getattr(node.targets[0], "id", "") == "DEFAULT_THEME")
    tsx = (ROOT / "src" / "NewsTemplate.tsx").read_text(encoding="utf-8")
    block = re.search(r"const DEFAULT_THEME = \{(.*?)\n\};", tsx, re.S)
    assert block, "NewsTemplate.tsx 에 DEFAULT_THEME 이 없습니다"
    tpl = {k: json.loads(v) for k, v in re.findall(r"^\s*(\w+): (.+?),\s*$", block.group(1), re.M)}
    assert seed == env == tpl, f"화면 모양 기본값이 서로 다릅니다:\n theme.json={seed}\n _ik_env={env}\n tsx={tpl}"


def build_zip(os_name: str) -> pathlib.Path:
    out = DOCS / f"issuekiller-setup-{os_name}.zip"
    if out.exists():
        out.unlink()                                   # 빌드 산출물은 매번 새로 만든다
    guide = (TPL / f"guide-{os_name}.txt").read_text(encoding="utf-8").replace("__GH_REPO__", GH_REPO)
    with zipfile.ZipFile(out, "w", zipfile.ZIP_DEFLATED) as zf:
        for name in PROJECT_FILES:
            add(zf, ROOT / name, f"{ZIP_TOP}/{name}")
        for d in PROJECT_DIRS:
            add_tree(zf, ROOT / d, f"{ZIP_TOP}/{d}")
        add_tree(zf, ROOT / "setup" / "common", f"{ZIP_TOP}/setup/common")
        add_tree(zf, ROOT / "setup" / os_name, f"{ZIP_TOP}/setup/{os_name}")
        add(zf, TPL / f"guide-{os_name}.txt", f"{ZIP_TOP}/설치안내.txt", guide.encode("utf-8"))
    return out


def human(n: int) -> str:
    return f"{n/1024:.0f}KB" if n < 1024 * 1024 else f"{n/1024/1024:.1f}MB"


def fill(text: str, values: dict) -> str:
    for key, val in values.items():
        assert key in text, f"자리표시자 없음: {key}"
        text = text.replace(key, val)
    return text


def main():
    DOCS.mkdir(exist_ok=True)
    n = sync_skill()
    check_kit()
    print(f"스킬 사본 동기화: .agents/skills → .claude/skills ({n}개 파일 동일)")
    if GH_REPO == "__GH_REPO__":
        print("⚠️  GH_REPO 가 아직 자리표시자입니다. 계정이 정해지면 tools/build.py 의 GH_REPO 를 바꾸고 다시 빌드하세요.")

    # 1) 한 줄 설치 스크립트 (get.sh: LF, 실행 권한 / get.ps1: BOM 없는 UTF-8 + CRLF — irm | iex 용)
    sh = fill((TPL / "get.sh").read_text(encoding="utf-8"), {"__GH_REPO__": GH_REPO})
    (ROOT / "get.sh").write_bytes(sh.replace("\r\n", "\n").encode("utf-8"))
    (ROOT / "get.sh").chmod(0o755)
    ps = fill((TPL / "get.ps1").read_text(encoding="utf-8"), {"__GH_REPO__": GH_REPO})
    (ROOT / "get.ps1").write_bytes(ps.replace("\r\n", "\n").replace("\n", "\r\n").encode("utf-8"))

    # 1-b) README (안내 페이지 주소는 GitHub Pages 기본 주소: <계정>.github.io/<저장소>)
    user, _, repo = GH_REPO.partition("/")
    pages = f"{user}.github.io/{repo}" if repo else "__GH_PAGES__"
    (ROOT / "README.md").write_text(fill((TPL / "README.md").read_text(encoding="utf-8"),
                                         {"__GH_REPO__": GH_REPO, "__GH_PAGES__": pages}), encoding="utf-8")

    # 2) zip 대안
    mac, win = build_zip("mac"), build_zip("windows")

    # 3) 안내 페이지
    html = fill((TPL / "site-v3.html").read_text(encoding="utf-8"), {
        "__GH_REPO__": GH_REPO,
        "__MAC_B64__": base64.b64encode(mac.read_bytes()).decode(),
        "__WIN_B64__": base64.b64encode(win.read_bytes()).decode(),
        "__MAC_SIZE__": human(mac.stat().st_size),
        "__WIN_SIZE__": human(win.stat().st_size),
        "__BUILD_DATE__": datetime.date.today().isoformat(),
    })
    (DOCS / "index.html").write_text(html, encoding="utf-8")
    (DOCS / ".nojekyll").write_bytes(b"")               # Pages 가 파일을 그대로 서빙하게
    outputs = [ROOT / "get.sh", ROOT / "get.ps1", ROOT / "README.md", mac, win, DOCS / "index.html"]

    # 4) 실습 페이지 · 내 것으로 바꾸기 안내 (템플릿이 있을 때만)
    for name in ("practice", "guide"):
        page_tpl = TPL / f"{name}.html"
        if not page_tpl.exists():
            continue
        page = DOCS / name / "index.html"
        page.parent.mkdir(parents=True, exist_ok=True)
        text = page_tpl.read_text(encoding="utf-8")
        if "__GH_REPO__" in text:                       # 자리표시자가 없는 페이지도 그대로 싣는다
            text = fill(text, {"__GH_REPO__": GH_REPO})
        page.write_text(text, encoding="utf-8")
        outputs.append(page)

    # 4-b) 실습 페이지에서 내려받는 '혼자 시작하기' 가이드 (AI 에게 첨부해 단계별 안내를 받는 파일)
    guide_md = TPL / "practice-guide.md"
    if guide_md.exists() and (DOCS / "practice").exists():
        out = DOCS / "practice" / "shorts-start-guide.md"
        out.write_text(fill(guide_md.read_text(encoding="utf-8"), {"__GH_REPO__": GH_REPO}), encoding="utf-8")
        outputs.append(out)

    for p in outputs:
        print(f"{p.relative_to(ROOT)}  {p.stat().st_size:,} bytes")


if __name__ == "__main__":
    main()
