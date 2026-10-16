# Estado do projeto — primeira sessão acompanhada

Atualizado: 2026-10-16. Base recuperada do GitHub: `610e5ec`.
Checkout atual: subpasta `foison-c24-print-bridge` do workspace printer-brigde;
o diretório pai não tinha código/Git válido. Não foi sobrescrito.

## Objetivo e aceite

Preparar uma única distribuição com impressão, interpretação vetorial real,
prévia em mm, geometria/HPGL e serial, com autorizações explícitas. Maximizar
chance do quadrado 20×20 mm na primeira sessão sem prometer hardware compatível.
Não entregar captura-only como cortador pronto.

## Implementado nesta etapa

- Domínio C# compartilhado net48/net8 (não um protótipo Python separado).
- PostScript real interpretado por Ghostscript, PDF intermediário vetorial e
  trace MuPDF; sem rasterização e sem regex fingindo interpretar prologs.
- CTM, pontos→mm, orientação, curvas cúbicas ≤0,01 mm, caminhos abertos/fechados.
  Raster, clipping intersectante/efeitos, operação desconhecida e múltiplas páginas falham fechado.
- Prévia WinForms portuguesa, medição em mm e seleção de captura pronta.
- Gerador real restrito a IN/PA/PU/PD; resolução sem default e perfil de revisão
  aprovado pelo desenvolvedor por sessão. Pesquisa não comprovou revisão exata.
- Serial COM configurável (COM2 default), 38400/8N1/Xon-Xoff, timeout/cancelamento,
  porta exclusiva; sem liberar à força, sem retry/reconnect.
- Confirmações por plano/operador, lâmina removida para movimento; corte exige
  ensaio observado do mesmo desenho/perfil. Mudança de COM invalida perfil.
- Limites físicos medidos ≤50×50 mm, margem 2 mm; sem scale-to-fit/homing implícito.
- Journal persistente por hash/modo, lock exclusivo e latch após interrupção.
  Cancelamento no PC não garante parar buffer físico; painel/manual obrigatórios.
- Provisionamento solicita modelo inbox exato MS Publisher Imagesetter e verifica
  PScript5 x64. Corrigido nome real do monitor: `Redirected Port`, conferido no
  fonte RedMon. GetConfig/SetConfig via XcvDataW com read-back, sem aspas ambíguas.
- Corrigido rollback que era interrompido por Write-Error sob Stop; desinstalador
  não remove porta usada por outra fila nem apaga manifesto se remoção falhar.
- Captura com GUID e marcador ready atômico; conversão somente no processo do
  usuário, nunca no spooler. Não iniciar UI elevada pelo instalador.
- Scripts de pacote falham se qualquer componente real/fontes/licença faltar.
  Engines/pré-requisitos oficiais fixados por SHA256; fontes correspondentes
  incluídas. Instalador offline pode exigir reboot de pré-requisitos Microsoft.
- Procedimento Flexi FILE separado (não Save to file/PRT), sem sniffer/filtro/FTDI;
  ainda não executado no FlexiSIGN 12 real.

## Evidência já obtida

- 14 testes Python/contratos passaram.
- 37 checks C# passaram no Ubuntu, incluindo GS/MuPDF reais, quadrado 20 mm,
  curvas/procedimentos/afins e rejeições, loop cancelado, stdin de receptor real
  e serial simulada. Novos casos adicionais estão em execução/revisão.
- UI/receptor/provisionador net48 compilaram; builds posteriores às últimas
  mudanças e validação CI ainda pendentes.
- Downloads oficiais conferidos por SHA256; Ghostscript também confrontado com
  SHA512SUMS oficial. Binários de terceiros não foram executados no Win7.
- Auditoria NuGet local indisponível (NU1900 por rede); não declarar auditoria limpa.

## Bloqueios e limites

Sem Windows 7 real, CorelDRAW X6, FlexiSIGN 12 ou Foison. NÃO executados:
instalação no SO alvo, spooler/RedMon/XcvData reais, impressão Corel/PScript real,
serial física, protocolo/resolução/revisão, origem/área física ou corte.
Fixtures próprias não são capturas reais do Corel. Clipping intersectante/efeitos e compensação
de arrasto/lâmina não suportados neste primeiro ensaio; não é qualidade de produção.
Sem evidência suficiente na sessão, parar sem qualquer movimento.

## Próximos passos

Finalizar validação ampliada, compilar NSIS/pacote, revisar diff/artefatos, fazer
commits e push autorizados, executar Actions Ubuntu + net48/engines Windows e
inspecionar artefatos. Atualizar aqui resultados reais/URLs/checksums.

## Último checkpoint
Run 38969791489: Ubuntu aprovado, net48/engines vetoriais aprovados até o teste
de stdin. Falha no pipe simulado: provável preâmbulo de encoding do Framework;
harness corrigido para binário sem BOM com igualdade SHA256 obrigatória.
Nova matriz local e repetição CI em andamento. Envelopes EOT/PJL e clips
retangulares sem interseção adicionados; clips que alteram caminhos bloqueiam.
Latch de segurança agora é persistido antes do primeiro byte, inclusive contra
crash/falha ao registrar o erro.
