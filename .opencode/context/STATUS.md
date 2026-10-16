# Objetivo / aceite
Candidato único para primeira sessão acompanhada: PS vetorial → prévia mm →
HPGL condicionado à prova de revisão → serial exclusiva → ensaio/corte autorizado.
Não entregar captura-only nem prometer hardware validado.

## Decisões e áreas alteradas
- Checkout real nesta subpasta, recuperado do GitHub a partir de 610e5ec; pai preservado.
- C# net48/net8 compartilhado: conversão GS/MuPDF reais, geometria, perfil/plano,
  IWire/Sender/journal; UI portuguesa e serial net48; Receiver binário atômico.
- Envelopes EOT/PJL estritos; clips só aceitos quando retangulares e inofensivos.
- IN/PA/PU/PD e resolução sem presunção; aprovação por sessão/plano/operador.
- Latch persistido antes do primeiro byte; sem retry e sem reset wire desconhecido.
- Provisionador RedMon corrigido pelo fonte 1.9: Redirected Port, RECONFIG e
  XcvDataW GetConfig/SetConfig/read-back. Driver inbox exato PScript5 x64.
- NSIS/ZIP completo com dependências oficiais fixadas, pré-requisitos e fontes.
  Setup RedMon exige chm/helper original; Bridge nunca executa seu desinstalador.
- Arquivos/comandos e roteiro técnico em README, docs e PRIMEIRA-SESSAO.md.

## Validações / entrega
- Código do candidato 48bdc05; workflow 38972159423 SUCCESS.
- 14 testes Python/contratos, 52 checks C# Ubuntu e net48/engines Windows reais.
- Spooler Windows 2022 real: Add/Get/Set/read-back/Enum/DeletePort passaram;
  nenhum teste de fila Corel/Win7 ou porta física.
- Build net48 sem warnings/erros no CI; NSIS /WX e PowerShell passaram.
- UI smoke revisada: quadrado 20 mm e envio bloqueado por padrão.
- Artefatos baixados e inspecionados: ZIP/CRC/SHA256, payload e fontes completas.
  Diferenças textuais do source archive são somente CRLF do checkout Windows.
- dist contém bytes exatos do CI: FoisonC24-Setup-x64.exe e ZIP Cliente-Win7-x64.
  Hash instalador: 48dd511435cad211d2a8f17eb2daebc9e0974ab0aeea5fd452bc7c5e4abd2d8a.
- Primeiro CI falhou pelo BOM no stdin simulado Framework; harness corrigido e
  igualdade SHA256 exigida, sem relaxar o receptor. Auditoria NuGet local indisponível.

## Bloqueios / próximos passos
Sem Win7/CorelDRAW X6/FlexiSIGN 12/Foison físicos. Protocolo, resolução, origem,
limites e serial reais ainda não comprovados. Seguir PRIMEIRA-SESSAO; sem prova
não mover. Pré-requisitos podem exigir reboot/atualização. Não apagar journal
para repetir trabalho incerto. Entrega é candidato completo, não corte validado.
