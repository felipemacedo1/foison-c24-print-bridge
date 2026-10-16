# Solução de problemas

- **Nenhum arquivo de captura:** a fila/monitor ainda não entregou stdin ao
  receptor; verificar spooler, argumentos e permissões no Windows.
- **Formato desconhecido:** preservar o `.raw` e não tentar tratá-lo como
  HPGL; identificar o driver que produziu o fluxo.
- **COM2 ocupada:** fechar o programa que possui a porta; o Bridge não encerra
  processos nem força abertura.
- **Dimensões incorretas:** não habilitar corte; revisar unidades, origem,
  transformação e calibração.
