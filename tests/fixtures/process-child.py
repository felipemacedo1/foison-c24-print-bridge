"""Portable fixture for the same real executor; not Windows/PS2 evidence."""
import base64
import os
import pathlib
import sys
import time
mode=sys.argv[1]
if mode=='args':
    for arg in sys.argv[2:]:os.write(1,base64.b64encode(arg.encode('utf-8'))+b'\n')
elif mode=='flood':
    for _ in range(128):
        for fd in (1,2):os.write(fd,bytes(range(256))*64)
elif mode=='binary':
    for fd in (1,2):os.write(fd,bytes(range(256)))
elif mode=='oem':
    for fd in (1,2):os.write(fd,'Configuração da impressora Foison C24.\r\n'.encode('cp850'))
else:
    os.write(1,pathlib.Path(sys.argv[2]).read_bytes())
    os.write(2,'stderr evidence: Não foi possível executar o processo.\r\n'.encode('utf-8'))
    if mode=='timeout':time.sleep(10)
    sys.exit(0 if mode=='zero' else 27)
