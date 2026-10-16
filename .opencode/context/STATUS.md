# Objetivo
Preparar candidato único para primeira sessão acompanhada: PS vetorial → prévia → HPGL → serial, sem autorizar hardware não comprovado.

## Critérios de aceite
Conversão vetorial real; escala/orientação testadas; limites e autorização por trabalho; serial exclusiva/cancelável sem retry; instalador e ZIP reais; testes Ubuntu e Windows CI; nenhuma alegação de validação Win7/hardware.

## Decisões
- Base clonada do GitHub em 610e5ec; diretório pai não era checkout válido.
- Domínio compartilhado C# net48/net8, UI net48. Python existente permanece referência experimental, não motor Windows.
- PostScript interpretado por Ghostscript isolado (-dSAFER), PDF vetorial intermediário e trace XML do MuPDF; sem rasterização. Conteúdo não suportado falha fechado.
- Protocolo/revisão/unidades não comprovados: aprovação de desenvolvedor por sessão e de operador por trabalho, nunca habilitação automática por arquivo/captura.

## Próximos passos
Implementar motor, testes determinísticos, integração UI/serial e empacotamento com dependências/licenças/fontes; revisar provisionamento; executar validações e publicar commits.

## Bloqueios
Sem Win7, CorelDRAW X6, FlexiSIGN 12 ou Foison física. Binários de terceiros também exigem teste de execução no Win7 real.

## Marco: núcleo e UI
- Adicionados domínio C# net48/net8, flattening Bézier 0,01 mm, leitor MuPDF com falha fechada, gerador HPGL IN/PA/PU/PD restrito e journal sem retry.
- Conversão GS real do quadrado 20 mm → plano → serial simulada: 27 checks passaram. 14 testes Python/contratos passaram.
- UI portuguesa com prévia, perfil de revisão por sessão, confirmações por plano e transporte serial net48 compila; captura publica marcador atomicamente.
- Build net48 dos três executáveis passou. Auditoria NuGet indisponível neste ambiente (NU1900); não implica auditoria de vulnerabilidades aprovada.
- Corrigida corrida de término do processo no monitor de memória, encontrada pelo teste real.
- Provisionamento agora solicita o modelo inbox exato MS Publisher Imagesetter e verifica PScript5 x64; ainda não executado em Win7.

## Marco: aceitação local ampliada
- 44 checks C# passaram após rebuild: inclui autorização por hash, porta ocupada sem bytes, cancelamento durante envio e pipeline Receiver stdin real → GS/MuPDF reais → HPGL → fake serial.
- Builds net48 atuais passaram (NU1900 de auditoria local indisponível no núcleo; demais sem warnings).
- NSIS completo em compilação. Adicionado teste de APIs RedMon em Windows 2022 descartável no CI e UI smoke (a executar).
- Fonte RedMon revelou nome de monitor errado no código anterior. Corrigido para Redirected Port, configuração binária e read-back; ainda sem execução nativa até CI.

## Marco: CI e compatibilidade de impressão
- Commits 67ba7fe e 5218126 enviados. Run 38969791489: Ubuntu passou; net48 passou geometria/engines Windows, falhou no stdin simulado do Receiver (formato desconhecido).
- Investigação: StreamWriter do stdin redirecionado no Framework pode acrescentar BOM, diferente do pipe binário RedMon. Harness agora força UTF8 sem BOM e exige SHA256 raw idêntico à fixture; repetir CI antes de entregar.
- 48 checks locais passaram na expansão anterior: envelopes EOT/PJL estritos e clip retangular que não altera vetores. Clips intersectantes continuam rejeitados.
- NSIS completo compilou sem warnings, mas ainda não é entrega final: regerar com fonte/commit atual após CI.
