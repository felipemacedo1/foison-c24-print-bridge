; Source installer definition. The Windows-side provisioning script detects an
; installed PostScript driver at runtime; no arbitrary INF is bundled.
Unicode true
!include LogicLib.nsh
!include x64.nsh
Name "Foison C24 Print Bridge (Teste)"
!ifndef OUTFILE
  !define OUTFILE "FoisonC24-Teste-Setup-x64.exe"
!endif
OutFile "${OUTFILE}"
InstallDir "$PROGRAMFILES64\Foison C24 Print Bridge"
RequestExecutionLevel admin

!ifndef RECEIVER_EXE
  !define RECEIVER_EXE "FoisonC24Receiver.exe"
!endif
!ifndef PORT_MONITOR_DLL
  !define PORT_MONITOR_DLL "redmon64.dll"
!endif
!ifndef DIAGNOSTIC_EXE
  !define DIAGNOSTIC_EXE "FoisonC24Diagnostic.exe"
!endif
Function .onInit
  ${IfNot} ${RunningX64}
    MessageBox MB_ICONSTOP "Este instalador requer Windows 7 SP1 de 64 bits."
    Abort
  ${EndIf}
FunctionEnd

Section "Foison C24 Print Bridge"
  SetOutPath "$INSTDIR"
  File "${RECEIVER_EXE}"
  File "${PORT_MONITOR_DLL}"
  File "setup64.exe"
  File "${DIAGNOSTIC_EXE}"
  File "FoisonC24Provisioner.exe"
  File "LEIA-ME.txt"
  File "Install-Queue-Win7.cmd"
  File "Install-Queue-Win7.ps1"
  WriteUninstaller "$INSTDIR\Uninstall.exe"
  ExecWait '"$SYSDIR\cmd.exe" /c "$INSTDIR\Install-Queue-Win7.cmd"' $0
  ${If} $0 != 0
    MessageBox MB_ICONSTOP "A fila não foi criada. Nenhuma impressora parcial foi deixada."
    Abort
  ${EndIf}
  CreateShortCut "$DESKTOP\Foison C24 Diagnóstico.lnk" "$INSTDIR\FoisonC24Diagnostic.exe"
SectionEnd

Section "Uninstall"
  ExecWait '"$SYSDIR\cmd.exe" /c "$INSTDIR\Install-Queue-Win7.cmd" uninstall' $0
  Delete "$DESKTOP\Foison C24 Diagnóstico.lnk"
  Delete "$INSTDIR\Install-Queue-Win7.cmd"
  Delete "$INSTDIR\Install-Queue-Win7.ps1"
  Delete "$INSTDIR\setup64.exe"
  Delete "$INSTDIR\${PORT_MONITOR_DLL}"
  Delete "$INSTDIR\FoisonC24Provisioner.exe"
  Delete "$INSTDIR\${DIAGNOSTIC_EXE}"
  Delete "$INSTDIR\${RECEIVER_EXE}"
  Delete "$INSTDIR\LEIA-ME.txt"
  Delete "$INSTDIR\Uninstall.exe"
  RMDir "$INSTDIR"
SectionEnd
