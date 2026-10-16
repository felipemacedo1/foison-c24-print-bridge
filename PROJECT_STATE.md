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
