@echo off
setlocal
set "ROOT=%~dp0"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%ROOT%Install-Queue-Win7.ps1" %*
exit /b %ERRORLEVEL%
