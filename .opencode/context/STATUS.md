# Missão
Corrigir instalação Win7/PowerShell 2, reconstruir instalador autocontido, validar
ZIP PKZIP e publicar prerelease com EXE/ZIP/checksums. Físico permanece bloqueado.

## Auditoria inicial (antes das alterações)
- main limpa em d36eeb5, remoto igual; sem tags/releases/rulesets e main não protegida.
- Assemblies SDK têm versão implícita 1.0.0.0; próxima correção 1.0.1-rc.1.
- Scripts atuais: prepare-tools.py, fetch-redmon.py, NSIS, package-client.py e CI.
- ZIP anterior 351266680 bytes, SHA256 aadb3356b760c2c1b20642b21215b3ae844ce09496c11671bc89c2417909df07.
  Cabeçalho PK0304, diretório central, 8 entradas ASCII únicas, método 8, sem
  ZIP64/criptografia, CRC Python e 7z passaram. Sintoma exato do cliente ausente:
  causa não comprovada; confusão com ZIP externo de artefatos é só hipótese.
- Falhas confirmadas: ordem RedMon, ausência de admin explícito, dependências
  incompletas, manifesto .json em key=value, escrita não atômica, locks sem finally,
  PrintUI sem timeout, NSIS sem verificação independente e runtime 1638 genérico.
- VC++ embarcado é 14.29.30157.0 (VS2019), hash fixado; não é runtime moderno
  indiscriminado. Engines PE x64 e dependência UCRT/VC14 serão verificadas no build.

## Plano / aceite
1. Orquestração PS2 testável, monitor verificado antes de portas, estado .properties
   migrável/atômico, propriedade e rollback conservadores, logging e verify separado.
2. Helpers nativos e NSIS sem falso sucesso; validação runtimes/arquitetura.
3. Pipeline único Release/testes/NSIS/ZIP Deflate não ZIP64, extração/hash independente.
4. Matriz simulada + APIs reais disponíveis/CI; release rc após artefatos aprovados.

## Bloqueios
Sem Win7/PS2/Corel/Foison físicos; testes específicos devem constar NÃO EXECUTADOS.

## Marco implementação
- PS orquestração + logs/ProcessRun + manifestos/migração/rollback implementados;
  20 casos de modelo/processo passaram em pwsh 7.6.7. PS2 não executado.
- 23 Python passaram. 52 C# E2E com engines reais Ubuntu passaram; net48 0 warnings.
- Unicode NSIS/PS/TXT BOM e inputcharset fixo; CMD ASCII/OEM segregado; gate textual.
- Pipeline atômico novo em scripts/build-release.py; estágio limpo e comparação
  byte-a-byte após NSIS/ZIP. Build de desenvolvimento em validação, não publicável.
- Próximo: concluir NSIS/ZIP local, commit/push, CI Windows (bootstrap/RedMon/UI/
  Shell ZIP), inspecionar artefatos e só então tag/prerelease.

## Marco build local de desenvolvimento
- Pipeline completo aprovado: builds Release net48/net8 sem warnings, 23 Python,
  20 modelos PS, 52 C#; NSIS 3.09 /WX sem warnings; payload NSIS extraído e
  comparado byte-a-byte; ZIP Deflate validado/extraído/hash e 7z t.
- Saída dist/development-rc1 explicitamente dirty/development, NÃO publicar.
- Últimas correções posteriores (resumo ASCII, ACL, mais propriedades da fila,
  decode UTF-8 primeiro e scripts CI) serão incluídas no build limpo do commit.

## CI 38989247059 / 6bc41db
- Ubuntu passou (23 Python / 20 modelos / 52 C#).
- Windows executou modelos e bootstrap missing-ps1 devolveu 66 com diagnóstico.
  Teste falhou porque filtro *-cmd.log também contou installation-latest-cmd.log;
  corrigido para install-*-cmd.log. Não foi falha silenciosa do produto.
- Acrescentados casos migração interrompida e ProgramData bloqueado (22 modelos),
  preservação do código original após rollback, duração total e inspeção Burn do
  VC2019 (Win7 x64 KB2999226 explícito). Testes locais passaram.

## Revisão adicional
- Mutex global NSIS protege também extração/desinstalação simultâneas, além do lock
  do PS; abortos NSIS são logados. Sucesso não afirma captura de spool não testada.
- Novo teste Windows executa subprocesso real com exit27/UTF-8/stdout/stderr,
  timeout e arquivo inexistente, independente dos modelos de processo.
- Build local limpo 9404ca6 em andamento; somente o CI final revisado será publicado.

## CI 38989478088 / 9404ca6
- Ubuntu e 22 modelos em pwsh/Windows PowerShell passaram. Bootstrap real: ausente
  ps1=66, PowerShell=69, sintaxe=1, exit23=23 com logs preservados.
- Detectado defeito real: redirecionamento ECHO em destino inválido não atualiza
  ERRORLEVEL de forma confiável no CMD; fallback podia seguir com código 0 antigo.
  Correção: marcador único efetivamente lido por findstr para provar escrita;
  erro 9009 preparado antes de lançar PS para falha de redirecionamento não virar 0.
- Teste nativo adicional força stdout.raw como diretório. Build local limpo 9404ca6
  passou completo, mas não é elegível para publicar porque falta esta correção.

## CI aprovado 38989726020 / 705e3df
- Ubuntu + Windows concluíram com sucesso. 23 Python, 22 modelos PS (7 e 5.1),
  52 C# net8/net48; builds 0 warnings/erros e NSIS 3.10 /WX.
- 6 cenários bootstrap nativos, subprocesso real Unicode/exit27/timeout/start failure,
  RedMon real isolado, UI real PortugueseBR/rejeição OS e Shell ZIP/hashes passaram.
- Artefato 12084776848 está sendo baixado para inspeção visual/CRC/hashes locais.
- Revisão final protege metacaracteres nos metadados CMD (aspas em caminhos) e
  acrescenta teste em pasta com Unicode e &. Sem mudar domínio/protocolo/UI.
- Inspeção manual adicional do VC2019: todos os imports estáticos VCRUNTIME140,
  VCRUNTIME140_1 e MSVCP140 dos engines existem nas DLLs do bundle fixado.

## Inspeção visual dos bytes aprovados 705e3df
- Artefato baixado completo; CRC do ZIP externo passou (245 entradas).
- Imagens de boas-vindas/licença/diretório/progresso/rejeição e WinForms abertas
  e revisadas: acentos pt-BR legíveis, prévia 20.000 x 20.000 mm, gates bloqueados.
- Título de boas-vindas longo ficava cortado em três linhas. Ajustado explicitamente
  para duas linhas curtas, sem remover acentos. Requer build/CI final novamente.
- Conclusão/desinstalação/Win7 real seguem não executados, não estão validados.

## Contrato de texto do pacote
- Revisão final fixou também CRLF nos TXT do staging, independentemente do host;
  BOM não basta para Notepad Win7 interpretar LF. Checksums ASCII também CRLF.
- Novo teste verifica BOM/acentos/CRLF/idempotência da normalização (24 Python).
  NSIS/ZIP continuam comparando bytes exatos do staging/extração; fontes originais
  de engines não são alterados. Aguardar CI final antes de publicar.

## Teste Unicode detectou outro caso real
- CI c459330 falhou no caso pasta ação & teste: código 73 com erro visível,
  porque findstr não conseguia verificar o caminho Unicode absoluto do log.
- Ajustado bootstrap: pushd nativo Unicode e nome ASCII relativo para findstr;
  não altera codepage global nem depende de nomes 8.3. Mesmo teste permanece
  obrigatório, sem ignorar falha. Aguardar CI do commit corrigido.

## Última revisão de rastreabilidade
- 9d0f864 passou CI 38991078711 completo e build Ubuntu local completo (24/22/52).
- Preservado também NativeErrorCode do Win32 no helper (ToString com mensagem
  customizada podia mostrar só HRESULT genérico); smoke nativo provoca falha de
  GetConfig na porta própria já removida e exige código numérico no log.
- Upload CI separado em ZIP cliente e evidências pequenas: EXE exato está dentro
  do ZIP e é conferido pelo SHA externo, evitando transferir duas cópias de 360 MB.
- O download do candidato anterior continua como evidência, não será publicado.
