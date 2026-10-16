#!/usr/bin/env sh
set -eu
root=$(CDPATH= cd -- "$(dirname "$0")/../.." && pwd)
out="$root/dist/windows"
mkdir -p "$out"

makensis_bin="${MAKENSIS:-$(command -v makensis || true)}"
if [ -z "$makensis_bin" ]; then
    echo "ERRO: makensis não está instalado; nenhum EXE foi gerado." >&2
    exit 2
fi
for required in FoisonC24Receiver.exe FoisonC24Diagnostic.exe FoisonC24Provisioner.exe redmon64.dll setup64.exe Install-Queue-Win7.cmd Install-Queue-Win7.ps1 LEIA-ME.txt; do
    if [ ! -f "$root/packaging/windows/$required" ]; then
        echo "ERRO: componente obrigatório ausente: $required" >&2
        exit 2
    fi
done
echo "Componentes presentes; a compilação real ainda deve ser validada no Windows 7."
if [ "$(uname -s)" = "Linux" ]; then
  (cd "$root/packaging/windows" && "$makensis_bin" \
    -DRECEIVER_EXE=FoisonC24Receiver.exe \
    -DDIAGNOSTIC_EXE=FoisonC24Diagnostic.exe \
    -DPORT_MONITOR_DLL=redmon64.dll \
    -DOUTFILE=FoisonC24-Teste-Setup-x64.exe \
    FoisonC24-Setup.nsi)
else
  (cd "$root/packaging/windows" && "$makensis_bin" /DRECEIVER_EXE=FoisonC24Receiver.exe \
    /DDIAGNOSTIC_EXE=FoisonC24Diagnostic.exe \
    /DPORT_MONITOR_DLL=redmon64.dll \
    /DOUTFILE=FoisonC24-Teste-Setup-x64.exe \
    FoisonC24-Setup.nsi)
fi
