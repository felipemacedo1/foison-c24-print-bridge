#!/usr/bin/env python3
"""Fail closed: no documentary/capture-only ZIP when any real component is absent."""
import hashlib
import subprocess
import zipfile
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
PACK=ROOT/'packaging/windows'
DIST=ROOT/'dist'
REQUIRED=['FoisonC24-Setup-x64.exe','FoisonC24Receiver.exe','FoisonC24Diagnostic.exe','FoisonC24.Core.dll','FoisonC24Provisioner.exe','redmon64.dll','redmon.chm',
          'tools/gs/bin/gswin64c.exe','tools/gs/bin/gsdll64.dll','tools/mupdf/mutool.exe','tools/manifest.json',
          'sources/foison-bridge-source.zip','sources/ghostscript-10.08.0.tar.xz','sources/mupdf-1.28.5-source.tar.gz',
          'prerequisites/ndp48.exe','prerequisites/vc_redist.x64.exe','THIRD-PARTY.txt','LEIA-ME.txt','PRIMEIRA-SESSAO.md']
for name in REQUIRED:
    if not (PACK/name).is_file() or (PACK/name).stat().st_size==0: raise RuntimeError('Missing component: '+name)
installer=(PACK/REQUIRED[0]).read_bytes()
if not installer.startswith(b'MZ'): raise RuntimeError('Installer is not a PE executable')
listing=subprocess.check_output(['7z','l','-slt',str(PACK/REQUIRED[0])],text=True).replace('\\','/')
for payload in ['FoisonC24Receiver.exe','FoisonC24Diagnostic.exe','FoisonC24.Core.dll','tools/gs/bin/gswin64c.exe','tools/gs/bin/gsdll64.dll','tools/mupdf/mutool.exe','sources/foison-bridge-source.zip','sources/ghostscript-10.08.0.tar.xz','sources/mupdf-1.28.5-source.tar.gz','testes/quadrado-20mm.svg','ndp48.exe','vc_redist.x64.exe']:
    if payload not in listing: raise RuntimeError('Installer missing embedded payload: '+payload)
DIST.mkdir(exist_ok=True)
(DIST/REQUIRED[0]).write_bytes(installer)
checksum=hashlib.sha256(installer).hexdigest()+'  '+REQUIRED[0]+'\n'
(DIST/'checksums.sha256').write_text(checksum,encoding='ascii')
commit=subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip()
info='Source commit: '+commit+'\nWindows 7/CorelDRAW X6/Foison hardware validation: NOT EXECUTED\nPhysical output: blocked until supervised per-session and per-job authorization\n'
with zipfile.ZipFile(DIST/'FoisonC24-Cliente-Win7-x64.zip','w',compression=zipfile.ZIP_DEFLATED) as z:
    z.write(DIST/REQUIRED[0],REQUIRED[0])
    z.writestr('checksums.sha256',checksum)
    z.writestr('BUILD-INFO.txt',info)
    for name in ['LEIA-ME.txt','INSTRUCOES-DE-TESTE.html','PRIMEIRA-SESSAO.md','THIRD-PARTY.txt']:
        z.write(PACK/name,name)
    z.write(ROOT/'tests/fixtures/quadrado-20mm.svg','quadrado-20mm.svg')
with zipfile.ZipFile(DIST/'FoisonC24-Cliente-Win7-x64.zip') as z:
    if z.testzip() is not None: raise RuntimeError('ZIP integrity failure')
print(checksum.strip())
print('Client ZIP complete. Does not imply hardware compatibility.')
