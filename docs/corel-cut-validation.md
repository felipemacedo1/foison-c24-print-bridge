# Painel de corte / captura vazia — 2026-10-17

## Continuação — instrumentação rc.4 em branch

Em `fix/capture-observability`, versão candidata local **1.0.1-rc.4**. O
Receiver agora registra cada tentativa e preserva metadados de rejeição; o
diagnóstico inclui Experimentos A/B, observação durante impressão e exportação
ZIP sem trabalhos brutos. Testes locais atuais: 38 Python, 73 checks C# E2E,
builds net48 e NSIS, ZIP Deflate/CRC/extração/hashes aprovados. Artefatos locais
são development build sujo, não são evidência de Win7. Veja
[`04-guided-capture-diagnostic.md`](reverse-engineering/04-guided-capture-diagnostic.md)
e `PROJECT_STATE.md` para limites e hashes do build.

**Ainda não comprovado:** UI do diagnóstico, exportação ZIP sob Windows 7/PS2,
fila/RedMon/Receiver/CorelDRAW X6 no alvo, e qualquer comportamento de hardware.
Não se atribuiu causa à captura vazia do cliente e não se desbloqueou corte.

## Diagnóstico e evidência do cliente

- Cliente relata rc.2 instalada rapidamente e fila reconhecida no CorelDRAW X6.
- Depois confirmou lista de trabalhos vazia no aplicativo após imprimir.
  Portanto instalação/fila não comprovam captura, processamento, serial ou corte.
- Arquivo recebido: `Foison.rar`, RAR5,208658971 bytes,660 entradas/633 arquivos;
  SHA256 `6feb48ed74a69efb4d90f4af7a1c31ffe8b2141ee939b456a30ac9c10b33901f`.
  Todos os arquivos descompactaram com libarchive3.7.2 oficial Ubuntu, sem erros.
  7z23.01 deste Ubuntu lista RAR mas não suporta a descompressão; não é evidência
  de corrupção. Diretórios não foram enviados a stdout no teste libarchive.
- Diagnostic/Core/Receiver/Provisioner/CMD/PS1/VERSION correspondem byte a byte
  ao instalador rc.2 a173d5e. Não executar binários recebidos nem publicar o RAR.
- O RAR de instalação não contém o estado atual de `ProgramData`. Foi solicitado
  **Exportar relatório** da instalação existente. Ainda não recebido nesta etapa.
- Ausência das opções em Propriedades: driver PScript5 sem plug-in OEM. A UI
  de corte pertence ao aplicativo separado. [Fluxo](corel-cut-settings.md).
- **A causa da captura vazia não foi identificada.** Nenhuma alteração de ACL,
  porta, driver ou RedMon foi feita por tentativa no cliente. O código original
  RedMon já coloca aspas no caminho do Receiver: não adicionar aspas extras.

## Mudanças reais

Branch `fix/corel-cut-settings`, sobre137b3ad, main preservada. Código cliente
`919ec25f58064d3cce3d34320c6318f7475369fc`, versão1.0.1-rc.2 →1.0.1-rc.3.

- Painel explícito de ajustes de geometria e porta, atalhos/instruções claras.
  Não implementa uma aba dentro de Propriedades do Corel nem paridade com Flexi.
- Redução1–100%, rotação ortogonal, espelhos, medição antes/depois, original
  imutável e mesma geometria para prévia e HPGL; sem acumular transformações.
- Ajustar revoga ensaio, trocar porta revoga também perfil. Hash do ensaio
  vinculado ao plano geométrico exato. Não modificar Sender/SerialWire/protocolo.
- Diagnóstico somente leitura e exportação incluem pasta/pares, Spooler/filaWMI,
  configuração da porta RedMon e existência do Receiver/config. Sem abrir COM,
  imprimir sonda automaticamente, reiniciar serviços ou ler desenhos brutos.
  Argumentos externos são representados apenas por vazio/não vazio.
- Não implementar comandos desconhecidos de força/velocidade; usar painel físico.

## Validação

[CI39058232989 aprovado](https://github.com/felipemacedo1/foison-c24-print-bridge/actions/runs/39058232989),
Ubuntu24.04 e WindowsServer2022. Sem desativar testes/auditoria de dependências.

- 36 testes Python/encoding/contratos. 67 checks C# por runtime net8/net48,
  engines vetoriais reais e fila/serial simulados. Transformações assimétricas,
  fechamentos, coordenadasHPGL, limites, revogação/idempotência testados.
- 25 modelosPS; processos/ACLs reais13 em WindowsPS5/7 e PS2/CLR2 no Server2022,
  não Win7. ProbePS2 com markers13/25 conferidos, não apenas ExitCode0.
- 12 testesCMD; compilação C#2/net20 da camada legado; builds/NSIS sem warnings
  ou erros; RedMon isolado e ShellZIP Windows; nenhuma execução física.
- Imagens reais WinForms do painel e diálogo revisadas: textos pt-BR legíveis,
  quadrado20×20mm, botões físicos bloqueados por padrão. Arquivos finais idênticos
  aos revisados. Não são imagens do Windows7 do cliente.
- Coletor nativo gerou relatório com SpoolerRunning, filaBridge ausente no CI,
  pasta de capturas ausente e sem exceção. Esses estados são do runner, não do
  cliente. `OS=` usa Environment.OSVersion e pode reportar versão de
  compatibilidade no Windows moderno (6.2 no CI). Não usar esse campo como prova
  do SO real; probePS2 separado registra host10.0.20348.
- Primeira execuçãoWindows39057252361 detectou erro dos novos testes lendo
  UTF8 como cp1252; corrigido com encoding explícito, sem alterar a expectativa.
- Pipeline completo local bloqueou em NuGetNU1900/rede, inclusive fora sandbox;
  não suprimimos a auditoria. Builds locais net48, testes36Python/67C# e encoding
  passaram; artefatos entregáveis são os bytes do CI completo aprovado.

## Artefatos candidatos

`dist/1.0.1-rc.3/`, sem substituir a rc.2 nem criar release final:

| Arquivo | Bytes | SHA256 |
|---|---:|---|
| FoisonC24-Setup-Win7-x64.exe | 361392281 | b1fc546c413de86f87ce280798838ab82f5300b4a26ad9379fff5ab64d13701a |
| FoisonC24-v1.0.1-rc.3-Win7-x64.zip | 361210504 | 5262fb82c770ecbb834fbfc873e578e099e2406674578477f855b7e6887cf1af |

ZIP PKZIP/Deflate8,8 arquivos em um diretórioASCII; sem ZIP64/AES/multipartes.
CRC Python, headers local/central,7zt, extração completa eSHA256, manifestos
interno/externo conferidos. InstaladorNSIS extraído, scripts e107 fontes
embarcadas comparados ao Git919ec25 (somente EOLWindows normalizado).
Evidências locais: `artifacts/rc3-final/`, não incluir logs privados do cliente.

## Próximo passo / limites

Não pedir reinstalação como tentativa. Receber ZIP **Exportar relatório** da rc.2
e correlacionar uma tentativa real de impressão. Se necessário, o desenvolvedor
pode usar a operação já existente `Install-Queue-Win7.cmd capture-test`, como
administrador, para testar fila→Receiver→vetor sem abrir COM (não comprova Corel).

Novo painel/coletor e captura rc.3 não executados no Win7 do cliente. Não há
validação serial/hardware ou corte. Aprovações, ensaio sem lâmina, limites,
journals/latch continuam obrigatórios; FTDI/Flexi/portas alheias preservados.
Não publicar como estável nem declarar que o painel corrige a captura vazia.
