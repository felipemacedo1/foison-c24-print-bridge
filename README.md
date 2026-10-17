# Foison C24 Print Bridge

**[Baixar 1.0.1-rc.1 (prerelease)](https://github.com/felipemacedo1/foison-c24-print-bridge/releases/tag/v1.0.1-rc.1)** — ZIP do cliente e instalador
publicados com checksums e evidências. Win7/CorelDRAW/hardware ainda não validados.

Candidato para a primeira sessão acompanhada:
**CorelDRAW X6 → impressora Foison C24 (Teste) → PostScript vetorial → prévia mm
→ HPGL condicionado à validação → COM2 → ensaio/corte autorizado.**

**Não é captura-only. Também não é hardware validado.** O protocolo/resolução
exatos da revisão do cliente e Win7/CorelDRAW não foram executados aqui. Sem
comprovar essas condições, nenhum movimento é permitido. Consulte
[estado](PROJECT_STATE.md) e [checklist do desenvolvedor](packaging/windows/PRIMEIRA-SESSAO.md).

## Produto

- Windows 7 SP1 x64 / .NET Framework 4.8; UI WinForms em português.
- Instalador offline `FoisonC24-Setup-Win7-x64.exe` com engines vetoriais reais,
  pré-requisitos, RedMon x64, fonte e licenças. Pode precisar reiniciar Windows
  pelos pré-requisitos; não é possível prometer sessão sem reboot.
- Driver PostScript inbox MS Publisher Imagesetter instalado pelo INF do próprio
  Windows e verificado como PScript5 x64; não requer adivinhar driver existente.
- Sem modificação de FTDI, configuração FlexiSIGN, COM2 do sistema ou outras filas.
- Serial configurável (COM2 padrão), 38400 8N1 Xon/Xoff; sem retry/forçar porta.
- Área inicial medida ≤50×50 mm; prévia e autorização por trabalho; ensaio sem
  lâmina obrigatório antes do corte. Nenhum comando de força/velocidade presumido.
- Curvas preservadas por aproximação ≤0,01 mm; abertos/fechados e afins testados.
  Imagens/recortes intersectantes/efeitos/operações desconhecidas são rejeitados, nunca omitidos.
- Journal e latch persistentes após interrupção incerta. O botão PC não é parada
  física de emergência; veja o procedimento PAUSE/OFFLINE no checklist.

## Cliente: três passos

1. Executar o instalador com o desenvolvedor presente.
2. Abrir `quadrado-20mm.svg` no CorelDRAW X6 e imprimir uma cópia em Foison C24
   (Teste), escala 100%, sem ajustar à página.
3. Abrir Foison C24, conferir prévia 20×20 mm e seguir as confirmações guiadas.

Se a revisão/protocolo/origem/escala/área não puder ser comprovada, não cortar.

## Desenvolvimento / validação

SDK .NET 8, Python 3.12; para testes reais Linux: `ghostscript` e `mupdf-tools`.
No host atual o SDK está em `~/.dotnet/dotnet`; use `dotnet` no PATH.

```sh
./scripts/test.sh                         # Python e contratos de provisionamento
# Compilações equivalem ao lint/tipo-check C#; não há formatter adicional.
dotnet build src/FoisonC24.WindowsReceiver -f net8.0 -c Release
dotnet run --project tests/FoisonC24.CoreTests -f net8.0 -c Release -- \
  /usr/bin/gs /usr/bin/mutool "$PWD/tests/fixtures" \
  "$PWD/src/FoisonC24.WindowsReceiver/bin/Release/net8.0/FoisonC24Receiver.dll"
dotnet build src/FoisonC24.Diagnostic -c Release
dotnet build src/FoisonC24.Provisioner -c Release
dotnet build src/FoisonC24.WindowsReceiver -f net48 -c Release
git diff --check
```

Desenvolvimento Windows: `dotnet run --project src/FoisonC24.Diagnostic`, com
`tools/` ao lado do exe. A UI não interpreta automaticamente ao imprimir nem
abre COM para sondar. Uma nova sessão exige nova aprovação do desenvolvedor.

## Build completo

```sh
# SDK .NET 8, Python 3.12, NSIS Unicode 3.09/3.10, PowerShell (testes), 7z.
# Ubuntu também requer gs/mutool reais; Windows usa os engines fixados no pacote.
python3 scripts/build-release.py
# Alternativas de entrada delegam ao mesmo pipeline; não empacotam EXE antigo.
# DOTNET/PWSH/MAKENSIS/GS/MUTOOL podem indicar executáveis locais.
```

Saída atômica em `dist/<VERSION>/`: instalador, ZIP versionado, SHA256SUMS.txt e
validation.json. Recusa substituir distribuição existente. Release exige Git
limpo; `--development --output dist/experimento` é **não publicável**.
Testa Python, matriz PS, C# E2E real/simulação, arquitetura/versões PE, payload
extraído do NSIS, headers ZIP/CRC, extração/hash de cada entrada e `7z t`.
ZIP: Deflate 8, nomes ASCII, diretório único, sem ZIP64/AES/multipartes.
[Recuperação e logs](packaging/windows/RECUPERACAO.txt),
[matriz de validação](docs/release-validation.md) e [auditoria ZIP anterior](docs/previous-zip-audit.json).

O Git deve conter as fontes atuais commitadas antes de preparar o arquivo fonte
com `git archive HEAD`. O CI automatiza todos esses passos, executa net48 com
os engines Windows, simula stdin da fila/serial e publica o ZIP único.
Isso **não executa** spooler/RedMon/PScript/CorelDRAW reais em Win7.
[Arquitetura](docs/architecture.md), [protocolo](docs/protocol.md),
[testes](docs/testing.md) e [licenças](packaging/windows/THIRD-PARTY.txt).

## Promoção de release (somente mantenedor)

`publish-candidate.yml` é manual e recebe ID do CI aprovado, SHA exato e tag rc
existente. Verifica origem/conclusão do run, tag, CRC/extração/hashes/PE e promove
os mesmos bytes, sem rebuild, stable ou sobrescrita de assets. A publicação usa
token efêmero gerenciado pelo GitHub com contents:write/actions:read; não se deve
copiar credenciais para arquivos ou logs. Não confundir o ZIP de evidências com
o único ZIP do cliente.
