# Objetivo / resultado atual
Correção Win7/PS2 preparada como candidato 1.0.1-rc.2 na branch
fix/win7-ps2-process-runner. Não houve merge/main, tag ou release final.
Código cliente congelado: a173d5e; CI39051351567 aprovado Ubuntu+Windows2022.

## Decisões / causas comprovadas
- Logs reais rc.1: RunId n16722667-4980, OS6.1.7601/PS2, ADMIN aprovado,
  LOCK falha binding Start-Process antes de icacls; não é prova de erro de ACL.
- Executor ProcessStartInfo/C#2/CLR2, token herdado, captura binária concorrente,
  PeekNamedPipe no Windows, timeout/kill só do próprio filho, estado UNKNOWN.
- NSIS append antes sobrescrevia BOM/histórico; seek END e códigos reais corrigidos.
  CheckedExec nas 5 chamadas impede reutilizar zero se filho não inicia.
- Execução CLR2 revelou SHA256Managed.Dispose não público: usar Clear no
  fingerprint e harness. PS2 -File retornou0 no erro: CMD exige recibo fresco
  nonce/run/op após orquestração positiva; sem prova retorna74.
- Probe antigo e55fa34 tinha falso positivo; raw refutou o aceite. Corrigido para
  wrapper/marker/err vazio; só a173d5e é candidato final. Nada intermediário publicado.
- Físico/FTDI/Flexi/COM2/filas externas/journals preservados; sem movimentos.

## Validações
- 32 Python, 25 modelos PS, 9 processos reais Ubuntu pwsh7.6.7/CLR10.0.13.
- Windows2022: 13 processos/ACLs reais em PS7.6.6, PS5.1 e PS2.0/CLR2.0.50727.9179;
  markers positivos/err vazio inspecionados. PS2 também concluiu25 modelos.
- 12 cenários CMD, inclusive erro PS2 exit0=>74 e recibo PS2 válido=>0.
- C#2/net20 API compile, 52 checks C# por runtime, Release net48/net8, NSIS
  Unicode3.09 local/3.10 CI sem warnings/erros. RedMon isolado/UI/Shell ZIP aprovados.
- Imagens pt-BR disponíveis revisadas; finish/uninstall em Win7 pendentes.
- ZIP8 arquivos, PKZIP/Deflate8,361187683 bytes; CRC/7z/extração/hashes/payload
  conferidos. 103 fontes embarcados comparados com Git (só EOL Windows normalizado).
- ZIP SHA256454c997985ecd1347b4bbfcc2380690893c4128974549d2f0bf72cdade32d9d7.
- EXE361368940 bytes SHA256408c835bdc0ce64f2404a8ade5cee07cfb6aefd50b8585fe5276ebc3af2ae9f3.
- Bytes CI em dist/1.0.1-rc.2; evidências/checagem extra artifacts/rc2-final.
  Logs de cliente ignorados/preservados; não embarcados nem publicados.

## VM / bloqueio / próximos passos
QEMU8.2.2 oficial extraído localmente, KVM_API12/QMP enabled/present provados;
QCOW2 vazio32GiB (2vCPU/3072MiB), snapshot blank-before-os, sem NIC/passthrough,
VM desligada e imagem íntegra. Sem ISO/licença Windows fornecida/localizada;
outra VDI preexistente é Ubuntu64 e foi preservada. Guia docs/win7-vm.md.
Win7 real rc.2 NÃO EXECUTADO; cliente usa CLR2.0.50727.8803, CI9179 em outro SO.
Faltam instalação/fila/reinstalação/uninstall/captura/Corel/serial/hardware no alvo.
Fornecer mídia legítima, executar legado com prova PASS, testar snapshots/alvo;
não mesclar nem declarar stable/hardware validado antes de comprovar critérios.
