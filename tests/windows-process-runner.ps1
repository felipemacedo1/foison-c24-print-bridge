# Real redirected subprocesses under Windows PowerShell. No spooler/serial APIs.
$ErrorActionPreference='Stop'
$root=Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
. (Join-Path $root 'packaging/windows/Install-Queue-Win7.ps1')
$StateDir=Join-Path $env:TEMP ('foison-matrix-process-'+[Guid]::NewGuid().ToString('N'))
$LogDirectory='';$RunId='native-process';InitializeLogging
$exe=Join-Path $StateDir 'Fixture.exe'
Add-Type -OutputAssembly $exe -OutputType ConsoleApplication -TypeDefinition @'
using System;using System.Threading;using System.Text;
public class ProcessFixture {
 public static int Main(string[] a){Console.OutputEncoding=new UTF8Encoding(false);Console.WriteLine("Instalação concluída com sucesso.");Console.Error.WriteLine("stderr evidence");if(a.Length>0 && a[0]=="timeout")Thread.Sleep(10000);return 27;}
}
'@
$code=ProcessRun $exe 'exit27'
if($code -ne 27) {throw 'Real process ExitCode not captured'}
$log=[IO.File]::ReadAllText((Join-Path $LogDirectory ('install-'+$RunId+'-fixture.log')))
if(-not $log.Contains('Instalação concluída com sucesso.') -or -not $log.Contains('stderr evidence')) {throw 'Actual UTF-8 stdout/stderr corrupted/lost'}
$failed=$false
try { ProcessRun $exe 'timeout' 100 | Out-Null } catch {$failed=$true;LogException $_}
if(-not $failed) {throw 'Real timeout did not fail'}
$log=[IO.File]::ReadAllText((Join-Path $LogDirectory ('install-'+$RunId+'-fixture.log')))
if(-not $log.Contains('Timeout=True')) {throw 'Real timeout evidence missing'}
$failed=$false
try {ProcessRun (Join-Path $StateDir 'Missing.exe') 'test'|Out-Null} catch {$failed=$true;LogException $_}
if(-not $failed) {throw 'Missing executable did not fail'}
Write-Host "PASS real Windows PowerShell subprocess exit27/stdout/stderr/Unicode/timeout/start failure; evidence=$StateDir"
