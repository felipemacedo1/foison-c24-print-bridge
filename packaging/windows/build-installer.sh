#!/usr/bin/env sh
set -eu
root=$(CDPATH= cd -- "$(dirname "$0")/../.." && pwd)
out="$root/dist/windows"
mkdir -p "$out"

if ! command -v makensis >/dev/null 2>&1; then
    echo "ERRO: makensis não está instalado; nenhum EXE foi gerado." >&2
    exit 2
fi
for required in FoisonC24Receiver.exe redmon64.dll postscript-driver.inf; do
    if [ ! -f "$root/packaging/windows/$required" ]; then
        echo "ERRO: componente obrigatório ausente: $required" >&2
        exit 2
    fi
done
echo "Componentes presentes; a compilação real ainda deve ser validada no Windows 7."
makensis /DRECEIVER_EXE="$root/packaging/windows/FoisonC24Receiver.exe" \
    "$root/packaging/windows/FoisonC24-Setup.nsi"
