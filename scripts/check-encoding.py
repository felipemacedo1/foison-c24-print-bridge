#!/usr/bin/env python3
"""Encoding gate for project-owned user text (no codepage workaround)."""
import json
import subprocess
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
SUFFIXES={'.nsi','.nsh','.ps1','.cmd','.bat','.cs','.resx','.txt','.md'}
# Construct patterns to avoid putting corrupted user-facing strings into sources.
BAD=['\ufffd','\u00c3\u00a7','\u00c3\u00a3','\u00c3\u00a9','\u00e2\u20ac','\u00c2\u00b0']
PHRASES=['Instalação concluída com sucesso.','Configuração da impressora Foison C24.','Não foi possível instalar o monitor de impressão.','Verificação de dependências concluída.','Falha na comunicação com a porta serial.','Atenção: reinicialização necessária.']
def audit():
    files=subprocess.check_output(['git','ls-files','--cached','--others','--exclude-standard'],cwd=ROOT,text=True).splitlines()
    result=[]
    for name in sorted(set(files)):
        p=ROOT/name
        if p.suffix.lower() not in SUFFIXES or not p.is_file():continue
        data=p.read_bytes();text=data.decode('utf-8-sig')
        if any(b in text for b in BAD):raise ValueError('Corrupted source text: '+name)
        bom=data.startswith(b'\xef\xbb\xbf')
        if p.suffix in ('.nsi','.nsh','.ps1') and not text.isascii() and not bom:raise ValueError('Win7/NSIS text requires UTF-8 BOM: '+name)
        if p.suffix in ('.cmd','.bat') and not text.isascii():raise ValueError('Bootstrap must be ASCII: '+name)
        if name.startswith('packaging/windows/') and p.suffix=='.txt' and not bom:raise ValueError('Win7 Notepad requires BOM: '+name)
        result.append({'path':name,'encoding':'UTF-8-BOM' if bom else ('ASCII' if text.isascii() else 'UTF-8'),'bytes':len(data)})
    phrases=(ROOT/'packaging/windows/TEXTOS-VALIDACAO.txt').read_text(encoding='utf-8-sig')
    if not all(p in phrases for p in PHRASES):raise ValueError('Portuguese validation phrases missing')
    return result
if __name__=='__main__':
    report=audit()
    print(json.dumps(report,ensure_ascii=True,indent=2))
