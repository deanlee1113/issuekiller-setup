# =====================================================================
#  이슈킬러 쇼츠 제작 환경 · Windows 한 줄 설치  (PowerShell 창에 붙여넣기)
#
#    irm https://raw.githubusercontent.com/deanlee1113/issuekiller-setup/main/get.ps1 | iex
#
#  하는 일
#    1) 프로젝트 폴더를 내려받아  %USERPROFILE%\issuekiller  에 놓는다
#    2) setup\windows\install.ps1 을 실행한다 (10~30분)
#  관리자 권한 · winget 없이, %USERPROFILE%\issuekiller-tools 한 폴더에만 설치합니다.
#  여러 번 실행해도 안전합니다. 이미 있는 폴더는 지우지 않습니다.
#  이미 설치한 폴더에 다시 실행하면 설치 도우미와 강의 키트 파일(스킬·CLAUDE.md·화면 템플릿 등,
#  setup\common\kit-files.txt 목록)만 최신으로 바꾸고, 수강생이 만든 영상·채널 설정은 건드리지 않습니다.
# =====================================================================

# 강의 키트 파일 갱신 (get.sh 의 sync_kit 과 같은 규칙)
#   kit  : 최신으로 교체 (내용이 다르면 원래 파일을 $Bak 에 먼저 복사)
#   seed : 없을 때만 넣음 (수강생이 고친 채널 설정·영상 등록부는 그대로)
function Sync-IssueKillerKit([string]$Src, [string]$Dest, [string]$Bak) {
  $list = Join-Path $Src "setup\common\kit-files.txt"
  if (-not (Test-Path -LiteralPath $list)) { return }
  $added = 0; $updated = 0
  foreach ($line in (Get-Content -LiteralPath $list -Encoding UTF8)) {
    $parts = @($line.Trim() -split "\s+")
    if ($parts.Count -lt 2 -or ($parts[0] -ne "kit" -and $parts[0] -ne "seed")) { continue }
    $kind = $parts[0]
    $item = Join-Path $Src ($parts[1] -replace "/", "\")
    if (-not (Test-Path -LiteralPath $item)) { continue }
    if (Test-Path -LiteralPath $item -PathType Container) {
      $files = @(Get-ChildItem -LiteralPath $item -Recurse -File -Force | Where-Object { $_.Name -ne ".DS_Store" -and $_.FullName -notmatch "\\__pycache__\\" })
    } else {
      $files = @(Get-Item -LiteralPath $item -Force)
    }
    foreach ($f in $files) {
      $rel = $f.FullName.Substring($Src.Length).TrimStart("\", "/")
      $target = Join-Path $Dest $rel
      if (Test-Path -LiteralPath $target) {
        if ($kind -eq "seed") { continue }
        if ((Get-FileHash -LiteralPath $target).Hash -eq (Get-FileHash -LiteralPath $f.FullName).Hash) { continue }
        $saved = Join-Path $Bak $rel
        New-Item -ItemType Directory -Force -Path (Split-Path -Parent $saved) | Out-Null
        Copy-Item -LiteralPath $target -Destination $saved -Force
        $updated++
      } else {
        $added++
      }
      New-Item -ItemType Directory -Force -Path (Split-Path -Parent $target) | Out-Null
      Copy-Item -LiteralPath $f.FullName -Destination $target -Force
    }
  }
  Write-Host "   강의 키트 파일: 새로 추가 $($added)개, 최신으로 교체 $($updated)개"
  if ($updated -gt 0) { Write-Host "   (바뀐 파일의 이전 내용은 $Bak 에 보관했습니다)" }
}

function Install-IssueKiller {
  $ErrorActionPreference = "Stop"
  $ProgressPreference = "SilentlyContinue"   # Invoke-WebRequest 진행 표시줄 끄기 (켜 두면 매우 느림)
  try { [Console]::OutputEncoding = [System.Text.Encoding]::UTF8 } catch {}
  try { chcp 65001 | Out-Null } catch {}
  try { [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 } catch {}

  $Repo   = if ($env:ISSUEKILLER_REPO)    { $env:ISSUEKILLER_REPO }    else { "deanlee1113/issuekiller-setup" }
  $Ref    = if ($env:ISSUEKILLER_REF)     { $env:ISSUEKILLER_REF }     else { "main" }
  $ZipUrl = if ($env:ISSUEKILLER_ZIP_URL) { $env:ISSUEKILLER_ZIP_URL } else { "https://github.com/$Repo/archive/refs/heads/$Ref.zip" }
  $Dest   = if ($env:ISSUEKILLER_PROJECT) { $env:ISSUEKILLER_PROJECT } else { Join-Path $env:USERPROFILE "issuekiller" }

  Write-Host ""
  Write-Host "이슈킬러 설치 도우미 v3 · Windows 한 줄 설치" -ForegroundColor White
  if ($env:PROCESSOR_ARCHITECTURE -ne "AMD64") {
    Write-Host "[XX] 64비트 Intel/AMD Windows 만 지원합니다. (이 컴퓨터: $env:PROCESSOR_ARCHITECTURE)" -ForegroundColor Red
    return
  }

  $tmp = Join-Path ([IO.Path]::GetTempPath()) ("issuekiller-get-" + [Guid]::NewGuid().ToString("N").Substring(0, 8))
  New-Item -ItemType Directory -Force -Path $tmp | Out-Null
  try {
    Write-Host "1) 프로젝트 폴더 내려받는 중..."
    $zip = Join-Path $tmp "kit.zip"
    try {
      Invoke-WebRequest -Uri $ZipUrl -OutFile $zip -UseBasicParsing
    } catch {
      Write-Host "[XX] 내려받기 실패: $ZipUrl" -ForegroundColor Red
      Write-Host "     인터넷 연결을 확인한 뒤 같은 명령을 다시 실행하세요. ($($_.Exception.Message))" -ForegroundColor Red
      return
    }
    $x = Join-Path $tmp "x"
    Expand-Archive -LiteralPath $zip -DestinationPath $x -Force
    $top = Get-ChildItem -LiteralPath $x -Directory | Select-Object -First 1
    if (-not $top -or -not (Test-Path (Join-Path $top.FullName "setup\windows\install.ps1"))) {
      Write-Host "[XX] 받은 파일 안에 설치 도우미가 없습니다. 강사에게 알려주세요." -ForegroundColor Red
      return
    }

    if (Test-Path (Join-Path $Dest "package.json")) {
      # 이미 프로젝트 폴더가 있으면 그대로 두고 설치 도우미와 강의 키트 파일만 최신으로 바꾼다.
      # 수강생이 만든 영상(src\*Composition.tsx, public\, output\)과 channel.json 은 건드리지 않는다.
      Write-Host "2) 기존 폴더 유지: $Dest (설치 도우미·강의 키트 파일만 최신으로 교체)"
      $setupDir = Join-Path $Dest "setup"
      New-Item -ItemType Directory -Force -Path $setupDir | Out-Null
      Copy-Item -Path (Join-Path $top.FullName "setup\*") -Destination $setupDir -Recurse -Force
      Sync-IssueKillerKit $top.FullName $Dest ("$Dest-backup-" + (Get-Date -Format "yyyyMMdd-HHmmss"))
    } elseif ((Test-Path $Dest) -and (Get-ChildItem -LiteralPath $Dest -Force | Select-Object -First 1)) {
      # 다른 내용이 든 폴더는 지우지 않고 이름을 바꿔 둔다.
      $old = "$Dest-old-" + (Get-Date -Format "yyyyMMdd-HHmmss")
      Write-Host "2) $Dest 에 다른 내용이 있어 $old 로 옮기고 새로 만듭니다."
      Move-Item -LiteralPath $Dest -Destination $old
      Copy-Item -LiteralPath $top.FullName -Destination $Dest -Recurse
    } else {
      Write-Host "2) 프로젝트 폴더 만드는 중: $Dest"
      if (Test-Path $Dest) { Remove-Item -LiteralPath $Dest -Force }   # 빈 폴더
      Copy-Item -LiteralPath $top.FullName -Destination $Dest -Recurse
    }
  } finally {
    Remove-Item -LiteralPath $tmp -Recurse -Force -ErrorAction SilentlyContinue
  }

  Write-Host "3) 설치 도우미 실행 (10~30분, 관리자 권한은 묻지 않습니다)"
  Write-Host ""
  & powershell.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $Dest "setup\windows\install.ps1")
}

Install-IssueKiller
