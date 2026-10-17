# 1.0.1-rc.1 — matriz de aceitação e limites

Versão implícita anterior: SDK 1.0.0.0; nenhuma tag/release no remoto durante a
auditoria. Próxima correção 1.0.1-rc.1. Não se declara instalação funcional no
Win7 apenas por build, mocks, APIs em Windows 2022 ou transmissão serial.

## Evidências locais (Ubuntu) e release publicada

- 25 testes Python do candidato (26 no ramo atual, incluindo promoção) (domínio, contratos, ZIP negativo/positivo, Unicode).
- 22 casos PS em PowerShell 7.6.7, orquestração real com adaptadores de spooler
  simulados; arquivos de estado/log/lock reais. NÃO executa PowerShell 2.
- 52 checks C# E2E com GS 10.02.1 e MuPDF 1.23.10 reais; stdin/binário/serial
  simulados; sem porta serial/hardware.
- net48 e NSIS Unicode 3.09: execução/build final registrados no relatório do
  pipeline; não são evidência de execução no Win7.

| Cenário | Cobertura automatizada | Windows 7 real |
|---|---|---|
| instalação limpa / RedMon ausente | modelo: monitor antes de portas, registro pós-setup | NÃO EXECUTADO |
| RedMon existente / porta ocupada | modelo preserva monitor e escolhe outro FOISONC24n | NÃO EXECUTADO |
| reinstalação / pós-desinstalação | modelo, mesmo owner e sem reconfigurar fila completa | NÃO EXECUTADO |
| sem admin / dependência ausente | modelo, exit=1, etapa/erro persistidos | NÃO EXECUTADO |
| driver ausente / falha na criação | modelo, rollback somente recursos atuais | NÃO EXECUTADO |
| fila homônima / alterada externamente | modelo, nenhuma exclusão | NÃO EXECUTADO |
| instalação interrompida | modelo, recupera quando prova; preserva caso ambíguo | NÃO EXECUTADO |
| concorrência / lock | arquivo exclusivo real, finally libera somente próprio | NÃO EXECUTADO |
| legado .json chave=valor | leitura literal, migração e backup | NÃO EXECUTADO |
| Provisioner não zero / timeout / launch failure | runner real com objeto de processo simulado; stdout/stderr e duração | NÃO EXECUTADO |
| CMD sem PS / sem ps1 / erro de sintaxe / exit23 | teste nativo Windows no CI | NÃO EXECUTADO |
| log sem permissão | modelo fallback + CMD nativo CI em caminho bloqueado | NÃO EXECUTADO |
| ZIP / extração / SHA256 | headers+CRC Python, extração completa/hash, 7z; Shell Windows CI | NÃO EXECUTADO |
| fila/PScript/RedMon/Receiver | sonda `capture-test` implementada, sem serial | NÃO EXECUTADO |
| CorelDRAW X6 imprimindo | sessão acompanhada obrigatória | NÃO EXECUTADO |
| serial / protocolo / limites / corte físico | somente simulador + gates; autorização por sessão/trabalho | NÃO EXECUTADO |

Testes de modelo não substituem instalação real, nem os cenários nativos CI.
Logs de falha simulados são retidos no artefato de evidência, sem jobs de clientes.
NSIS não prossegue em Windows 2022: rejeição intencional antes de extrair/provisionar.

## ZIP anterior

`docs/previous-zip-audit.json`: arquivo exato de 351266680 bytes, magic PK0304,
8 entradas método 8, diretório central/CRC íntegros, sem duplicatas/encriptação/
ZIP64. Python e 7z passaram. Não reproduzimos corrupção. Não há o sintoma exato
nem logs da máquina do usuário: causa do comportamento estranho **não determinada**.
O ZIP externo do Actions com artefatos aninhados pode confundir, mas é hipótese.
Nova release oferece ZIP do cliente diretamente, com uma única pasta ASCII.

## Encoding e causa investigada

Fontes auditados: NSIS, includes, PS, CMD, C#, resx quando presentes, TXT e MD;
relatório automatizado lista charset/BOM. Não havia padrões de mojibake nos
fontes rastreados. NSIS antigo e TXT estavam UTF-8 **sem BOM** e build sem charset
explícito; NSIS pode interpretá-los pelo ACP. Isso é um defeito reproduzível de
contrato de encoding, compatível com a falha relatada; sem screenshot antigo não
se atribui com certeza a causa de cada tela do cliente.

Correção: `Unicode true`, MUI PortugueseBR, NSIS/PS UTF-8 BOM, compilação
`INPUTCHARSET UTF8`, TXT UTF-8 BOM para Notepad Win7, CMD só bootstrap ASCII.
NSIS log separado UTF-16LE BOM; PS/componentes UTF-8 BOM; CMD metadata OEM com
codepage registrado, streams .raw preservados separadamente. Não há mistura de
bytes OEM em arquivo UTF-8. Nenhum `chcp 65001` como remendo universal.
As seis frases pt-BR constam em TEXTOS-VALIDACAO.txt; bytes são comparados depois
de extrair instalador e ZIP. CI inspeciona texto Unicode de controles e captura
welcome/licença/diretório/rejeição reais. Conclusão/desinstalação e pt-BR Win7
requerem ambiente alvo e permanecem pendentes; isso impede declarar versão estável.

Referências primárias: [charset NSIS](https://nsis.sourceforge.io/Docs/Chapter3.html),
[Unicode e ACP](https://nsis.sourceforge.io/Docs/AppendixF.html),
[logs UTF-16 NSIS](https://nsis.sourceforge.io/Docs/Chapter4.html).

## Runtime / dependências

.NET alvo 4.8, não 4.8.1. [Matriz Microsoft](https://learn.microsoft.com/en-us/dotnet/framework/get-started/system-requirements).
VC++ embarcado 2019 v142 **14.29.30157.0 x64**, versão/hash verificados no build,
extraído de URL oficial fixada. O BurnManifest foi extraído e contém explicitamente
Windows7_MSU_x64 / KB2999226, condição `VersionNT = v6.1 AND VersionNT64`,
MSI runtime 14.29.30157 e condição bootstrap que admite NT6.1 x64. O pipeline
verifica essas condições do bundle real; não confunde isso com execução no Win7. Não seguir `latest` moderno, cuja matriz não
inclui Win7. [Versões v142](https://learn.microsoft.com/en-us/lifecycle/faq/visual-c-faq),
[redist moderno](https://learn.microsoft.com/en-us/cpp/windows/latest-supported-vc-redist).
Bootstrap VC é PE x86 contendo runtime x64; engines/RedMon/helpers são AMD64;
Core AnyCPU sem 32BITREQUIRED; subsistemas PE <=6.1. Essas checagens não provam
que todos os imports dinâmicos/UCRT funcionem no Win7. Engines reais rodam como
selftest no destino **antes** de criar fila; se faltarem APIs/runtime, bloqueiam.
O CI Windows 2022 verifica execução net48 e engines Windows, não seu suporte legado.
Atualizações legítimas UCRT/SHA-2 podem ser necessárias. [NSIS suporta Win7](https://nsis.sourceforge.io/Docs/Chapter1.html).

## Aceite final e publicação

- Código cliente/tag: **b2df7cd / v1.0.1-rc.1**. Main contém também automação
  de promoção, sem modificar os bytes desse candidato. PR não exigido pela política
  observada; main não protegida, sem rulesets no início da auditoria.
- [Build e gates completos](https://github.com/felipemacedo1/foison-c24-print-bridge/actions/runs/38993143001):
  Ubuntu + Windows 2022 aprovados. 25 Python, 22 modelos PS (pwsh e Windows
  PowerShell 5.1), 52 C# por runtime; net48/Release e NSIS Unicode 3.10 /WX sem warnings/erros.
- Sete cenários CMD nativos passaram: ps1 ausente=66, PS ausente=69, sintaxe=1,
  filho exit23=23, fallback=23, stdout bloqueado=9009, caminho Unicode/&=23.
  Process runner real preservou UTF-8/stdout/stderr/exit27 e diagnosticou timeout/
  launch failure sem herdar o código anterior. RedMon GetConfig na porta própria
  já removida produziu **NativeErrorCode=87** em log preservado.
- UI final aberta e imagens inspecionadas: boas-vindas (título agora em duas linhas),
  licença, diretório, progresso/rejeição e WinForms com prévia 20.000 x 20.000 mm.
  Acentos legíveis. Botões nativos de MessageBox seguem o idioma do Windows de
  teste (en-US). Finalização/desinstalação/locale pt-BR no Win7 NÃO executados.
- Shell.Application extraiu o ZIP no Windows 2022 e conferiu todos os hashes.
  Isso não é teste do Shell no Win7.
- Build local completo do mesmo b2df7cd aprovado com NSIS 3.09; os assets publicados
  são os bytes do CI Windows 3.10, não uma reconstrução local.
- Download local desses bytes: headers, CRC Python, 7z t, extração completa,
  comparação SHA256, TXT BOM/CRLF, payload NSIS e fontes correspondentes conferidos.
  gsdll64.lib de link foi omitido do runtime; scripts PostScript lib/ preservados.
- [Promoção aprovada](https://github.com/felipemacedo1/foison-c24-print-bridge/actions/runs/38995440164)
  sem rebuild, somente rc, verificando run/SHA/tag, CRC/hashes/PE antes de upload e
  digests/tamanhos retornados pelo GitHub após upload. Sem --clobber/deleções.
- [Release pública](https://github.com/felipemacedo1/foison-c24-print-bridge/releases/tag/v1.0.1-rc.1)
  confirmada com prerelease=true e draft=false; EXE, ZIP cliente, checksums,
  validation.json e ZIP de evidências (logs sintéticos de falha + imagens).

### Artefatos exatos

| Arquivo | Bytes | SHA256 |
|---|---:|---|
| FoisonC24-Setup-Win7-x64.exe | 361331246 | bf46847b38d1974f6862211c8756c2d7a414aca9a4d8a6445a76f0ed82c12747 |
| FoisonC24-v1.0.1-rc.1-Win7-x64.zip | 361149977 | a3aa2cc69a1c432a0b1390a61abff6830a94cb9b4ce8fc25b18e49d76c5a6ee9 |

ZIP cliente: 8 arquivos, todos método 8, PKZIP convencional, sem ZIP64/AES/
multipartes; nomes ASCII e pasta única. Manifesto dentro do ZIP cobre os demais
arquivos; SHA256SUMS externo cobre EXE/ZIP/relatório/evidências. Não há hash circular.

### Causas-raiz confirmadas durante validação

Além da ordem RedMon/admin/estado/rollback, o CMD podia manter ERRORLEVEL=0
após falhar redirecionamento ECHO. Agora prova escrita por marcador lido e prepara
erro 9009 antes de lançar o PS. Findstr recebia caminho Unicode absoluto e podia
falhar: agora opera com nome ASCII relativo após pushd. Códigos antigos eram
reutilizados em launch failure/timeout; agora limpos por tentativa. ToString do
Win32Exception com mensagem customizada perdia a causa nativa; código numérico
agora explícito. Corrupção no ZIP anterior não foi reproduzida.

**Pendência externa:** instalação/reinstalação/desinstalação reais em Win7 SP1 x64,
PowerShell 2, driver/fila/RedMon/GDI/CorelDRAW X6, protocolo da revisão, limites/
calibração, serial e corte. Não declarar candidato validado no operador.

Os links públicos do instalador e ZIP responderam HTTP 200 após publicação.
Os quatro hashes do manifesto externo publicado foram conferidos novamente nos
arquivos locais; ZIP de evidências publicado (199 arquivos) passou CRC, extração
e 7z. As evidências são de laboratório/fixtures, não de trabalhos de clientes.
