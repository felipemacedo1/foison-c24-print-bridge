#!/usr/bin/env python3
"""Offline Win7 laboratory. Never downloads Windows, exposes a NIC or passes USB.
Requires a legally supplied ISO/license to install the guest. Local paths ignored.
"""
import argparse
import errno
import fcntl
import json
import os
import re
import shutil
import socket
import subprocess
import sys
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
LOCAL=ROOT/'.build-cache/qemu-local'
VM=ROOT/'.legacy-vm'

def tool(name):
    value=os.environ.get(name.upper().replace('-','_')) or shutil.which(name)
    if value:return Path(value)
    value=LOCAL/'usr/bin'/name
    if value.is_file():return value
    raise RuntimeError('Install official QEMU or set '+name.upper().replace('-','_'))

def environment():
    env=dict(os.environ)
    libraries=LOCAL/'usr/lib/x86_64-linux-gnu'
    if libraries.is_dir():env['LD_LIBRARY_PATH']=str(libraries)+(':'+env['LD_LIBRARY_PATH'] if env.get('LD_LIBRARY_PATH') else '')
    return env

def run(argv,**kwargs):return subprocess.run(list(map(str,argv)),env=environment(),check=True,**kwargs)

def qmp(command):
    # Local UNIX socket only, inside mode0700 directory. No TCP/VNC service.
    with socket.socket(socket.AF_UNIX,socket.SOCK_STREAM) as client:
        client.settimeout(5);client.connect(str(VM/'qmp.sock'));stream=client.makefile('rwb')
        greeting=json.loads(stream.readline());
        if 'QMP' not in greeting:raise RuntimeError('Not QMP')
        for request in [{'execute':'qmp_capabilities'},command]:
            stream.write(json.dumps(request).encode()+b'\n');stream.flush()
            while True:
                response=json.loads(stream.readline())
                if 'error' in response:raise RuntimeError(str(response['error']))
                if 'return' in response:break
        return response['return']

def command(iso=None,transfer=None,headless=False,paused=False):
    argv=[tool('qemu-system-x86_64'),'-name','Foison-Win7-offline','-machine','pc,accel=kvm',
          '-cpu','Nehalem','-smp','2','-m','3072','-nic','none','-vga','std',
          '-rtc','base=localtime',
          '-drive','file='+str(VM/'win7.qcow2')+',format=qcow2,if=ide,index=0',
          '-qmp','unix:'+str(VM/'qmp.sock')+',server=on,wait=off','-monitor','none',
          '-serial','none','-parallel','none']
    # Firmware paths for extracted official Ubuntu packages; not global installs.
    bios=LOCAL/'usr/share/seabios/bios-256k.bin'
    if bios.is_file():
        argv[argv.index('std')]='none'
        argv+=['-bios',str(bios),'-L',str(LOCAL/'usr/share/qemu'),'-device','VGA,romfile='+str(LOCAL/'usr/share/seabios/vgabios-stdvga.bin')]
    if iso:argv+=['-drive','file='+str(iso)+',media=cdrom,readonly=on,if=ide,index=2','-boot','order=d']
    else:argv+=['-boot','order=c']
    if transfer:argv+=['-drive','file='+str(transfer)+',media=cdrom,readonly=on,if=ide,index=3']
    if headless:argv+=['-display','none']
    if paused:argv+=['-S']
    return argv

def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('action',choices=['init','start','status','shutdown','snapshot','restore','plan'])
    parser.add_argument('--iso',type=Path,help='Legitimate licensed Windows ISO; never downloaded')
    parser.add_argument('--transfer',type=Path,help='Optional read-only data ISO; remove after testing')
    parser.add_argument('--name',help='Offline snapshot name')
    parser.add_argument('--dry-run',action='store_true');parser.add_argument('--headless',action='store_true');parser.add_argument('--paused',action='store_true')
    args=parser.parse_args();VM.mkdir(mode=0o700,exist_ok=True)
    if VM.is_symlink():raise RuntimeError('VM directory must not be a symlink')
    for path in (args.iso,args.transfer):
        if path and (not path.is_file() or path.suffix.lower()!='.iso' or ',' in str(path)):raise RuntimeError('Existing ISO path required; commas unsupported by QEMU drive syntax')
    if args.action=='init':
        if (VM/'win7.qcow2').exists():raise RuntimeError('Refusing to overwrite existing guest')
        run([tool('qemu-img'),'create','-f','qcow2',VM/'win7.qcow2','32G'])
        run([tool('qemu-img'),'snapshot','-c','blank-before-os',VM/'win7.qcow2'])
        print('Blank disk only. Windows/PS2 NOT INSTALLED. Supply legal media/license.')
    elif args.action in ('plan','start'):
        argv=command(args.iso,args.transfer,args.headless,args.paused)
        if args.action=='plan' or args.dry_run:print(json.dumps(list(map(str,argv)),indent=2));return
        if not (VM/'win7.qcow2').is_file():raise RuntimeError('Run init first')
        lock=(VM/'run.lock').open('a')
        fcntl.flock(lock,fcntl.LOCK_EX | fcntl.LOCK_NB)
        socket_path=VM/'qmp.sock'
        if socket_path.exists():
            try:
                qmp({'execute':'query-status'})
            except OSError as error:
                if error.errno!=errno.ECONNREFUSED or not socket_path.is_socket():raise
                socket_path.unlink() # Own stale socket after failed QEMU startup; lock held.
            else:raise RuntimeError('A QMP server is active; preserve it.')
        # Foreground, bounded guest resources, no -daemonize or auto-start service.
        try:run(argv)
        finally:
            # Only our foreground run can have created this socket; after exit it is stale.
            path=VM/'qmp.sock'
            if path.is_socket():path.unlink()
    elif args.action in ('snapshot','restore'):
        if not args.name or not re.fullmatch(r'[A-Za-z0-9_-]{1,64}',args.name):raise RuntimeError('Simple snapshot name required')
        if (VM/'qmp.sock').exists():raise RuntimeError('Shut guest down normally before snapshot/restore')
        run([tool('qemu-img'),'snapshot','-c' if args.action=='snapshot' else '-a',args.name,VM/'win7.qcow2'])
    else:print(json.dumps(qmp({'execute':'query-status' if args.action=='status' else 'system_powerdown'}),indent=2))
if __name__=='__main__':
    try:main()
    except (OSError,RuntimeError,subprocess.CalledProcessError) as error:sys.exit(str(error))
