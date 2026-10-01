@echo off
chcp 65001 >nul
title IssueKiller Shorts - Install v3 (Windows)
echo Starting IssueKiller install helper v3 (no admin needed)...
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0install.ps1"
echo.
echo Done. You may close this window.
pause
