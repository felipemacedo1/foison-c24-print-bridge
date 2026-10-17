# CorelDRAW: onde configurar e autorizar o corte

## Instalação existente (rc.2)

O cliente relatou instalação rápida e impressora visível no CorelDRAW X6.
Isso é evidência relatada dessas etapas, não validação independente de toda
a cadeia ou de hardware. O arquivo recebido chama-se `Foison.rar`, é RAR5,
não ZIP. Seus sete componentes principais correspondem ao instalador rc.2
do CI. Nenhum executável recebido foi executado.

**Não é preciso reinstalar para abrir o controlador existente.** Na área de
trabalho, abra **Foison C24**, imprima pelo CorelDRAW, selecione o trabalho
e clique em **Pré-visualizar**. Protocolo, área, eixos e unidades/mm estão em
**Validar máquina (dev)**; depois há **Movimento sem lâmina** e **Primeiro corte**.
Se a lista estiver vazia, o problema é captura/RedMon, não falta de propriedades
de corte: preserve logs do Receiver e faça diagnóstico antes de qualquer envio.

## Por que Propriedades não tem opções de plotter?

O projeto instala uma fila com o driver Microsoft PostScript PScript5;
ela não é um driver OEM completo Foison nem o FlexiSIGN. Não implementamos
um plug-in de propriedades desse driver. A Microsoft documenta que personalizar
essas páginas requer um [plug-in de interface PScript](https://learn.microsoft.com/en-us/windows-hardware/drivers/print/pscript-user-interface).
Logo, não é falha de instalação nem de privilégio a ausência desses controles.
Não trocar o driver compartilhado ou mexer na configuração Flexi/FTDI para
tentar fazê-los aparecer.

## Painel explícito na rc.3

1. Abra **Foison C24 - Configurações de corte**, na área de trabalho.
2. No CorelDRAW, imprima uma cópia, escala 100%, sem ajustar à página.
3. Selecione o trabalho e abra **Pré-visualizar**: o quadrado deve medir20×20mm.
4. **Configurações de corte** permite selecionar a porta do Bridge (COM2 padrão),
   redução de1–100%, rotação anti-horária0/90/180/270° e espelhos X/Y. O diálogo
   mostra dimensões antes e depois dos ajustes. Amplie no CorelDRAW, não no
   Bridge, para não ampliar o erro de aproximação das curvas acima de0,01mm.
5. Aplicar modifica a prévia e a geometria enviada ao mesmo gerador HPGL;
   não acumula transformações a cada edição e não envia nenhum comando.
   Espelho ocorre antes da rotação, sobre a geometria normalizada.
6. O desenvolvedor verifica protocolo real, unidades/mm, eixos e área física
   em **Validar máquina (dev)**. O mapeamento dos eixos da máquina é separado
   dos ajustes artísticos do desenho; a prévia é anterior a esse mapeamento,
   explicitado na autorização e conferido pelo ensaio.
7. Confira origem física, margem2mm e área medida até50×50mm. Remova a lâmina
   para o ensaio autorizado; meça o movimento e só então autorize o corte.

Editar configurações revoga o ensaio. Trocar a porta revoga também a aprovação
do dispositivo. Autorizações não são gravadas como preferência, e impressão
jamais dispara corte automático. O atalho abre o aplicativo; não adiciona
uma aba dentro de Propriedades no CorelDRAW.

**Força, velocidade e ferramenta são ajustadas no painel da plotter.** Não há
comandos comprovados para estes ajustes na revisão do cliente. Também não
implementamos offset de lâmina, cópias múltiplas, otimização de percurso ou
qualidade equivalente ao FlexiSIGN. A rc.3 continua limitada ao primeiro ensaio.

## Conferência antes de encaminhar

- CoreTests: transformações assimétricas, original imutável, curvas/abertos/
  fechados, coordenadas HPGL exatas, limites e plano de ensaio distinto.
- WinForms `--ui-smoke`: dimensões após ajustes/restauração sem acúmulo,
  botões físicos bloqueados; imagens da janela e diálogo no CI Windows.
- Integridade de encoding, builds net48/net8, NSIS e pacote padrão existentes.
- Win7/CorelDRAW: instalação/fila rc.2 relatadas; **painel rc.3, captura real,
  comunicação e corte ainda não executados no alvo**. Imagens do CI não são
  evidência visual de Windows7.
