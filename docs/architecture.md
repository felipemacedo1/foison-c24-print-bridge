# Arquitetura — candidato de primeira sessão

Alvo: Windows 7 SP1 x64, .NET Framework 4.8, CorelDRAW X6. Desenvolvimento e
núcleo testável no Ubuntu (.NET 8). Compatibilidade real com Win7/hardware não
foi executada. Dependências Windows também exigem validação no SO de destino.

```
CorelDRAW → PScript5 x64 (MS Publisher Imagesetter inbox) → RedMon 1.9
 → Receiver (stdin limitado → raw imutável → marcador JSON atômico)
 → seleção explícita na UI WinForms (usuário normal, não spooler/SYSTEM)
 → Ghostscript -dSAFER / pdfwrite / NoOutputFonts (processo isolado)
 → PDF vetorial → MuPDF draw -F trace (processo isolado)
 → TraceParser → domínio em milímetros → prévia
 → Hpgl.Build (somente após perfil comprovado) → plano imutável
 → Authorization por hash + journal → IWire → SerialPort exclusivo
```

## Separação

- `FoisonC24.Core`: conversão, geometria, perfil, plano, bloqueios e journal;
  `IWire` permite fake determinístico sem SO/impressora.
- `FoisonC24.WindowsReceiver`: somente captura; não interpreta nem abre COM.
  Limite de 64 MiB, nome único por GUID, marcador ready somente após raw completo.
- `FoisonC24.Diagnostic`: UI portuguesa, confirmações, visualização do mesmo
  modelo do gerador, diagnóstico e adaptação `SerialPort` net48.
- `FoisonC24.Provisioner` + PowerShell 2: somente integração spooler/RedMon.
- Módulo Python anterior permanece protótipo independente, não é o motor do
  produto Windows. Não é usado como evidência do comportamento C#.

## Interpretação e geometria

PostScript é uma linguagem, não um conjunto de regex. Ghostscript interpreta
procedimentos/prologs/fontes/CTM reais. `pdfwrite` preserva vetores; texto é
convertido a contornos. MuPDF extrai operações vetoriais via trace, sem bitmap
nem vectorização de raster. Qualquer imagem, texto residual, clip intersectante/não retangular, grupo,
transparência, sombreado, operação desconhecida ou múltiplas páginas bloqueia
a conversão. Não se omitem silenciosamente partes do desenho.

As transformações afins são aplicadas antes da conversão pontos→mm; Y é
normalizado para cima. Curvas cúbicas usam subdivisão adaptativa com erro
máximo 0,01 mm no modelo físico, com limite de profundidade. Fechamento é
preservado (fill implica fechamento; stroke aberto permanece aberto).
Preenchimentos geram perímetros; strokes geram linhas centrais. Não há
compensação de arrasto/lâmina, ordenação otimizada, weed box ou ajuste à mídia.
Estes não são necessários para um quadrado sem preenchimento e não devem ser
confundidos com qualidade de produção de curvas/letras pequenas.

Processos: sem shell, prazo 30 s, working set monitorado 512 MiB, intermediário
32 MiB, diagnóstico limitado e leitura em blocos. XML sem DTD/entidades externas.
Limites não são sandbox OS: somente trabalhos locais confiáveis. Não executar
UI elevada; selftest do instalador só usa fixture própria confiável.

## Provisionamento

Pede driver inbox exato pelo INF Microsoft, verifica WMI nome+PScript5 x64
único, sem redistribuir DLL/INF Microsoft do spooler. Falha em vez de escolher
um driver aleatório. RedMon: `,XcvMonitor Redirected Port` (nome conferido no
código-fonte 1.9), `XcvDataW(AddPort/GetConfig/SetConfig)` com RECONFIG Unicode
6180 bytes/version 190 e read-back. Isso evita o caminho rundll32 que não
comprova persistência e evita aspas aninhadas inválidas em Arguments.
A porta executa Receiver sem argumentos (usa ProgramData padrão).

Fila existente alheia nunca é removida; portas FOISONC24n: são enumeradas.
Manifesto string-data histórico em `install-state.json` prova propriedade
somente dos recursos do Bridge. Rollback é restrito à execução atual. Falha de
remoção preserva manifesto/porta; nenhuma desinstalação do RedMon compartilhado
ou remoção do driver inbox ocorre. Logs de erro não usam Write-Error sob Stop,
que abortaria o próprio rollback. FTDI/FlexiSIGN não são alterados.

## Transmissão e falhas

Sem aprovação de revisão/unidades/comandos/área, nem se abre a porta. Uma
confirmação vincula desenho+comandos+perfil, com origem normalizada e margem
explícita; nada é escalado para caber. Mudança de porta invalida aprovação.
Journal global persistente, lock exclusivo, uma tentativa por hash/modo antes
do primeiro byte. Sem retry/reconexão. Latch global é persistido antes do primeiro byte (inclusive contra crash). Falha/cancelamento preserva estado
incerto; encerrar/reinstalar app não libera. Limpar latch exige procedimento
manual do desenvolvedor após conferir o buffer/máquina, nunca reenvio incerto.
BytesToWrite zero só comprova buffer do PC, não execução física. O botão PC não
é emergência; PAUSE/OFFLINE e procedimento da revisão são obrigatórios.

Envelopes EOT/PJL PostScript são normalizados estritamente (8 KiB de metadados),
sem executar PJL e preservando o raw. Clip retangular que contém integralmente
todos os vértices e controles é aceito por não alterar a geometria; qualquer
interseção, clip curvo ou desconhecido bloqueia, sem fingir aplicar recorte.

## Instalação 1.0.1-rc.1 e rastreabilidade

NSIS Unicode/PortugueseBR x86 é bootstrap para payload AMD64 e PS 64 bits no
Win7 SP1. Runtimes precedem os helpers net48; o monitor é comprovado por
EnumMonitors antes de EnumPorts. AddPrinter atribui comentário de ownership
atomicamente; porta RedMon recebe o mesmo UUID e configuração com read-back.
PS usa WMI compatível com PS2, lock exclusivo e manifesto literal UTF-8
.properties com publicação atômica. Legado .json chave=valor requer prova de fila/
porta e intenção de migração persistida antes de adoção. Incerteza/alteração externa
bloqueia remoção, não autoriza adivinhar propriedade. Monitor e driver compartilhados
nunca são removidos. NSIS possui mutex e verificação independente antes de concluir.

Logs por execução iniciam no CMD antes do PS; mensagens bootstrap ASCII e codepage
registrado, PS UTF-8 BOM, NSIS UTF-16LE BOM, streams raw separados. Fallback TEMP,
retention, timeouts, etapas e códigos/Win32 nativos preservados. Configuração/exes
não recebem escrita de Users; somente diretório de sessão necessário à operação.
TXT do cliente normalizados BOM+CRLF; fontes/bytes de engines permanecem íntegros,
com omissão de intermediários de link/debug do runtime. ZIP PKZIP Deflate validado
por CRC/headers/extração/hash/7z e Shell Windows 2022. Promoção manual não reconstrói:
confere run/SHA/tag e hashes e só cria prerelease com bytes aprovados. Isso não
substitui a aceitação Win7/PS2/CorelDRAW/hardware.

## Executor legado e prova de conclusão (rc.2)

PowerShell2 permanece no CLR2; não carregar DLL net48 nesse host. O PS1 compila
helper C#2 com APIs net20, ProcessStartInfo.UseShellExecute=false e token herdado.
Dois leitores binários concorrentes preservam stdout/stderr; PeekNamedPipe evita
read bloqueante Windows, com timeout/kill só do próprio filho e drain limitado.
Não há Start-Process no caminho de produção. HashAlgorithm usa Clear público
CLR2, não Dispose dinâmico (que não era público nesse runtime).

ExitCode desconhecido não é zero. PS2 -File pode retornar0 após erro terminante;
CMD exige recibo ASCII fresco por nonce/run/op emitido só após Invoke-BridgeSetup
positivo. NSIS aguarda CMD e verify independente e verifica launch failure além
do retorno. Recibo é prova do fluxo verificado, não autorização física nem prova
Corel/corte. Proteções de ownership/rollback/journal e protocolo não mudam.

CLR2 foi exercitado de verdade no Server2022 (patch9179); isso não substitui
Win7/CLR2.8803, impressão alvo nem validação física. Cada estado é independente.
