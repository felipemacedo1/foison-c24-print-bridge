#!/usr/bin/env python3
"""Compile the actual embedded executor against CLR2 reference assemblies, C#2.
This is an API/compiler check, NOT a PS2 or Win7 runtime validation.
"""
import os
import subprocess
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]

def source():
    script=(ROOT/'packaging/windows/Install-Queue-Win7.ps1').read_text(encoding='utf-8-sig')
    section=script.split('function InitializeProcessRunner {',1)[1].split('function InvokeProcessAdapter(',1)[0]
    return section.split("-TypeDefinition @'\n",1)[1].split("\n'@",1)[0]+'\n'

def main():
    project=ROOT/'tests/FoisonC24.LegacyProcessCompile'
    generated=project/'obj/LegacyProcess.generated.cs';generated.parent.mkdir(exist_ok=True)
    generated.write_text(source(),encoding='utf-8')
    subprocess.run([os.environ.get('DOTNET','dotnet'),'build',str(project/'FoisonC24.LegacyProcessCompile.csproj'),'-c','Release','-warnaserror','-m:1','-nr:false'],cwd=ROOT,check=True)
    print('PASS C#2 / net20 reference API compile; PS2 / Win7 runtime NOT EXECUTED')
if __name__=='__main__':main()
