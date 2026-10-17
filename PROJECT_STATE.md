# Ativo 2026-10-17 — candidato diagnóstico de captura 1.0.1-rc.4

Objetivo: transformar as hipóteses da lista vazia em observações verificáveis
por uma tentativa guiada, sem corte/COM. Código validado em CI; prerelease pendente.

- Receiver registra START/identidade/PID/argumentos e variáveis RedMon saneadas,
  stdin, primeiro byte, EOF/total, hash, formato, gravação, marcador, erro/stack,
  duração e exit code. Tentativas rejeitadas salvam JSON com hash/causa em
  captures/attempts; bytes rejeitados não são guardados. Log tenta ProgramData,
  depois saída de captura/TEMP. Captura aceita mantém convenção raw+json.
- `GuidedDiagnosticForm` executa Experimento A por escrita binária direta em
  stdin com fixture quadrado e parser real; Experimento B registra WMI process
  start/stop, fila/jobs, estado RedMon e metadados enquanto o operador imprime.
  Lista/prévia exigem confirmação manual. O ZIP é allowlist sem arquivos brutos.
- `FoisonC24-Diagnostico.cmd` executa a UI; NSIS inclui o arquivo e cria atalho
  no menu Iniciar. `FoisonC24-Diagnostico.exe --guided-diagnosis` inicia fluxo.
- Receiver usa SHA-256 incremental; mesmo entrada acima do limite é drenada até
  EOF para registrar tamanho/hash completos, sendo rejeitada sem persistência do
  excedente. Falhas de logging não mascaram o código de saída da captura.
- Testes locais: builds Receiver net48/net8, Diagnostic net48, Provisioner
  net48, CoreTests net8 sem warnings; 38 Python e encoding gate passaram; API
  compile C#2/net20 passou. Harness C# E2E 73 checks passou (GS + MuPDF real via
  Wine, quadrado PS 20×20, stdin binário, formato desconhecido sem raw, serial
  apenas simulada). NSIS 3.09-4 sem warnings; payload chave extraído e comparado
  por SHA; ZIP PKZIP Deflate, 8 arquivos, CRC/extract/hash/7z passaram.
- Workflow Windows ampliado com smoke end-to-end do gerador do ZIP de diagnóstico
  sintético, validação de integridade/allowlist e confirmação de UNKNOWN; Actions
  passou. O contrato Python foi corrigido após variável não inicializada; 38/38.
- Primeiro Actions `39069412287` detectou que o teste Windows esperava logs na
  pasta da captura, mas a precedência correta do Receiver em Win32 é ProgramData.
  Harness agora correlaciona RunId e pesquisa os destinos ProgramData/captura/TEMP;
  73 checks passaram localmente. Correção commit `7031948`, enviada; Actions
  `39069926356` em execução.
- Segundo Actions `39069926356`: build/package/NSIS/E2E/visual passaram; smoke
  do ZIP criou e verificou 9 itens via 7z, mas comparação de acento falhou por
  literal Unicode dentro de script Windows PowerShell. Alterado para construir
  U+00C3 por codepoint (`6d0d815` enviado).
- Actions `39070334614` passou o smoke após essa correção. Actions
  `39070594835` (commit `828bcec`) passou Ubuntu+Windows 2022, build Release,
  testes, NSIS, ZIP/extração nativa, UI e ZIP de diagnóstico sintético com
  allowlist e UNKNOWN. Esse run é sobre o código/candidato; não prova Win7 real.
- Artifact baixado e inspecionado: `validation.json` confirma 1.0.1-rc.4, commit
  `828bcecc2e1b0b46b73d99e8cc357c8a0d260948`, dirty=false, 8 arquivos. ZIP
  361267595 bytes, PKZIP Deflate8, `zipfile.testzip()` limpo; SHA256
  `b1ea7e7255bbd44cc50a0a45c93eca3427940d4a0d61712fd43666055151ca48`.
  Instalador SHA256 `85c3dd8699282ece4dc28b958896fee6f309da60583c060ea4cace7f3d89c1c3`.
  Win7/Corel/RedMon real/hardware NOT EXECUTED.
- Candidate development-build local obsoleto `dist/1.0.1-rc.4-candidate-final` (8-entry
  PKZIP Deflate,361266881bytes, CRC/extract/hash/7z checked): EXE SHA256
  `3a113ef60b9133e37bb8585863406572b8108fd809aa65e45a749e000005a41b`, ZIP
  SHA256 `ab912bc2677434309a4028a7acd629bac9c73962542a6e1c9e8148af85b2cab4`.
  `scripts/build-release.py` inteiro não rodou localmente por ausência de
  PowerShell 7; o instalador/ZIP foram criados em staging local com o mesmo
  NSIS/Deflate e verificados. O artifact oficial é o run Actions `39070594835`,
  com hashes acima. Não executados: Win7/PS2, Corel/RedMon real.
- Atenção: os arquivos locais e hashes da pasta acima são anteriores às últimas
  mudanças de hashing incremental e smoke ZIP; estão obsoletos, não distribuir.
- Próximo: commit do estado, criar `v1.0.1-rc.4` no commit exato `828bcec` (CI
  aprovado) e promover somente prerelease após validar os checksums remotos.
  Não afirmar captura corrigida nem homologação antes da sessão real.

## Candidato rc.3 conferido — não corrige captura por suposição

Código919ec25, branch fix/corel-cut-settings, CI39058232989 aprovado. 36Python,
67C# por runtime, builds/NSIS/ZIP, UI e coletor somente leitura aprovados nas
condições documentadas em docs/corel-cut-validation.md. Dist/1.0.1-rc.3 contém
os bytes CI conferidos (ZIP8 arquivos Deflate8,361210504bytes). Fonte embarcada
107 arquivos conferida. Sem merge/tag/release final.
**Pendência principal:** cliente confirmou lista vazia depois de imprimir.
Aguarda-se Exportar relatório atual; não declarar captura ou corte funcionais.
Não reinstalar por tentativa nem modificar recursos externos. Físico preservado.

## Retorno posterior: fila visível, captura NÃO aparece

Usuário confirmou lista vazia no aplicativo depois de imprimir. Não declarar
cadeia funcional nem corte desbloqueado operacionalmente: falta evidência
RedMon/Receiver/capturas. Solicitado relatório da instalação existente, sem
reinstalar por tentativa. Coletor somente leitura rc.3 acrescenta contagens,
WMI/Spooler/registroRedMon e localização do Receiver ao relatório exportável.
CI39057524445 passou o painel anterior; coletor em validação no STATUS.

## 2026-10-17 — retorno cliente / painel de corte rc.3

Cliente relata instalação rc.2 rápida e impressora reconhecida no CorelDRAW X6.
Evidência: relato + Foison.rar RAR5,208658971 bytes,660 entradas/633 arquivos;
sete componentes principais idênticos byte a byte ao instalador CIrc.2 a173d5e.
Descompressão integral dos arquivos com libarchive passou (7z Ubuntu não suporta
RAR). Arquivo privado ignorado, sem executar binários recebidos nem publicá-los.
Não foram recebidos nesta evidência testes de captura/vetores/COM/corte.

Causa do relato sobre propriedades: fila usa PScript5 genérico, sem plug-in de
propriedades OEM de corte. Aplicativo Foison existente faz prévia/envio. rc.3
explicita painel de configurações de corte separado; não promete configurar
força/velocidade via comandos não comprovados. Branch fix/corel-cut-settings,
main preservada; validações/build desta etapa em andamento no STATUS.

## Candidato 1.0.1-rc.2 — correção PS2/CLR2 e distribuição conferida

- Branch fix/win7-ps2-process-runner; main preservada em7351014. Código cliente
  **a173d5e**, [CI39051351567 aprovado](https://github.com/felipemacedo1/foison-c24-print-bridge/actions/runs/39051351567). Sem tag/release final/merge.
- Falha rc.1 comprovada em logs: binding Start-Process em LOCK, antes de icacls;
  substituído por executor C#2/CLR2 com captura raw concorrente e timeout.
- Execução real CLR2 encontrou também SHA.Dispose (corrigido para Clear) e erro
  -File com exit0: bootstrap exige comprovante nonce/run/op, sem prova=>74.
- NSIS append/BOM/histórico/códigos reais e launch failure9009 corrigidos.
- 32 Python;25 modelos (também no PS2 real);13 casos reais de processos/ACLs em
  PS2.0/CLR2.0.50727.9179 no **Server2022**, além de PS5/7. Não é Win7 validado.
- 12 casos CMD;52 checks C# por runtime;net48/NSIS sem warnings/erros;UI/RedMon
  isolado/Shell ZIP aprovados. Gate positivo e raw conferidos, não apenas exit0.
- Candidato exato CI em dist/1.0.1-rc.2, ZIP8 arquivos Deflate8,361187683 bytes,
  SHA256454c997985ecd1347b4bbfcc2380690893c4128974549d2f0bf72cdade32d9d7.
- EXE361368940 bytes, SHA256408c835bdc0ce64f2404a8ade5cee07cfb6aefd50b8585fe5276ebc3af2ae9f3.
- CRC/7z/extração completa/hashes/NSIS e103 fontes conferidos; logs do cliente
  preservados/ignorados, nunca empacotados. Relatório docs/win7-ps2-correction.md.
- KVM/VM vazia offline verificados e desligados, sem mídia Windows licenciada.
  Win7/CLR2.8803 do cliente, instalação/fila/Corel/serial/hardware ainda pendentes.
  Físico desabilitado por padrão; não enviar movimentos nem alterar Flexi/FTDI.

## Histórico anterior (não representa o estado atual da correção)

## Release 1.0.1-rc.1 publicada — candidato, não estável

- [Release](https://github.com/felipemacedo1/foison-c24-print-bridge/releases/tag/v1.0.1-rc.1),
  tag/código cliente b2df7cd; CI 38993143001 e promoção 38995440164 aprovados.
- EXE 361331246 bytes; ZIP PKZIP/Deflate 8 com 8 arquivos, 361149977 bytes.
  ZIP SHA256 a3aa2cc69a1c432a0b1390a61abff6830a94cb9b4ce8fc25b18e49d76c5a6ee9.
- Provisionamento/ownership/rollback/estado .properties/migração, logging desde CMD,
  códigos nativos, Unicode/BOM/CRLF, NSIS sem falso sucesso e pipeline único integrados.
- 25 Python do candidato (26 atuais com promoção), 22 modelos PS, 52 C# por runtime;
  builds/net48/NSIS sem warnings/erros; APIs RedMon/erros/subprocessos/UI/Shell ZIP
  reais no Windows 2022. ZIP/NSIS extraídos e hashes conferidos também localmente.
- Evidências de falha e imagens anexadas à release. Código de promoção verifica
  run/SHA/tag/ZIP/hashes/PE e digests GitHub, sem rebuild/overwrite, só prerelease.
- **Win7/PowerShell 2/CorelDRAW/Foison/serial/corte físico NÃO EXECUTADOS.**
  Físico bloqueado por padrão; não é compatibilidade comprovada nem corte garantido.
- Matriz, hashes, causas-raiz e limites completos em docs/release-validation.md.
  Próximo passo: uma sessão acompanhada no alvo; se falhar qualquer condição,
  preservar FlexiSIGN/configuração e não enviar movimentos.

## Histórico da correção versionada — 1.0.1-rc.1

- Auditoria inicial: main d36eeb5, sem tags/releases; SDK implícito 1.0.0.0.
- ZIP anterior é PKZIP válido (8 arquivos, Deflate, CRC Python/7z); causa do
  sintoma do cliente não reproduzida. Relatório docs/previous-zip-audit.json.
- Implementados monitor antes de portas, admin/PS64, estado .properties atômico,
  migração com intenção persistida, markers/fingerprint, rollback conservador,
  logs correlacionados desde CMD e NSIS com verify independente.
- UTF-8 BOM NSIS/PS/TXT, idioma PortugueseBR, charset explícito, bootstrap ASCII;
  testes de texto e pipeline unificado de build/extração/hashes/ZIP convencional.
- Evidência local parcial: 23 Python, 22 modelos PS e 52 checks C# reais/simulados;
  builds net48 sem warnings. Build NSIS/pacote final e CI em andamento.
- Win7/PS2/CorelDRAW/serial/Foison não executados. Corte físico bloqueado.
- Matriz e limites: docs/release-validation.md. Publicação somente prerelease
  após concluir verificações aplicáveis; não há compatibilidade real comprovada.

# Investigação do spooler — situação 2026-10-17

Prioridade ativa: localizar a ausência de trabalhos na lista, sem avançar para
protocolo físico. Cliente relata fila no Corel e lista vazia; posteriormente
desinstalou o Bridge. Não há evidência runtime retroativa do print. O RAR contém
arquivos de instalação, não ProgramData; `Logs/` disponível é uma falha rc.1 em
LOCK anterior ao provisionamento, não a instalação rc.2.

`docs/reverse-engineering/00-current-state.md` registra a cadeia etapa a etapa:
fila visível é relato confirmado; spool JobId, RedMon launch, bytes stdin,
persistência e refresh UI são não comprovados no cliente. Fonte RedMon confirma
pipeline de stdin como capacidade do produto, mas não a execução no alvo.
`docs/reverse-engineering/01-spooler-capture-hypotheses.md` contém H01–H12 e
plano de correlação.

Preparado coletor PS2 read-only `packaging/windows/Collect-Print-Diagnostics-Win7.ps1`
para incluir no próximo setup (WMI/Registro/Spooler/processos/metadados, sem
documento bruto/título, alterações ou COM). Testes sintáticos atuais usaram
PowerShell 7; execução Win7/PS2 não feita. Próximo passo é instrumentação do
Receiver por tentativa e uma única coleta correlacionada em Windows 7; corrigir
somente o primeiro estágio observado falhando. Sem root cause ou corte declarado.

# Estado do projeto — candidato para primeira sessão acompanhada

Atualizado: 2026-10-16. Código do candidato: **48bdc05**.
Checkout: `foison-c24-print-bridge/` dentro do workspace `printer-brigde`.
O diretório pai não tinha código/Git válido e foi preservado; a base existente
`610e5ec` foi recuperada do GitHub, sem alterar o checkout da Área de Trabalho.

## Objetivo / aceite

Distribuição única com impressão, interpretação vetorial real, prévia em mm,
HPGL e serial, com aprovações explícitas. Maximizar a chance do primeiro quadrado
20×20 mm sem prometer compatibilidade física nem entregar captura-only.
Status: **candidato completo gerado e testado em software; NÃO validado no hardware**.

## Implementado

- Domínio C# compartilhado net48/net8, WinForms em português e Receiver binário.
- PS real → Ghostscript 10.08.0 → PDF vetorial → MuPDF 1.28.5 → geometria mm.
  Sem rasterização. Envelopes EOT/PJL estritos; afins, escala, Y-up, cúbicas com
  tolerância 0,01 mm e caminhos abertos/fechados. Clips retangulares que não
  alteram caminhos são aceitos; imagens/efeitos/recortes intersectantes e
  operações desconhecidas bloqueiam, sem omitir conteúdo silenciosamente.
- Prévia e medição; plano HPGL restrito IN/PA/PU/PD, sem unidade presumida.
  Perfil de revisão só aprovado por desenvolvedor na sessão. Nenhum arquivo
  ou fixture do simulador habilita o físico automaticamente.
- COM configurável (COM2 padrão), 38400/8N1/Xon-Xoff, exclusividade, timeout,
  cancelamento, sem retry/reconexão/forçar porta. Porta ocupada não é atribuída
  ao Flexi com certeza; diagnóstico lista processos potencialmente relevantes.
- Área medida ≤50×50 mm, margem 2 mm, sem scale-to-fit; confirmação por plano,
  lâmina removida para movimento, ensaio observado antes do mesmo corte.
- Lock/journal por hash/modo e latch persistido antes do primeiro byte, inclusive
  contra crash. Interrupção incerta bloqueia novos envios. Cancelar no PC não
  garante parar o buffer da máquina; PAUSE/OFFLINE/procedimento real são exigidos.
- Provisionamento automático pede MS Publisher Imagesetter pelo INF do Windows
  e verifica PScript5 x64; RedMon usa porta FOISONC24n: e XcvDataW com read-back.
  Nome correto `Redirected Port` e RECONFIG 6180 bytes/version 190 conferidos
  no fonte original. Rollback/desinstalação limitados a recursos registrados;
  RedMon compartilhado, FTDI, FlexiSIGN e portas alheias são preservados.
- Instalador offline com engines/pré-requisitos oficiais fixados por hash,
  licenças/fontes correspondentes, autoteste 20 mm antes da fila. Inclui os
  companions exigidos pelo setup RedMon; nunca executa unredmon64.exe.
- Procedimento autorizado Flexi FILE separado de PRT, sem sniffer/filtro/FTDI;
  disponibilidade e execução no FlexiSIGN 12 real ainda não verificadas.

## Validações concluídas

Workflow **38972159423 — SUCCESS**, código 48bdc05:
https://github.com/felipemacedo1/foison-c24-print-bridge/actions/runs/38972159423

- Ubuntu: 14 testes Python/contratos e 52 checks C# com GS/MuPDF reais.
- Windows 2022: mesmos 52 checks em net48 com engines exatos do pacote.
- E2E: stdin real do Receiver (fronteira RedMon simulada) → conversão real →
  geometria → HPGL → serial simulada; igualdade SHA256 do fluxo binário exigida.
- Geometria, limites, aprovações, porta ocupada, concorrência, idempotência,
  cancelamento durante envio, latch/crash e rejeições de conteúdo/loop testados.
- Spooler Windows 2022 real: AddPort/GetConfig/SetConfig/read-back/EnumPorts e
  DeletePort/limpeza passaram. Isso NÃO testa a fila/driver/Corel em Windows 7.
- Build net48: zero warnings/erros no CI; sintaxe PowerShell e NSIS /WX passaram.
- UI smoke e imagem revisada: quadrado 20×20 mm visível; botões físicos bloqueados.
- ZIP/instalador CI baixados: CRC/ZIP/SHA256 e installer interno conferidos;
  630 entradas NSIS testadas. Fonte própria embarcada corresponde a todos os
  arquivos rastreados do commit (diferenças textuais apenas CRLF do Windows).
- Primeiro CI encontrou BOM no stdin simulado do Framework; corrigido no harness
  sem relaxar o receptor; os runs posteriores aprovados comprovam o fluxo binário.
- Auditoria NuGet local indisponível (NU1900 por rede). O CI tem avisos de
  depreciação dos actions/Node; não equivalem a erro do produto nem auditoria do SO.

## Entrega única para o cliente

Em `dist/`, bytes exatos baixados do CI aprovado (substituem o build local):
- `FoisonC24-Setup-x64.exe` — 351167140 bytes.
- `FoisonC24-Cliente-Win7-x64.zip` — 351266680 bytes; instalador, instruções,
  checklist do desenvolvedor, quadrado SVG, checksums e identificação do build.
- `checksums.sha256`; `UI-preview.png` é evidência para o desenvolvedor.

SHA256 do instalador:
`48dd511435cad211d2a8f17eb2daebc9e0974ab0aeea5fd452bc7c5e4abd2d8a`

## Bloqueios / limites que permanecem

Não há Windows 7 real, CorelDRAW X6, FlexiSIGN 12 ou Foison nesta bancada.
NÃO executados: instalação/fila/PScript/Corel em Win7, impressão Corel real,
serial FTDI física, protocolo/resolução da revisão, origem/área ou corte.
Fixtures próprias não são capturas Corel. O manual de família não comprova
unidades e instruções da revisão exata; sem evidência suficiente, NÃO mover.
Clipping que altera caminhos, compensação de arrasto/lâmina e qualidade de
produção não fazem parte deste primeiro ensaio simples. Pré-requisitos Microsoft
podem exigir atualizações/reinicialização do Windows: não prometer sessão sem reboot.

## Próximo passo (hardware, não nova instalação por tentativa)

Seguir `packaging/windows/PRIMEIRA-SESSAO.md`: comprovar protocolo/escala por
fonte técnica/captura FILE autorizada, instalar candidato, imprimir quadrado,
conferir prévia, medir origem/área, confirmar comunicação, ensaio sem lâmina e
somente então autorizar o primeiro corte. Se algo falhar, exportar diagnóstico,
não reenviar estado incerto e preservar a configuração funcional do FlexiSIGN.
