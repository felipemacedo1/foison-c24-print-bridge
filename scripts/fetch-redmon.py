#!/usr/bin/env python3
"""Download original RedMon 1.9; verify exact x64 binaries before packaging."""
import hashlib
import urllib.request
import zipfile
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
CACHE=ROOT/'.build-cache'
EXPECTED={'unredmon64.exe':'14d63c1088f853e24a6807e69f8d857ec9987c24bd14d3a1c9cae2f7bbea63d6',
          'redmon64.dll':'22d0d6a323625f5d2cdbb60101a4663c536cc89eb47d1cbb23c8b1aa0fa50ccb',
          'setup64.exe':'3a0c692c32d33083844639b66ef54a2ca5d012cf51ec32a5663cdba79c95905e'}
CACHE.mkdir(exist_ok=True)
archive=CACHE/'redmon19.zip'
if not archive.exists():
    with urllib.request.urlopen('https://www.ghostgum.com.au/download/redmon19.zip',timeout=120) as r:
        archive.write_bytes(r.read())
if hashlib.sha256(archive.read_bytes()).hexdigest()!='5e652bfd5fc31cb74e87f02a177762baeb5f9df5d72d91c3f3d3ccb73b8d920d':
    raise RuntimeError('RedMon distribution checksum mismatch')
with zipfile.ZipFile(archive) as z:
    # Never extract paths supplied by the archive.
    for name, digest in EXPECTED.items():
        data=z.read(name)
        if hashlib.sha256(data).hexdigest()!=digest: raise RuntimeError('RedMon hash mismatch: '+name)
        (ROOT/'packaging/windows'/name).write_bytes(data)
    (ROOT/'packaging/windows/redmon.chm').write_bytes(z.read('redmon.chm'))
    if hashlib.sha256(z.read('src.zip')).digest()!=hashlib.sha256((ROOT/'third_party/redmon/redmon-src.zip').read_bytes()).digest():
        raise RuntimeError('RedMon source does not match tracked source archive')
print('RedMon 1.9 original x64 binaries and corresponding source verified')
