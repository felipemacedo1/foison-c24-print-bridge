#!/usr/bin/env python3
"""Manual-only prerelease promotion of an already successful, immutable CI run.
No rebuild, no credentials read, no stable release, no asset overwrite.
"""
import argparse
import json
import os
import re
import shutil
import subprocess
import tempfile
import zipfile
from pathlib import Path
from distribution import make_zip, pe_info, sha256, validate_zip, win7_text_bytes, unique_package


def checked(args, **kwargs):
    return subprocess.run(list(map(str,args)),check=True,**kwargs)


def api(path):
    return json.loads(subprocess.check_output(['gh','api',path]))


def main():
    p=argparse.ArgumentParser();p.add_argument('--run-id',required=True);p.add_argument('--tag',required=True);p.add_argument('--source',required=True);a=p.parse_args()
    if not re.fullmatch(r'[0-9]+',a.run_id) or not re.fullmatch(r'[a-f0-9]{40}',a.source) or not re.fullmatch(r'v[0-9]+\.[0-9]+\.[0-9]+-rc\.[0-9]+',a.tag):raise ValueError('Only explicit source SHA and rc tags accepted')
    repo=os.environ['GITHUB_REPOSITORY']
    producer=api(f'repos/{repo}/actions/runs/{a.run_id}')
    if producer['conclusion']!='success' or producer['head_sha']!=a.source or producer['path']!='.github/workflows/windows-build.yml':raise ValueError('Source workflow was not successful for this SHA')
    checked(['git','fetch','origin','tag',a.tag])
    resolved=subprocess.check_output(['git','rev-parse',a.tag+'^{commit}'],text=True).strip()
    if resolved!=a.source:raise ValueError('Tag points to a different source')
    version=a.tag[1:]
    with tempfile.TemporaryDirectory(prefix='foison-promotion-') as tmp:
        root=Path(tmp);metadata=root/'metadata';package=root/'package';out=root/'release';out.mkdir()
        for name,folder in [('foison-c24-validation-evidence',metadata),('foison-c24-client-zip',package)]:
            checked(['gh','run','download',a.run_id,'--repo',repo,'--name',name,'--dir',folder])
        report_path=metadata/version/'validation.json';report=json.loads(report_path.read_text())
        if report['commit']!=a.source or report['dirty'] or report['version']!=version:raise ValueError('Artifact/source mismatch')
        bundle=unique_package(package,'FoisonC24-v'+version+'-Win7-x64.zip')
        inspected=validate_zip(bundle)
        if inspected['sha256']!=report['sha256'] or inspected['files']!=8:raise ValueError('ZIP differs from validated CI')
        prefix='FoisonC24-v'+version+'-Win7-x64/'
        exe=out/'FoisonC24-Setup-Win7-x64.exe'
        with zipfile.ZipFile(bundle) as z:
            with z.open(prefix+exe.name) as source,exe.open('wb') as target:shutil.copyfileobj(source,target)
            entries={Path(i.filename).name:i for i in z.infolist()}
            for line in z.read(prefix+'SHA256SUMS.txt').decode('ascii').splitlines():
                digest,name=line.split('  ')
                import hashlib
                if hashlib.sha256(z.read(prefix+name)).hexdigest()!=digest:raise ValueError('Inner manifest mismatch: '+name)
            for name in ['LEIA-ME.txt','RECUPERACAO.txt','THIRD-PARTY.txt','TEXTOS-VALIDACAO.txt','BUILD-INFO.txt']:
                data=z.read(prefix+name)
                if not data.startswith(b'\xef\xbb\xbf') or b'\n' in data.replace(b'\r\n',b''):raise ValueError('Not Win7 Notepad text: '+name)
        for line in (metadata/version/'SHA256SUMS.txt').read_text().splitlines():
            digest,name=line.split('  ');file=exe if name==exe.name else bundle
            if file.name!=name or sha256(file)!=digest:raise ValueError('External manifest mismatch: '+name)
        if pe_info(exe)['file_version']!=[int(x) for x in version.split('-')[0].split('.')]+[0]:raise ValueError('PE version mismatch')
        checked(['7z','t',exe],stdout=subprocess.DEVNULL)
        shutil.copyfile(bundle,out/bundle.name);shutil.copyfile(report_path,out/'validation.json')
        evidence={}
        for path in metadata.rglob('*'):
            if path.is_file() and path.suffix.lower() in ('.log','.txt','.properties','.raw','.bak','.png','.json'):
                name=re.sub('[^A-Za-z0-9_./-]','_',path.relative_to(metadata).as_posix())
                if name in evidence:raise ValueError('Duplicate evidence path')
                evidence[name]=path
        native=(metadata/'native-redmon-error.log').read_text(encoding='utf-8-sig')
        if 'NativeErrorCode=' not in native:raise ValueError('Native failure evidence absent')
        evidence_zip=out/('FoisonC24-v'+version+'-Evidencias-CI.zip')
        make_zip(evidence_zip,evidence);validate_zip(evidence_zip,evidence)
        assets=[exe,out/bundle.name,out/'validation.json',evidence_zip]
        sums=out/'SHA256SUMS.txt';sums.write_bytes((''.join(sha256(f)+'  '+f.name+'\r\n' for f in assets)).encode('ascii'))
        notes=root/'NOTES.md'
        notes.write_text(f'''## {version} — teste acompanhado, NÃO estável

Versão candidata anterior no projeto **1.0.1-rc.3 → {version}**. A tag pública anterior conhecida é `v1.0.1-rc.1`; esta prerelease não substitui nem apaga versões anteriores.

**[ZIP do cliente](https://github.com/{repo}/releases/download/{a.tag}/{bundle.name})** — extraia tudo, execute o instalador com o desenvolvedor e use o menu Iniciar *Foison C24 Print Bridge → Diagnóstico da captura*. O relatório ZIP resultante é somente para o desenvolvedor. Não é uma versão homologada para corte.

### Correções
- RedMon instalado/verificado nas APIs antes de enumerar portas; elevação, PowerShell x64 e dependências completas.
- Driver PScript5 x64 único; estado `.properties` atômico, migração com backup, UUID/fingerprint, locks e rollback/desinstalação conservadores. Recursos externos e estados ambíguos são preservados.
- CMD registra ausência/sintaxe/startup do PowerShell, fallback TEMP, stdout/stderr e códigos reais; corrigidos falso zero de redirecionamento e caminhos Unicode. PS preserva etapa/tipo/linha/stack/inner exception, duração, timeout e Win32 NativeErrorCode. Sem pausa em automação.
- NSIS só conclui após pré-requisitos, autoteste vetorial, provisionamento e verificação independente. Logs preservados em ProgramData/FoisonC24/Logs (fallback TEMP).
- NSIS Unicode/PortugueseBR e charset explícito; PS/TXT com BOM, TXT CRLF, bootstrap ASCII, gates de texto e inspeção de telas compiladas. Título corrigido após revisão visual.
- Pipeline único Release/testes/staging/NSIS/extração e hashes/PKZIP Deflate. Intermediários de link/debug omitidos. Engines reais, fontes/licenças e pré-requisitos estão no instalador; não é captura-only.
- Receiver registra antes de classificar: RunId/AttemptId, PID/identidade, variáveis RedMon sem título do documento, abertura/primeiro byte/EOF, tamanho/hash/assinatura, persistência, exceções e ExitCode. Entradas rejeitadas deixam metadados/hash/causa sem guardar o conteúdo bruto.
- Diagnóstico de um clique pelo menu Iniciar. Experimento A testa stdin binário direto e parser; Experimento B mantém WMI/process trace, spooler/fila/RedMon e metadados sob observação enquanto o operador imprime o quadrado sintético. ZIP sanitizado inclui snapshots/logs/checksums, sem RAW. A lista/prévia são confirmações manuais; falta de evidência continua UNKNOWN.

### Evidência
[CI aprovado]({producer['html_url']}), commit `{a.source}`, tag `{a.tag}`.
38 testes Python, 73 checks C# por runtime com engines reais, bytes de stdin e serial simulados. Windows 2022: testes de provisionamento/process runner, RedMon isolado, UI pt-BR/rejeição do OS e Shell.Application extraindo ZIP com hashes. Release/net48 e NSIS 3.10 `/WX` sem warnings/erros.
ZIP PKZIP, método 8, 8 arquivos, {bundle.stat().st_size} bytes, sem ZIP64/AES/multipartes; CRC Python, extração/hash e 7z. Manifestos externos/internos e versão PE conferidos novamente na promoção. Instalador SHA256: `{sha256(exe)}`. ZIP SHA256: `{sha256(bundle)}`.
VC2019 x64 14.29.30157 fixado por hash; manifesto real inclui Win7 x64 KB2999226. Isso não comprova execução no Win7. ZIP anterior disponível passou CRC/7z; causa do sintoma do cliente não determinada.

### Limites obrigatórios
**Windows 7/PowerShell 2/CorelDRAW X6/instalação/captura real/serial/Foison/corte físico NÃO EXECUTADOS.** Instalação real e telas finais/desinstalação em Win7 continuam pendentes. Não se declara compatibilidade comprovada nem garantia de corte na primeira sessão. O candidato é para diagnóstico acompanhado e não desbloqueia envio físico.
Corte físico bloqueado por padrão. Sem protocolo específico, escala/orientação/limites/comunicação e confirmações acompanhadas, não envie movimentos. Transmissão não comprova corte. PAUSE/OFFLINE no painel continua obrigatório; cancelar no PC não esvazia com certeza o buffer.
FTDI, COM2, FlexiSIGN e filas de terceiros não são reconfigurados. Pode haver reinicialização/atualizações legítimas pelos pré-requisitos. Veja RECUPERACAO.txt e PROJECT_STATE.md.
''',encoding='utf-8')
        # Never --clobber, force, stable, or delete an existing release.
        checked(['gh','release','create',a.tag,'--repo',repo,'--verify-tag','--target',a.source,'--prerelease','--title','Foison C24 '+version+' — teste acompanhado','--notes-file',notes,*assets,sums])
        published=api(f'repos/{repo}/releases/tags/{a.tag}')
        expected={f.name:(f.stat().st_size,'sha256:'+sha256(f)) for f in assets+[sums]}
        if not published['prerelease']:raise ValueError('Not a prerelease')
        for asset in published['assets']:
            if asset['name'] not in expected or (asset['size'],asset.get('digest'))!=expected[asset['name']]:raise ValueError('Published digest/size mismatch')
        if set(expected)!={x['name'] for x in published['assets']}:raise ValueError('Missing published asset')
        print(json.dumps({'url':published['html_url'],'assets':[{k:f[k] for k in ('name','size','digest','browser_download_url')} for f in published['assets']]},indent=2))
if __name__=='__main__':main()
