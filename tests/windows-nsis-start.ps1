#requires -version 2.0
# Actual tiny NSIS launch-failure regression using the exact production macro.
$ErrorActionPreference='Stop'
$repo=Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
. (Join-Path $repo 'packaging/windows/Install-Queue-Win7.ps1')
$StateDir=Join-Path $env:TEMP ('foison-matrix-nsis-start-'+[Guid]::NewGuid().ToString('N'))
$LogDirectory='';$RunId='nsis-launch';InitializeLogging
$script=[IO.File]::ReadAllText((Join-Path $repo 'packaging/windows/FoisonC24-Setup.nsi'))
$macro='!macro CheckedExec PREFIX COMMAND'+$script.Split(@('!macro CheckedExec PREFIX COMMAND'),[StringSplitOptions]::None)[1].Split(@('!macroend'),[StringSplitOptions]::None)[0]+'!macroend'
$template=@'
Unicode true
!include LogicLib.nsh
Name "Foison NSIS test"
OutFile "missing-child.exe"
RequestExecutionLevel admin
SilentInstall silent
!MACRO_BODY!
Function Fail
  FileOpen $1 "$EXEDIR\failure.txt" w
  FileWriteUTF16LE /BOM $1 "RunId=nsis-launch Stage=EXECWAIT_START ExitCode=$0 Não foi possível executar o processo."
  FileClose $1
  SetErrorLevel $0
  Abort
FunctionEnd
Section
  ; Simulate an earlier successful child; launch failure MUST NOT reuse zero.
  StrCpy $0 0
  !insertmacro CheckedExec "" '"$EXEDIR\nonexistent-child.exe"'
  FileOpen $1 "$EXEDIR\FALSE_SUCCESS.txt" w
  FileClose $1
SectionEnd
'@
$nsi=Join-Path $StateDir 'missing-child.nsi'
[IO.File]::WriteAllText($nsi,$template.Replace('!MACRO_BODY!',$macro),[Text.Encoding]::UTF8)
$compiler=Join-Path ${env:ProgramFiles(x86)} 'NSIS/makensis.exe'
if((ProcessRun $compiler ('/WX /INPUTCHARSET UTF8 "'+$nsi+'"')) -ne 0){throw 'NSIS fixture compiler failed'}
$code=ProcessRun (Join-Path $StateDir 'missing-child.exe') '/S'
if($code -ne 9009 -or (Test-Path (Join-Path $StateDir 'FALSE_SUCCESS.txt'))){throw 'NSIS launch failure falsely succeeded or lost error code'}
$text=[IO.File]::ReadAllText((Join-Path $StateDir 'failure.txt'))
if(-not $text.Contains('ExitCode=9009 Não foi possível executar o processo.')){throw 'NSIS startup failure evidence/Unicode lost'}
Write-Host ('PASS actual NSIS missing child ExitCode9009, no false success, UTF16 message. Evidence='+$StateDir)
