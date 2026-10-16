#!/usr/bin/env sh
set -eu
root=$(CDPATH= cd -- "$(dirname "$0")/../.." && pwd)
makensis_bin="${MAKENSIS:-$(command -v makensis || true)}"
if [ -z "$makensis_bin" ]; then
    echo "ERRO: makensis não está instalado; nenhum EXE foi gerado." >&2
    exit 2
fi
cd "$root/packaging/windows"
# NSIS File statements are deliberately mandatory; any missing engine,
# prerequisite, license or source prevents producing a capture-only installer.
if [ "$(uname -s)" = "Linux" ]; then
    "$makensis_bin" -WX -DOUTFILE=FoisonC24-Setup-x64.exe FoisonC24-Setup.nsi
else
    "$makensis_bin" /WX /DOUTFILE=FoisonC24-Setup-x64.exe FoisonC24-Setup.nsi
fi
