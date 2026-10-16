# Instalação (planejada)

Ainda não há instalador Windows funcional gerado. O procedimento de validação deve
começar por uma VM/computador Windows 7 SP1 x64 com backup e sem alterar o
FlexiSIGN. O instalador futuro deverá criar somente a fila e componentes
próprios, verificar .NET Framework 4.8, solicitar elevação apenas na etapa
privilegiada e possuir rollback.

O código-fonte do instalador está em `packaging/windows/FoisonC24-Setup.nsi`.
Ele recusa a compilação se o receptor Windows, o monitor de porta ou o driver
PostScript não estiverem presentes no computador. O instalador extrai os
componentes e executa `Install-Queue-Win7.ps1`, que verifica Windows 7 SP1 x64,
instala RedMon, cria/configura `RPT1:`, detecta PScript e registra
`Foison C24 (Teste)`. Falhas removem a fila e tentam remover a porta criada.
