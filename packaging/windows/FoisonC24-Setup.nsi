; Source installer definition.
; This file intentionally refuses to build until the Windows receiver and
; legally redistributable printer components are present beside it.
Unicode true
!include LogicLib.nsh
!include x64.nsh
Name "Foison C24 Print Bridge (Teste)"
OutFile "FoisonC24-Setup-x64.exe"
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
!ifndef POSTSCRIPT_INF
  !define POSTSCRIPT_INF "postscript-driver.inf"
!endif

Function .onInit
  ${IfNot} ${RunningX64}
    MessageBox MB_ICONSTOP "Este instalador requer Windows 7 SP1 de 64 bits."
    Abort
  ${EndIf}
  IfFileExists "${RECEIVER_EXE}" +2 0
    MessageBox MB_ICONSTOP "Receptor Windows ausente. O pacote não está completo."
    Abort
  IfFileExists "${PORT_MONITOR_DLL}" +2 0
    MessageBox MB_ICONSTOP "Monitor de porta ausente. Não é seguro criar a fila."
    Abort
  IfFileExists "${POSTSCRIPT_INF}" +2 0
    MessageBox MB_ICONSTOP "Driver PostScript ausente. A fila não será simulada."
    Abort
FunctionEnd

Section "Foison C24 Print Bridge"
  SetOutPath "$INSTDIR"
  File "${RECEIVER_EXE}"
  File "${PORT_MONITOR_DLL}"
  File "${DIAGNOSTIC_EXE}"
  File "${POSTSCRIPT_INF}"
  File "LEIA-ME.txt"
  WriteUninstaller "$INSTDIR\Uninstall.exe"
  ; Queue registration is deliberately delegated to the tested Windows
  ; provisioning script, not guessed in this source template.
  File "Install-Queue-Win7.cmd"
  CreateShortCut "$DESKTOP\Foison C24 Bridge.lnk" "$INSTDIR\FoisonC24Receiver.exe"
SectionEnd

Section "Uninstall"
  Delete "$DESKTOP\Foison C24 Bridge.lnk"
  Delete "$INSTDIR\Install-Queue-Win7.cmd"
  Delete "$INSTDIR\${POSTSCRIPT_INF}"
  Delete "$INSTDIR\${PORT_MONITOR_DLL}"
  Delete "$INSTDIR\${DIAGNOSTIC_EXE}"
  Delete "$INSTDIR\${RECEIVER_EXE}"
  Delete "$INSTDIR\LEIA-ME.txt"
  Delete "$INSTDIR\Uninstall.exe"
  RMDir "$INSTDIR"
SectionEnd
