# Validação

Comandos executáveis no README e `.github/workflows/windows-build.yml`.

## Camadas separadas de evidência

1. Python/contratos: testes legados portáteis e contratos textuais da instalação.
   Contratos textuais não provam comportamento de spooler nem Win7.
2. Harness C# net8/net48: domínio real de produção, geometria, autorizações,
   HPGL, limites, journal, cancelamento, fake IWire ocupado/falha.
3. E2E com fixtures PostScript próprias: stdin real do Receiver (substitui a
   fronteira RedMon, não o spooler); engines GS/MuPDF reais; trace→geometria→
   plano→porta serial simulada. Quadrado 20 mm, curvas CTM/procedimentos bind,
   abertos/fechados; imagens/clipping/multipágina/loop são rejeitados.
4. Windows Actions: executa net48 com os engines exatos do pacote; valida sintaxe
   PowerShell; UI smoke renderiza prévia e exige botões físicos bloqueados.
5. Smoke RedMon no runner Windows 2022 descartável: AddPort, GetConfig,
   SetConfig/read-back, EnumPorts, DeletePort. **Não é Windows 7/CorelDRAW.**
6. Aceite real ainda obrigatório: instalar no Win7, imprimir Corel/PScript,
   confirmar protocolo da revisão/limites/serial físicos, ensaio e medir corte.

Não usar credenciais, documentos reais do cliente nem capturas comerciais em CI.
Aprovações nos testes dizem SIMULATOR ONLY e nunca são perfis de produção.
O valor 40 unidades/mm aparece SOMENTE como parâmetro dos testes simulados.

## Contratos de segurança

- Estado padrão não abre COM; consentimento ligado a hash exato do plano.
- Porta ocupada envia zero bytes; nenhuma tentativa de matar o FlexiSIGN.
- Caminho fora dos limites/valores não finitos/conteúdo não interpretado bloqueia.
- Sem retries; latch após erro/cancelamento impede próximos envios.
- `.sent` persiste antes do primeiro byte; não apague para repetir estado incerto.
- Erro de conversão/instalador nunca gera pacote documental como substituto pronto.
- Não confundir buffer do PC drenado com execução física confirmada.

## Limites dos testes

Sem captura CorelDRAW X6 real, sem máquina e sem Windows 7 nesta bancada. O runner
Windows moderno não prova compatibilidade de drivers, runtime ou APIs no Win7.
A UI smoke é visualização programática, não teste humano de toda a sessão. O fake
serial não valida elétrico/firmware/FTDI/Xon-Xoff físicos. Clipping é rejeitado,
não interpretado parcialmente. Qualidade de curvas com lâmina de arrasto exige
calibração/compensação futura; primeiro ensaio é quadrado simples.
