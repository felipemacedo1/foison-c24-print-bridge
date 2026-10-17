"""PE and conservative PKZIP validation; production build and tests share no mocks."""
import hashlib
import json
import re
import struct
import subprocess
import tempfile
import zipfile
from pathlib import Path, PurePosixPath


def sha256(path):
    with Path(path).open('rb') as f:
        return hashlib.file_digest(f, 'sha256').hexdigest()


def pe_info(path):
    data = Path(path).read_bytes()
    if data[:2] != b'MZ': raise ValueError(f'Not PE: {path}')
    offset = struct.unpack_from('<I', data, 0x3c)[0]
    if data[offset:offset+4] != b'PE\0\0': raise ValueError('Invalid PE signature')
    machine, sections = struct.unpack_from('<HH', data, offset+4)
    optional_size = struct.unpack_from('<H', data, offset+20)[0]
    optional = offset+24
    magic = struct.unpack_from('<H',data,optional)[0]
    if magic not in (0x10b,0x20b): raise ValueError('Unsupported PE optional header')
    directory = optional + (112 if magic==0x20b else 96)
    section_table=optional+optional_size
    def rva(address):
        for i in range(sections):
            virtual_size, virtual, raw_size, raw = struct.unpack_from('<IIII',data,section_table+40*i+8)
            if virtual<=address<virtual+max(virtual_size,raw_size): return raw+address-virtual
        raise ValueError('PE RVA outside sections')
    imports=[]
    import_rva=struct.unpack_from('<I',data,directory+8)[0]
    if import_rva:
        pos=rva(import_rva)
        for i in range(256):
            descriptor=struct.unpack_from('<IIIII',data,pos+20*i)
            if not any(descriptor):break
            name=rva(descriptor[3]);end=data.index(b'\0',name)
            imports.append(data[name:end].decode('ascii'))
        else: raise ValueError('Too many PE imports')
    version=None
    resource_rva=struct.unpack_from('<I',data,directory+2*8)[0]
    if resource_rva:
        resource=rva(resource_rva)
        def entries(relative):
            named,ids=struct.unpack_from('<HH',data,resource+relative+12)
            return [struct.unpack_from('<II',data,resource+relative+16+8*i) for i in range(named+ids)]
        for kind,target in entries(0):
            if kind!=16:continue # RT_VERSION, not embedded installer/plugin binaries
            for depth in range(4):
                if not target&0x80000000:break
                children=entries(target&0x7fffffff)
                if not children:raise ValueError('Empty version resource')
                _,target=children[0]
            address,size=struct.unpack_from('<II',data,resource+target)
            blob=data[rva(address):rva(address)+size]
            fixed=blob.find(struct.pack('<I',0xfeef04bd))
            if fixed>=0:
                ms,ls=struct.unpack_from('<II',blob,fixed+8)
                version=[ms>>16,ms&65535,ls>>16,ls&65535]
            break
    clr_rva=struct.unpack_from('<I',data,directory+14*8)[0]
    clr_flags=struct.unpack_from('<I',data,rva(clr_rva)+16)[0] if clr_rva else None
    return {'machine':hex(machine),'os_version':list(struct.unpack_from('<HH',data,optional+40)),
            'subsystem_version':list(struct.unpack_from('<HH',data,optional+48)),
            'file_version':version,'clr_flags':clr_flags,'imports':imports}


def validate_zip(path, expected=None, seven_zip='7z'):
    """Reject exotic/unsafe formats, then independently test/extract/hash every file."""
    path=Path(path)
    with path.open('rb') as f:
        if f.read(4)!=b'PK\x03\x04':raise ValueError('Not a standard ZIP local header')
        f.seek(max(0,path.stat().st_size-65557));tail=f.read()
    eocd=tail.rfind(b'PK\x05\x06')
    if eocd<0 or eocd+22>len(tail):raise ValueError('Missing/truncated ZIP central directory')
    fields=struct.unpack_from('<4s4H2IH',tail,eocd)
    if fields[1] or fields[2] or fields[3]!=fields[4] or fields[3]==65535 or fields[5]==0xffffffff or fields[6]==0xffffffff:
        raise ValueError('Multipart or ZIP64 is forbidden')
    if eocd+22+fields[-1]!=len(tail):raise ValueError('Truncated ZIP or trailing data')
    report=[];names=set();normalized=set()
    with zipfile.ZipFile(path) as archive:
        if fields[4]!=len(archive.infolist()):raise ValueError('Central-directory count mismatch')
        for info in archive.infolist():
            name=info.filename;parts=PurePosixPath(name).parts
            if not name.isascii() or '\\' in name or name.startswith('/') or not parts or any(p in ('..','.') or ':' in p for p in parts):raise ValueError('Unsafe ZIP path: '+name)
            if info.is_dir() or name in names or name.lower() in normalized:raise ValueError('Duplicate/directory entry: '+name)
            names.add(name);normalized.add(name.lower())
            if info.compress_type not in (0,8) or info.flag_bits & (1|64|0x800) or info.extract_version>20:raise ValueError('Unsupported Win7 ZIP features')
            if info.extra:raise ValueError('Unexpected ZIP extra fields (including ZIP64/AES)')
            with path.open('rb') as f:
                f.seek(info.header_offset);header=f.read(30)
                local=struct.unpack('<4s5H3I2H',header)
                if local[0]!=b'PK\x03\x04' or local[2]!=info.flag_bits or local[3]!=info.compress_type:raise ValueError('Local/central headers disagree')
                local_name=f.read(local[-2]).decode('ascii')
                if local_name!=name or local[-1]!=0:raise ValueError('Invalid local path/extra field')
                if not info.flag_bits&8 and (local[6],local[7],local[8])!=(info.CRC,info.compress_size,info.file_size):raise ValueError('Local CRC/size mismatch')
            report.append({'name':name,'method':info.compress_type,'bytes':info.file_size,'compressed':info.compress_size,'crc32':f'{info.CRC:08x}'})
        if expected is not None and names!=set(expected):raise ValueError('Missing/unexpected ZIP contents')
        if archive.testzip() is not None:raise ValueError('CRC failure')
        with tempfile.TemporaryDirectory(prefix='foison-zip-') as tmp:
            archive.extractall(tmp)
            for entry in report:
                extracted=Path(tmp)/entry['name']
                entry['sha256']=sha256(extracted)
                if expected is not None and entry['sha256']!=sha256(expected[entry['name']]):raise ValueError('Extracted file differs: '+entry['name'])
    subprocess.run([seven_zip,'t',str(path)],check=True,stdout=subprocess.DEVNULL)
    return {'format':'PKZIP','zip64':False,'encryption':False,'files':len(report),'bytes':path.stat().st_size,'sha256':sha256(path),'entries':report,'checks':['local+central headers','Python CRC','complete extraction + SHA256','7z t']}


def make_zip(path, files):
    with zipfile.ZipFile(path,'w',compression=zipfile.ZIP_DEFLATED,allowZip64=False,compresslevel=6) as z:
        for name,source in sorted(files.items()):
            info=zipfile.ZipInfo(name,date_time=(2026,1,1,0,0,0))
            info.compress_type=zipfile.ZIP_DEFLATED;info.create_system=0;info.external_attr=0x20
            with z.open(info,'w',force_zip64=False) as out, Path(source).open('rb') as inp:
                for block in iter(lambda:inp.read(1024*1024),b''):out.write(block)


def vc_legacy_manifest(path):
    """Inspect pinned official Burn bundle's Win7 x64 UCRT/package conditions."""
    import xml.etree.ElementTree as xml
    with tempfile.TemporaryDirectory(prefix='foison-vc-') as tmp:
        subprocess.run(['7z','x','-y',str(path),'-o'+tmp,'0','u31'],check=True,stdout=subprocess.DEVNULL)
        manifest=xml.parse(Path(tmp)/'0').getroot()
        app=xml.parse(Path(tmp)/'u31').getroot()
        packages=[x for x in manifest.iter() if x.tag.split('}')[-1]=='MsuPackage' and x.get('Id')=='Windows7_MSU_x64']
        runtime=[x for x in manifest.iter() if x.get('Id')=='vcRuntimeMinimum_x64' and x.tag.split('}')[-1]=='MsiPackage']
        conditions=[x.attrib for x in app.iter() if x.tag.split('}')[-1]=='WixBalCondition']
        if len(packages)!=1 or packages[0].get('InstallCondition')!='VersionNT = v6.1 AND VersionNT64' or packages[0].get('KB')!='2999226':raise ValueError('VC bundle no longer targets Windows 7 x64 UCRT')
        if len(runtime)!=1 or runtime[0].get('Version')!='14.29.30157':raise ValueError('Wrong native runtime package version')
        if not any(x.get('Condition')=='VersionNT64 >= v6.0 OR (VersionNT64 = v5.2 AND ServicePackLevel >= 1)' for x in conditions):raise ValueError('Unexpected VC bundle OS eligibility')
        return {'runtime':runtime[0].attrib,'win7_ucrt':packages[0].attrib,'bootstrap_conditions':conditions,'actual_win7_execution':'NOT EXECUTED'}


def win7_text_bytes(text):
    """UTF-8 BOM + CRLF: Windows 7 Notepad does not understand bare LF."""
    return b'\xef\xbb\xbf'+text.replace('\r\n','\n').replace('\r','\n').replace('\n','\r\n').encode('utf-8')


def prune_build_only(directory):
    """Omit linker/debug intermediates from our owned runtime staging copy only."""
    removed=[]
    for file in Path(directory).rglob('*'):
        if file.is_file() and file.suffix.lower() in ('.lib','.exp','.obj','.pdb'):
            removed.append(str(file.relative_to(directory)).replace('\\','/'))
            file.unlink()
    return sorted(removed)
