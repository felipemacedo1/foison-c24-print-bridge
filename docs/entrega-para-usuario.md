# Como entregar ao usuário final

## Situação atual

**Não envie o repositório atual como se fosse um instalador.** Ele ainda não
contém `FoisonC24-Setup-x64.exe`, não cria uma impressora no Windows e não
validou o protocolo da plotter. O usuário final não precisa instalar Python,
Git, GitHub CLI ou abrir o terminal para usar o produto; portanto, enviar o
código agora só causaria confusão.

O artefato atualmente disponível em
`dist/FoisonC24-Teste-Win7-x64.zip` é apenas documental. Ele serve para
revisão interna das instruções, não para instalação no computador do usuário.

## Pacote que o usuário deverá receber

Quando a fila tiver sido testada no Windows 7, a entrega deve ser um arquivo
ZIP ou, preferencialmente, um instalador:

```text
FoisonC24-Release/
├── FoisonC24-Setup-x64.exe
├── LEIA-ME.txt
├── INSTALACAO.pdf
├── SOLUCAO-DE-PROBLEMAS.txt
└── checksums.sha256
```

O usuário deve executar o instalador como administrador apenas durante a
instalação, selecionar a impressora **Foison C24** no CorelDRAW e operar a
interface normal. Ele não deve executar scripts, instalar dependências de
programação ou alterar o FlexiSIGN.

## O que é necessário antes de enviar

1. Gerar um executável Windows x64 compatível com Windows 7 SP1.
2. Criar a fila **Foison C24 (Teste)** e comprovar uma impressão do CorelDRAW
   chegando ao receptor.
3. Confirmar que o receptor identifica o trabalho e grava diagnóstico.
4. Implementar desinstalação que remova somente os componentes do Bridge.
5. Validar o protocolo, escala e limites da revisão real da C24 antes de
   habilitar corte físico.

## Teste que o usuário deverá fazer

O operador não precisa programar. Ele deverá apenas:

1. Fechar o FlexiSIGN.
2. Executar `FoisonC24-Setup-x64.exe`.
3. Abrir o CorelDRAW X6.
4. Desenhar um quadrado simples de 50 × 50 mm.
5. Usar **Arquivo → Imprimir** e escolher **Foison C24**.
6. Imprimir em **modo simulação**, sem a plotter se mover.
7. Informar se o aplicativo mostrou o trabalho recebido.

Se falhar, o operador deve enviar o arquivo de diagnóstico criado pelo
programa e uma captura de tela da mensagem. Ele não deve apagar arquivos,
reiniciar o spooler, mexer no registro ou desinstalar o FlexiSIGN.

## Mensagem pronta para enviar ao operador agora

> O programa ainda está em fase de teste e não existe uma versão instalável
> pronta para uso. Não instale arquivos do GitHub nem altere o FlexiSIGN.
> Quando a versão de teste estiver pronta, você receberá um instalador
> `FoisonC24-Setup-x64.exe` e instruções simples. O primeiro teste será feito
> em modo simulação, sem movimentar a plotter. Precisaremos confirmar apenas o
> Windows 7, o CorelDRAW e o resultado da impressão de um quadrado.
