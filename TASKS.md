# Diagnóstico da captura — 1.0.1-rc.4 (candidato, sem homologação)
- [x] Instrumentar Receiver: RunId/AttemptId, stdin, tamanho/hash/formato, logs,
  persistência, códigos e metadados de rejeições sem guardar documentos.
- [x] Experimento A binário direto no harness e fluxo guiado com verificação do
  parser e da persistência, independente de spooler/RedMon/COM.
- [x] Diagnóstico de um clique, monitoramento durante Corel, relatório ZIP
  sanitizado, atalho do menu Iniciar e instruções; corte/serial não utilizados.
- [x] Contratos de rejeição segura e logs; teste smoke binário real em Linux.
- [x] Completar regressão C# com motores vetoriais, builds net48, NSIS/ZIP local,
  checksums e extração. 73 checks C# E2E e 38 testes Python passaram.
- [ ] Aguardar CI do pipeline oficial em commit limpo; build local unificado não
  pôde executar testes PowerShell porque `pwsh` não está instalado.
- [ ] Validar o fluxo WinForms e exportação ZIP em Windows, com fixture/testes.
- [ ] Executar Experimento B em Windows 7 SP1/PS2/Corel X6; sem declarar causa
  raiz ou compatibilidade até observar os logs da sessão real.

## Painel de corte rc.3 — retorno do cliente
- [x] Receber relato positivo de instalação/fila no Corel (não é corte validado).
- [x] Inspecionar RAR privado; principais componentes idênticos ao CIrc.2.
- [x] Diagnosticar PScript sem UI OEM e implementar painel explícito no aplicativo.
- [x] Geometria de ajustes testada, ensaio revogado, protocolo/limites preservados.
- [x] Concluir pacote/CI39058232989/screenshots e conferir artefatos919ec25.
- [x] Cliente abriu aplicativo: lista vazia, captura ainda NÃO comprovada.
- [x] Coletor somente leitura de pasta/fila/Spooler/RedMon e exportação.
- [x] Documentar evidência, hipóteses H01–H12 e primeiro limite ainda sem prova.
- [x] Preparar coletor PS2 somente leitura para fila, jobs ativos, RedMon, processos e metadados de spool.
- [ ] Instrumentar Receiver com RunId/job, bytes/EOF, assinatura, persistência e erro sem conteúdo bruto.
- [ ] Correlacionar um job sintético no Windows 7/PS2 e corrigir o primeiro estágio reproduzivelmente falho.
- [ ] Validar prévia, ensaio e corte no alvo, sem presumir cadeia funcional.

## Correção Win7/PS2 1.0.1-rc.2
- [x] Auditar main atual e logs reais correlacionados, sem atribuir falha a ACL.
- [x] Substituir executor e corrigir append/BOM NSIS/código real.
- [x] Testes reais Ubuntu + compile C#2/net20 + matriz de regressão.
- [x] Preparar laboratório isolado; KVM/VM vazia comprovados e desligados.
- [x] Concluir CI Windows moderno, PS2/CLR2 real no Server2022, build e ZIP candidato validado.
- [ ] Executar Win7 SP1/PS2/CLR2 com mídia legítima (ainda não fornecida).
- [ ] Homologar instalação/reinstalação/desinstalação/fila no alvo; sem merge/final antes disso.

## Missão 1.0.1-rc.1
- [x] Auditar repositório e ZIP anterior sem presumir corrupção.
- [x] Corrigir orquestração, estado, ownership, logs e contrato Unicode.
- [x] Implementar pipeline único e testes negativos/modelos.
- [x] Concluir build/NSIS/extração/hash/ZIP e CI Windows nativo.
- [x] Inspecionar evidências visuais disponíveis e registrar pendências Win7.
- [x] Publicar prerelease versionada com EXE/ZIP/checksums após aceite aplicável.
- [ ] Validar Win7/PowerShell 2/CorelDRAW e hardware reais na sessão acompanhada (não disponíveis aqui).

# Tarefas — prioridade primeiro quadrado físico

## Implementado, aceitação automatizada em andamento

- [x] Núcleo geométrico C# compartilhado net48/net8 e interpretação PS real.
- [x] Prévia em milímetros, curvas, afins e abertos/fechados sem rasterizar.
- [x] Gerador HPGL limitado e autorização por revisão/perfil/trabalho.
- [x] Serial real exclusiva com timeout/cancelamento e journal sem retry.
- [x] Confirmação operador, ensaio sem lâmina, limites e latch de interrupção.
- [x] Provisionamento inbox exato + RedMon GetConfig/SetConfig e read-back.
- [x] Desenho 20 mm e fixtures vetoriais/rejeições, stdin e serial simulados.
- [x] Procedimento de evidência Flexi via setup FILE sem tocar FTDI.
- [x] Empacotamento offline completo com ferramentas, pré-requisitos e fontes.
- [x] Revisão final de segurança, build NSIS e testes finais Ubuntu.
- [x] Actions 38972159423: net48/engines, UI smoke, APIs RedMon Windows 2022 e ZIP inspecionado.

## Exige ambiente real; não presumir concluído

- [ ] Instalar e verificar Win7 SP1 x64, pré-requisitos, fila, XcvData/RedMon.
- [ ] Imprimir pelo CorelDRAW X6 e anexar fixture autorizada sanitizada.
- [ ] Confirmar revisão, wire protocol, resolução, eixos, inicialização, lâmina.
- [ ] Confirmar COM2 real (38400/8N1/Xon-Xoff/DTR/RTS) e porta ocupada.
- [ ] Medir origem/área, ensaio sem lâmina e interrupção física segura.
- [ ] Autorizar e medir primeiro quadrado físico de 20 mm.
