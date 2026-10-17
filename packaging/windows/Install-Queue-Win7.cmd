@echo off
setlocal EnableExtensions DisableDelayedExpansion
rem ASCII bootstrap. This log uses the active OEM codepage; never append it to UTF-8 logs.
set "MODE=install"
if not "%~1"=="" set "MODE=%~1"
set "QUIET=0"
if /i "%~2"=="--noninteractive" set "QUIET=1"
set "RUN_ID=b%RANDOM%-%RANDOM%-%RANDOM%"
if not "%~3"=="" set "RUN_ID=%~3"
rem Never accept arbitrary path characters in the correlation identifier.
for /f "delims=abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_-" %%A in ("%RUN_ID%") do set "RUN_ID=b%RANDOM%-%RANDOM%-%RANDOM%"
set "LOG_DIR=%ProgramData%\FoisonC24\Logs"
if not exist "%LOG_DIR%" mkdir "%LOG_DIR%" >nul 2>&1
set "CMD_LOG=%LOG_DIR%\install-%RUN_ID%-cmd.log"
(echo [%DATE% %TIME%] [INFO] [%RUN_ID%] [cmd] BEGIN bootstrap OEM log) >>"%CMD_LOG%" 2>nul
if not errorlevel 1 goto log_ready
set "LOG_DIR=%TEMP%\FoisonC24\Logs"
if not exist "%LOG_DIR%" mkdir "%LOG_DIR%" >nul 2>&1
set "CMD_LOG=%LOG_DIR%\install-%RUN_ID%-cmd.log"
(echo [%DATE% %TIME%] [WARN] [%RUN_ID%] [cmd] ProgramData unavailable; TEMP fallback) >>"%CMD_LOG%" 2>nul
if not errorlevel 1 goto log_ready
echo ERRO: Nao foi possivel gravar diagnostico em ProgramData nem TEMP.
set "BRIDGE_EXIT=73"
goto finish
:log_ready
forfiles /P "%LOG_DIR%" /M install-* /D -90 /C "cmd /c del /q @path" >nul 2>&1
>>"%CMD_LOG%" echo Script=%~f0
>>"%CMD_LOG%" echo WorkingDirectory=%CD%
>>"%CMD_LOG%" echo OS=%OS% Architecture=%PROCESSOR_ARCHITECTURE% NativeArchitecture=%PROCESSOR_ARCHITEW6432%
ver >>"%CMD_LOG%" 2>&1
chcp >>"%CMD_LOG%" 2>&1
set "PS=%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe"
if exist "%SystemRoot%\Sysnative\WindowsPowerShell\v1.0\powershell.exe" set "PS=%SystemRoot%\Sysnative\WindowsPowerShell\v1.0\powershell.exe"
>>"%CMD_LOG%" echo PS1=%~dp0Install-Queue-Win7.ps1
if not exist "%~dp0Install-Queue-Win7.ps1" goto missing_script
>>"%CMD_LOG%" echo PS1Exists=true
if not exist "%PS%" goto missing_powershell
>>"%CMD_LOG%" echo PowerShellExists=true
if /i "%MODE%"=="install" goto invoke
if /i "%MODE%"=="verify" goto invoke
if /i "%MODE%"=="uninstall" goto invoke
if /i "%MODE%"=="capture-test" goto invoke
set "BRIDGE_EXIT=64"
>>"%CMD_LOG%" echo [ERROR] Invalid operation. Expected install, verify or uninstall.
goto report
:invoke
set "FOISON_RUN_ID=%RUN_ID%"
>>"%CMD_LOG%" echo Command="%PS%" -NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass -File Install-Queue-Win7.ps1 %MODE% [correlation/log directory]
rem Separate raw streams retain syntax/startup errors even before PS logging is initialized.
"%PS%" -NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass -File "%~dp0Install-Queue-Win7.ps1" -Operation "%MODE%" -RunId "%RUN_ID%" -LogDirectory "%LOG_DIR%" 1>>"%LOG_DIR%\install-%RUN_ID%-stdout.raw" 2>>"%LOG_DIR%\install-%RUN_ID%-stderr.raw"
set "BRIDGE_EXIT=%ERRORLEVEL%"
>>"%CMD_LOG%" echo [%DATE% %TIME%] PowerShellExitCode=%BRIDGE_EXIT%
>>"%CMD_LOG%" echo Stdout=install-%RUN_ID%-stdout.raw
>>"%CMD_LOG%" echo Stderr=install-%RUN_ID%-stderr.raw
goto report
:missing_script
set "BRIDGE_EXIT=66"
>>"%CMD_LOG%" echo [FATAL] PS1Exists=false. Installation script is missing.
goto report
:missing_powershell
set "BRIDGE_EXIT=69"
>>"%CMD_LOG%" echo [FATAL] PowerShellExists=false. Windows PowerShell could not start.
:report
>>"%CMD_LOG%" echo [%DATE% %TIME%] [INFO] [%RUN_ID%] [cmd] END ExitCode=%BRIDGE_EXIT%
rem Latest pointer is ASCII/OEM, separate from the PowerShell UTF-8 pointer.
>"%LOG_DIR%\installation-latest-cmd.log" echo %CMD_LOG%
echo Foison C24: codigo %BRIDGE_EXIT%. Diagnostico: "%CMD_LOG%"
if "%BRIDGE_EXIT%"=="0" goto finish
if exist "%LOG_DIR%\install-%RUN_ID%-summary.txt" type "%LOG_DIR%\install-%RUN_ID%-summary.txt"
echo ERRO: A operacao nao foi concluida. Compartilhe a pasta de logs com o desenvolvedor.
if exist "%LOG_DIR%\install-%RUN_ID%-stderr.raw" type "%LOG_DIR%\install-%RUN_ID%-stderr.raw"
:finish
if "%QUIET%"=="1" goto return
if "%BRIDGE_EXIT%"=="0" goto return
echo Pressione uma tecla para fechar. Nao envie comandos a plotter.
pause >nul
:return
exit /b %BRIDGE_EXIT%
