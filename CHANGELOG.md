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
- Testes unitários determinísticos em Python.

### Known limitations

- A fila/driver Windows ainda não foi instalada ou testada.
- O parser PostScript e o protocolo/escala C24 ainda não estão validados.
