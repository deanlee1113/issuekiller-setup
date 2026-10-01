# =====================================================================
#  이슈킬러 쇼츠 제작 환경 확인표 v3 (Windows)
#  실행: 같은 폴더의 check.bat 을 더블클릭. [XX] 가 있으면 화면을 캡처해서 보내주세요.
# =====================================================================
$ErrorActionPreference = "SilentlyContinue"
try { [Console]::OutputEncoding = [System.Text.Encoding]::UTF8 } catch {}
$SetupDir = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$ToolsDir = Join-Path $env:USERPROFILE "issuekiller-tools"
$BinDir   = Join-Path $ToolsDir "bin"
$NodeDir  = Join-Path $ToolsDir "node"
$GitDir   = Join-Path $ToolsDir "git"
$VenvPy   = Join-Path $ToolsDir "venv\Scripts\python.exe"
$env:Path = "$BinDir;$NodeDir;$GitDir\cmd;$env:USERPROFILE\.local\bin;" + [Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [Environment]::GetEnvironmentVariable("Path", "User")

$script:NG = 0
function Row($okFlag, $name, $desc) {
  if ($okFlag) { Write-Host ("  [OK] {0}  -  {1}" -f $name, $desc) -ForegroundColor Green }
  else { Write-Host ("  [XX] {0}  -  {1}" -f $name, $desc) -ForegroundColor Red; $script:NG++ }
}
function Has($cmd) { return [bool](Get-Command $cmd -ErrorAction SilentlyContinue) }
function Ver($cmd, $arg) { try { $o = & $cmd $arg 2>$null | Select-Object -First 1; return "$o" } catch { return "" } }
function PyOk($code) { if (-not (Test-Path $VenvPy)) { return $false }; & $VenvPy -c $code 2>$null | Out-Null; return ($LASTEXITCODE -eq 0) }
function PyOut($code) { if (-not (Test-Path $VenvPy)) { return "" }; return "$(& $VenvPy -c $code 2>$null)" }
function Find-Project {
  $cands = @($env:ISSUEKILLER_PROJECT, (Split-Path -Parent $SetupDir),
             (Join-Path $env:USERPROFILE "issuekiller"),
             (Join-Path $env:USERPROFILE "Desktop\issuekiller"),
             (Join-Path $env:USERPROFILE "Downloads\issuekiller"))
  foreach ($c in $cands) {
    if ($c -and (Test-Path (Join-Path $c "package.json"))) {
      if (Select-String -Path (Join-Path $c "package.json") -Pattern '"remotion"' -Quiet) { return (Resolve-Path $c).Path }
    }
  }
  return $null
}
function DirSize($p) { if (Test-Path $p) { $b = (Get-ChildItem $p -Recurse -File | Measure-Object Length -Sum).Sum; return ("{0:N0} MB" -f ($b / 1MB)) } else { return "" } }

$os = Get-CimInstance Win32_OperatingSystem
$free = (Get-PSDrive -Name ($env:USERPROFILE.Substring(0,1))).Free
$arch = $env:PROCESSOR_ARCHITECTURE; if ($env:PROCESSOR_ARCHITEW6432) { $arch = $env:PROCESSOR_ARCHITEW6432 }
Write-Host ""
Write-Host ("이슈킬러 제작 환경 확인  -  {0}" -f (Get-Date -Format "yyyy-MM-dd HH:mm"))
Write-Host ("  {0} (build {1}, {2}) / 여유 디스크 {3:N0} GB" -f $os.Caption, $os.BuildNumber, $arch, ($free / 1GB))
Write-Host ("  설치 폴더: {0} ({1})" -f $ToolsDir, (DirSize $ToolsDir))
Write-Host ""

$NodeExe = Join-Path $NodeDir "node.exe"; $Npm = Join-Path $NodeDir "npm.cmd"
Row (Test-Path $NodeExe) "Node.js" ((Ver $NodeExe "-v") + " ($NodeDir)")
Row (Test-Path $Npm)     "npm"     (Ver $Npm "-v")
$ff = Join-Path $BinDir "ffmpeg.exe"; $fp = Join-Path $BinDir "ffprobe.exe"
$ffTile = $false
if (Test-Path $ff) { $ffTile = [bool](& $ff -hide_banner -filters 2>$null | Select-String -Pattern '^\s*[A-Z.]+\s+tile\s' -Quiet) }
Row $ffTile          "ffmpeg"  ((((Ver $ff "-version") -split " ") | Select-Object -First 3) -join " ") + " (tile 필터 포함)"
Row (Test-Path $fp)  "ffprobe" ((((Ver $fp "-version") -split " ") | Select-Object -First 3) -join " ")
$uv = Join-Path $BinDir "uv.exe"
Row (Test-Path $uv)  "uv (파이썬 설치 도구)" (Ver $uv "--version")
$bash = Join-Path $GitDir "bin\bash.exe"
Row (Test-Path $bash) "Git Bash (휴대용)" ((Ver (Join-Path $GitDir "cmd\git.exe") "--version") + " ($GitDir)")
# Claude Code(터미널용)는 선택 항목: 없어도 [XX] 로 세지 않는다 (AI 앱으로 실습)
if (Has claude) { Row $true "Claude Code (선택)" (Ver claude "--version") }
else { Write-Host "  [--] Claude Code (선택)  -  없음 · AI 앱(ChatGPT·Claude·Antigravity)으로 실습하면 필요 없습니다" -ForegroundColor DarkGray }

Row (Test-Path $VenvPy) "Python 가상환경" ("$ToolsDir\venv (" + (PyOut "import sys;print(sys.version.split()[0])") + ")")
Row (PyOk "import supertonic, onnxruntime, numpy, soundfile") "  supertonic 패키지" (PyOut "import onnxruntime;print('supertonic 1.3.1, onnxruntime', onnxruntime.__version__)")
Row (PyOk "import faster_whisper")  "  faster-whisper" (PyOut "import faster_whisper;print(faster_whisper.__version__)")
Row (PyOk "import PIL")             "  pillow"         (PyOut "import PIL;print(PIL.__version__)")
$stCache = Join-Path $env:USERPROFILE ".cache\supertonic3\onnx"
$whHub   = Join-Path $env:USERPROFILE ".cache\huggingface\hub"
$whCache = Join-Path $whHub "models--Systran--faster-whisper-small"
Row (Test-Path $stCache) "Supertonic 모델"    ("~\.cache\supertonic3 (" + (DirSize (Split-Path $stCache)) + ")")
Row (Test-Path $whCache) "Whisper small 모델" ("~\.cache\huggingface\hub (" + (DirSize $whHub) + ")")
Row (Test-Path (Join-Path $ToolsDir "test-voice.wav")) "시험 합성 음성" (Join-Path $ToolsDir "test-voice.wav")

$ProjectDir = Find-Project
if ($ProjectDir) {
  Row $true "프로젝트 폴더" $ProjectDir
  $remPkg = Join-Path $ProjectDir "node_modules\remotion\package.json"
  $remVer = if (Test-Path $remPkg) { (Get-Content $remPkg | ConvertFrom-Json).version } else { "" }
  Row (Test-Path $remPkg) "  Remotion 패키지" $remVer
  $browser = (Test-Path (Join-Path $env:USERPROFILE ".remotion\chrome-headless-shell")) -or (Test-Path (Join-Path $ProjectDir "node_modules\.remotion"))
  Row $browser "  렌더용 브라우저" "node_modules\.remotion 또는 ~\.remotion"
} else {
  Row $false "프로젝트 폴더" "package.json 을 찾지 못함 (다운로드한 zip 을 $env:USERPROFILE\issuekiller 에 압축 해제)"
}
$userPath = [Environment]::GetEnvironmentVariable("Path", "User")
Row ([bool]($userPath -and $userPath.Contains($BinDir))) "사용자 PATH 등록" "issuekiller-tools\bin 포함"
$gb = [Environment]::GetEnvironmentVariable("CLAUDE_CODE_GIT_BASH_PATH", "User")
Row ([bool]($gb -and (Test-Path $gb))) "Claude Code Git Bash 연결" "CLAUDE_CODE_GIT_BASH_PATH=$gb"
$tr = Join-Path $ToolsDir "test-render.mp4"
$ffprobe = Join-Path $BinDir "ffprobe.exe"
$trCodec = if ((Test-Path $tr) -and (Test-Path $ffprobe)) { & $ffprobe -v error -select_streams v:0 -show_entries stream=codec_name -of csv=p=0 $tr 2>$null } else { "" }
Row ("$trCodec" -match "h264") "시험 렌더 영상" "$tr (2초, 1080x1920 H.264)"

Write-Host ""
if ($script:NG -eq 0) {
  Write-Host "모든 항목 준비 완료. 강의 당일 바로 실습할 수 있습니다." -ForegroundColor Green
} else {
  Write-Host ("[XX] {0}개 항목이 준비되지 않았습니다. install.bat 을 다시 실행하거나 이 화면을 캡처해서 보내주세요." -f $script:NG) -ForegroundColor Red
}
exit $script:NG
