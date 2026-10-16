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
receptor. RedMon 1.9 foi verificado na fonte do fornecedor: possui binário x64 para
Windows 7, aceita stdin e é GPLv3 com código-fonte redistribuível. O
provisionador agora instala `setup64.exe`, cria uma porta exclusiva `FOISONC24n:` por `XcvData(AddPort)`,
configura `RedMonConfigurePortW` para executar o receptor e cria a fila pelo
`PrintUIEntry`. Ainda é necessário executar esse fluxo no Windows 7. Um
processador/monitor próprio é alternativa caso a instalação seja mais
confiável. Uma fila “Foison C24 (Teste)” deve ser validada antes da fila final.

O Microsoft PScript é documentado como driver padrão PostScript, mas seus
componentes/INF de sistema não são automaticamente redistribuíveis pelo
projeto. A instalação final precisa usar uma fonte legalmente redistribuível ou
solicitar o componente presente no Windows, e deve ser testada no spooler real.

## Segurança e concorrência

- Rejeitar entrada vazia, desconhecida ou maior que o limite.
- Não executar PostScript arbitrário no processo do receptor.
- Um único trabalho físico por vez; fila e cancelamento serão adicionados
  depois da captura comprovada.
- Nunca abrir COM2 à força nem reiniciar processos do FlexiSIGN.
