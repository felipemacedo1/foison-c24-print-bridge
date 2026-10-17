Unicode true
!include MUI2.nsh
!include LogicLib.nsh
!include x64.nsh
!include WinVer.nsh
!include FileFunc.nsh
!include "version.nsh"
Name "Foison C24 Print Bridge ${BRIDGE_VERSION} — teste acompanhado"
!ifndef OUTFILE
!define OUTFILE "FoisonC24-Setup-Win7-x64.exe"
!endif
OutFile "${OUTFILE}"
VIProductVersion "${BRIDGE_QUAD}"
VIFileVersion "${BRIDGE_QUAD}"
VIAddVersionKey /LANG=1046 "ProductName" "Foison C24 Print Bridge"
VIAddVersionKey /LANG=1046 "ProductVersion" "${BRIDGE_VERSION}"
VIAddVersionKey /LANG=1046 "FileVersion" "${BRIDGE_VERSION}"
VIAddVersionKey /LANG=1046 "FileDescription" "Instalador de teste acompanhado — não validado no hardware"
VIAddVersionKey /LANG=1046 "LegalCopyright" "Foison C24 Print Bridge contributors"
InstallDir "$PROGRAMFILES64\Foison C24 Print Bridge"
RequestExecutionLevel admin
SetCompressor zlib
ShowInstDetails show
ShowUninstDetails show
!define MUI_ABORTWARNING
!define MUI_WELCOMEPAGE_TEXT "Configuração da impressora Foison C24.$\r$\n$\r$\nCandidato de teste: Windows 7 SP1 x64. Requer acompanhamento do desenvolvedor. Não é compatibilidade comprovada.$\r$\n$\r$\nCorte físico permanece bloqueado por padrão. FTDI, COM2 e FlexiSIGN não serão reconfigurados."
!insertmacro MUI_PAGE_WELCOME
!insertmacro MUI_PAGE_LICENSE "THIRD-PARTY.txt"
!insertmacro MUI_PAGE_DIRECTORY
!insertmacro MUI_PAGE_INSTFILES
!define MUI_FINISHPAGE_TEXT "Instalação concluída com sucesso.$\r$\nFila, porta, driver e conversão foram verificados neste computador. Imprima o quadrado no CorelDRAW, escala 100%, e abra Foison C24.$\r$\n$\r$\nIsso não comprova CorelDRAW, serial, protocolo nem corte físico. Siga o desenvolvedor antes de qualquer movimento."
!insertmacro MUI_PAGE_FINISH
!insertmacro MUI_UNPAGE_CONFIRM
!insertmacro MUI_UNPAGE_INSTFILES
!insertmacro MUI_UNPAGE_FINISH
!insertmacro MUI_LANGUAGE "PortugueseBR"

Var RunId
Var LogDir
Var LogFile
Var Step
Var FailureCode
Var LogHandle

!macro Logging PREFIX
Function ${PREFIX}InitLog
  SetRegView 64
  SetShellVarContext all
  System::Call 'kernel32::GetTickCount()i.r1'
  System::Call 'kernel32::GetCurrentProcessId()i.r2'
  StrCpy $RunId "n$1-$2"
  StrCpy $LogDir "$APPDATA\FoisonC24\Logs"
  CreateDirectory "$LogDir"
  ClearErrors
  StrCpy $LogFile "$LogDir\install-$RunId-nsis.log"
  FileOpen $LogHandle "$LogFile" a
  ${If} ${Errors}
    StrCpy $LogDir "$TEMP\FoisonC24\Logs"
    CreateDirectory "$LogDir"
    StrCpy $LogFile "$LogDir\install-$RunId-nsis.log"
    ClearErrors
    FileOpen $LogHandle "$LogFile" a
    ${If} ${Errors}
      SetErrorLevel 73
      MessageBox MB_ICONSTOP "Não foi possível criar diagnóstico em ProgramData nem TEMP. Instalação interrompida."
      Abort
    ${EndIf}
  ${EndIf}
  FileSeek $LogHandle 0 END $1
  ${If} $1 == 0
    FileWriteUTF16LE /BOM $LogHandle "Foison C24 ${BRIDGE_VERSION}; NSIS Unicode; log UTF-16LE; RunId=$RunId$\r$\n"
  ${EndIf}
  FileClose $LogHandle
  StrCpy $Step "INITIALIZE"
  StrCpy $FailureCode 1
FunctionEnd
Function ${PREFIX}Log
  ; $3 holds a fixed diagnostic message, never credentials or a print stream.
  ${GetTime} "" "L" $4 $5 $6 $7 $8 $9 $R0
  FileOpen $LogHandle "$LogFile" a
  FileWriteUTF16LE $LogHandle "$6-$5-$4 $8:$9:$R0 [INFO] [$RunId] [nsis] [$Step] $3$\r$\n"
  FileClose $LogHandle
  DetailPrint "$Step: $3"
FunctionEnd
Function ${PREFIX}Fail
  StrCpy $3 "ERROR ExitCode=$0; a operação não foi concluída; arquivos/logs preservados."
  Call ${PREFIX}Log
  SetErrorLevel $FailureCode
  IfSilent done_${PREFIX}
  MessageBox MB_ICONSTOP|MB_YESNO "A instalação/desinstalação não foi concluída.$\r$\nEtapa: $Step; código: $0.$\r$\nDiagnóstico: $LogDir$\r$\n$\r$\nNenhum corte foi autorizado. Abrir a pasta de diagnóstico?" IDNO done_${PREFIX}
  ExecShell "open" "$LogDir"
  done_${PREFIX}:
  Abort
FunctionEnd
!macroend
!insertmacro Logging ""
!insertmacro Logging "un."
Function .onInit
  Call InitLog
  StrCpy $3 "BEGIN setup. Log=$LogFile"
  Call Log
FunctionEnd
Function un.onInit
  Call un.InitLog
  StrCpy $3 "BEGIN uninstall. Log=$LogFile"
  Call un.Log
FunctionEnd
Function .onInstFailed
  SetErrorLevel $FailureCode
FunctionEnd
Function un.onUninstFailed
  SetErrorLevel $FailureCode
FunctionEnd
Function CheckPrerequisiteExit
  StrCpy $3 "Microsoft prerequisite ExitCode=$0"
  Call Log
  ${If} $0 == 3010
  ${OrIf} $0 == 1641
    SetRebootFlag true
    StrCpy $FailureCode 3010
    IfSilent reboot_silent
    MessageBox MB_ICONINFORMATION "Atenção: reinicialização necessária. Reinicie e execute o mesmo instalador. A fila não foi alterada. Logs: $LogDir"
    reboot_silent:
    SetErrorLevel 3010
    Abort
  ${ElseIf} $0 != 0
    ; Do not blindly accept 1638. Registry version is checked before installation.
    Call Fail
  ${EndIf}
FunctionEnd
Function CheckVC
  StrCpy $2 0
  ClearErrors
  ReadRegDWORD $1 HKLM "SOFTWARE\Microsoft\VisualStudio\14.0\VC\Runtimes\x64" "Installed"
  ${If} $1 == 1
    ReadRegDWORD $1 HKLM "SOFTWARE\Microsoft\VisualStudio\14.0\VC\Runtimes\x64" "Major"
    ${If} $1 == 14
      ReadRegDWORD $1 HKLM "SOFTWARE\Microsoft\VisualStudio\14.0\VC\Runtimes\x64" "Minor"
      ${If} $1 > 29
        StrCpy $2 1
      ${ElseIf} $1 == 29
        ReadRegDWORD $1 HKLM "SOFTWARE\Microsoft\VisualStudio\14.0\VC\Runtimes\x64" "Bld"
        ${If} $1 >= 30157
          StrCpy $2 1
        ${EndIf}
      ${EndIf}
    ${EndIf}
  ${EndIf}
FunctionEnd
Section "Instalação completa — corte bloqueado"
  StrCpy $Step "OPERATING_SYSTEM"
  StrCpy $3 "Verificando Windows 7 SP1 x64."
  Call Log
  ${IfNot} ${RunningX64}
    StrCpy $0 50
    Call Fail
  ${EndIf}
  ${IfNot} ${IsWin7}
    StrCpy $0 50
    Call Fail
  ${EndIf}
  ${IfNot} ${AtLeastServicePack} 1
    StrCpy $0 50
    Call Fail
  ${EndIf}
  ${DisableX64FSRedirection}
  InitPluginsDir
  SetOutPath "$PLUGINSDIR"
  StrCpy $Step "DOTNET48"
  ReadRegDWORD $1 HKLM "SOFTWARE\Microsoft\NET Framework Setup\NDP\v4\Full" "Release"
  ${If} $1 < 528040
    File "prerequisites\ndp48.exe"
    ExecWait '"$PLUGINSDIR\ndp48.exe" /q /norestart /log "$LogDir\install-$RunId-dotnet.html"' $0
    Call CheckPrerequisiteExit
  ${EndIf}
  ReadRegDWORD $1 HKLM "SOFTWARE\Microsoft\NET Framework Setup\NDP\v4\Full" "Release"
  ${If} $1 < 528040
    StrCpy $0 1603
    Call Fail
  ${EndIf}
  StrCpy $Step "VC2019_X64"
  Call CheckVC
  ${If} $2 != 1
    File "prerequisites\vc_redist.x64.exe"
    ExecWait '"$PLUGINSDIR\vc_redist.x64.exe" /install /quiet /norestart /log "$LogDir\install-$RunId-vc.log"' $0
    Call CheckPrerequisiteExit
  ${EndIf}
  Call CheckVC
  ${If} $2 != 1
    StrCpy $0 1603
    Call Fail
  ${EndIf}
  StrCpy $Step "EXTRACT"
  SetOutPath "$INSTDIR"
  File "VERSION"
  File "FoisonC24Receiver.exe"
  File "FoisonC24Receiver.exe.config"
  File "redmon64.dll"
  File "setup64.exe"
  ; Required RedMon companion; NEVER executed to remove the shared monitor.
  File "unredmon64.exe"
  File "redmon.chm"
  File "FoisonC24Diagnostic.exe"
  File "FoisonC24Diagnostic.exe.config"
  File "FoisonC24.Core.dll"
  File "FoisonC24Provisioner.exe"
  File "FoisonC24Provisioner.exe.config"
  File "LEIA-ME.txt"
  File "THIRD-PARTY.txt"
  File "PRIMEIRA-SESSAO.md"
  File "RECUPERACAO.txt"
  File "TEXTOS-VALIDACAO.txt"
  File "Install-Queue-Win7.cmd"
  File "Install-Queue-Win7.ps1"
  File /r "tools"
  File /r "sources"
  SetOutPath "$INSTDIR\testes"
  File "testes\square-20mm.ps"
  File "testes\quadrado-20mm.svg"
  SetOutPath "$INSTDIR"
  ; Recovery remains available after partial provisioning; no false-success shortcut.
  WriteUninstaller "$INSTDIR\Uninstall.exe"
  StrCpy $Step "PROVISION"
  ExecWait '"$SYSDIR\cmd.exe" /d /c ""$INSTDIR\Install-Queue-Win7.cmd" install --noninteractive $RunId"' $0
  ${If} $0 != 0
    Call Fail
  ${EndIf}
  StrCpy $Step "INDEPENDENT_VERIFY"
  ExecWait '"$SYSDIR\cmd.exe" /d /c ""$INSTDIR\Install-Queue-Win7.cmd" verify --noninteractive $RunId"' $0
  ${If} $0 != 0
    Call Fail
  ${EndIf}
  CreateShortCut "$DESKTOP\Foison C24.lnk" "$INSTDIR\FoisonC24Diagnostic.exe"
  CreateShortCut "$DESKTOP\Quadrado Foison 20 mm.lnk" "$INSTDIR\testes\quadrado-20mm.svg"
  WriteRegStr HKLM "SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\FoisonC24Bridge" "DisplayName" "Foison C24 Print Bridge (teste acompanhado)"
  WriteRegStr HKLM "SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\FoisonC24Bridge" "DisplayVersion" "${BRIDGE_VERSION}"
  WriteRegStr HKLM "SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\FoisonC24Bridge" "UninstallString" '$\"$INSTDIR\Uninstall.exe$\"'
  StrCpy $Step "COMPLETE"
  StrCpy $3 "Instalação concluída com sucesso. Verificação de dependências concluída. Corte físico bloqueado."
  Call Log
  SetErrorLevel 0
SectionEnd
Section "Uninstall"
  ${DisableX64FSRedirection}
  StrCpy $Step "SAFE_UNINSTALL"
  ExecWait '"$SYSDIR\cmd.exe" /d /c ""$INSTDIR\Install-Queue-Win7.cmd" uninstall --noninteractive $RunId"' $0
  ${If} $0 != 0
    Call un.Fail
  ${EndIf}
  Delete "$DESKTOP\Foison C24.lnk"
  Delete "$DESKTOP\Quadrado Foison 20 mm.lnk"
  DeleteRegKey HKLM "SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\FoisonC24Bridge"
  ; Delete only known project files. Keep journals, logs and unexpected files.
  Delete "$INSTDIR\FoisonC24Receiver.exe.config"
  Delete "$INSTDIR\FoisonC24Diagnostic.exe.config"
  Delete "$INSTDIR\FoisonC24Provisioner.exe.config"
  Delete "$INSTDIR\VERSION"
  Delete "$INSTDIR\Install-Queue-Win7.cmd"
  Delete "$INSTDIR\Install-Queue-Win7.ps1"
  Delete "$INSTDIR\setup64.exe"
  Delete "$INSTDIR\unredmon64.exe"
  Delete "$INSTDIR\redmon.chm"
  Delete "$INSTDIR\redmon64.dll"
  Delete "$INSTDIR\FoisonC24Provisioner.exe"
  Delete "$INSTDIR\FoisonC24Diagnostic.exe"
  Delete "$INSTDIR\FoisonC24.Core.dll"
  Delete "$INSTDIR\FoisonC24Receiver.exe"
  Delete "$INSTDIR\LEIA-ME.txt"
  Delete "$INSTDIR\THIRD-PARTY.txt"
  Delete "$INSTDIR\PRIMEIRA-SESSAO.md"
  Delete "$INSTDIR\RECUPERACAO.txt"
  Delete "$INSTDIR\TEXTOS-VALIDACAO.txt"
  Delete "$INSTDIR\Uninstall.exe"
  !include "uninstall-files.nsh"
  RMDir "$INSTDIR"
  StrCpy $3 "Desinstalação concluída. RedMon compartilhado, driver, logs e journal preservados."
  Call un.Log
  SetErrorLevel 0
SectionEnd
