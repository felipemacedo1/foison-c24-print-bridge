# Estratégia de testes

## Portátil

`python3 -m unittest discover -s tests -v` verifica limites do receptor,
detecção de PostScript/RAW inválido, transformações, Bézier, limites e
serialização sem depender de hardware.

## Windows 7

Instalar primeiro uma fila de teste sem COM2. Imprimir um quadrado de 50 ×
50 mm no CorelDRAW, confirmar que o receptor criou um `.raw` e um relatório,
e só depois implementar/validar interpretação vetorial. Teste no Wine não é
prova de compatibilidade.

## Hardware

Fechar o FlexiSIGN, confirmar COM2 livre, simular o percurso, medir escala e
área útil, e somente então habilitar transmissão explicitamente. Não reenviar
automaticamente após falha serial porque o estado físico pode ser desconhecido.
