# Foison C24 Print Bridge — instruções para agentes

## Objetivo

Construir uma ponte local para selecionar uma impressora **Foison C24** no
CorelDRAW X6 (Windows 7 SP1 x64), capturar o trabalho, preservar vetores,
simular o percurso e, somente após validação, transmitir comandos à plotter
pela interface FTDI em COM2.

## Requisitos inegociáveis

- Destino: Windows 7 SP1 x64 e .NET Framework 4.8.
- Desenvolvimento principal: Ubuntu; testes de spooler e hardware exigem
  Windows 7 real.
- Não remover, substituir ou reconfigurar o FTDI, o FlexiSIGN ou outras
  impressoras.
- COM2 é padrão, mas deve ser configurável e nunca aberta à força quando
  estiver ocupada.
- O modo inicial é simulação; não enviar comandos físicos não validados.
- Não declarar compatibilidade ou corte físico sem evidência correspondente.

## Continuidade

Antes de trabalhar, leia `AGENTS.md`, `PROJECT_STATE.md`, `TASKS.md` e o
`README.md`, depois confira `git status`, branch e último commit. Ao terminar,
atualize o estado e tarefas; crie um handoff se houver trabalho incompleto.

## Código e validação

Mantenha domínio, geometria, captura, transporte, serial, UI e instalação
separados. Prefira testes determinísticos sem impressora. Use comandos
documentados no README e registre limitações do ambiente.

## Git

Use commits pequenos e coerentes. Não reescreva histórico, não use operações
destrutivas e não inclua segredos, tokens, credenciais, documentos de usuário ou
logs extensos.

## Comandos atuais

- Testes Python/contratos: `./scripts/test.sh`.
- Build/lint/tipos: `dotnet build src/FoisonC24.Diagnostic -c Release`,
  `dotnet build src/FoisonC24.Provisioner -c Release`,
  `dotnet build src/FoisonC24.WindowsReceiver -f net48 -c Release`.
- E2E portátil: comandos completos em README (engines reais + stdin e serial
  simulados); harness C# em `tests/FoisonC24.CoreTests`.
- Desenvolvimento Windows: `dotnet run --project src/FoisonC24.Diagnostic`
  (tools/ deve estar ao lado do EXE; nenhuma aprovação física persistida).
- Dependências: `python3 scripts/prepare-tools.py`, `python3 scripts/fetch-redmon.py`.
- NSIS e pacote: `./packaging/windows/build-installer.sh` e
  `./scripts/build-distribution.sh`; nenhum ZIP incompleto deve ser entregue.
- Nunca declarar tests simulados como validação Win7/Corel/hardware. Não apagar
  journal ou latch para repetir trabalho cujo estado físico é incerto.
