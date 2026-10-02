@echo off
cd /d "%~dp0"
powershell -NoProfile -File "%~dp0server.ps1"
pause
