#!/usr/bin/env python3
"""이슈킬러 설치 저장소 빌드.

  1) get.sh / get.ps1 / README.md : tools/templates/ 의 템플릿에 GH_REPO 를 채워 저장소 루트에 쓴다.
  2) docs/*.zip              : 명령어 방식이 안 되는 사람을 위한 Mac/Windows zip (프로젝트 + setup + 설치안내.txt)
  3) docs/index.html         : GitHub Pages 안내 페이지 (zip 은 base64 로 안에 넣고, 같은 폴더의 zip 으로도 연결)

  실행: python3 tools/build.py      (저장소 어디서 실행해도 됨)
  GH_REPO 는 아래 상수 하나만 바꾸면 스크립트·페이지·README 링크에 모두 반영된다.
"""
import base64, datetime, pathlib, stat, zipfile

GH_REPO = "deanlee1113/issuekiller-setup"          # 예: "deanlee/issuekiller-setup"  ← 계정이 정해지면 여기만 바꾼다
ZIP_TOP = "issuekiller"          # zip 안 최상위 폴더 이름
EXEC = {".command", ".sh"}       # 실행 권한을 줄 확장자
STAMP = (2026, 9, 30, 12, 0, 0)  # zip 안 파일 날짜 (빌드마다 바뀌지 않게 고정)

ROOT = pathlib.Path(__file__).resolve().parent.parent
TPL, DOCS = ROOT / "tools" / "templates", ROOT / "docs"
PROJECT_FILES = ["package.json", "package-lock.json", "remotion.config.ts", "tsconfig.json",
                 "CLAUDE.md", "channel.json", ".gitignore"]
PROJECT_DIRS = ["src", "public", "scripts", ".claude"]   # .claude = 쇼츠 제작 스킬 (점으로 시작하는 폴더도 포함)
SKIP_NAMES = {".DS_Store", "settings.local.json"}   # settings.local.json = 강사 개인 Claude 설정
SKIP_DIRS = {"__pycache__", "node_modules"}


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

    for p in (ROOT / "get.sh", ROOT / "get.ps1", ROOT / "README.md", mac, win, DOCS / "index.html"):
        print(f"{p.relative_to(ROOT)}  {p.stat().st_size:,} bytes")


if __name__ == "__main__":
    main()
