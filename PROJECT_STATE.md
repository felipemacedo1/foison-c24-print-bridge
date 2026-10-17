## Correção Win7/PS2 — 1.0.1-rc.2 em branch dedicada

- Base main 7351014, branch fix/win7-ps2-process-runner; sem merge ou release final.
- Logs do cliente rc.1: RunId n16722667-4980, OS6.1.7601/PS2, ADMIN aprovado,
  binding de Start-Process falha antes do icacls, ExitCode desconhecido.
- Executor substituído por ProcessStartInfo/C#2/CLR2, streams binários concorrentes,
  timeout/kill do próprio filho e logs com início/PID/UNKNOWN/bytes preservados.
- NSIS corrigido: seek END antes de append preserva BOM/histórico e código real.
- Local: 28 Python, 22 modelos PS, 9 subprocessos reais em pwsh7, API compile
  C#2/net20 sem warnings. CI/build/pacote novo ainda em andamento.
- KVM API12/QMP enabled/present confirmados; QEMU8.2.2 extraído sem serviços.
  Disco vazio32GiB, snapshot blank-before-os; VM pausada testada e encerrada.
- Sem mídia/licença fornecida para instalar Win7. Win7/PS2 corrigido, instalação,
  fila/Corel/hardware NÃO EXECUTADOS aqui. Nenhum movimento/COM foi acionado.
- Evidências locais recebidas ignoradas e preservadas; sem logs de cliente no Git.
- Detalhes: docs/win7-ps2-correction.md; reprodução: docs/win7-vm.md.

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
