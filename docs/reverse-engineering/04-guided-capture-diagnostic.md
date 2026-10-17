# Diagnóstico guiado da captura — rc.4

## Execução no Windows alvo

Use somente com o desenvolvedor presente. Não reinstale nem altere opções do
FlexiSIGN para obter o relatório.

1. No menu Iniciar, abra **Foison C24 Print Bridge → Diagnóstico da captura**.
2. Execute **Experimento A — Receiver direto**. O programa escreve os bytes do
   `testes/square-20mm.ps` diretamente em stdin por `BaseStream.Write`, confere
   o SHA-256, abre o parser real e verifica dimensões de 20 × 20 mm. Não usa
   CMD `type`, spooler, RedMon, serial ou dispositivo.
3. Use **Abrir painel para conferir a lista**. A confirmação é manual porque a
   lista é UI WinForms e não é considerada provada por um arquivo criado.
4. Clique **Iniciar monitoramento da impressão**. Só depois imprima uma vez o
   quadrado sintético no CorelDRAW X6 para **Foison C24 (Teste)**.
5. Retorne e clique **Concluir/Cancelar monitoramento**. Responda às perguntas
   de visibilidade na lista e sucesso da prévia com base no que realmente viu.
6. Clique **Exportar ZIP de diagnóstico** e envie ao desenvolvedor.

O monitoramento permanece ativo enquanto a caixa de instrução está aberta e
durante o tempo em que o operador retorna ao Corel. Usa `Win32_ProcessStartTrace`
e `Win32_ProcessStopTrace` para o Receiver, consulta `Win32_PrintJob` e a fila
`Win32_Printer`, verifica a chave RedMon associada à porta Bridge e observa
marcadores/logs de captura. Se WMI, Registro, spooler ou ACL bloquearem a leitura,
o relatório registra UNKNOWN/erro; ausência de evento nunca vira FAIL automático.

## Evidência e privacidade

Receiver grava logs UTF-8 sem BOM em `C:\ProgramData\FoisonC24\Logs`; se
indisponível, tenta pasta de diagnóstico das capturas e `%TEMP%`. Cada tentativa
tem arquivo exclusivo com UTC, RunId, AttemptId, PID, identidade/SID, variáveis
RedMon seguras, estágio, EOF, bytes, SHA-256 e ExitCode. `REDMON_DOCNAME` é apenas
marcado como presente/ausente; seu valor e os bytes do trabalho nunca entram no
log. A tentativa rejeitada salva metadados, hash e causa em `captures\attempts`,
mas não salva o documento bruto. O teste A aceito usa somente a fixture sintética.

O ZIP permite `summary.txt`, `environment.json`, `printer-state.json`,
`redmon-state.txt`, `receiver.log`, `capture-metadata.json`, `application.log`,
`errors.log` e `checksums.txt`. Não contém arquivos `.raw`, PDFs ou conteúdo de
documentos. Verifique localmente antes de compartilhar. Os logs podem conter
nome de conta/SID e caminho da instalação porque a identidade e o executável são
necessários para diagnosticar permissões; compartilhe apenas com o desenvolvedor.

## Interpretar A/B

- A PASS + B sem Receiver: priorizar fila/driver/RedMon/lançamento do processo.
- B Receiver + EOF com formato desconhecido: bytes chegaram; revisar formato e
  subsistema/driver antes de mudar parser.
- B bytes + metadados rejected: estágio da rejeição, formato, hash e exceção
  identificam o ponto a investigar; o conteúdo não é coletado.
- B metadados aceitos + UI FAIL: revisar refresh/filtros/listagem da aplicação.
- WMI sem eventos, porém log Receiver existe: o processo foi confirmado pelo
  próprio componente; WMI é limitação, não evidência negativa.
- Sem evidência suficiente: manter UNKNOWN. Não atribuir causa a driver, ACL,
  PostScript ou encoding sem os registros correspondentes.

O relatório é um diagnóstico, não homologação. Não abre COM2, não escreve dados
seriais, não altera fila/driver/configuração, e não faz corte físico.

## Exemplo validado em teste automatizado

Fixture sintética no host Ubuntu, experimento isolado do equipamento:

```text
Receiver direto: PASS — 273 bytes, SHA-256 9675e988ce4bf48ff31e7d88f49bbbe0a40831f54f937fb8316bcebfc99ec851
Formato: PostScript; stdin aberto/primeiro byte/EOF; persistência raw+JSON: PASS
Parser vetorial E2E: PASS — quadrado PostScript 20 × 20 mm, GS + MuPDF via Wine; 73 checks C# no total
Unknown binário: ExitCode 2; metadados de rejeição + log: PASS; conteúdo bruto: NÃO preservado
Fluxo interativo/UI guiada, WMI do alvo, spooler/RedMon do cliente, PowerShell 2, CorelDRAW real e Foison C24: NÃO TESTADOS
```

Este resumo é um exemplo sintético, não dados do cliente. O executável real
produziu um ZIP de smoke no Windows 2022; o CI confirmou 9 entradas exatas,
integridade 7z, allowlist sem `.raw`/`.pdf` e status `UNKNOWN` sem alegar captura
real. Isso valida somente o gerador/formato do relatório, não o fluxo guiado no
Windows 7 nem uma impressão Corel/RedMon real. O parser 20 × 20 mm foi exercitado
separadamente pelo harness com fixture real e stdin binário.
