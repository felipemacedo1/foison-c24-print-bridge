# Estado atual do projeto

Atualizado em: 2026-10-16 16:40
Branch: main
Último commit: ainda não criado

## Objetivo atual

Entregar um primeiro slice portátil e testável: captura segura de stdin,
detecção de formato, persistência de diagnóstico e modelo geométrico para
permitir a futura integração da fila Windows.

## Estado geral

Status: EM DESENVOLVIMENTO

## Implementado

- [x] Ambiente Ubuntu e diretório real documentados.
- [x] Repositório local inicializado na área de trabalho.
- [x] Receptor de fluxo bruto com limites, detecção e relatório.
- [x] Modelo de caminhos, transformações, Bézier e limites.
- [x] Serializador HPGL explicitamente experimental.
- [x] Testes determinísticos sem impressora.
- [x] Fronteira de transporte serial com simulação e fila de um transmissor.

## Em andamento

- [ ] Integrar captura PostScript real da fila de impressão no Windows 7.

## Próxima ação

Escolher e testar em Windows 7 o mecanismo de fila/monitor (RedMon + driver
PostScript ou monitor próprio), então anexar uma captura real do CorelDRAW.

## Bloqueios

- Não há Windows 7/CorelDRAW/plotter disponíveis neste Ubuntu.
- O protocolo e a escala da revisão exata Foison C24 não estão confirmados.
- Não há toolchain .NET/Mono local nem developer pack .NET Framework.

## Testes

- Compilação: NÃO APLICÁVEL (slice Python)
- Testes unitários: PASSOU (`./scripts/test.sh`, 9 testes)
- Testes Windows 7: NÃO EXECUTADO
- Testes físicos: NÃO EXECUTADO

## Decisões recentes

- Captura rejeita formatos desconhecidos; ver `docs/decisions/0001-printing-architecture.md`.
- Protocolo HPGL fica marcado como experimental; ver
  `docs/decisions/0002-vector-intermediate-format.md`.

## Arquivos relevantes

- `src/foison_bridge/receiver.py`
- `src/foison_bridge/geometry.py`
- `src/foison_bridge/hpgl.py`
- `tests/test_bridge.py`

## Como continuar

1. Execute `python3 -m unittest discover -s tests -v`.
2. Empacote o receptor para Windows e configure uma fila de teste sem COM2.
3. Capture um trabalho real do CorelDRAW e valide o relatório antes de criar o
   parser PostScript.
