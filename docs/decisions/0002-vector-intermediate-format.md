# ADR-0002 — Formato intermediário vetorial

Status: Proposed
Data: 2026-10-16

## Contexto

O formato que chegará da fila ainda não foi observado no Windows real.

## Decisão

Usar um modelo interno de caminhos (`Path`/`Segment`) independente do formato
de entrada. A primeira detecção reconhece PostScript pelo cabeçalho e rejeita
bytes desconhecidos; um parser seguro de subconjunto será implementado após
captura real.

## Consequências

Não há falsa promessa de que RAW é HPGL. A extração completa de curvas,
transformações e clipping permanece pendente.
