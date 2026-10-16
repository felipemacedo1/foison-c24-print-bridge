# Changelog

## Unreleased

### Added

- Estrutura inicial e documentação de continuidade.
- Receptor seguro de stdin com arquivos brutos e relatórios JSON.
- Modelo geométrico com linhas, Bézier, transformações e limites.
- Simulação textual e gerador HPGL explicitamente não validado.
- Configuração serial validada, transporte injetável em simulação e fila de
  trabalho de um único transmissor.
- Receptor `net48` Windows e aplicativo WinForms para exportar diagnóstico.
- Workflow de build Windows e material RedMon 1.9 x64/GPLv3 verificado.
- Componentes Windows compilados no run `38959064970`; o instalador foi
  omitido com status explícito por falta de INF/PPD PostScript redistribuível.
- Candidato NSIS experimental passa a extrair componentes e executar o
  provisionador RedMon/PrintUIEntry com rollback; não validado ainda no
  Windows 7.
- Testes unitários determinísticos em Python.
- Provisionamento revisado para preservar filas existentes, detectar conflitos
  com `EnumPorts`, usar portas exclusivas `FOISONC24n:` e registrar manifesto de
  propriedade em `ProgramData`.
- Seleção de driver PostScript agora exige uma única correspondência e INF
  verificável; rollback e desinstalação removem somente recursos próprios.
- Instruções do operador atualizadas para o candidato instalável experimental;
  14 testes determinísticos passaram e o provisionador net48 foi recompilado.

### Known limitations

- A fila/driver Windows ainda não foi instalada ou testada.
- O parser PostScript e o protocolo/escala C24 ainda não estão validados.

## Candidato de primeira sessão acompanhada — 2026-10-16

- Pipeline Windows real PostScript → GS/PDF vetorial → MuPDF → geometria mm →
  prévia/HPGL → serial, condicionado à evidência de revisão e autorizações.
- Limites, cancelamento/timeouts, exclusividade, journal e bloqueio após incerteza.
- Corrigidos nome RedMon (`Redirected Port`), configuração binária XcvData/read-back,
  descoberta/instalação inbox PScript5 x64 e rollback/desinstalação restritos.
- Distribuição offline completa, fontes/licenças, pré-requisitos e roteiro Flexi
  FILE sem sniffer/alteração FTDI. CI ampliado com testes reais dos engines e mocks.
- Win7/CorelDRAW/revisão/protocolo físico/corte continuam NÃO validados.
