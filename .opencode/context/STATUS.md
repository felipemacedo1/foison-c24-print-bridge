# Objetivo / resultado
Correção de instalação Win7, logging/Unicode, build e release computacional entregue
como 1.0.1-rc.1. Corte físico segue bloqueado por padrão. Não declarar Win7 validado.

## Aceite e decisões
- Cliente/tag b2df7cd / v1.0.1-rc.1; CI 38993143001 aprovado Ubuntu+Windows 2022.
- Promoção 38995440164 aprovada; release pública prerelease=true/draft=false, 5 assets.
- Versão anterior SDK implícita 1.0.0.0, sem tags/releases; main sem PR obrigatório
  na auditoria. Sem force/reset/deleções de releases ou histórico.
- Publicação promove bytes imutáveis, sem rebuild/overwrite/stable; digests GitHub
  conferidos. Código de promoção em main é separado do SHA cliente tagueado.

## Áreas alteradas
PS2/CMD, helper Win32, diagnóstico/sonda sem serial, NSIS Unicode, VERSION/props,
pipeline build/PKZIP/PE/encoding, testes/modelos/nativos, workflows e documentação.
Estado .properties atômico com migração, ownership/fingerprint, rollback restrito;
monitor comprovado antes de portas; logs desde bootstrap e códigos nativos reais;
BOM/CRLF e pt-BR. Lib de link/debug omitida do runtime, não dos fontes licenciados.

## Validações
- Candidato: 25 Python, 22 modelos PS, 52 C# por runtime; main atual 26 Python.
- Release net48/net8 e NSIS 3.09 local / 3.10 CI sem warnings/erros.
- Nativos Windows 2022: 7 falhas/bootstrap, processos/UTF-8/timeout/start failure,
  RedMon isolado/erro Win32 87, UI e Shell.Application ZIP/hash.
- Imagens finais abertas/revisadas: acentos legíveis e título sem corte.
- ZIP cliente 8 arquivos, PKZIP método 8, 361149977 bytes; CRC, 7z, extração completa,
  comparação de hashes, payload NSIS e fontes conferidos localmente e na promoção.
- EXE SHA256 bf46847b38d1974f6862211c8756c2d7a414aca9a4d8a6445a76f0ed82c12747.
- ZIP SHA256 a3aa2cc69a1c432a0b1390a61abff6830a94cb9b4ce8fc25b18e49d76c5a6ee9.
- ZIP anterior disponível íntegro; causa do sintoma do cliente não determinada.
- Matriz/limites: docs/release-validation.md; logs e imagens anexados à release.

## Bloqueios / próximo passo
Sem Win7/PS2/CorelDRAW/Foison reais: instalação/fila/extração alvo, telas finais/
desinstalação, protocolo/revisão/limites/calibração/serial/corte NÃO EXECUTADOS.
Realizar sessão acompanhada; sem comprovação de condições não enviar movimentos.
Preservar FTDI/COM2/FlexiSIGN/filas externas e journal/latch de estado físico incerto.
