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
