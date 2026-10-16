# Distribuição Windows

O workflow `Build and deterministic acceptance` exige Ubuntu E2E aprovado antes
à execução net48 com GS/MuPDF Windows. Também testa a prévia e tenta APIs reais
RedMon no spooler Windows 2022 descartável, sem COM nem impressora física.

Saída obrigatória:
- `dist/FoisonC24-Setup-x64.exe`;
- `dist/FoisonC24-Cliente-Win7-x64.zip` (um ZIP para o cliente);
- `dist/checksums.sha256`, `dist/UI-preview.png` (evidência da UI no CI).

`prepare-tools.py` obtém engines/pré-requisitos oficiais fixados por SHA256 e
fontes completas. `fetch-redmon.py` confere distribuição/binários/fontes RedMon.
NSIS exige todos os componentes; `package-client.py` impede ZIP incompleto.
Não reutilizar distribuição de captura dos runs antigos como cortador pronto.
O arquivo de fonte própria corresponde a `git archive HEAD`: fazer commit antes
de gerar distribuição local. Não versionar downloads, binários ou documentos de
cliente. A fonte de build e os hashes ficam no repositório e no pacote.

Scripts locais Linux: `MAKENSIS=/caminho/makensis` e, se NSIS extraído sem instalação,
`NSISDIR=/caminho/usr/share/nsis`. Nenhum binário publicado equivale a validação
Win7/PScript/Corel/hardware. Ver PROJECT_STATE para resultados do run atual.
