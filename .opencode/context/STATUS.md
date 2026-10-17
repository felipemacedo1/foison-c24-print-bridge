# Objetivo atual — candidato de diagnóstico observável rc.4

## Atualização de validação (2026-10-17)

- Hash do Receiver alterado para incremental. Quando a entrada excede o limite,
  continua drenando stdin até EOF, registra bytes/hash completos e rejeita sem
  alocar nem persistir o excesso.
- Builds explícitos MSBuild: Diagnostic/net48, Receiver/net48/net8 e
  Provisioner/net48 aprovados; API C#2/net20 aprovada. `./scripts/test.sh`:
  38/38; encoding e `git diff --check` aprovados; E2E pós-alteração: 73 checks.
- A primeira repetição do teste Python encontrou NameError no próprio contrato
  estático (variáveis workflow/report_builder não carregadas); foi corrigido e a
  suíte passou. A smoke WinForms do ZIP foi executada posteriormente pelo Actions.
- Primeiro Actions `39069412287` falhou no teste E2E Windows, não no produto:
  teste assumia logs em `captures/diagnostics`, mas Receiver Win32 usa primeiro
  `ProgramData\FoisonC24\Logs`. Ajustado harness para correlacionar RunId e
  procurar em todas as localizações oficiais; execução Linux passou 73/73.
  Correção em `7031948`, push realizado.
- O segundo run `39069926356` aprovou build, NSIS, pacote, testes E2E e smoke
  visual, mas a asserção da smoke do ZIP falhou ao ler literal `NÃO` no script
  PowerShell (code page do próprio script); 7z já havia validado os 9 itens do
  ZIP. Asserção alterada para gerar U+00C3 via `[char]`, evitando encoding
  ambíguo; commit/push `6d0d815`.
- Actions `39070334614` aprovou o smoke da UI/ZIP após esse ajuste, mas seu SHA
  era anterior ao commit documental que corrigiu as notas de versão. O run
  `39070594835` no commit `828bcec` concluiu sucesso em Ubuntu e Windows 2022,
  incluindo build integrado, testes, NSIS, empacotamento, ZIP nativo e smoke
  sintético do relatório. Nenhum run valida Win7/Corel/RedMon no cliente.
- Builds de artefato local anteriores são obsoletos após essas alterações; não
  distribuir seus hashes. `pwsh` ausente impede o pipeline release completo aqui.
- Run `39070594835` validou o commit `828bcecc2e1b0b46b73d99e8cc357c8a0d260948`.
  Artifact baixado e inspecionado independentemente: ZIP 361267595 bytes,
  8 entradas, PKZIP Deflate (método 8), `zipfile.testzip()` sem erro. ZIP SHA-256
  `b1ea7e7255bbd44cc50a0a45c93eca3427940d4a0d61712fd43666055151ca48`;
  instalador SHA-256 `85c3dd8699282ece4dc28b958896fee6f309da60583c060ea4cace7f3d89c1c3`.
  `validation.json`: dirty=false, build/test PASS; Win7/Corel/hardware NOT
  EXECUTED. Prerelease pública `v1.0.1-rc.4` publicada após verificar tag,
  SHA/size de todos os 5 assets: https://github.com/felipemacedo1/foison-c24-print-bridge/releases/tag/v1.0.1-rc.4

Branch `fix/capture-observability`, baseada em `fix/corel-cut-settings` em
`919ec25`; `main` intacta. Commits de código enviados (`cfb792d`, `7031948`,
`6d0d815`, `828bcec`). Versão candidata `1.0.1-rc.4`. Tags remotas auditadas:
única anterior conhecida `v1.0.1-rc.1`; `v1.0.1-rc.4` ainda não criada.

## Marco: instrumentação Receiver e fluxo guiado

- Receiver agora loga antes da detecção: RunId/AttemptId, PID, identidade,
  argumentos/REDMON_* com DOCNAME redigido, abertura stdin, primeiro byte, EOF,
  contagem, hash SHA-256, formato, persistência/marker, exceção/stack e exitcode.
  Rejeições deixam JSON de metadados/hash/causa sem salvar bytes brutos. Log
  tenta CommonApplicationData, captura/diagnostics e TEMP.
- Nova `GuidedDiagnosticForm`: teste A envia fixture binária exata para stdin e
  verifica raw/hash/JSON/parser 20×20; B inicia observação WMI start/stop,
  amostra PrintJob/fila/RedMon/Receiver/metadados durante a sessão e pede
  confirmação manual de lista e prévia. Exportação allowlist ZIP sem RAW/PDF.
- `FoisonC24-Diagnostico.cmd`, comando `--guided-diagnosis`, payload NSIS e
  atalho Menu Iniciar adicionados. README/LEIA-ME/CHANGELOG/PROJECT_STATE e
  documento operacional atualizado.
- Builds Receiver `net8.0`, Receiver `net48`, Diagnostic `net48`, Provisioner
  `net48` e CoreTests `net8.0` passaram sem warnings (analyzer CA1416 e escopo
  corrigidos). 38 testes Python passaram; encoding gate passou; API compile C#2 /
  net20 passou (não é runtime PS2). C# E2E: 73 checks passaram, incluindo
  Ghostscript + MuPDF empacotado sob Wine, geometria real 20×20 mm, Receiver
  binário, unknown e serial simulada. NSIS 3.09-4 gerou instalador sem warnings;
  extração 7z conferiu EXEs/DLL/CMD byte a byte. ZIP testado com cabeçalhos/CRC,
  extração+SHA-256 e `7z t`: 8 arquivos, Deflate, sem ZIP64/AES.
- Artefato local **development build obsoleto** em `dist/1.0.1-rc.4-candidate-final/`
  (ZIP8, Deflate8, 361266881 bytes, CRC/headers/Python extraction+hash/7z t).
  EXE SHA256 `3a113ef60b9133e37bb8585863406572b8108fd809aa65e45a749e000005a41b`,
  ZIP SHA256 `ab912bc2677434309a4028a7acd629bac9c73962542a6e1c9e8148af85b2cab4`.
  Build pipeline unificado não executou localmente: PowerShell/pwsh indisponível;
  artefato local foi gerado com staging/NSIS/ZIP manual verificável. CI ainda
  necessário para artefato imutável de fonte limpa. Não executados: Win7/PS2, UI
  guiada/ZIP pelo WinForms, Corel/RedMon real.
- Segurança: nenhum comando serial, corte físico, alteração de fila/driver/FTDI,
  FlexiSIGN ou COM2. ZIP não inclui bruto. `summary` reporta UNKNOWN em estágios
  sem observação. O cliente desinstalou e não há logs daquela impressão antiga.

## Próximos passos

Atualizar e commitar estado da release; preparar checklist para a sessão guiada
do cliente e coletar o ZIP diagnóstico. Win7/PS2/Corel/RedMon reais continuam
não homologados; não habilitar corte.

# Histórico do diagnóstico anterior — captura vazia / painel rc.3
Branch fix/corel-cut-settings; main7351014 preservada. Sem merge/tag/release final.
Cliente relata rc.2 instalada rapidamente e fila visível no CorelDRAW X6, mas
confirmou lista vazia no aplicativo após imprimir. Captura NÃO comprovada;
causa real pendente de relatório atual, não atribuir por hipótese a ACL/driver.
Solicitado Exportar relatório da instalação existente; ainda não recebido. O cliente
posteriormente desinstalou o software; não há coleta retroativa desse print.

## Marco 2026-10-17 — auditoria do pipeline e coleta somente leitura

- Reconciliado: branch `fix/corel-cut-settings` em `919ec25`; alterações de
  documentação anteriores preservadas. `Logs/` contém apenas RunId rc.1
  `n16722667-4980`, que falhou no LOCK antes de provisionar; não é log do print
  rc.2. O `Foison.rar` não contém estado runtime/ProgramData.
- Código: Receiver lê stdin até EOF, limite64MiB, exige prefixo PS/EOT+PS ou
  envelope UEL/PJL suportado; só publica raw+JSON depois da detecção e escrita.
  UI enumera pares. Falha antes do marcador produz lista vazia, mas não sabemos
  se foi launch, stdin, formato, persistência ou refresh no cliente.
- Fonte RedMon 1.9 confirma child com hStdInput ligado ao pipe e variáveis
  `REDMON_*`; `Output=0` é "Program handles output" em redmonrc.h e log RedMon
  está desativado na config Bridge. Isso prova capacidade/configuração de fonte,
  não execução real no cliente. Error logger do Receiver captura IOException,
  mas não isola todas as falhas de logging; registrar isso como gap, não causa.
- Criados `docs/reverse-engineering/00-current-state.md` e
  `01-spooler-capture-hypotheses.md`, estados H01–H12 e coleta/correlação.
  `Collect-Print-Diagnostics-Win7.ps1` é PS2 syntax-surface, BOM UTF-8,
  somente leitura WMI/Registro/serviço/metadados sem nomes/conteúdo de documentos;
  incluído no staging, NSIS/uninstaller. README/TASKS atualizados.
- Validações: 37 testes Python passaram (`PYTHONPATH=src`), encoding e diff check
  passaram, parser PowerShell 7 aceitou sintaxe. **Não executado em Windows 7/PS2**;
  parser moderno não comprova compatibilidade runtime. Nenhum hardware alterado.
- Próximo passo técnico: instrumentar o Receiver para log de tentativa/bytes/EOF,
  assinatura, persistência/ExitCode sem conteúdo bruto; depois reconstruir
  candidato. Causa do print do cliente exige observação nova; após desinstalação
  não há eventos runtime para coletar retroativamente.

## Decisões / alterações
- Propriedades são PScript5 sem plug-in OEM; painel Foison separado, não dentro
  do Corel. Não alterar driver compartilhado/Flexi/FTDI/COM2 para adicionar UI.
- CutSettings imutável: redução1–100%, rotação ortogonal, espelhos; prévia e HPGL
  usam mesma cópia do original. Ampliações no Corel preservam tolerância0,01mm.
- Alterar ajustes revoga ensaio; alterar porta revoga perfil. Ensaio por hash
  exato do plano de movimento. Limites50mm/margem2mm/confirmações preservados.
- Força/velocidade/ferramenta no painel físico: sem comandos presumidos.
- Coletor/exportação somente leitura: pasta/pares, Spooler/filaWMI/registroRedMon,
  executável/configReceiver. Não imprime, abre COM ou reinicia serviços.
- RAR cliente privado ignorado:633 arquivos/660 entradas;7 componentes idênticos
  byte a byte ao CIrc.2. Libarchive oficial local descompactou todos os arquivos;
  7z Ubuntu não suporta RAR. Não executar nem distribuir o payload recebido.

## Validações / candidato
Código cliente919ec25, versão1.0.1-rc.3, CI39058232989 aprovado Ubuntu+Windows2022.
36Python/67C# por runtime, net48/buildNSIS sem warnings/erros. 25modelosPS,
13processos/ACL Windows emPS5/7 ePS2/CLR2 real Server2022 (nãoWin7);12CMD.
Probe positivo PS2 markers13/25 conferidos. UI/prévia/diálogo pt-BR vistos,
images finais idênticas às revisadas; coletor nativo gerou relatório legível.
Relatório OS do coletor usa Environment.OSVersion, sujeito à versão de
compatibilidade no Windows moderno (CI devolve6.2); não prova SO alvo.
CI inicial39057252361 falhou em novos testes por cp1252; UTF8 explícito corrigiu.
Pipeline completo local bloqueado por NuGet NU1900/rede (também fora sandbox),
não suprimido; CI completo aprovado é origem dos artefatos finais.
Dist/1.0.1-rc.3: ZIP8 arquivosPKZIP/Deflate8,361210504bytes,
SHA2565262fb82c770ecbb834fbfc873e578e099e2406674578477f855b7e6887cf1af.
EXE361392281bytes SHA256b1fc546c413de86f87ce280798838ab82f5300b4a26ad9379fff5ab64d13701a.
CRC/7zt/extração/hashes/NSIS/107 fontes embarcados conferidos. Evidências privadas
locais em artifacts/rc3-final, relatório docs/corel-cut-validation.md.

## Bloqueios / próximo passo
Não pedir reinstalação como tentativa de resolver captura. Receber ZIP Exportar
relatório da rc.2, correlacionar tentativa real e só corrigir causa comprovada.
Se necessário, comando existente Install-Queue-Win7.cmd capture-test (admin)
exercita somente fila→Receiver→vetores sem COM; não executar hardware por teste.
Novo painel/coletor rc.3/captura/serial/hardware NÃO executados no alvo. Sem
movimentos locais. Sem mídia/licençaWin7; VMKVM vazia offline preservada/desligada.
