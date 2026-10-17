# 1.0.1-rc.3 — configurações de corte no aplicativo (candidato)

- Identifica claramente a separação entre Propriedades PScript e painel Foison.
- Novo diálogo de configurações: porta, redução 1–100%, rotação e espelhamentos;
  prévia mede a mesma geometria passada ao gerador HPGL, sem acumular ajustes.
- Alterações revogam ensaio; troca de porta também revoga perfil de máquina.
  Ensaio vinculado ao plano geométrico exato, não somente ao arquivo original.
- Atalho explícito e instruções de fluxo; uma cópia, margem2mm, limites mantidos.
- Nenhum comando de força/velocidade presumido; ajustes no painel da máquina.
- rc.2: instalação/fila no Corel relatadas pelo cliente, não prova de corte.
  Retorno posterior confirma lista vazia: causa real de captura ainda pendente
  de logs do alvo. Novo coletor/exportação somente leitura não altera recursos.

# 1.0.1-rc.2 — candidato de correção Win7/PS2 (não homologado)

- Corrige falha real ParameterBindingException antes de icacls na rc.1: executor
  ProcessStartInfo com token herdado, captura binária concorrente e timeout.
- Distingue ExitCode UNKNOWN de zero; registra início/PID/saídas/erros reais.
- Corrige append NSIS que sobrescrevia BOM UTF-16LE e histórico; devolve erro real.
- Corrige SHA256Managed.Dispose não público no CLR2 usando Clear no fingerprint.
- CMD exige recibo positivo fresco: PS2 -File com erro/code0 nunca basta; falha74.
- Probe legado exige markers/err vazio; 13 processos reais e25 modelos em PS2/CLR2
  no Server2022, sem confundir com Win7; compilação C#2/net20 e32 contratos Python.
- Estados independentes de build, API CLR2, runtime Win7/PS2, instalação e físico.
- Laboratório QEMU/KVM offline documentado; mídia/licença Windows não fornecida.
- Não instalar rc.1 como correção; rc.2 exige validação no alvo antes de liberação final.

# Changelog

## 1.0.1-rc.1 — correção de instalação e distribuição

Versão anterior implícita SDK 1.0.0.0, sem tag/release. Candidato, não estável.
Publicado: código b2df7cd / tag v1.0.1-rc.1, CI 38993143001, promoção 38995440164.
25 Python/22 modelos PS/52 C# por runtime; matriz e hashes em docs/release-validation.md.
- RedMon instalado/verificado antes de enumerar portas; admin/OS/64 bits explícitos.
- Dependências completas e engines reais; driver exato, leitura final independente.
- Manifesto literal .properties atômico; migração recuperável do falso .json legado.
- Propriedade da fila/porta com UUID e fingerprint; lock, rollback restrito e
  preservação quando há alteração externa ou estado incompleto não comprovável.
- Logs desde CMD, correlação NSIS/PS/processos, fallback TEMP, stdout/stderr,
  timeouts, exceções/etapas e códigos reais; erros manuais não desaparecem.
- Unicode pt-BR: NSIS/PS e TXT com BOM, charset de compilação explícito, CMD ASCII,
  logs segregados por encoding e gate automatizado contra corrupção textual.
- Pipeline único testa/compila/stage limpo/NSIS/extrai e compara bytes/ZIP Deflate
  convencional/CRC/hash/7z, com nomes versionados e checksums.
- Sonda vetorial de 20 mm para a fila própria, captura e conversão sem serial.
- Win7/PowerShell 2/CorelDRAW/Foison e telas de conclusão/desinstalação em Win7
  continuam NÃO EXECUTADOS. Corte físico bloqueado por padrão.

## Histórico pré-versionamento (Unreleased)

### Added

- Estrutura inicial e documentação de continuidade.
- Receptor seguro de stdin com arquivos brutos e relatórios JSON.
- Modelo geométrico com linhas, Bézier, transformações e limites.
- Simulação textual e gerador HPGL explicitamente não validado.
- Configuração serial validada, transporte injetável em simulação e fila de
  trabalho de um único transmissor.
- Receptor `net48` Windows e aplicativo WinForms para exportar diagnóstico.
- Workflow de build Windows e material RedMon 1.9 x64/GPLv3 verificado.
- Componentes Windows compilados no run `38959064970`; o instalador foi
  omitido com status explícito por falta de INF/PPD PostScript redistribuível.
- Candidato NSIS experimental passa a extrair componentes e executar o
  provisionador RedMon/PrintUIEntry com rollback; não validado ainda no
  Windows 7.
- Testes unitários determinísticos em Python.
- Provisionamento revisado para preservar filas existentes, detectar conflitos
  com `EnumPorts`, usar portas exclusivas `FOISONC24n:` e registrar manifesto de
  propriedade em `ProgramData`.
- Seleção de driver PostScript agora exige uma única correspondência e INF
  verificável; rollback e desinstalação removem somente recursos próprios.
- Instruções do operador atualizadas para o candidato instalável experimental;
  14 testes determinísticos passaram e o provisionador net48 foi recompilado.

### Known limitations

- A fila/driver Windows ainda não foi instalada ou testada.
- Nota histórica: parser real foi implementado posteriormente; protocolo/escala da revisão física continuam sem validação.

## Candidato de primeira sessão acompanhada — 2026-10-16

- Pipeline Windows real PostScript → GS/PDF vetorial → MuPDF → geometria mm →
  prévia/HPGL → serial, condicionado à evidência de revisão e autorizações.
- Limites, cancelamento/timeouts, exclusividade, journal e bloqueio após incerteza.
- Corrigidos nome RedMon (`Redirected Port`), configuração binária XcvData/read-back,
  descoberta/instalação inbox PScript5 x64 e rollback/desinstalação restritos.
- Distribuição offline completa, fontes/licenças, pré-requisitos e roteiro Flexi
  FILE sem sniffer/alteração FTDI. CI ampliado com testes reais dos engines e mocks.
- Win7/CorelDRAW/revisão/protocolo físico/corte continuam NÃO validados.
