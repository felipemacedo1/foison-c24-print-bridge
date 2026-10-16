# Primeira sessão — checklist do desenvolvedor (não do cliente)

**Candidato com conversão e transporte reais, mas ainda não validado no Win7,
CorelDRAW X6 e revisão física C24. Não é promessa de primeiro corte.**

## Antes de começar

- Confirmar Windows 7 SP1 x64, atualizações necessárias, acesso administrativo,
  .NET 4.8 e VC++ 2019. O instalador offline inclui os dois pré-requisitos; se
  exigirem reboot, é necessário reiniciar antes de instalar a fila.
- Manter instalador e ZIP originais/checksums. Backup da configuração funcional
  FlexiSIGN por meios do próprio software, sem exportar dados pessoais.
- Anotar revisão/firmware da C24, ajustes Xp/Yp sem alterá-los, configuração da
  COM2/FTDI e parâmetros do Flexi (38400, 8N1, Xon/Xoff, DTR/RTS).
- Nenhum driver/filtro serial deve ser instalado. Não executar PortMon, não
  duplicar a COM2, não mudar número de COM nem matar processos.

## Obter evidência legítima do FlexiSIGN 12

A documentação oficial SAi descreve a porta **FILE**, que salva os dados de
saída do dispositivo, diferente de “Save to file” do Cut/Plot (.prt nativo).
Disponibilidade no Flexi 12 local ainda deve ser confirmada.

1. Esvaziar/pausar trabalhos pendentes e fotografar/anotar a configuração
   funcional original, com autorização do cliente.
2. Preferir criar um **setup temporário separado** no Production Manager, mesmo
   modelo/driver Foison e mesmas configurações, mas porta FILE. Nunca alterar
   o setup usado em produção para testar uma hipótese.
3. Exportar somente desenhos sintéticos: quadrado 20 mm; L assimétrico 10×20;
   curva simples; caminho aberto. Escala 100%, uma cópia, sem otimização,
   compensação, repetição, weed box, marca ou avanço final.
4. Se FILE ou setup separado não existirem, parar e pedir ao suporte SAi/Foison
   um método documentado. Não instalar sniffer e não interceptar o driver FTDI.
5. Guardar bytes originais e SHA256, sem reenviá-los. Inspecionar init/fim,
   IN/PA/PU/PD, necessidade de seleção de ferramenta, unidade, eixos e comandos
   extras. Não tratar PRT, binário, DMPL ou HPGL/2 como HPGL básico.
6. Excluir somente o setup temporário após conferir que o original continua
   idêntico e funcional. A captura FILE sozinha não comprova comportamento da
   revisão; confirmar com manual específico/fornecedor ou ensaio já autorizado
   e observado da configuração funcional do Flexi.

Referências oficiais:
- https://support.thinksai.com/hc/en-us/articles/4405338258708-Change-Port
- https://support.thinksai.com/hc/en-us/articles/4405157981204-Cut-Plot-Dialog-Box-General-Tab
- Manual Foison, revisão 3.181 (não necessariamente a revisão do cliente):
  https://www.bridgecutters.com/download/C24_user_manual.pdf

## Instalação e impressão

1. Instalador verifica SO, pré-requisitos e executa conversão real de autoteste
   20 mm antes de tocar na fila. Falha: registrar erro, não entregar captura-only.
2. Registra MS Publisher Imagesetter pelo INF do próprio Windows e verifica
   PScript5 x64; RedMon usa a porta exclusiva FOISONC24n: e configuração lida de
   volta por XcvData. Nenhuma porta serial é configurada aqui.
3. Confirmar fila no CorelDRAW. Abrir SVG do quadrado, 100×100 mm de página,
   quadrado 20×20, sem fill. Imprimir a 100%, sem fit/paginação, uma cópia.
4. Conferir prévia e dimensões (erro máximo esperado 0,02 mm devido a formatos/
   precisão numérica). Se escala/orientação/contorno divergirem, parar.
   Fonte real Corel/PScript ainda não está disponível como fixture do projeto.
5. Sem alterar a origem relativa do desenho, o plano translada os limites
   mínimos para (2,2) mm, não aplica escala nem “fit”. A UI mostra X→, Y↑;
   troca/inversão de eixos exige evidência e aparece na confirmação final.

## Portões para autorizar movimento/corte

- No diálogo “Validar máquina (dev)”, indicar arquivo de evidência real, revisão,
  unidades/mm comprovadas, área livre medida ≤50×50 mm e mapeamento dos eixos.
- Comprovar que **IN; PA; PU; PUx,y; PDx,y; PU;** são suficientes e seguros
  nessa revisão. Se precisar de SP, VS, FS, ESC, reset ou outro comando, este
  candidato não está aprovado. Nenhum comando adicional é enviado para tentar.
- Não deduzir resolução de “precisão mecânica 0,025 mm”, nem usar 40 unidades/mm
  só porque foi usado no simulador. O manual geral não especifica o contrato de
  comandos e resolução. A documentação conhecida não basta para aprovar.
- Confirmar COM2 exclusiva com Flexi/Production Manager fechados normalmente,
  Xon/Xoff e DTR/RTS desligados compatíveis com a configuração funcional.
  Acesso negado/ocupada bloqueia. O aplicativo não pode atribuir o lock ao
  Flexi com certeza; lista processos relevantes sem presumir propriedade.
- Ajustar baixa força/velocidade **no painel**, conforme manual/revisão/material.
  Definir origem física e conferir percurso incluindo a posição atual do carro
  até o primeiro ponto. Software não conhece a posição física nem homing.
- Remover a lâmina. Autorizar um ensaio PU deste desenho. Observar parada física,
  escala/orientação/área. Pode usar caneta apropriada apenas se suportada pelo
  fabricante; um ensaio PU não deixa marca para medir sozinho.
- Somente após comprovar a escala física (evidência Flexi/calibração ou caneta
  validada), marcar ensaio observado. Recolocar ferramenta com máquina parada,
  conferir origem inalterada/material, e autorizar o corte do mesmo trabalho.
- Cada envio consome uma tentativa persistente por hash/modo. Não há retries,
  reconexão automática ou confirmação de execução pela plotter. “Bytes enviados”
  não significa que terminou ou que cortou corretamente.

## Interrupção

1. Usar PAUSE/OFFLINE no painel seguindo o manual da revisão; afastar mãos do
   carro/material. O botão do PC cancela novos writes e descarta só buffer local.
2. Comandos já recebidos podem continuar. Não enviar IN/PU/ESC “de emergência”
   sem protocolo comprovado; fechamento da COM2 não é parada de emergência.
3. Timeout/cancelamento/falha deixam `ProgramData\FoisonC24\session\INTERRUPTED`.
   A sessão fica bloqueada, inclusive após reiniciar/reinstalar o aplicativo.
4. Desenvolvedor deve seguir procedimento do fabricante para descartar trabalho
   e verificar máquina/buffer. Só depois, com app fechado e autorização explícita
   do operador, arquivar/remover o marcador INTERRUPTED. Não apagar arquivos
   *.sent para reenviar um trabalho incerto. Nova impressão requer nova análise.
5. Se máquina não tem interrupção segura conhecida, **não começar o ensaio**.

## Critérios finais / registro

Registrar diagnóstico de instalação, hash do PS e da evidência, versão/revisão,
medidas dos dois lados do quadrado, orientação, material, forças/velocidades no
painel, origem/limites, fim do movimento e autorização. Não registrar documentos
comerciais nem informações pessoais no repositório. Se qualquer condição falhar,
não mover a plotter e preservar integralmente o setup funcional FlexiSIGN.
