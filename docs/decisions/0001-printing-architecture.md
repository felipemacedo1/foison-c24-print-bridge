# ADR-0001 — Arquitetura de impressão

Status: Accepted (primeira etapa)
Data: 2026-10-16

## Contexto

O CorelDRAW precisa selecionar uma fila Windows real e entregar o trabalho sem
exportação manual. O ambiente de desenvolvimento não contém Windows 7.

## Decisão

Separar captura, interpretação e corte. Investigar primeiro PostScript
redirecionado por uma fila/monitor, mantendo um receptor que lê stdin, salva
bytes e produz diagnóstico antes de interpretar vetores.

## Justificativa

Preserva o fluxo nativo de impressão e permite provar a chegada do trabalho
antes de envolver protocolo ou COM2. O receptor pode ser testado com fixtures.

## Consequências

Driver, monitor, instalação e comportamento do spooler ainda dependem de teste
no Windows 7. O receptor não promete que todo PostScript seja vetorial.

## Alternativas rejeitadas

Macro VBA, PlotCalc, CoCut e exportação para FlexiSIGN não atendem ao fluxo
independente exigido.
