# =====================================================================
#  이슈킬러 쇼츠 제작 환경 설치 도우미 v3 · 영상 제작 전용 (Windows 10 / 11, 64비트)
#
#  관리자 권한 · winget 없이 설치합니다. (음성 엔진에 필요한 Microsoft Visual C++ 구성 요소가 없을 때만
#  마이크로소프트 공식 설치 파일을 받아 설치하며, 이때 '예'를 누르는 확인 창이 한 번 뜹니다)
#  모든 도구는  %USERPROFILE%\issuekiller-tools  한 폴더에만 들어갑니다. (지우면 원상복구)
#
#  실행 방법: 같은 폴더의 install.bat 을 더블클릭
#  여러 번 실행해도 안전합니다. 이미 설치된 항목은 건너뜁니다.
#  로그: %USERPROFILE%\issuekiller-tools\install-windows.log
# =====================================================================
$ErrorActionPreference = "Continue"
$ProgressPreference = "SilentlyContinue"   # 다운로드 속도 (진행 표시줄이 느리게 만듦)
try { [Console]::OutputEncoding = [System.Text.Encoding]::UTF8 } catch {}
try { [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 } catch {}

$SetupDir  = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$CommonDir = Join-Path $SetupDir "common"
$ToolsDir  = Join-Path $env:USERPROFILE "issuekiller-tools"
$BinDir    = Join-Path $ToolsDir "bin"
$NodeDir   = Join-Path $ToolsDir "node"
$GitDir    = Join-Path $ToolsDir "git"
$VenvDir   = Join-Path $ToolsDir "venv"
$VenvPy    = Join-Path $VenvDir "Scripts\python.exe"
$DlDir     = Join-Path $ToolsDir "downloads"
$NodeLine  = "latest-v24.x"   # Node.js LTS 계열
foreach ($d in @($ToolsDir, $BinDir, $DlDir)) { New-Item -ItemType Directory -Force -Path $d | Out-Null }
Start-Transcript -Path (Join-Path $ToolsDir "install-windows.log") -Append | Out-Null

# 이 스크립트 안에서만 쓰는 경로 (영구 등록은 9단계에서)
$env:Path = "$BinDir;$NodeDir;$GitDir\cmd;$env:USERPROFILE\.local\bin;" + $env:Path
$env:UV_PYTHON_INSTALL_DIR = Join-Path $ToolsDir "python"
$env:UV_CACHE_DIR          = Join-Path $ToolsDir "uv-cache"
$env:UV_PYTHON_PREFERENCE  = "only-managed"

$Total = 9
$script:Failed = @()
function Step($n, $t) { Write-Host ""; Write-Host "[$n/$Total] $t" -ForegroundColor Cyan; Write-Host ("-" * 60) }
function Ok($m)   { Write-Host "  [OK] $m" -ForegroundColor Green }
function Warn($m) { Write-Host "  [!!] $m" -ForegroundColor Yellow }
function Fail($m) { Write-Host "  [XX] $m" -ForegroundColor Red; $script:Failed += $m }
function Has($cmd) { return [bool](Get-Command $cmd -ErrorAction SilentlyContinue) }
function Download($url, $dest, [int]$minBps = 50000, [int]$maxSec = 1800) {
  # curl.exe(Windows 10 1803+ 기본 포함)가 빠르고 안정적. 없으면 Invoke-WebRequest.
  # 서버가 느리거나 연결이 멈추면 끝없이 기다리지 않도록: 45초 동안 $minBps(바이트/초)보다 느리면 끊고 재시도,
  # 그래도 안 되면 실패로 돌려 예비 서버로 넘어가게 한다. 진행 막대를 보여 멈춘 것처럼 보이지 않게 한다.
  if (Test-Path $dest) { Remove-Item $dest -Force }
  if (Get-Command curl.exe -ErrorAction SilentlyContinue) {
    & curl.exe -fL --retry 2 --retry-delay 3 --connect-timeout 20 --speed-limit $minBps --speed-time 45 --max-time $maxSec --progress-bar -S -o $dest $url
    if ($LASTEXITCODE -eq 0 -and (Test-Path $dest)) { return $true }
    if (Test-Path $dest) { Remove-Item $dest -Force -ErrorAction SilentlyContinue }
    return $false   # curl 이 있는데 실패했다면 같은 서버를 다시 오래 기다리지 않는다 (예비 서버로)
  }
  try { Invoke-WebRequest -Uri $url -OutFile $dest -UseBasicParsing -TimeoutSec $maxSec; return (Test-Path $dest) } catch { return $false }
}
function Sha256($path) { return (Get-FileHash -Path $path -Algorithm SHA256).Hash.ToLower() }
function Run($exe, [string[]]$argv) { & $exe @argv; return ($LASTEXITCODE -eq 0) }
function Q($a) { if ("$a" -match '[\s"]') { return '"' + ("$a" -replace '"', '\"') + '"' } return "$a" }   # Start-Process 인자 따옴표
function Test-VoiceEngine { if (-not (Test-Path $VenvPy)) { return $false }; & $VenvPy -c "import onnxruntime" 2>$null; return ($LASTEXITCODE -eq 0) }
function Install-VCRedist {
  # 음성 엔진(onnxruntime)은 Microsoft Visual C++ 재배포 패키지가 있어야 실행된다. 없거나 오래됐으면 공식 파일로 설치/갱신한다.
  Write-Host ""
  Write-Host "  음성 엔진에 필요한 윈도우 구성 요소(Microsoft Visual C++)를 설치합니다." -ForegroundColor Yellow
  Write-Host "  '이 앱이 디바이스를 변경하도록 허용하시겠어요?' 창이 뜨면 [예]를 눌러 주세요." -ForegroundColor Yellow
  $exe = Join-Path $DlDir "vc_redist.x64.exe"
  if (-not (Download "https://aka.ms/vs/17/release/vc_redist.x64.exe" $exe)) { Fail "Visual C++ 구성 요소 다운로드 실패 (https://aka.ms/vs/17/release/vc_redist.x64.exe)"; return $false }
  $sig = Get-AuthenticodeSignature -FilePath $exe
  if ($sig.Status -ne "Valid" -or "$($sig.SignerCertificate.Subject)" -notmatch "Microsoft Corporation") { Fail "받은 Visual C++ 설치 파일의 서명을 확인하지 못했습니다"; return $false }
  try { $p = Start-Process -FilePath $exe -ArgumentList "/install", "/quiet", "/norestart" -Verb RunAs -Wait -PassThru }
  catch { Fail "Visual C++ 구성 요소 설치가 취소됐습니다. 다시 실행하고 확인 창에서 [예]를 눌러 주세요."; return $false }
  # 0 = 설치됨, 1638 = 이미 같은/새 버전, 3010 = 설치됨(재시작 권장)
  if (@(0, 1638, 3010) -contains $p.ExitCode) { Ok "Visual C++ 구성 요소 준비 완료"; return $true }
  Fail ("Visual C++ 구성 요소 설치 실패 (종료 코드 " + $p.ExitCode + ")"); return $false
}
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
function FfmpegOk {
  $ff = Join-Path $BinDir "ffmpeg.exe"; $fp = Join-Path $BinDir "ffprobe.exe"
  if (-not (Test-Path $ff) -or -not (Test-Path $fp)) { return $false }
  $filters = & $ff -hide_banner -filters 2>$null
  return [bool]($filters | Select-String -Pattern '^\s*[A-Z.]+\s+tile\s' -Quiet)
}

$os = Get-CimInstance Win32_OperatingSystem
$arch = $env:PROCESSOR_ARCHITECTURE
if ($env:PROCESSOR_ARCHITEW6432) { $arch = $env:PROCESSOR_ARCHITEW6432 }
Write-Host ("설치 시작: {0}  ({1} build {2}, {3})" -f (Get-Date -Format "yyyy-MM-dd HH:mm:ss"), $os.Caption, $os.BuildNumber, $arch)
Write-Host "설치 도우미 위치: $SetupDir"
Write-Host "설치 폴더: $ToolsDir"
if ($arch -eq "ARM64") {
  $NodeArch = "win-arm64"; $GitPattern = "PortableGit-*-arm64.7z.exe"
  Warn "ARM 기반 Windows 입니다. 음성 인식 패키지가 ARM용으로 제공되지 않아 일부 단계가 실패할 수 있습니다."
} elseif ($arch -eq "AMD64") {
  $NodeArch = "win-x64"; $GitPattern = "PortableGit-*-64-bit.7z.exe"
} else {
  Fail "64비트 Windows 가 필요합니다. (감지: $arch)"; Stop-Transcript | Out-Null; exit 1
}
if ([int]$os.BuildNumber -lt 17763) {
  Fail "Windows 10 버전 1809 (build 17763) 이상이 필요합니다. 현재 build $($os.BuildNumber)"; Stop-Transcript | Out-Null; exit 1
}

# ---------------------------------------------------------------------
Step 1 "인터넷 연결 확인"
try {
  Invoke-WebRequest -Uri "https://nodejs.org/dist/$NodeLine/SHASUMS256.txt" -UseBasicParsing -TimeoutSec 20 | Out-Null
  Ok "nodejs.org 접속 확인"
} catch {
  Fail "인터넷에 연결되지 않았거나 다운로드가 차단되어 있습니다 (nodejs.org)"; Stop-Transcript | Out-Null; exit 1
}

# ---------------------------------------------------------------------
Step 2 "Node.js LTS (공식 배포판, 약 30MB)"
$NodeExe = Join-Path $NodeDir "node.exe"
$nodeOk = $false
if (Test-Path $NodeExe) { & $NodeExe -v 2>$null | Out-Null; $nodeOk = ($LASTEXITCODE -eq 0) }
if ($nodeOk) {
  Ok ("이미 설치됨: node " + (& $NodeExe -v) + ", npm " + (& (Join-Path $NodeDir "npm.cmd") -v))
} else {
  $shas = (Invoke-WebRequest -Uri "https://nodejs.org/dist/$NodeLine/SHASUMS256.txt" -UseBasicParsing).Content -split "`n"
  $line = $shas | Where-Object { $_ -match "node-v[0-9.]+-$NodeArch\.zip" } | Select-Object -First 1
  if (-not $line) {
    Fail "Node.js 파일 목록에서 $NodeArch 용 zip 을 찾지 못했습니다"
  } else {
    $nodeSha = ($line -split "\s+")[0]; $nodeZip = ($line -split "\s+")[1]
    $zipPath = Join-Path $DlDir $nodeZip
    Write-Host "  다운로드: $nodeZip"
    if (-not (Download "https://nodejs.org/dist/$NodeLine/$nodeZip" $zipPath)) {
      Fail "Node.js 다운로드 실패 (https://nodejs.org/dist/$NodeLine/)"
    } elseif ((Sha256 $zipPath) -ne $nodeSha) {
      Fail "Node.js 파일 검증(SHA256) 실패 - 다시 실행해 주세요"
    } else {
      $tmp = Join-Path $DlDir "node-tmp"
      if (Test-Path $tmp) { Remove-Item $tmp -Recurse -Force }
      Expand-Archive -Path $zipPath -DestinationPath $tmp -Force
      $inner = Get-ChildItem $tmp -Directory | Select-Object -First 1
      if (Test-Path $NodeDir) { Remove-Item $NodeDir -Recurse -Force }
      Move-Item $inner.FullName $NodeDir
      & $NodeExe -v 2>$null | Out-Null
      if ($LASTEXITCODE -eq 0) { Ok ("설치 완료: node " + (& $NodeExe -v) + ", npm " + (& (Join-Path $NodeDir "npm.cmd") -v) + " -> $NodeDir") }
      else { Fail "Node.js 압축 해제 후 실행 실패" }
    }
  }
}

# ---------------------------------------------------------------------
Step 3 "ffmpeg · ffprobe (gyan.dev 정식 빌드, 약 115MB)"
if (FfmpegOk) {
  Ok ("이미 설치됨: " + (((& (Join-Path $BinDir "ffmpeg.exe") -version 2>$null | Select-Object -First 1) -split " ")[0..2] -join " "))
} else {
  $ffZip = Join-Path $DlDir "ffmpeg.zip"
  $ffTmp = Join-Path $DlDir "ffmpeg-tmp"
  $got = $false
  Write-Host "  다운로드: ffmpeg-release-essentials.zip (해외 서버라 느릴 수 있어요. 너무 느리면 자동으로 예비 서버로 넘어가요)"
  if (Download "https://www.gyan.dev/ffmpeg/builds/ffmpeg-release-essentials.zip" $ffZip 200000 900) {
    try {
      $want = ((Invoke-WebRequest -Uri "https://www.gyan.dev/ffmpeg/builds/ffmpeg-release-essentials.zip.sha256" -UseBasicParsing).Content.Trim() -split "\s+")[0].ToLower()
      if ($want -and ((Sha256 $ffZip) -ne $want)) { Warn "gyan.dev 파일 검증(SHA256) 불일치" } else { $got = $true }
    } catch { $got = $true }
  }
  if (-not $got) {
    Warn "기본 서버가 느리거나 멈춰서 예비 서버(GitHub, 약 200MB)로 다시 받습니다"
    $got = Download "https://github.com/BtbN/FFmpeg-Builds/releases/latest/download/ffmpeg-master-latest-win64-gpl.zip" $ffZip
  }
  if ($got) {
    if (Test-Path $ffTmp) { Remove-Item $ffTmp -Recurse -Force }
    Expand-Archive -Path $ffZip -DestinationPath $ffTmp -Force
    foreach ($b in @("ffmpeg.exe", "ffprobe.exe")) {
      $src = Get-ChildItem $ffTmp -Recurse -Filter $b | Select-Object -First 1
      if ($src) { Copy-Item $src.FullName (Join-Path $BinDir $b) -Force }
    }
  }
  if (FfmpegOk) { Ok ("설치 완료: " + (((& (Join-Path $BinDir "ffmpeg.exe") -version 2>$null | Select-Object -First 1) -split " ")[0..2] -join " ") + " -> $BinDir") }
  else { Fail "ffmpeg/ffprobe 설치 실패 (실행되지 않거나 tile 필터가 없음)" }
}

# ---------------------------------------------------------------------
Step 4 "Git Bash (휴대용 Git, 약 60MB - Claude Code 의 명령 실행용)"
$BashExe = Join-Path $GitDir "bin\bash.exe"
if (Test-Path $BashExe) {
  Ok ("이미 설치됨: " + (& (Join-Path $GitDir "cmd\git.exe") --version 2>$null))
} else {
  try {
    $assetName = $null; $assetUrl = $null
    try {   # 1차: GitHub API 로 최신 파일 이름 조회
      $rel = Invoke-RestMethod -Uri "https://api.github.com/repos/git-for-windows/git/releases/latest" -UseBasicParsing
      $asset = $rel.assets | Where-Object { $_.name -like $GitPattern } | Select-Object -First 1
      if ($asset) { $assetName = $asset.name; $assetUrl = $asset.browser_download_url }
    } catch { }
    if (-not $assetName) {   # 2차: releases/latest 리다이렉트의 태그명으로 파일 이름 조립 (API 제한 시)
      $loc = $null
      try {
        $r = Invoke-WebRequest -Uri "https://github.com/git-for-windows/git/releases/latest" -UseBasicParsing -MaximumRedirection 0 -ErrorAction Stop
        $loc = "$($r.Headers.Location)"; if (-not $loc -and $r.BaseResponse) { $loc = $r.BaseResponse.ResponseUri.AbsoluteUri }
      } catch { try { $loc = "$($_.Exception.Response.Headers['Location'])" } catch { } }
      if ($loc -match "tag/v([0-9.]+)\.windows\.([0-9]+)") {
        $ver = $Matches[1]; if ([int]$Matches[2] -gt 1) { $ver = "$ver.$($Matches[2])" }
        $assetName = $GitPattern.Replace("*", $ver)
        $assetUrl = "https://github.com/git-for-windows/git/releases/download/v$($Matches[1]).windows.$($Matches[2])/$assetName"
      }
    }
    if (-not $assetName) { throw "PortableGit 파일을 찾지 못함" }
    $gitExe = Join-Path $DlDir $assetName
    Write-Host ("  다운로드: {0}" -f $assetName)
    if (-not (Download $assetUrl $gitExe)) { throw "다운로드 실패" }
    if (Test-Path $GitDir) { Remove-Item $GitDir -Recurse -Force }
    # 7-Zip 자동 압축 해제 파일: -o<폴더> -y 로 조용히 풀림
    $p = Start-Process -FilePath $gitExe -ArgumentList @("-o`"$GitDir`"", "-y") -Wait -PassThru
    if (-not (Test-Path $BashExe)) { throw "압축 해제 실패 (exit $($p.ExitCode))" }
    # 휴대용 Git 의 1회성 마무리 설정 (post-install.bat) 을 미리 실행
    if (Test-Path (Join-Path $GitDir "post-install.bat")) {
      try { Start-Process -FilePath (Join-Path $GitDir "git-cmd.exe") -ArgumentList @("--no-cd", "--command=cmd.exe", "/c", "exit") -Wait -WindowStyle Hidden } catch { }
    }
    Ok ("설치 완료: " + (& (Join-Path $GitDir "cmd\git.exe") --version 2>$null) + " -> $GitDir")
  } catch { Fail "휴대용 Git 설치 실패: $_" }
}
if (Test-Path $BashExe) {
  [Environment]::SetEnvironmentVariable("CLAUDE_CODE_GIT_BASH_PATH", $BashExe, "User")
  $env:CLAUDE_CODE_GIT_BASH_PATH = $BashExe
  Ok "Claude Code 가 이 Git Bash 를 쓰도록 등록 (CLAUDE_CODE_GIT_BASH_PATH)"
}

# ---------------------------------------------------------------------
Step 5 "Python 3.12 + 가상환경 + 음성 합성/검증 패키지 (약 1GB, 3~5분)"
$Uv = Join-Path $BinDir "uv.exe"
if (-not (Test-Path $Uv)) {
  try {
    $env:UV_UNMANAGED_INSTALL = $BinDir
    Invoke-RestMethod https://astral.sh/uv/install.ps1 | Invoke-Expression
    Remove-Item Env:\UV_UNMANAGED_INSTALL -ErrorAction SilentlyContinue
  } catch { }
  if (Test-Path $Uv) { Ok ("uv(파이썬 설치 도구) 준비: " + (& $Uv --version)) } else { Fail "uv 다운로드 실패 (https://astral.sh/uv/install.ps1)" }
}
if (Test-Path $Uv) {
  if (Run $Uv @("python", "install", "3.12", "--no-progress")) { Ok "Python 3.12 준비 -> $env:UV_PYTHON_INSTALL_DIR" }
  else { Fail "Python 3.12 다운로드 실패 (uv python install 3.12)" }
  if (-not (Test-Path $VenvPy)) { Run $Uv @("venv", "--seed", "--python", "3.12", $VenvDir) | Out-Null }
  if (Test-Path $VenvPy) {
    if (Run $Uv @("pip", "install", "--python", $VenvPy, "-r", (Join-Path $CommonDir "requirements.txt"))) {
      Ok ("패키지 설치 완료 -> $VenvDir (" + (& $VenvPy --version) + ")")
      if (Test-VoiceEngine) { Ok "음성 엔진 실행 확인" }
      elseif ((Install-VCRedist) -and (Test-VoiceEngine)) { Ok "음성 엔진 실행 확인 (Visual C++ 구성 요소 설치 후)" }
      else { Fail "음성 엔진(onnxruntime)을 실행할 수 없습니다. 이 창을 캡처해서 보내주세요." }
    } else { Fail "Python 패키지 설치 실패 (uv pip install -r common\requirements.txt)" }
  } else { Fail "Python 가상환경을 만들지 못했습니다 (uv venv)" }
}

# ---------------------------------------------------------------------
Step 6 "Claude Code (터미널용, 선택 - AI 앱을 쓰면 없어도 됩니다)"
if ($env:SKIP_CLAUDE -eq "1") {
  Warn "건너뜀 (SKIP_CLAUDE=1)"
} elseif (Has claude) {
  Ok ("이미 설치됨: " + (claude --version 2>$null | Select-Object -First 1))
} else {
  try {
    Invoke-RestMethod https://claude.ai/install.ps1 | Invoke-Expression
    $env:Path = "$env:USERPROFILE\.local\bin;" + $env:Path
    if (Has claude) { Ok "설치 완료 (로그인은 강의 안내에 따라 진행)" }
    else { Warn "설치는 끝났지만 claude 명령을 아직 찾지 못했습니다. 새 터미널에서 다시 확인하세요." }
  } catch { Warn "Claude Code(선택) 설치 실패 - AI 앱으로 실습하면 필요 없습니다: $_" }
}

# ---------------------------------------------------------------------
Step 7 "음성 모델 다운로드 + 시험 합성/인식 (약 850MB, 5~10분)"
$TestWav = Join-Path $ToolsDir "test-voice.wav"
if (Test-Path $VenvPy) {
  & $VenvPy (Join-Path $CommonDir "warmup_tts.py") $TestWav
  if ($LASTEXITCODE -eq 0) {
    Ok "Supertonic 음성 합성 성공"
    & $VenvPy (Join-Path $CommonDir "warmup_asr.py") $TestWav
    if ($LASTEXITCODE -eq 0) { Ok "faster-whisper 음성 인식 성공" } else { Fail "faster-whisper 시험 인식 실패" }
  } else { Fail "Supertonic 시험 합성 실패" }
} else { Fail "가상환경이 없어 모델 단계를 건너뜀" }

# ---------------------------------------------------------------------
Step 8 "영상 프로젝트(Remotion) 패키지 + 렌더용 브라우저 + 시험 렌더 (약 1.5GB, 5~15분)"
$ProjectDir = Find-Project
if (-not (Test-Path $NodeExe)) {
  Fail "Node.js 가 없어 프로젝트 단계를 건너뜀"; $ProjectDir = ""
} elseif ($ProjectDir) {
  Write-Host "  프로젝트 폴더: $ProjectDir"
  Push-Location $ProjectDir
  $npm = Join-Path $NodeDir "npm.cmd"; $npx = Join-Path $NodeDir "npx.cmd"
  if (Test-Path "package-lock.json") { & $npm ci --no-audit --no-fund } else { & $npm install --no-audit --no-fund }
  if ($LASTEXITCODE -eq 0) { Ok "npm 패키지 설치 완료" } else { Fail "npm 패키지 설치 실패 (프로젝트 폴더에서 npm install)" }
  & $npx remotion browser ensure
  if ($LASTEXITCODE -eq 0) { Ok "렌더용 브라우저 준비 완료" } else { Fail "Remotion 브라우저 다운로드 실패 (npx remotion browser ensure)" }
  # 2초짜리 확인용 영상을 실제로 렌더해 본다 (설치가 끝까지 동작하는지 가장 확실한 검사)
  $testMp4 = Join-Path $ToolsDir "test-render.mp4"
  # 느린 PC 에서는 오래 걸려 멈춘 것처럼 보인다 -> 30초마다 진행 안내, 20분 넘으면 끊고 안전 모드로 한 번 더.
  function Render-Test([string[]]$extra) {
    if (Test-Path $testMp4) { Remove-Item $testMp4 -Force }
    $argv = @("remotion", "render", "src/index.ts", "TestShort", (Q $testMp4), "--log=warn") + $extra
    $p = Start-Process -FilePath $npx -ArgumentList $argv -NoNewWindow -PassThru -WorkingDirectory $ProjectDir
    $null = $p.Handle   # 끝난 뒤 ExitCode 를 읽기 위해 핸들을 잡아 둔다
    $t0 = Get-Date
    while (-not $p.WaitForExit(30000)) {
      $min = [int][math]::Floor(((Get-Date) - $t0).TotalMinutes)
      Write-Host ("  ... 시험 영상을 만드는 중이에요 (" + $min + "분째). 컴퓨터에 따라 오래 걸릴 수 있어요. 창을 닫지 마세요.") -ForegroundColor Yellow
      if ($min -ge 20) { & taskkill.exe /PID $p.Id /T /F 2>$null | Out-Null; return $false }
    }
    $codec = if (Test-Path $testMp4) { & (Join-Path $BinDir "ffprobe.exe") -v error -select_streams v:0 -show_entries stream=codec_name -of csv=p=0 $testMp4 2>$null } else { "" }
    return ($p.ExitCode -eq 0 -and "$codec" -match "h264")
  }
  Write-Host "  시험 영상(2초)을 만들어 봅니다. 보통 1~5분, 느린 컴퓨터는 10분 넘게 걸릴 수 있어요."
  if (Render-Test @()) { Ok "시험 렌더 완료: $testMp4" }
  else {
    Warn "시험 렌더가 끝나지 않아 안전 모드(그래픽 카드 사용 안 함)로 한 번 더 만듭니다."
    if (Render-Test @("--gl=swangle", "--concurrency=1")) { Ok "시험 렌더 완료 (안전 모드): $testMp4" }
    else { Fail "시험 렌더 실패 (npx remotion render src/index.ts TestShort)" }
  }
  Pop-Location
} else {
  Warn "프로젝트 폴더(package.json)를 찾지 못해 건너뜁니다."
  Warn "다운로드한 zip 을 다시 압축 해제한 뒤(권장 위치: $env:USERPROFILE\issuekiller) install.bat 을 다시 실행하세요."
  $ProjectDir = ""
}

# ---------------------------------------------------------------------
Step 9 "사용자 PATH 등록 + 설치 결과 확인"
$userPath = [Environment]::GetEnvironmentVariable("Path", "User")
if (-not $userPath) { $userPath = "" }
$parts = @($userPath -split ";" | Where-Object { $_ -ne "" })
$add = @($BinDir, $NodeDir, (Join-Path $GitDir "cmd"), (Join-Path $env:USERPROFILE ".local\bin"))
$new = @($add | Where-Object { $parts -notcontains $_ }) + $parts
if (($new -join ";") -ne ($parts -join ";")) {
  [Environment]::SetEnvironmentVariable("Path", ($new -join ";"), "User")
  Ok "사용자 PATH 에 등록: $BinDir ; $NodeDir ; $GitDir\cmd"
} else { Ok "사용자 PATH 이미 등록됨" }
Remove-Item $DlDir -Recurse -Force -ErrorAction SilentlyContinue
@{
  platform     = "windows"
  tools_dir    = $ToolsDir
  venv_python  = $VenvPy
  node         = $NodeExe
  ffmpeg       = (Join-Path $BinDir "ffmpeg.exe")
  ffprobe      = (Join-Path $BinDir "ffprobe.exe")
  git_bash     = $BashExe
  project_dir  = $ProjectDir
  test_render  = (Join-Path $ToolsDir "test-render.mp4")
  installed_at = (Get-Date -Format "yyyy-MM-ddTHH:mm:ss")
} | ConvertTo-Json | ForEach-Object { [IO.File]::WriteAllText((Join-Path $ToolsDir "env.json"), $_, (New-Object System.Text.UTF8Encoding($false))) }
& (Join-Path $SetupDir "windows\check.ps1")

Write-Host ""
if ($script:Failed.Count -eq 0) {
  Write-Host "설치가 모두 끝났습니다." -ForegroundColor Green
} else {
  Write-Host "다음 항목이 실패했습니다:" -ForegroundColor Red
  $script:Failed | ForEach-Object { Write-Host "  - $_" }
  Write-Host "이 창을 캡처해서 보내주세요. 로그: $ToolsDir\install-windows.log"
}
Write-Host ""
Write-Host "설치 끝. 강의 날: 쓰시는 AI 앱(ChatGPT·Claude·Gemini용 Antigravity)을 열고 홈 폴더의 issuekiller 폴더를 여세요."
Stop-Transcript | Out-Null
