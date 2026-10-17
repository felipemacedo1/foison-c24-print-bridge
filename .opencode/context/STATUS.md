# Objetivo
Corrigir falha real Win7 SP1/PowerShell 2 no executor e preservar diagnóstico.
Branch fix/win7-ps2-process-runner; base main 7351014. Sem merge/release estável.

## Evidências / decisões
- Logs locais recebidos (não versionar): RunId n16722667-4980, OS 6.1.7601 SP1 x64,
  PowerShell 2.0, ADMIN aprovado; LOCK falha ParameterBindingException em
  Start-Process antes de executar icacls. ExitCode desconhecido, não zero.
- NSIS FileOpen a abre no início; Log sem FileSeek END sobrescreve BOM/histórico.
  Corrigir separadamente da falha de parâmetros. UTF-8 PS recebido está íntegro.
- Substituir Start-Process no executor por ProcessStartInfo/Process com captura
  binária concorrente e limites de tempo, usando APIs CLR2; sem elevação extra.
- Preservar ownership, rollback, FTDI/Flexi/COM2 e bloqueios físicos.

## Plano / áreas
1. Auditoria e viabilidade VM; preparar execução isolada sem mídia ilegal.
2. Executor legado + append NSIS/códigos/logs, regressões reais e contratos.
3. Testar Ubuntu/Windows CI, versionar candidato rc.2 e gerar pacote íntegro.
4. Documentar evidências/limites e commits na branch, sem alterar main.

## Validações / bloqueios
Executor e append NSIS implementados; 28 Python, 24 modelos PS, 9 processos reais
em pwsh7, C#2/net20 API compile sem warnings/erros. CI/build/pacote pendentes.
Ubuntu 24.04 x64, i5 VT-x, 15 GiB RAM/~10 disponíveis, 92 GiB livres.
KVM API12 e QMP present/enabled confirmados fora do sandbox. QEMU8.2.2 extraído
localmente, sem serviços/libvirt. QCOW2 vazio32GiB, snapshot blank-before-os;
prelaunch pausado testado e encerrado. Host evidence artifacts/win7-vm-host.json.
Nenhuma mídia Windows localizada na pesquisa inicial; não há autorização de licença.
Win7/PS2 local, instalação/fila/Corel/serial/hardware ainda NÃO EXECUTADOS aqui.

## Próximos passos
Commit/push branch, executar CI Windows + build único local, investigar falhas,
validar candidato ZIP/NSIS e registrar hashes/limites. Não mesclar main ou final.

## Marco de build / CI
- Build local a48feff aprovado, net48/NSIS3.09/52 checks C#/ZIP/hashes em
  dist/local-rc2-a48feff (não substituído). CI39048647575: Ubuntu aprovado;
  Windows bloqueou fixture Add-Type ConsoleApplication não suportada no PS7.
- Corrigido harness Core com csc.exe Framework pelo executor real. Adicionados
  modelos captura incompleta exit0 e log bloqueado; lock tem estado honesto.
- Revalidar/push para CI; o candidato definitivo ainda não está pronto.
