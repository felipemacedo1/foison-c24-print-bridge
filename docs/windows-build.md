# Build Windows e artefatos

## Ferramentas configuradas

- SDK .NET 8.0.416 em `~/.dotnet`, usado para compilar projetos direcionados
  ao .NET Framework 4.8 com `Microsoft.NETFramework.ReferenceAssemblies`.
- NSIS 3.09 extraído em `~/.local/foison-tools/nsis`, sem privilégios de root.
- RedMon 1.9 x64 obtido do fornecedor e acompanhado de GPLv3/código-fonte em
  `third_party/redmon`.
- MinGW não foi instalado porque nenhum componente nativo próprio é compilado
  neste slice; RedMon é um binário de terceiro e não deve ser recompilado
  silenciosamente.

## Evidência

O workflow `.github/workflows/windows-build.yml`, run
`38959064970`, concluiu no runner Windows moderno e publicou:

- `foison-c24-windows-components`: `FoisonC24Receiver.exe` e
  `FoisonC24Diagnostic.exe` x64 para `net48`.
- `foison-c24-installer-candidate`: candidato NSIS experimental. A instalação
  ainda precisa ser executada em Windows 7.

Esses artefatos comprovam compilação no Windows moderno, não compatibilidade
ou instalação no Windows 7.

## Para gerar o instalador

O instalador não redistribui um driver PostScript aleatório. Ele detecta um
driver PostScript/PScript já instalado no Windows. A rotina Windows 7:

1. instala o RedMon x64;
2. crie uma porta redirecionada para `FoisonC24Receiver.exe`;
3. registre a fila `Foison C24 (Teste)` usando o driver;
4. configure a fila para não acessar COM2;
5. remova somente esses componentes durante a desinstalação.

Se nenhum driver compatível existir, a instalação falha antes de deixar uma
fila. Não coloque um INF aleatório para forçar a instalação.
