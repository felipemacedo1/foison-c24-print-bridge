# Investigação do pipeline de impressão — estado 2026-10-17

## Escopo e conclusão provisória

Prioridade: localizar o primeiro limite sem evidência entre CorelDRAW, spooler,
RedMon, Receiver, persistência e lista da UI. Não estudar nem enviar protocolo
serial até que esta cadeia esteja demonstrada, salvo trilha independente que não
use COM. Esta nota não afirma causa-raiz.

| Transição | Estado | Evidência / limite |
|---|---|---|
| CorelDRAW → fila registrada | CONFIRMADO (relato) | Cliente viu a fila no CorelDRAW; isso não prova que selecionou essa fila num trabalho concluído. |
| Trabalho → spooler | NÃO COMPROVADO | Nenhum JobId/evento/spool observado da impressão do cliente. |
| Spooler → RedMon | NÃO COMPROVADO no cliente | Código/configuração não provam execução da fila específica. |
| RedMon → processo Receiver | NÃO COMPROVADO no cliente | Não há Process Create correlacionado nem log RedMon daquele trabalho. |
| Receiver → bytes stdin | NÃO COMPROVADO no cliente | O Receiver conta bytes apenas em memória e não publica tentativa/EOF quando rejeita a entrada. |
| Bytes → arquivo `.raw` + marcador `.json` | NÃO COMPROVADO no cliente | Lista vazia não distingue ausência de entrada de rejeição/falha de escrita. |
| Persistência → UI | NÃO COMPROVADO no cliente | A UI enumera somente `job-*.json` com `.raw` correspondente. |

## Evidências existentes

1. Relato do cliente: instalação anterior terminou, fila aparece no CorelDRAW e,
   após imprimir, a lista do aplicativo estava vazia. O software já foi removido.
2. `Foison.rar` é pacote de arquivos instalados; não inclui o estado runtime de
   `C:\ProgramData\FoisonC24` nem eventos/processos daquela impressão.
3. `Logs/` contém uma execução anterior rc.1 (RunId `n16722667-4980`), que falhou
   na etapa LOCK antes de provisionar a fila: `Start-Process` ParameterBindingException.
   Isso explica aquela instalação, não a impressão posterior rc.2.
4. O fonte RedMon 1.9 incluído (`third_party/redmon/redmon-src.zip`, arquivos
   `src/redmon.c` e `src/redmonrc.h`) configura
   `STARTF_USESTDHANDLES`, liga `hStdInput` do filho ao pipe de entrada e chama
   `CreateProcess`; também define variáveis `REDMON_PORT`, `REDMON_JOB`,
   `REDMON_PRINTER`, `REDMON_DOCNAME`. É evidência de capacidade do RedMon, não da
   execução no cliente. Os campos de arquivo de log RedMon estão desligados na
   configuração Bridge atual; portanto a falha de launch pode não deixar log próprio.
5. Código anterior à rc.4 lia stdin até EOF (limite64MiB), reconhecia PostScript
   com prefixo `%!PS-`, EOT+`%!PS-` ou envelope UEL/PJL específico, e persistia raw
   + JSON; entrada vazia/desconhecida não gerava item visível. Na rc.4, cada
   tentativa tem log exclusivo (RunId/AttemptId, identidade, stdin, hash,
   assinatura, persistência/ExitCode) e tentativa rejeitada cria JSON de causa
   sem manter bytes brutos. A execução dessa instrumentação ainda não ocorreu no
   cliente; não prova por si só que RedMon iniciou o Receiver.
6. A UI enumera `job-*.json` pareados a `.raw` em CommonApplicationData/FoisonC24/captures.
   Sem marcador JSON completo, a UI deliberadamente não mostra o raw.
7. O coletor rc.3 é somente leitura, porém consulta estado atual; não observou o
   instante da impressão e não faz snapshot de Win32_PrintJob/process creation.
   Além disso, relatório rc.3 não foi obtido do alvo.

## Hipóteses a discriminar — sem atribuição prematura

| ID | Hipótese | Evidência que confirma | Evidência que refuta / próximo passo |
|---|---|---|---|
| H01 | Corel enviou para outra fila ou o trabalho não terminou | Impressão sintética identificada; JobId/eventos mostram nome de outra fila ou falha antes de spool | JobId/evento do nome da fila Foison; capturar num único ensaio correlacionado |
| H02 | Spooler recebeu, mas não encaminhou/processou | JobId/PrintService com falha/estado persistente; PrintProcessor/DataType discrepantes | evento de conclusão da fila + processo RedMon criado |
| H03 | Fila aponta para driver/porta diferente da configuração Bridge | Win32_Printer/Registro mostram divergência | leitura WMI + RedMon mostram nomes/porta/config esperados |
| H04 | RedMon não está ativo/configurado ou launch falha | EnumMonitors/EnumPorts, readback XcvData e Process Monitor mostram ausência/erro | child Receiver criado para o JobId |
| H05 | Receiver inicia mas não lê ou não chega a EOF | Process Create sem ReadFile/EOF/recibo de término | relatório de tentativa traz bytes>0, EOF, hash e resultado |
| H06 | Receiver rejeita formato/envelope ou tamanho | entrada medida + resultado de assinatura/erro do parser | stream reconhecido e arquivos persistidos |
| H07 | Persistência falha por caminho/ACL/colisão | erro real de IO/ACL com processo e diretório | raw+ready JSON com hash pareado |
| H08 | UI não enumera/atualiza item persistido | arquivos pareados presentes enquanto refresh não os adiciona; exceção/log da UI | UI lista o ID do marcador |
| H09 | Contexto/SID/sessão/ACL difere do esperado | Process Monitor User/Session/Result e ACL efetiva no diretório | acesso e criação de arquivo bem-sucedidos sob o token real |
| H10 | Dados EMF/RAW/PostScript são diferentes do assumido | `PrintJobDataType` + bytes da entrada no limite RedMon | cabeçalho e bytes reais confirmam formato aceito |

H11 (terminação precoce/ExitCode) é examinada junto com H04-H07 por Process Exit,
stderr, tempo e marcador de conclusão. Não inferir ExitCode zero quando ausente.

## Instrumentação rc.4 preparada / lacunas reais

- Coleta PS2 somente leitura: `packaging/windows/Collect-Print-Diagnostics-Win7.ps1`.
  Registra versões, filas/porta/driver/print processor/datatype, jobs ativos sem
  título do documento, serviço spooler, processos Bridge, contagens/tamanhos de
  spool/capturas, readback de valores RedMon e eventos PrintService existentes.
  Não lê conteúdo de trabalhos, não muda configuração e não abre COM.
- O coletor não substitui Process Monitor. Para um único trabalho sintético,
  usar captura backing file do Procmon e filtros por `spoolsv.exe`, Receiver,
  caminho `C:\ProgramData\FoisonC24`, `CreateFile`, `ReadFile`, `Process Create/Exit`,
  `ACCESS DENIED` e `PATH NOT FOUND`; salvar PML e CSV fora do repositório.
- `FoisonC24Receiver` agora cria log antes de interpretar, com PID/identidade,
  variáveis RedMon exceto o valor de `REDMON_DOCNAME`, stdin/primeiro byte/EOF,
  bytes/hash/formato, persistência, exceções/stack e ExitCode. `attempts/*.json`
  conserva rejeição sem corpo bruto. Há fallback ProgramData → captures/diagnostics
  → TEMP. O RunId do processo RedMon pode ser independente do RunId do app; a
  correlação usa janela UTC, PID/AttemptId e registros anexados, não presume
  propagação de ambiente através de `spoolsv.exe`.
- `FoisonC24-Diagnostico.cmd`/menu Iniciar inicia diagnóstico guiado. Experimento A
  usa stdin binário direto; B mantém WMI/process trace + amostragem spooler/fila/
  RedMon/Receiver durante a impressão. Relatório ZIP allowlist sem `.raw`, com
  confirmação manual da lista e da prévia. Implementação/build local não é
  validação da UI ou do Windows 7; teste no alvo ainda necessário.
- Limites restantes: WMI pode perder jobs breves, ProcessStartTrace pode estar
  indisponível, RedMon pode falhar antes de criar log próprio, códigos de saída
  WMI e `PrintService/Operational` dependem do sistema, UI é confirmação humana.
  Se houver limitação, o relatório mantém UNKNOWN e a sessão pode requerer Procmon.
- RedMon 1.9 tem logging próprio, mas ativá-lo exige escolher path/ACL e pode
  registrar detalhes do trabalho. Só habilitar temporariamente para uma fila
  Bridge de teste, com path dedicado, limite/retention e reversão imediata; não
  alterar monitor compartilhado nem Flexi. Primeiro preferir Procmon + log mínimo
  do Receiver.

## Critério de encerramento do diagnóstico A

Para um único job sintético `FC24-TEST-<id>`, registrar:

```text
Corel selecionou fila + impressão concluída: PASS/FAIL + evidência
Spooler JobId/evento/fila/DataType: PASS/FAIL + evidência
Porta RedMon/readback do monitor: PASS/FAIL + evidência
Process Create Receiver / PID / Exit: PASS/FAIL + evidência
stdin bytes / EOF / assinatura: PASS/FAIL + evidência
raw+ready marker/hash: PASS/FAIL + evidência
UI lista o mesmo job_id: PASS/FAIL + evidência
Primeiro estágio FAIL e causa observada:
Explicações alternativas ainda abertas:
```

Um `capture-test` sintético da fila pode provar fila→PScript→RedMon→Receiver sem
COM; não substitui Corel. Fazer esse ensaio apenas uma vez, dentro da mesma sessão
instrumentada, se reduzir a ambiguidade entre driver/spooler e Corel.

## Segurança / privacidade

Usar apenas quadrado vetorial sintético. Não registrar título pessoal, caminho de
documentos, conteúdo bruto, credenciais ou environment completo. Não abrir COM,
enviar movimento, reiniciar spooler, alterar FTDI/Flexi ou drivers externos. Os
artefatos PML/CSV/runtime ficam privados; publicar apenas fixtures artificiais.
