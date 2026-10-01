@echo off
chcp 65001 >nul
title IssueKiller Shorts - Check v3 (Windows)
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0check.ps1"
echo.
pause
