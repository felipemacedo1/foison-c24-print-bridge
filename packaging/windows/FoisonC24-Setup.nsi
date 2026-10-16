Unicode true
!include LogicLib.nsh
!include x64.nsh
!include WinVer.nsh
Name "Foison C24 Print Bridge — primeira sessão acompanhada"
!ifndef OUTFILE
  !define OUTFILE "FoisonC24-Setup-x64.exe"
!endif
OutFile "${OUTFILE}"
InstallDir "$PROGRAMFILES64\Foison C24 Print Bridge"
RequestExecutionLevel admin
SetCompressor /SOLID lzma
Page directory
Page instfiles
UninstPage uninstConfirm
UninstPage instfiles

Function .onInit
  ${IfNot} ${RunningX64}
    MessageBox MB_ICONSTOP "É necessário Windows 7 SP1 x64."
    Abort
  ${EndIf}
  ${IfNot} ${IsWin7}
    MessageBox MB_ICONSTOP "Este candidato foi preparado exclusivamente para Windows 7 SP1 x64."
    Abort
  ${EndIf}
  ${IfNot} ${AtLeastServicePack} 1
    MessageBox MB_ICONSTOP "É necessário Windows 7 Service Pack 1."
    Abort
  ${EndIf}
  SetRegView 64
FunctionEnd

Function CheckPrerequisiteExit
  ${If} $0 == 3010
    SetRebootFlag true
    MessageBox MB_ICONINFORMATION "O pré-requisito Microsoft exige reinicialização. Reinicie e execute este mesmo instalador. Nenhuma fila ou porta serial foi alterada."
    Abort
  ${ElseIf} $0 == 1641
    SetRebootFlag true
    Abort
  ${ElseIf} $0 != 0
    ${If} $0 != 1638
      MessageBox MB_ICONSTOP "Falha no pré-requisito Microsoft (código $0). O desenvolvedor deve verificar as atualizações do Windows; nenhuma fila foi alterada."
      Abort
    ${EndIf}
  ${EndIf}
FunctionEnd

Section "Instalação completa (envio inicialmente bloqueado)"
  SetOutPath "$PLUGINSDIR"
  ReadRegDWORD $1 HKLM "SOFTWARE\Microsoft\NET Framework Setup\NDP\v4\Full" "Release"
  ${If} $1 < 528040
    File "prerequisites\ndp48.exe"
    ExecWait '"$PLUGINSDIR\ndp48.exe" /q /norestart' $0
    Call CheckPrerequisiteExit
  ${EndIf}
  File "prerequisites\vc_redist.x64.exe"
  ExecWait '"$PLUGINSDIR\vc_redist.x64.exe" /install /quiet /norestart' $0
  Call CheckPrerequisiteExit

  SetOutPath "$INSTDIR"
  File "FoisonC24Receiver.exe"
  File "redmon64.dll"
  File "setup64.exe"
  File "redmon.chm"
  File "FoisonC24Diagnostic.exe"
  File "FoisonC24.Core.dll"
  File "FoisonC24Provisioner.exe"
  File "LEIA-ME.txt"
  File "THIRD-PARTY.txt"
  File "PRIMEIRA-SESSAO.md"
  File "Install-Queue-Win7.cmd"
  File "Install-Queue-Win7.ps1"
  File /r "tools"
  File /r "sources"
  SetOutPath "$INSTDIR\testes"
  File "..\..\tests\fixtures\square-20mm.ps"
  File "..\..\tests\fixtures\quadrado-20mm.svg"
  SetOutPath "$INSTDIR"
  ExecWait '"$INSTDIR\FoisonC24Diagnostic.exe" --selftest' $0
  ${If} $0 != 0
    MessageBox MB_ICONSTOP "O interpretador vetorial não passou o teste de 20 mm neste Windows (código $0). Nenhuma fila foi alterada. Veja %TEMP%\FoisonC24-selftest-error.txt. Não use uma versão apenas de captura."
    Abort
  ${EndIf}
  ExecWait '"$SYSDIR\cmd.exe" /c "$INSTDIR\Install-Queue-Win7.cmd"' $0
  ${If} $0 != 0
    ; Rollback is scoped to this invocation in PowerShell. Never uninstall an
    ; existing owned queue just because an upgrade/preflight failed.
    MessageBox MB_ICONSTOP "A instalação da fila falhou. Recursos anteriores foram preservados; o rollback trata somente recursos desta execução. Veja ProgramData\FoisonC24\installation-error.log. Não envie comandos à plotter."
    Abort
  ${EndIf}
  WriteUninstaller "$INSTDIR\Uninstall.exe"
  CreateShortCut "$DESKTOP\Foison C24.lnk" "$INSTDIR\FoisonC24Diagnostic.exe"
  CreateShortCut "$DESKTOP\Quadrado Foison 20 mm.lnk" "$INSTDIR\testes\quadrado-20mm.svg"
  MessageBox MB_ICONINFORMATION "Instalação e autoteste concluídos. Abra o CorelDRAW e imprima o quadrado a 100% em Foison C24 (Teste). Abra o atalho Foison C24. Corte físico permanece bloqueado até a validação acompanhada."
  ; Open the desktop shortcut normally, never launch the document interpreter elevated.
SectionEnd

Section "Uninstall"
  ExecWait '"$SYSDIR\cmd.exe" /c "$INSTDIR\Install-Queue-Win7.cmd" uninstall' $0
  ${If} $0 != 0
    MessageBox MB_ICONSTOP "Não foi possível remover a fila/porta com segurança. Arquivos preservados; peça ajuda ao desenvolvedor."
    Abort
  ${EndIf}
  Delete "$DESKTOP\Foison C24.lnk"
  Delete "$DESKTOP\Quadrado Foison 20 mm.lnk"
  Delete "$INSTDIR\Install-Queue-Win7.cmd"
  Delete "$INSTDIR\Install-Queue-Win7.ps1"
  Delete "$INSTDIR\setup64.exe"
  Delete "$INSTDIR\redmon.chm"
  Delete "$INSTDIR\redmon64.dll"
  Delete "$INSTDIR\FoisonC24Provisioner.exe"
  Delete "$INSTDIR\FoisonC24Diagnostic.exe"
  Delete "$INSTDIR\FoisonC24.Core.dll"
  Delete "$INSTDIR\FoisonC24Receiver.exe"
  Delete "$INSTDIR\LEIA-ME.txt"
  Delete "$INSTDIR\THIRD-PARTY.txt"
  Delete "$INSTDIR\PRIMEIRA-SESSAO.md"
  Delete "$INSTDIR\Uninstall.exe"
  RMDir /r "$INSTDIR\tools"
  RMDir /r "$INSTDIR\sources"
  RMDir /r "$INSTDIR\testes"
  RMDir "$INSTDIR"
  ; Shared RedMon, inbox driver and session journal are deliberately preserved.
SectionEnd
