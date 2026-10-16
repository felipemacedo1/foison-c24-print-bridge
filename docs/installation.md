# Instalação

Use exclusivamente o candidato completo `FoisonC24-Setup-x64.exe` na sessão
acompanhada. O instalador verifica Win7 SP1 x64, instala pré-requisitos offline,
executa autoteste vetorial 20 mm e só então provisiona a fila. Não abre COM2.
Pré-requisitos Microsoft podem exigir reboot e atualizações do Windows; nesse
caso parar, reiniciar e continuar com o mesmo instalador, sem tentar contornar.

A fila é `Foison C24 (Teste)`, com MS Publisher Imagesetter inbox PScript5 x64 e
porta RedMon exclusiva FOISONC24n:. Se driver/monitor/configuração não forem
verificáveis, falha com diagnóstico em ProgramData/FoisonC24. Não usar outro
driver aleatório nem alterar a instalação funcional de FTDI/FlexiSIGN.

Fila alheia é preservada. Reinstalação confere propriedade antes de reconfigurar
somente sua porta. Remoção usa manifesto e verifica fila/porta não compartilhadas;
RedMon compartilhado, driver inbox e journal de segurança são preservados.

Após instalar, abrir o atalho Foison C24 como usuário normal. Conversão de
trabalhos não deve rodar elevada/SYSTEM. Somente a fixture confiável de autoteste
é executada pelo instalador. Detalhes e bloqueios em
[PRIMEIRA-SESSAO](../packaging/windows/PRIMEIRA-SESSAO.md).
