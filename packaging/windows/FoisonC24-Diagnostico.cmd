@echo off
setlocal
title Foison C24 - Diagnostico da captura
if not exist "%~dp0FoisonC24Diagnostic.exe" (
  echo Foison C24 Diagnostic nao encontrado em "%~dp0".
  echo Reinstale o Foison C24 Print Bridge ou abra um chamado com esta mensagem.
  pause
  exit /b 2
)
"%~dp0FoisonC24Diagnostic.exe" --guided-diagnosis
set "BRIDGE_EXIT=%ERRORLEVEL%"
if not "%BRIDGE_EXIT%"=="0" (
  echo O diagnostico terminou com codigo %BRIDGE_EXIT%.
  echo Consulte C:\ProgramData\FoisonC24\Logs ou %%TEMP%%\FoisonC24\Logs.
  pause
)
exit /b %BRIDGE_EXIT%
