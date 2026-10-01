@echo off
rem IssueKiller Python runner for Windows (PowerShell and cmd).
rem   usage (in the project folder):  scripts\py.cmd <script.py> [args...]
rem                                   scripts\py.cmd scripts/tool.py ffmpeg [args...]
rem Runs %USERPROFILE%\issuekiller-tools\venv\Scripts\python.exe with the kit tools
rem (ffmpeg, node/npx, portable git) on PATH, so it works even when the AI app
rem did not load the user Path. Mac / Git Bash use scripts/py.sh instead.
setlocal
set "IK_TOOLS=%USERPROFILE%\issuekiller-tools"
set "IK_PY=%IK_TOOLS%\venv\Scripts\python.exe"
set "PATH=%IK_TOOLS%\bin;%IK_TOOLS%\node;%IK_TOOLS%\git\cmd;%PATH%"
set "PYTHONIOENCODING=utf-8"
set "PYTHONUTF8=1"
if not exist "%IK_PY%" goto nopy
"%IK_PY%" %*
exit /b %ERRORLEVEL%

:nopy
echo [issuekiller] Python venv not found: %IK_TOOLS%\venv 1>&2
echo [issuekiller] Run setup\windows\install.bat again. 1>&2
exit /b 127
