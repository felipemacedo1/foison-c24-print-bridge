# Foison C24 Print Bridge

Ponte local em desenvolvimento para o fluxo **CorelDRAW X6 → Arquivo →
Imprimir → Foison C24** em Windows 7 SP1 x64. O projeto captura o fluxo de
impressão, preserva o original para diagnóstico, converte geometria vetorial
para um modelo comum e oferece simulação antes de qualquer transmissão à
plotter Foison C24 via FTDI/COM2.

> **Estado honesto:** o receptor, modelo geométrico, simulador textual e
> conversor HPGL experimental já possuem testes no Ubuntu. A criação da fila
> de impressão no Windows, a interpretação completa de PostScript, o protocolo
> exato da revisão C24 e o corte físico ainda não foram validados. O modo
> físico permanece desabilitado por padrão.

## Decisões iniciais

- Alvo operacional: Windows 7 SP1 x64, .NET Framework 4.8, CorelDRAW X6 x64.
- Padrão serial inicial configurável: COM2, 38400 8N1, Xon/Xoff.
- A entrada primária planejada é PostScript redirecionado por uma fila de
  impressão. Bytes desconhecidos são rejeitados, nunca tratados como HPGL.
- O receptor portátil atual usa Python 3 para testes e captura; o componente
  Windows/driver será separado quando o teste no Windows estiver disponível.
- HPGL e escala da C24 são **não validados** até existir documentação ou uma
  captura autorizada do FlexiSIGN/Production Manager.

## Ambiente Ubuntu

Descoberta inicial (2026-10-16):

| Item | Resultado |
|---|---|
| Sistema | Ubuntu 24.04.5 LTS x86_64 |
| Shell | `/usr/bin/zsh` |
| Git | 2.55.0 |
| GitHub CLI | 2.45.0, autenticado |
| Python | 3.12.3 |
| .NET/Mono/MSBuild | não instalados |
| Wine | instalado |
| Compiladores C/C++ | gcc, g++, clang |
| Projeto | `/home/felipe-macedo/Desktop/foison-c24-print-bridge` |

O Ubuntu atual não tem referência assemblies do .NET Framework. Não se deve
confundir os testes portáteis com compatibilidade comprovada no Windows 7.

Desde 2026-10-16, o SDK .NET 8 foi instalado em `~/.dotnet` e NSIS 3.09 em
`~/.local/foison-tools/nsis` (sem privilégios
de administrador) e os projetos `net48` do receptor e do diagnóstico compilam
no Ubuntu usando o pacote de reference assemblies. Isso prova compilação, não
execução/compatibilidade no Windows 7.

## Desenvolvimento e testes

```bash
python3 -m unittest discover -s tests -v
printf '%s\\n' '%!PS-Adobe-3.0' '%%EOF' | \
  python3 -m foison_bridge.receiver --output-dir /tmp/foison-captures
python3 -m foison_bridge.simulator
```

O receptor grava `job-*.raw` e um relatório JSON. O processo termina com erro
para formato desconhecido, entrada vazia ou dados acima do limite configurado.

## Próxima validação Windows

1. Construir/empacotar o receptor para Windows 7 x64 em ambiente com toolchain
   compatível.
2. Validar uma fila de teste com driver PostScript/RedMon ou uma alternativa
   de monitor de porta suportada; nenhum desses componentes foi presumido como
   instalado.
3. Imprimir um quadrado no CorelDRAW e anexar o relatório do receptor.
4. Somente depois validar parsing vetorial e protocolo/escala com simulador.
5. Testar COM2 apenas com FlexiSIGN fechado e `physical_cut_enabled=false`
   até aprovação explícita do operador.

O workflow `.github/workflows/windows-build.yml` produz os executáveis em um
runner Windows moderno e tenta gerar um instalador candidato. O artefato não
será considerado funcional até a fila ser criada e testada no Windows 7.

O build do instalador exige ainda um INF/PPD do driver PostScript que possa ser
redistribuído legalmente e uma rotina comprovada de criação da fila. Esses
arquivos não são inventados nem substituídos por um driver aleatório.

O histórico do build Windows e os artefatos publicados estão documentados em
`docs/windows-build.md`.

Consulte `PROJECT_STATE.md`, `TASKS.md` e `docs/architecture.md` para a fonte
de verdade operacional.

## Entrega para usuário sem conhecimento técnico

O instalador experimental agora é gerado como
`packaging/windows/FoisonC24-Teste-Setup-x64.exe` e pelo workflow Windows.
Ele só deve ser entregue para teste controlado: exige Windows 7 SP1 x64,
detecta um driver PostScript/PScript já instalado, cria uma porta exclusiva `FOISONC24n:` via RedMon e
mantém COM2/corte físico intocados. O roteiro de entrega está em
`docs/entrega-para-usuario.md`.

O candidato local é um binário Windows compilado pelo NSIS, mas ainda não foi
instalado/testado em Windows 7. Não declare a fila como aprovada antes desse
teste.
