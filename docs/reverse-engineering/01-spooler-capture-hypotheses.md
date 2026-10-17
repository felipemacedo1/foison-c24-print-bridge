# Hipóteses e coleta do pipeline (Windows 7 / PowerShell 2)

Este roteiro serve para uma sessão única e instrumentada, com documento
sintético. Não é requisito de instalação nem pede alteração do Flexi/FTDI/COM.
Como o Bridge foi removido, não há coleta retroativa do print anterior.

## Caminho recomendado para o candidato rc.4

O procedimento antigo abaixo foi elaborado antes do journal do Receiver. Para
uma nova sessão, use o atalho **Diagnóstico da captura** do menu Iniciar e siga
[`04-guided-capture-diagnostic.md`](04-guided-capture-diagnostic.md): A prova
Receiver/parser/persistência sem spooler, depois B monitora durante a impressão
Corel. Não é necessário coletor PS1 separado para o ensaio normal. O coletor
`Collect-Print-Diagnostics-Win7.ps1` permanece opção somente leitura caso a UI ou
o executável de diagnóstico não abra.

A e B têm estado independente. A PASS com B sem Receiver localiza investigação
em fila/driver/RedMon; B com EOF e assinatura desconhecida localiza análise em
formato; persistência confirmada com UI FAIL direciona à listagem. A coleta real
Windows 7/PowerShell 2 ainda não foi feita; esses critérios descrevem evidência,
não resultados atuais do cliente.

## Hipóteses priorizadas pelo custo de discriminação

1. **H04/H05: fila/RedMon não invoca Receiver.** Distinguir por configuração
   lida, eventos de spool e Process Monitor `Process Create/Exit`. A configuração
   atual desativa o log próprio do RedMon; isso não prova que RedMon falhou.
2. **H06/H07: Receiver não recebe ou rejeita stream.** Distinguir por bytes/EOF,
   assinatura, ExitCode e erro do Receiver, sem persistir conteúdo nos logs.
3. **H07/H08: persistência falha.** Distinguir por `CreateFile/WriteFile/SetRename`
   e resultado do Receiver; registrar ACL/identidade se houver `ACCESS DENIED`.
4. **H09: UI não enumera arquivo persistido.** Se raw+JSON pareados existirem,
   investigar refresh/filtro/parse da UI, não o driver.
5. **H01/H02/H03/H10: fila/spooler/formato diferentes do previsto.** WMI é
   snapshot e pode perder trabalhos rápidos; correlacionar eventos PrintService
   existentes e PML. Não habilitar o canal global na primeira coleta.

Ordem por observabilidade/custo, não por probabilidade numérica. H11
(terminação/ExitCode) cruza H04–H08 e deve ser correlacionada por PID/tempo.

## Coleta reproduzível

1. (Fluxo manual complementar/backup.) Preparar um quadrado vetorial sintético 20×20 mm, escala 100%, uma página,
   com nome de teste `FC24-TEST-0001`; sem arte/dados do cliente.
2. Antes da única impressão, executar o coletor e abrir Process Monitor
   comprovadamente compatível com Windows 7. Guardar PML/CSV localmente fora do
   repositório. Filtrar por `spoolsv.exe`, `FoisonC24Receiver.exe`, path
   `C:\ProgramData\FoisonC24`, operações `CreateFile`, `ReadFile`, `WriteFile`,
   `Process Create`, `Process Exit`, resultados `ACCESS DENIED` e `PATH NOT FOUND`.
   Preservar filtro exportado e registrar se houve eventos descartados.
3. Imprimir uma vez pelo CorelDRAW, anotando apenas fila exata e hora aproximada.
   O coletor captura jobs WMI ativos sem título do documento, mas jobs curtos
   podem desaparecer entre snapshots.
4. Executar snapshot adicional depois da impressão e correlacionar
   Process Monitor → processo filho/Exit → log/bytes Receiver → raw+JSON → UI.
   Não copiar nomes de documentos nem conteúdo bruto ao relatório.
5. Identificar o primeiro estágio sem prova. Somente se persistir a ambiguidade
   entre Corel/driver e caminho da fila, executar uma única sonda `capture-test`
   sem serial na mesma sessão, antes/depois do snapshot. Se a sonda passar e
   Corel não, comparar o formato/processor; se falhar, focar fila/RedMon/Receiver.
   A sonda exige reinstalação acompanhada e autorização administrativa local.

### Coletor PowerShell 2.0

```cmd
powershell.exe -NoProfile -ExecutionPolicy RemoteSigned -File "C:\Program Files\Foison C24 Print Bridge\Collect-Print-Diagnostics-Win7.ps1" -RunId FC24-TEST-0001
```

Usar o mesmo `-RunId FC24-TEST-0001` antes e depois; cada relatório tem
`SnapshotId` e nome único. Saída no Desktop ou `%TEMP%`, em UTF-8 BOM. Registra
versões, estado do spooler, fila/driver/porta/processor/DataType, jobs Bridge
ativos sem títulos, configuração RedMon, processos Receiver e metadados de
capturas/spool. Usa `Get-WmiObject`, não `Get-Printer`. Erro de leitura aparece
como erro, nunca como ausência comprovada.

O script não lê arquivos `.raw`/`.SPL`/`.SHD`, altera settings, consulta ACL
recursivamente, reinicia serviços ou abre COM. Process Monitor e `wevtutil` são
etapas separadas, necessárias para eventos transitórios.

### Canal PrintService existente

```cmd
wevtutil el
wevtutil gl "Microsoft-Windows-PrintService/Operational"
wevtutil qe "Microsoft-Windows-PrintService/Operational" /c:30 /f:text
```

Consultar sem habilitar/desabilitar canais. Se ausente/desabilitado, registrar
esse fato; não alterar estado sem evidência de que é necessário.

## Critérios de PASS/FAIL

- **Spooler PASS:** JobId/evento da fila exata correlacionado ou sonda termina na
  porta RedMon. WMI depois do término sozinho não basta.
- **Launch PASS:** Procmon mostra Receiver criado no intervalo do JobId. Ausência
  só vale se filtros/captura estão completos e `dropped events=0`.
- **Input PASS:** journal novo registra bytes positivos e EOF.
- **Persistência PASS:** raw + marcador JSON ready correspondem ao mesmo job/hash.
- **UI PASS:** mesmo ID aparece após refresh.
- **FAIL:** erro explícito, código/Win32 error ou operação observada falhando.
  Falta de observação é `NÃO COMPROVADO`, não FAIL.

## Reversão e privacidade

O snapshot não altera estado. Fechar Procmon após a impressão. PML/CSV ficam
privados e não entram no GitHub; não tocar em `%WINDIR%\System32\spool\PRINTERS`.
Não anexar PML, RAW, SHD, títulos, usuário, caminhos pessoais ou documentos ao
repositório. Não abrir COM, enviar movimento, reiniciar spooler nem alterar
FTDI/Flexi/drivers externos.
