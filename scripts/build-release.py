#!/usr/bin/env python3
"""One fail-closed build/test/stage/NSIS/PKZIP pipeline; publish externally after CI."""
import argparse
import importlib.util
import json
import os
import re
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path
from distribution import make_zip, pe_info, sha256, validate_zip, vc_legacy_manifest
ROOT=Path(__file__).resolve().parents[1]
PACK=ROOT/'packaging/windows'

def run(args,**kw):
    print('+',*map(str,args),flush=True)
    return subprocess.run(list(map(str,args)),cwd=ROOT,check=True,**kw)
def write(path,text):Path(path).write_bytes(b'\xef\xbb\xbf'+text.replace('\r\n','\n').replace('\n','\r\n').encode('utf-8'))
def main():
    parser=argparse.ArgumentParser();parser.add_argument('--development',action='store_true',help='Dirty source permitted; not publishable');parser.add_argument('--output',type=Path);args=parser.parse_args()
    version=(ROOT/'VERSION').read_text().strip()
    match=re.fullmatch(r'(\d+)\.(\d+)\.(\d+)(-rc\.\d+)?',version)
    if not match:raise ValueError('Invalid version')
    commit=subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip()
    dirty=bool(subprocess.check_output(['git','status','--porcelain'],cwd=ROOT,text=True).strip())
    if dirty and not args.development:raise RuntimeError('Commit reviewed source before release; embedded source must match HEAD')
    output=(args.output or ROOT/'dist'/version).resolve()
    if output.exists():raise RuntimeError('Refusing to overwrite existing distribution: '+str(output))
    dotnet=os.environ.get('DOTNET','dotnet');pwsh=os.environ.get('PWSH',shutil.which('pwsh') or 'powershell')
    nsis=os.environ.get('MAKENSIS') or shutil.which('makensis')
    if not nsis and os.name=='nt':nsis=str(Path(os.environ['ProgramFiles(x86)'])/'NSIS/makensis.exe')
    if not nsis:raise RuntimeError('NSIS 3.09/3.10+ Unicode required')
    nsis_version=subprocess.check_output([nsis,'/VERSION' if os.name=='nt' else '-VERSION'],text=True).strip()
    if not re.search(r'v?3\.(09|1\d)',nsis_version):raise RuntimeError('Unreviewed NSIS version: '+nsis_version)
    run([sys.executable,'scripts/check-encoding.py'],stdout=subprocess.DEVNULL)
    run([sys.executable,'-m','unittest','discover','-s','tests','-v'],env=dict(os.environ,PYTHONPATH=str(ROOT/'src')))
    run([pwsh,'-NoLogo','-NoProfile','-File','tests/provisioning-matrix.ps1'])
    if os.name=='nt':
        run(['powershell','-NoLogo','-NoProfile','-File','tests/provisioning-matrix.ps1'])
        run(['powershell','-NoLogo','-NoProfile','-File','tests/windows-bootstrap.ps1'])
    for project,framework in [('src/FoisonC24.WindowsReceiver','net48'),('src/FoisonC24.Diagnostic',None),('src/FoisonC24.Provisioner',None),('tests/FoisonC24.CoreTests','net48' if os.name=='nt' else 'net8.0')]:
        run([dotnet,'build',str(Path(project)/(Path(project).name+'.csproj')),'-c','Release','-warnaserror','-m:1','-nr:false']+(['-f',framework] if framework else []))
    if os.name!='nt':run([dotnet,'build','src/FoisonC24.WindowsReceiver','-c','Release','-f','net8.0','-warnaserror'])
    run([sys.executable,'scripts/prepare-tools.py']);run([sys.executable,'scripts/fetch-redmon.py'])
    if os.name=='nt':
        for project,exe in [('FoisonC24.WindowsReceiver','FoisonC24Receiver.exe'),('FoisonC24.Diagnostic','FoisonC24Diagnostic.exe'),('FoisonC24.Provisioner','FoisonC24Provisioner.exe')]:
            shutil.copyfile(ROOT/'src'/project/'bin/Release/net48'/exe,PACK/exe)
        shutil.copyfile(ROOT/'src/FoisonC24.Diagnostic/bin/Release/net48/FoisonC24.Core.dll',PACK/'FoisonC24.Core.dll')
    harness=ROOT/'tests/FoisonC24.CoreTests/bin/Release'
    if os.name=='nt':
        run([harness/'net48/FoisonC24.CoreTests.exe',PACK/'tools/gs/bin/gswin64c.exe',PACK/'tools/mupdf/mutool.exe',ROOT/'tests/fixtures',ROOT/'src/FoisonC24.WindowsReceiver/bin/Release/net48/FoisonC24Receiver.exe'])
    else:
        run([dotnet,harness/'net8.0/FoisonC24.CoreTests.dll',os.environ.get('GS','gs'),os.environ.get('MUTOOL','mutool'),ROOT/'tests/fixtures',ROOT/'src/FoisonC24.WindowsReceiver/bin/Release/net8.0/FoisonC24Receiver.dll'])
    output.parent.mkdir(parents=True,exist_ok=True)
    with tempfile.TemporaryDirectory(prefix='foison-stage-',dir=ROOT/'.build-cache') as temporary:
        stage=Path(temporary)/'installer';stage.mkdir()
        for name in ['Install-Queue-Win7.cmd','Install-Queue-Win7.ps1','FoisonC24-Setup.nsi','LEIA-ME.txt','THIRD-PARTY.txt','PRIMEIRA-SESSAO.md','RECUPERACAO.txt','TEXTOS-VALIDACAO.txt','setup64.exe','redmon64.dll','unredmon64.exe','redmon.chm']:
            shutil.copyfile(PACK/name,stage/name)
        for folder in ['tools','sources','prerequisites']:shutil.copytree(PACK/folder,stage/folder)
        for project,exe in [('FoisonC24.WindowsReceiver','FoisonC24Receiver.exe'),('FoisonC24.Diagnostic','FoisonC24Diagnostic.exe'),('FoisonC24.Provisioner','FoisonC24Provisioner.exe')]:
            compiled=ROOT/'src'/project/'bin/Release/net48'
            shutil.copyfile(compiled/exe,stage/exe)
            config=compiled/(exe+'.config')
            if config.exists():shutil.copyfile(config,stage/config.name)
        shutil.copyfile(ROOT/'src/FoisonC24.Diagnostic/bin/Release/net48/FoisonC24.Core.dll',stage/'FoisonC24.Core.dll')
        write(stage/'VERSION',version+'\n')
        write(stage/'version.nsh','!define BRIDGE_VERSION "'+version+'"\n!define BRIDGE_QUAD "'+'.'.join(match.group(i) for i in (1,2,3))+'.0"\n')
        (stage/'testes').mkdir()
        for name in ['square-20mm.ps','quadrado-20mm.svg']:shutil.copyfile(ROOT/'tests/fixtures'/name,stage/'testes'/name)
        checks={}
        x64=['FoisonC24Receiver.exe','FoisonC24Diagnostic.exe','FoisonC24Provisioner.exe','redmon64.dll','setup64.exe','unredmon64.exe','tools/gs/bin/gswin64c.exe','tools/gs/bin/gsdll64.dll','tools/mupdf/mutool.exe']
        for name in x64+['FoisonC24.Core.dll','prerequisites/vc_redist.x64.exe','prerequisites/ndp48.exe']:
            checks[name]=pe_info(stage/name)
            if name in x64 and checks[name]['machine']!='0x8664':raise ValueError('Not AMD64: '+name)
            if checks[name]['subsystem_version']>[6,1]:raise ValueError('PE subsystem requires newer Windows: '+name)
        if checks['FoisonC24.Core.dll']['clr_flags']&2:raise ValueError('Core requires 32-bit')
        vc=stage/'prerequisites/vc_redist.x64.exe'
        if checks['prerequisites/vc_redist.x64.exe']['file_version']!=[14,29,30157,0]:raise ValueError('VC runtime is not pinned Win7-era v142')
        vc_manifest=vc_legacy_manifest(vc)
        if sha256(vc)!='6afae68a783f11292149175844aed0e2ce3f247bc0250f6cb18c931295b3f399':raise ValueError('Unexpected VC runtime')
        for exe in ['FoisonC24Receiver.exe','FoisonC24Diagnostic.exe','FoisonC24Provisioner.exe']:
            if checks[exe]['file_version']!=[int(match.group(i)) for i in (1,2,3)]+[0]:raise ValueError('Version mismatch: '+exe)
        # Explicit allowlist for uninstall: no recursive deletion of foreign files.
        includes=[];dirs=set()
        for file in sorted(stage.rglob('*')):
            if file.is_file() and file.relative_to(stage).parts[0] in ('tools','sources','testes'):
                rel=file.relative_to(stage);includes.append('Delete "$INSTDIR\\'+str(rel).replace('/','\\')+'"')
                dirs.update(rel.parents)
        includes += ['RMDir "$INSTDIR\\'+str(d).replace('/','\\')+'"' for d in sorted(dirs,key=lambda d:len(d.parts),reverse=True) if str(d)!='.']
        write(stage/'uninstall-files.nsh','\n'.join(includes)+'\n')
        payload=Path(temporary)/'payload';payload.mkdir()
        exe=payload/'FoisonC24-Setup-Win7-x64.exe'
        prefix='/' if os.name=='nt' else '-'
        run([nsis,prefix+'WX',prefix+'INPUTCHARSET','UTF8',prefix+'DOUTFILE='+str(exe),stage/'FoisonC24-Setup.nsi'])
        run(['7z','t',exe],stdout=subprocess.DEVNULL)
        installer_info=pe_info(exe)
        if installer_info['file_version']!=[int(match.group(i)) for i in (1,2,3)]+[0]:raise ValueError('Installer metadata version mismatch: '+str(installer_info))
        # Extract actual NSIS payload and compare every mandatory project/dependency byte.
        extracted=Path(temporary)/'extracted'
        run(['7z','x','-y',exe,'-o'+str(extracted)],stdout=subprocess.DEVNULL)
        for file in stage.rglob('*'):
            if not file.is_file() or file.suffix in ('.nsi','.nsh'):continue
            relative=file.relative_to(stage)
            actual=extracted/relative
            if relative.parts[0]=='prerequisites':actual=extracted/'$PLUGINSDIR'/file.name
            if not actual.is_file() or sha256(actual)!=sha256(file):raise ValueError('Installer payload missing/corrupted: '+str(relative))
        for name in ['LEIA-ME.txt','THIRD-PARTY.txt','RECUPERACAO.txt','TEXTOS-VALIDACAO.txt']:shutil.copyfile(stage/name,payload/name)
        shutil.copyfile(stage/'testes/quadrado-20mm.svg',payload/'quadrado-20mm.svg')
        write(payload/'BUILD-INFO.txt','Version: '+version+'\nSource commit: '+commit+'\nDirty development build: '+str(dirty)+'\nNSIS: '+nsis_version+'\nWin7 SP1/PowerShell 2/CorelDRAW/hardware: NOT EXECUTED\nPhysical output: blocked by default; supervised authorization required.\n')
        sums=''.join(sha256(p)+'  '+p.name+'\n' for p in sorted(payload.iterdir()))
        (payload/'SHA256SUMS.txt').write_text(sums,encoding='ascii')
        bundle=Path(temporary)/('FoisonC24-v'+version+'-Win7-x64.zip')
        files={'FoisonC24-v'+version+'-Win7-x64/'+p.name:p for p in payload.iterdir()}
        make_zip(bundle,files);report=validate_zip(bundle,files)
        report.update(version=version,commit=commit,dirty=dirty,nsis=nsis_version,pe=checks,installer_pe=installer_info,vc_manifest=vc_manifest,win7='NOT EXECUTED',physical='NOT EXECUTED')
        ready=Path(temporary)/'ready';ready.mkdir()
        shutil.copyfile(exe,ready/exe.name);shutil.copyfile(bundle,ready/bundle.name)
        (ready/'SHA256SUMS.txt').write_text(sha256(exe)+'  '+exe.name+'\n'+sha256(bundle)+'  '+bundle.name+'\n',encoding='ascii')
        (ready/'validation.json').write_text(json.dumps(report,indent=2,ensure_ascii=True)+'\n',encoding='utf-8')
        # Same filesystem atomic directory rename: incomplete outputs never become final.
        ready.rename(output)
    print('VALIDATED',output,flush=True)
if __name__=='__main__':main()
