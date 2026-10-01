# =====================================================================
#  이슈킬러 쇼츠 제작 환경 · Windows 한 줄 설치  (PowerShell 창에 붙여넣기)
#
#    irm https://raw.githubusercontent.com/__GH_REPO__/main/get.ps1 | iex
#
#  하는 일
#    1) 프로젝트 폴더를 내려받아  %USERPROFILE%\issuekiller  에 놓는다
#    2) setup\windows\install.ps1 을 실행한다 (10~30분)
#  관리자 권한 · winget 없이, %USERPROFILE%\issuekiller-tools 한 폴더에만 설치합니다.
#  여러 번 실행해도 안전합니다. 이미 있는 폴더는 지우지 않습니다.
# =====================================================================
function Install-IssueKiller {
  $ErrorActionPreference = "Stop"
  $ProgressPreference = "SilentlyContinue"   # Invoke-WebRequest 진행 표시줄 끄기 (켜 두면 매우 느림)
  try { [Console]::OutputEncoding = [System.Text.Encoding]::UTF8 } catch {}
  try { chcp 65001 | Out-Null } catch {}
  try { [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 } catch {}

  $Repo   = if ($env:ISSUEKILLER_REPO)    { $env:ISSUEKILLER_REPO }    else { "__GH_REPO__" }
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
      # 이미 프로젝트 폴더가 있으면 그대로 두고 설치 스크립트만 최신으로 덮어쓴다.
      Write-Host "2) 기존 폴더 유지: $Dest (설치 도우미만 최신으로 교체)"
      $setupDir = Join-Path $Dest "setup"
      New-Item -ItemType Directory -Force -Path $setupDir | Out-Null
      Copy-Item -Path (Join-Path $top.FullName "setup\*") -Destination $setupDir -Recurse -Force
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
