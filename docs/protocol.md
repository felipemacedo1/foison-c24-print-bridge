# Protocolo e evidência (2026-10-16)

**Nenhuma revisão física C24 foi validada neste projeto.** O gerador é real,
mas HPGL genérico não é prova de compatibilidade da máquina do cliente.

## Fontes e o que elas comprovam

- Manual do fabricante Foison C12/24/30/48, distribuído pela Bridge Cutters:
  https://www.bridgecutters.com/download/C24_user_manual.pdf
  Documenta suporte de família a HPGL/DMPL, baud padrão 38400, origem definida
  pelo usuário, regulagem de força/velocidade e PAUSE/Online no painel. Cita
  firmware 3.181 e ajustes Xp/Yp. Não especifica tabela de instruções wire,
  resolução HPGL ou semântica segura de reset para todas as revisões.
- SAi (fornecedor do Flexi), porta FILE:
  https://support.thinksai.com/hc/en-us/articles/4405338258708-Change-Port
  Documenta salvar dados de saída sem usar a COM. A presença dessa opção no
  FlexiSIGN 12 local ainda não foi verificada.
- SAi, Cut/Plot:
  https://support.thinksai.com/hc/en-us/articles/4405157981204-Cut-Plot-Dialog-Box-General-Tab
  “Save to file” produz arquivo nativo .prt, não é prova de bytes seriais.

Não inferimos 40 unidades/mm a partir da precisão mecânica. Nenhum comando de
força, velocidade, seleção de ferramenta, consulta, ESC, homing ou reset de
emergência é enviado. Não usamos comandos de uma C24 PRO como prova da C24.

## Contrato implementado, condicionado à aprovação da revisão

Somente ASCII com terminador `;`: `IN;`, `PA;`, `PU;`, `PUx,y;`, `PDx,y;`.
A inicialização não deve ser enviada se IN mover/rebaixar ou mudar a origem de
forma não conhecida nessa revisão. PU precede todo reposicionamento; caminhos
abertos não são fechados; caminhos fechados retornam ao primeiro vértice; o fim
é PU sem retorno automático à origem. “Movimento” usa apenas PU, nunca PD.
É obrigatório remover fisicamente a lâmina e comprovar o estado erguido.

A escala é informada pelo desenvolvedor a partir de evidência verificável, sem
valor padrão; quantização usa arredondamento ao inteiro mais próximo. Erro
máximo por eixo de 0,5/unidadesPorMm mm, além da aproximação de curvas ≤0,01 mm.
O plano normaliza a origem do desenho e adiciona 2 mm de margem, sem escalar.
Área validada inicial é medida fisicamente e limitada a 50×50 mm; todos os
pontos, inclusive quantizados, são verificados. Limites não substituem conferir
posição atual/origem/caminho de acesso da ferramenta.

Transporte: COM2 configurável, 38400 8N1 Xon/Xoff, DTR/RTS false, exclusividade,
WriteTimeout 1000 ms, prazo total 30 s. Sem retry, polling wire, reconexão ou
execução de capturas Flexi. Porta ocupada/acesso negado não é atribuída ao Flexi
com certeza: a UI explica que pode ser FlexiSIGN ou outro processo/permissão.

Aprovação do protocolo é volátil por sessão; aprovação do plano é específica do
hash da captura, comandos e perfil. Journal persistente impede repetição por
hash/modo e bloqueia todos os próximos envios após interrupção incerta.
Somente entrega ao driver do PC pode ser medida; conclusão física é manual.

Procedimento detalhado e critérios de bloqueio:
[`PRIMEIRA-SESSAO.md`](../packaging/windows/PRIMEIRA-SESSAO.md).
