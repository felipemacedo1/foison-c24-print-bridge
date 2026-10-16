#!/usr/bin/env sh
set -eu
root=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
dist="$root/dist/windows"
rm -rf "$dist"
mkdir -p "$dist"
cp "$root/packaging/windows/LEIA-ME.txt" "$dist/LEIA-ME.txt"
cp "$root/packaging/windows/INSTRUCOES-DE-TESTE.html" "$dist/INSTRUCOES-DE-TESTE.html"
if command -v google-chrome >/dev/null 2>&1; then
  google-chrome --headless --no-sandbox --disable-gpu \
    --print-to-pdf="$dist/INSTRUCOES-DE-TESTE.pdf" \
    "file://$dist/INSTRUCOES-DE-TESTE.html" >/dev/null 2>&1
else
  echo "AVISO: google-chrome ausente; PDF não foi gerado." >&2
fi
printf '%s  %s\n' \
  "$(sha256sum "$dist/LEIA-ME.txt" | cut -d' ' -f1)" "LEIA-ME.txt" \
  "$(sha256sum "$dist/INSTRUCOES-DE-TESTE.html" | cut -d' ' -f1)" "INSTRUCOES-DE-TESTE.html" \
  > "$dist/checksums.sha256"
if [ -f "$dist/INSTRUCOES-DE-TESTE.pdf" ]; then
  printf '%s  %s\n' "$(sha256sum "$dist/INSTRUCOES-DE-TESTE.pdf" | cut -d' ' -f1)" "INSTRUCOES-DE-TESTE.pdf" >> "$dist/checksums.sha256"
fi
(
  cd "$root/dist"
  rm -f FoisonC24-Teste-Win7-x64.zip
  zip -qr FoisonC24-Teste-Win7-x64.zip windows
)
echo "Distribuição documental criada em $dist; FoisonC24-Setup-x64.exe não foi gerado."
