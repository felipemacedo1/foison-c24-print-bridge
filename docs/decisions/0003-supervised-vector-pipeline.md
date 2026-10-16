# ADR 0003 — interpretação real e candidato único supervisionado

Decisão: compartilhar domínio C# net48/net8 entre testes e UI; executar
Ghostscript 10.08.0 e MuPDF 1.28.5 oficiais sem rasterização, fora do processo de
captura/spooler. Não escrever um parser parcial de PostScript como se cobrisse
prologs reais PScript/Corel. Conteúdo sem contrato vetorial suportado falha fechado.

Dependências fixadas por SHA256, fontes completas e avisos no instalador.
Pré-requisitos offline Microsoft incluídos. Não empacotar somente capturador
quando faltarem engines/fontes/licenças. O autoteste 20 mm acontece antes da fila.

HPGL só é gerado para transmissão após perfil verificado manualmente na revisão
física. A pesquisa não confirmou resolução nem instruções de todas as C24.
Compatibilidade Win7 dos binários e fila/Corel permanece critério de hardware,
não resultado de build Windows moderno. Não usar driver alternativo/FTDI novo,
filtro/sniffer serial ou comandos de tentativa para contornar incerteza.

Consequência: é possível preparar código e candidato completos, mas não prometer
corte na primeira sessão. Interpretação de recortes/efeitos, compensação de
lâmina e qualidade de produção não fazem parte do primeiro quadrado seguro.
