# Arquitetura

```text
CorelDRAW X6
    ↓ fila Windows (a validar: PostScript + monitor de porta)
Receiver (stdin → arquivo bruto + relatório)
    ↓ detector/parser seguro
Vector model (paths, transformações, unidades)
    ├── Simulator
    └── Protocol adapter (HPGL/DMPL somente após validação)
             ↓ transport adapter
        Serial COM2 (exclusivo, configurável)
```

Os módulos de domínio não conhecem serial, spooler ou UI. O receptor preserva
os bytes originais e usa limites explícitos. A transmissão física é uma etapa
separada da conversão e começa desabilitada.

## Integração de impressão

O caminho inicialmente investigado é driver PostScript → monitor de porta →
receptor. RedMon pode ser avaliado, mas não é uma dependência aceita até
confirmar binários, licença, x64 e comportamento no Windows 7 SP1. Um
processador/monitor próprio é alternativa caso a instalação seja mais
confiável. Uma fila “Foison C24 (Teste)” deve ser validada antes da fila final.

## Segurança e concorrência

- Rejeitar entrada vazia, desconhecida ou maior que o limite.
- Não executar PostScript arbitrário no processo do receptor.
- Um único trabalho físico por vez; fila e cancelamento serão adicionados
  depois da captura comprovada.
- Nunca abrir COM2 à força nem reiniciar processos do FlexiSIGN.
