# Retorno adicional — captura vazia (prioridade atual)
Cliente confirmou lista de trabalhos vazia após imprimir. Instalação/fila visível
não comprovam captura. Solicitado Exportar relatório da instalação existente;
Foison.rar contém arquivos de instalação, não estado/logs ProgramData atuais.
Não assumir causa. Revisão fonte RedMon confirma que ele já coloca aspas no
Command; não inserir aspas extras nem alterar configuração sem evidência.
Adicionado coletor somente leitura (pasta/pares, Spooler/fila WMI/registroRedMon),
exportado no ZIP sem desenho bruto; não abre COM/imprime/reinicia serviços.
CI39057524445/2643fad aprovou painel/67C#/35Python/build/NSIS/ZIP; coletor em
validação subsequente. Sem afirmar que novo painel resolve captura vazia.

# Em andamento — painel de corte / CorelDRAW (2026-10-17)
Objetivo: tornar acessíveis as configurações reais de corte, sem substituir o driver
PostScript compartilhado nem executar UI como spooler/SYSTEM.
Branch fix/corel-cut-settings, base137b3ad; main preservada.
Cliente relata instalação rc.2 rápida e fila visível no CorelDRAW X6; relato não
comprova captura/vetores/serial/corte. Arquivo recebido é Foison.rar (RAR5), local
privado/ignorado, não foison.zip. Auditoria em andamento; 7z local lista mas não
suporta descompressão RAR, obtendo extrator oficial sem instalação global.
Causa no código: propriedades são PScript5 genérico; painel Foison é aplicativo
separado, fluxo pouco descobrível. Não existe plug-in de propriedades OEM.
Plano: auditar payload; painel explícito (escala reduzida/rotação/espelho/porta,
prévia das mesmas coordenadas enviadas); invalidar ensaio ao editar; instruções
claras/atalhos; testes geométricos + UI CI + build/ZIP. Sem comandos não comprovados
de força/velocidade; ajustar no painel físico. Escala >100% no Corel para não
ampliar erro de aproximação de curvas acima de0,01mm.
Validações locais:35 testes Python,67 checks C# net8 com engines reais e fila/
serial simulados; net48 UI/Receiver builds sem warnings/erros e gate encoding.
Primeiro build paralelo falhou sem diagnóstico MSBuild; build -m:1 passou,
pipeline uniformizado em modo serial (já usado pelos demais projetos).
RAR:633 arquivos descompactados sem erro/CRC libarchive;7 componentes exatosCIrc.2.
Escala/rotação/espelho implementados no modelo usado por prévia e HPGL; alterações
revogam ensaio e troca de porta revoga perfil. CI39057252361:Ubuntu passou;Windows detectou read_text sem encoding em novos
contratos (cp1252 do runner), corrigido UTF-8 explícito; não foi erro de runtime
ou instalador. Pipeline local bloqueado por NuGet NU1900/rede mesmo fora sandbox;
não suprimir auditoria nem promover build parcial. CI/UI/NSIS/ZIP em reexecução.
Nenhum comando serial/hardware enviado.

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
