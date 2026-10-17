# Correção 1.0.1-rc.2 — evidência real, não homologação

## Diagnóstico correlacionado

Logs recebidos localmente, **não incluídos no Git, fontes ou distribuição**.
RunId `n16722667-4980`, em 2026-10-17:

- CMD registra Windows 6.1.7601, AMD64, página OEM 850, PS1 e PowerShell presentes.
- PowerShell registra OS 6.1.7601 / SP1 / 64-bit / PS 2.0. Etapa ADMIN passa.
- LOCK tenta `icacls.exe` para `/setowner *S-1-5-32-544` no diretório do projeto.
- Em 49 ms, `ParameterBindingException`, linha 84 / `Command=Start-Process`.
  O processo não tem código verificável. **Não interpretar vazio como zero**.
- A falha de binding acontece antes da execução nativa; não há evidência de erro
  do icacls ou perda do token administrativo. A combinação WindowStyle e redirect
  é a hipótese específica de conjuntos PS2; a metadata do cmdlet PS2 não está
  disponível aqui para reproduzir isoladamente cada conjunto. Não usar a sintaxe
  atual PS5/7 como comprovação do contrato PS2.
- NSIS, CMD e PS usam o mesmo RunId; CMD devolve 1 e preserva stdout. O log PS e
  o stdout recebidos estão UTF-8 íntegros, inclusive acentos.

### Defeito secundário demonstrado

O log NSIS recebido não começa com BOM, contém apenas o último erro e restos de
linhas anteriores. `Log` reabria com `FileOpen a`, mas não fazia `FileSeek END`.
O manual NSIS confirma que **todos** os modos abrem com ponteiro no início:
[FileOpen/FileSeek](https://nsis.sourceforge.io/Docs/Chapter4.html#fileopen).
Logo os registros sobrescreviam o cabeçalho UTF-16LE e o histórico. Isso explica
esse arquivo danificado, **não** a ParameterBindingException ou todas as telas.

## Correção

- Executor em C# embarcado no PS1, compilado por Add-Type disponível no PS2.
  ProcessStartInfo com UseShellExecute=false, CreateNoWindow=true e token herdado.
  Sem Start-Process, RunAs, política global ou wrapper CMD para executar filhos.
- Duas leituras concorrentes **binárias** para arquivos `.out.raw`/`.err.raw`
  exclusivos, abertos antes de iniciar o processo. Nenhuma decodificação altera
  os bytes. Excertos UTF-8/OEM são separados e identificados como heurísticos.
- Threads C# não usam callbacks PowerShell/runspaces. No Windows, PeekNamedPipe
  evita leitura bloqueante no pipe vazio, inclusive após herança por descendente.
- WaitForExit com prazo; kill somente do filho direto criado pelo Bridge,
  confirmação limitada a 5 s; drenagem limitada a 2 s e parada dos leitores.
  Captura incompleta ou encerramento não comprovado falham fechado, sem repetir.
- ExitCode conhecido (inclusive não zero) é preservado. Falha de início/timeout
  é UNKNOWN, não reutiliza código anterior. Logs incluem PID, início, captura,
  erro nativo quando existente, duração, timeout e arquivos raw.
- Recursos são fechados em finally; erros de logging não substituem a exceção
  original. Arquivo de captura indisponível impede o início do filho.
- NSIS posiciona no final antes de cada append UTF-16LE; Fail propaga o código
  real (por exemplo 50 em OS não suportado), em vez de sempre retornar 1.
- ACLs continuam limitadas ao diretório do projeto e session/. SIDs well-known
  S-1-5-18 SYSTEM, S-1-5-32-544 Administrators e S-1-5-32-545 Users não dependem
  do idioma. Não há nova elevação, acesso COM ou alteração de drivers externos.

[Documentação Microsoft sobre pipes/deadlocks](https://learn.microsoft.com/dotnet/api/system.diagnostics.process.standarderror)
fundamenta drenar as duas saídas concorrentemente. O executor usa a superfície
CLR2; a API moderna documentada não é alegação de execução Win7.

## Matriz desta correção

| Camada | Execução disponível | Estado alvo Win7/PS2 |
|---|---|---|
| Contratos, ZIP, encoding Python | 29 testes Ubuntu | não substitui runtime |
| Executor + fixture C# | C#2, referências net20, zero warnings/erros | API compile, não execução |
| Zero/não zero, streams, argumentos, binário/OEM, flood, timeout, ausente | 9 testes reais Ubuntu pwsh7 | pendente PS2 |
| Orquestração, admin/lock, rollback/idempotência/uninstall | 24 modelos, PS7 | pendente APIs reais |
| icacls real/ACL/session/lock, erros e token herdado | CI Windows moderno a executar | pendente Win7 |
| NSIS silencioso, código 50, BOM/append/cronologia | CI Windows moderno a executar | pendente Win7 |
| net48, vetores/serial simulada, NSIS, ZIP/extração/hashes/UI | pipeline a executar | instalação alvo pendente |
| VM QEMU/KVM | API 12, QMP kvm present/enabled, prelaunch pausado, sem rede | disco vazio; Windows ausente |
| Instalação/fila/CorelDRAW/FTDI/serial/corte | não executado aqui | **PENDENTE** |

As evidências do cliente comprovam uma tentativa **falha** no Win7/PS2 rc.1,
não validação positiva da rc.2. Rodar `tests/legacy-validation.ps1` em mídia
licenciada. Esse script exige 6.1.7601 x64 / PS2 / CLR2, sem fallback moderno,
registra ambiente e sintaxe Start-Process, testa executor/ACLs em diretórios
TEMP e modelos. Não instala a fila nem abre COM. Instalação real e ciclo
reinstalação/desinstalação devem ser medidos separadamente em snapshot.

## Gates e distribuição

`build-release.py` exige teste real do executor e compile CLR2 antes do build;
`validation.json` distingue build/testes/API de Win7, instalação, Corel e físico.
A branch dedicada não deve ser mesclada nem promovida como final enquanto o alvo
não for exercitado. A rc.1 permanece no histórico, mas a falha PS2 é conhecida:
**não encaminhar a rc.1 como instalador corrigido**. Novo pacote é candidato.
Logs recebidos e mídia/VM ficam ignorados e não são anexados ao CI/publicação.

### Regressão encontrada pelo primeiro CI desta branch

O primeiro CI 39048647575 passou Ubuntu e bloqueou no gerador de fixture Windows:
PowerShell7 Add-Type não suporta OutputType ConsoleApplication. Não era erro do
executor em produção. O harness agora usa o csc.exe Framework instalado no host
Core, através do próprio executor, e conserva Add-Type em Windows PowerShell
2/5. Não houve remoção do teste nem substituição por mocks.
Também se testa captura incompleta com exit0 (deve falhar) e erro de log que não
pode substituir o erro original de início. O estado do lock agora distingue
not-acquired de released; não relata liberação de um lock nunca obtido.

### Cadeia de inicialização NSIS

A auditoria também encontrou ExecWait sem verificar Errors: se o processo não
iniciasse, $0 poderia continuar com valor anterior. Todas as cinco chamadas
agora passam pelo mesmo CheckedExec (primeiro UNKNOWN/9009, Errors explícito),
incluindo pré-requisitos e desinstalador. Um NSIS mínimo de regressão extrai o
macro **real** e tenta filho ausente após $0=0: precisa retornar9009, preservar
mensagem UTF16 e nunca alcançar marcador de sucesso. A rejeição OS do instalador
completo verifica código50 e histórico/BOM separadamente.

### ACL e disponibilidade PS2

O harness também lê o descritor real após icacls: proprietário Administrators,
raiz protegida de herança, SYSTEM/Administrators FullControl, Users RX na raiz e
logs e escrita apenas em session/. Isso não depende só do ExitCode=0.
O CI sonda powershell.exe -Version2 sem instalar/habilitar componentes antigos.
Só se PSmajor2 e CLRmajor2 forem confirmados executa a mesma regressão real;
caso contrário preserva código/saídas e registra NOT_CONFIRMED. Mesmo um teste
PS2 em Server2022 não homologa Win7; não há fallback falso para PS5/7.
