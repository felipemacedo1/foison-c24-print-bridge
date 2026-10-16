# Instalação (planejada)

Ainda não há instalador Windows funcional gerado. O procedimento de validação deve
começar por uma VM/computador Windows 7 SP1 x64 com backup e sem alterar o
FlexiSIGN. O instalador futuro deverá criar somente a fila e componentes
próprios, verificar .NET Framework 4.8, solicitar elevação apenas na etapa
privilegiada e possuir rollback.

O código-fonte do instalador está em `packaging/windows/FoisonC24-Setup.nsi`.
Ele recusa a compilação se o receptor Windows, o monitor de porta ou o driver
PostScript não estiverem presentes. Isso é intencional: um executável que não
cria uma fila real seria uma entrega enganosa.
