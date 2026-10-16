#!/usr/bin/env python3
"""Fetch pinned, unmodified official distributions. No execution or system install.
Requires Python 3 and 7z. Corresponding sources are installed alongside binaries.
"""
import hashlib
import json
import shutil
import subprocess
import urllib.request
import zipfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
CACHE = ROOT / '.build-cache'
PACK = ROOT / 'packaging/windows'
FILES = [
    ('gs10080w64.exe', 'https://github.com/ArtifexSoftware/ghostpdl-downloads/releases/download/gs10080/gs10080w64.exe', '52a91b8bf09298788d7a57b9206127026c23eacd75405f0a131e26dc381dce50'),
    ('mupdf-1.28.5-windows.zip', 'https://casper.mupdf.com/downloads/archive/mupdf-1.28.5-windows.zip', '13476a53e84f5527983158acb6442c7853b3cdc022f3b24880780dcfba1fcc99'),
    ('ghostscript-10.08.0.tar.xz', 'https://github.com/ArtifexSoftware/ghostpdl-downloads/releases/download/gs10080/ghostscript-10.08.0.tar.xz', 'c20492bc8ebb96c87fa2e52a0926e1cda8cde95d66145e018ac713fed5da38cf'),
    ('mupdf-1.28.5-source.tar.gz', 'https://casper.mupdf.com/downloads/archive/mupdf-1.28.5-source.tar.gz', '98a5c10cda20c3992cdf76ff6b2a1149c32bd79cc796d3f703230b1185b7e934'),
    ('vc_redist.x64.exe', 'https://download.visualstudio.microsoft.com/download/pr/b6c6fac1-c78c-4c3c-9461-d8e2c68ac8b4/6AFAE68A783F11292149175844AED0E2CE3F247BC0250F6CB18C931295B3F399/VC_redist.x64.exe', '6afae68a783f11292149175844aed0e2ce3f247bc0250f6cb18c931295b3f399'),
    ('ndp48.exe', 'https://go.microsoft.com/fwlink/?linkid=2088631', '0a3a390c47e639d0f7fc65b21195fee6b7f65b066f80f70c60fab191d14b7e40'),
]

def digest(path):
    h = hashlib.sha256()
    with path.open('rb') as f:
        for block in iter(lambda: f.read(1024*1024), b''):
            h.update(block)
    return h.hexdigest()

def main():
    CACHE.mkdir(exist_ok=True)
    for name, url, expected in FILES:
        path = CACHE / name
        if not path.exists():
            print('Download:', name, flush=True)
            temporary = path.with_suffix(path.suffix + '.partial')
            with urllib.request.urlopen(url, timeout=120) as r, temporary.open('wb') as out:
                shutil.copyfileobj(r, out)
            if digest(temporary) != expected:
                raise RuntimeError('Checksum mismatch: ' + name + '; review new upstream release, do not bypass')
            temporary.replace(path)
        if digest(path) != expected:
            raise RuntimeError('Checksum mismatch: ' + name)
    gs = PACK / 'tools/gs'
    gs.mkdir(parents=True, exist_ok=True)
    subprocess.run(['7z', 'x', '-y', str(CACHE / FILES[0][0]), '-o'+str(gs), 'bin', 'Resource', 'lib', 'doc'], check=True, stdout=subprocess.DEVNULL)
    mu = PACK / 'tools/mupdf'
    mu.mkdir(parents=True, exist_ok=True)
    with zipfile.ZipFile(CACHE / FILES[1][0]) as z:
        for name in ['mutool.exe', 'COPYING.txt', 'README.txt', 'CHANGES.txt']:
            (mu / name).write_bytes(z.read('mupdf-1.28.5-windows/' + name))
    for folder, names in [('sources', [FILES[2][0], FILES[3][0]]), ('prerequisites', ['vc_redist.x64.exe', 'ndp48.exe'])]:
        target = PACK / folder
        target.mkdir(parents=True, exist_ok=True)
        for name in names:
            shutil.copyfile(CACHE / name, target / name)
    (PACK / 'tools/manifest.json').write_text(json.dumps([{'file': n, 'url': u, 'sha256': h} for n,u,h in FILES], indent=2)+'\n')
    # Repository archive includes build scripts, notices and RedMon corresponding source.
    (PACK / 'sources').mkdir(exist_ok=True)
    subprocess.run(['git', 'archive', '--format=zip', '-o', str(PACK / 'sources/foison-bridge-source.zip'), 'HEAD'], cwd=ROOT, check=True)
    print('Pinned tools, prerequisites and sources ready; Win7 execution still unverified.')

if __name__ == '__main__':
    main()
