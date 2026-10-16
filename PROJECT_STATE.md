# Estado atual do projeto

Atualizado em: 2026-10-16 17:05
Branch: main
Último commit: ff6a720

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
- [x] Roteiro honesto de entrega para operador sem conhecimento técnico.
- [x] Fonte do instalador NSIS com verificações de componentes obrigatórios.
- [x] Pacote documental de pré-validação e instruções em português.
- [x] Receptor Windows `net48` e aplicativo WinForms de diagnóstico compiláveis.
- [x] Workflow Windows para compilar componentes e produzir candidato NSIS.
- [x] SDK .NET local e NSIS local instalados sem privilégios administrativos.
- [x] Workflow executado: componentes Windows compilaram; geração do instalador
  foi bloqueada corretamente pela ausência do INF/PPD PostScript.
- [x] Run Actions `38959064970` concluiu; artefatos do receptor e diagnóstico
  foram baixados e inspecionados.
- [x] Provisionador real: instala RedMon, cria/remove `RPT1:` via XcvData,
  detecta driver PostScript e registra a fila por PrintUIEntry com rollback.
- [x] NSIS extrai os componentes antes de executar o provisionamento e gera
  `FoisonC24-Teste-Setup-x64.exe` localmente.

## Em andamento

- [ ] Integrar captura PostScript real da fila de impressão no Windows 7.
- [ ] Gerar `FoisonC24-Setup-x64.exe` após obter/validar receptor, monitor e driver.

## Próxima ação

Escolher e testar em Windows 7 o mecanismo de fila/monitor (RedMon + driver
PostScript ou monitor próprio), então anexar uma captura real do CorelDRAW.

## Bloqueios

- Não há Windows 7/CorelDRAW/plotter disponíveis neste Ubuntu.
- O protocolo e a escala da revisão exata Foison C24 não estão confirmados.
- Não há ambiente Windows para instalar/validar a fila.
- A rotina ainda precisa ser executada em Windows 7; depende de driver
  PostScript/PScript presente no computador.
- O runner GitHub Actions pode compilar o candidato, mas isso não equivale a
  teste de instalação no Windows 7.

## Testes

- Compilação Python: PASSOU; receptor/diagnóstico net48: PASSOU localmente e no
  run Actions `38959064970`
- Testes unitários: PASSOU (`./scripts/test.sh`, 9 testes)
- Testes Windows 7: NÃO EXECUTADO
- Testes físicos: NÃO EXECUTADO
- Distribuição: candidato NSIS compilado localmente; instalador NÃO VALIDADO
  no Windows 7

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
4. Executar o workflow Windows para obter os executáveis e validar
   instalação/criação da fila em Windows 7 real após resolver o INF/PPD.
