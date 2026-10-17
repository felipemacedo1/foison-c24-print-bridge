# 1.0.1-rc.1 — matriz de aceitação e limites

Versão implícita anterior: SDK 1.0.0.0; nenhuma tag/release no remoto durante a
auditoria. Próxima correção 1.0.1-rc.1. Não se declara instalação funcional no
Win7 apenas por build, mocks, APIs em Windows 2022 ou transmissão serial.

## Evidências locais (Ubuntu)

- 23 testes Python (domínio, contratos, ZIP negativo/positivo, Unicode).
- 20 casos PS em PowerShell 7.6.7, orquestração real com adaptadores de spooler
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
extraído de URL oficial fixada. Não seguir `latest` moderno, cuja matriz não
inclui Win7. [Versões v142](https://learn.microsoft.com/en-us/lifecycle/faq/visual-c-faq),
[redist moderno](https://learn.microsoft.com/en-us/cpp/windows/latest-supported-vc-redist).
Bootstrap VC é PE x86 contendo runtime x64; engines/RedMon/helpers são AMD64;
Core AnyCPU sem 32BITREQUIRED; subsistemas PE <=6.1. Essas checagens não provam
que todos os imports dinâmicos/UCRT funcionem no Win7. Engines reais rodam como
selftest no destino **antes** de criar fila; se faltarem APIs/runtime, bloqueiam.
O CI Windows 2022 verifica execução net48 e engines Windows, não seu suporte legado.
Atualizações legítimas UCRT/SHA-2 podem ser necessárias. [NSIS suporta Win7](https://nsis.sourceforge.io/Docs/Chapter1.html).
