#requires -version 2.0
# Actual ProcessStartInfo executor, not mocked. Safe on Win7/PS2 and modern hosts.
param([switch]$RequireLegacy)
$ErrorActionPreference='Stop'
$repo=Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
if (-not $env:ProgramData) { $env:ProgramData=[IO.Path]::GetTempPath() }
. (Join-Path $repo 'packaging/windows/Install-Queue-Win7.ps1')
$windows=[Environment]::OSVersion.Platform -eq [PlatformID]::Win32NT
$legacy=$windows -and [Environment]::OSVersion.Version.Major -eq 6 -and [Environment]::OSVersion.Version.Minor -eq 1 -and $PSVersionTable.PSVersion.Major -eq 2 -and [Environment]::Version.Major -eq 2
if($RequireLegacy -and -not $legacy) {throw 'Legacy evidence requires Windows NT6.1 + PowerShell2 + CLR2; this host does not qualify.'}
$base=Join-Path ([IO.Path]::GetTempPath()) ('foison-matrix-real-process-'+[Guid]::NewGuid().ToString('N'))
$StateDir=Join-Path $base 'Configuração & teste com espaços'
$LogDirectory='';$RunId='real-process';InitializeLogging
Stage 'PROCESS_REGRESSION'
$script:cases=@()
function Assert($condition,$message) {if(-not $condition){throw $message}}
function Pass($name){$script:cases+=$name;Write-Host ('PASS '+$name)}
function DirectoryAcl($path) {
 # Avoid module autoload across PS7 -> Windows PowerShell child environments.
 # Framework's API exists in CLR2; Core exposes the equivalent as an extension.
 if($PSVersionTable.PSVersion.Major -ge 6) {
  $directory=New-Object IO.DirectoryInfo($path)
  return [IO.FileSystemAclExtensions]::GetAccessControl($directory)
 }
 return [IO.Directory]::GetAccessControl($path)
}
$phrases=Join-Path $repo 'packaging/windows/TEXTOS-VALIDACAO.txt'
if($windows) {
 $child=Join-Path $StateDir 'Process Fixture.exe'
 if($PSVersionTable.PSVersion.Major -ge 6) {
  # Core Add-Type cannot emit an EXE. Compile the same CLR fixture with the
  # installed Framework compiler, through the actual production executor.
  $compiler=Join-Path $env:windir 'Microsoft.NET/Framework64/v4.0.30319/csc.exe'
  $compileArgs='/nologo /codepage:65001 /target:exe /out:"'+$child+'" "'+(Join-Path $repo 'tests/fixtures/process-child.cs')+'"'
  Assert ((ProcessRun $compiler $compileArgs) -eq 0) 'Fixture compiler failed'
 } else {
  Add-Type -OutputAssembly $child -OutputType ConsoleApplication -TypeDefinition ([IO.File]::ReadAllText((Join-Path $repo 'tests/fixtures/process-child.cs')))
 }
 $prefix=''
} else {
 $child=(Get-Command python3).Source
 $fixture=Join-Path $StateDir 'process child.py'
 [IO.File]::Copy((Join-Path $repo 'tests/fixtures/process-child.py'),$fixture)
 $prefix='"'+$fixture+'" '
}
# Block use of Start-Process to make any regression fail even on modern PS.
function Start-Process {throw 'The legacy production executor must not call Start-Process'}
function Raw($suffix) {
 $files=@(Get-ChildItem $LogDirectory -Filter ('*'+$suffix+'.raw') | Sort-Object LastWriteTimeUtc -Descending)
 return $files[0].FullName
}
function CheckRaw($expected,$path) {
 $actual=[IO.File]::ReadAllBytes($path)
 Assert ($actual.Length -eq $expected.Length) ('Raw byte length differs: '+$path)
 for($i=0;$i -lt $expected.Length;$i++) {if($actual[$i] -ne $expected[$i]){throw ('Raw byte mismatch offset '+$i)}}
}
foreach($mode in @('zero','exit27')) {
 $expected=27;if($mode -eq 'zero'){$expected=0}
 $code=ProcessRun $child ($prefix+$mode+' "'+$phrases+'"')
 Assert ($code -eq $expected -and $LastProcessCode -eq $expected) 'Exit code lost'
 CheckRaw ([IO.File]::ReadAllBytes($phrases)) (Raw '.out')
 $text=[Text.Encoding]::UTF8.GetString([IO.File]::ReadAllBytes((Raw '.err')))
 Assert ($text.Contains('Não foi possível executar o processo.')) 'Stderr text lost'
 Pass $mode
}
$arguments=@('caminho com espaços','Configuração & (teste) % ! ^ | < >','C:\path with spaces\fim\','aspas "internas"')
# Standard Win32 quoting, no shell. Escape embedded quotes/backslashes as CRT expects.
function Quote($value) {return '"'+[regex]::Replace([regex]::Replace($value,'(\\*)"','$1$1\"'),'(\\+)$','$1$1')+'"'}
$line=$prefix+'args';foreach($arg in $arguments){$line+=' '+(Quote $arg)}
Assert ((ProcessRun $child $line) -eq 0) 'Argument fixture failed'
$actual=[IO.File]::ReadAllLines((Raw '.out'))
Assert ($actual.Length -eq $arguments.Count) 'Argument count changed'
for($i=0;$i -lt $arguments.Count;$i++) {Assert ([Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($actual[$i])) -ceq $arguments[$i]) 'Argument changed'}
Pass 'spaces-Unicode-metacharacters-quotes-no-shell'
Assert ((ProcessRun $child ($prefix+'binary')) -eq 0) 'Binary fixture'
$bytes=New-Object byte[] 256;for($i=0;$i -lt 256;$i++){$bytes[$i]=[byte]$i}
CheckRaw $bytes (Raw '.out');CheckRaw $bytes (Raw '.err');Pass 'binary-byte-exact'
Assert ((ProcessRun $child ($prefix+'oem')) -eq 0) 'OEM fixture'
$bytes=[Text.Encoding]::GetEncoding(850).GetBytes("Configuração da impressora Foison C24.`r`n")
CheckRaw $bytes (Raw '.out');CheckRaw $bytes (Raw '.err');Pass 'OEM850-byte-exact'
$watch=[Diagnostics.Stopwatch]::StartNew()
Assert ((ProcessRun $child ($prefix+'flood') 15000) -eq 0) 'Concurrent pipe drain failed'
Assert ($watch.ElapsedMilliseconds -lt 18000) 'Pipe deadlock'
foreach($suffix in @('.out','.err')) {
 $data=[IO.File]::ReadAllBytes((Raw $suffix));Assert ($data.Length -eq 2097152) 'Flood truncated'
 $sha=[Security.Cryptography.SHA256]::Create()
 try {
  $expected=New-Object byte[] 2097152;for($i=0;$i -lt $expected.Length;$i++){$expected[$i]=[byte]($i%256)}
  Assert ([Convert]::ToBase64String($sha.ComputeHash($data)) -ceq [Convert]::ToBase64String($sha.ComputeHash($expected))) 'Flood hash changed'
 } finally {$sha.Dispose()}
}
Pass 'simultaneous-2MiB-stdout-and-stderr-no-deadlock'
$script:LastProcessCode=27
$failed=$false;$watch=[Diagnostics.Stopwatch]::StartNew()
try {ProcessRun $child ($prefix+'timeout "'+$phrases+'"') 200|Out-Null} catch {$failed=$true;LogException $_}
Assert ($failed -and $null -eq $LastProcessCode -and $watch.ElapsedMilliseconds -lt 8000) 'Timeout did not fail bounded with unknown exit'
$logs=@(Get-ChildItem $LogDirectory -Filter '*.log' | ForEach-Object {[IO.File]::ReadAllText($_.FullName)}) -join "`n"
Assert ($logs.Contains('Timeout=True')) 'Timeout evidence missing'
# Result PID must no longer refer to the direct process created by this call.
$matches=[regex]::Matches($logs,'PID=([0-9]+) Timeout=True')
Assert ($matches.Count -gt 0) 'Timed-out PID not recorded'
$childPid=[int]$matches[0].Groups[1].Value
$alive=$false;try {$process=[Diagnostics.Process]::GetProcessById($childPid);try{$alive=-not $process.HasExited}finally{$process.Dispose()}} catch [ArgumentException] {}
Assert (-not $alive) 'Direct child still running after timeout';Pass 'timeout-killed-only-direct-child'
$failed=$false
try {ProcessRun (Join-Path $StateDir 'Missing.exe') ''|Out-Null} catch {$failed=$true;LogException $_}
Assert ($failed -and $null -eq $LastProcessCode) 'Missing executable falsely succeeded'
Pass 'missing-executable-UNKNOWN-not-zero'
InitializeProcessRunner
$result=[FoisonBridge.LegacyProcess]::Run($child,($prefix+'zero "'+$phrases+'"'),$StateDir,(Join-Path $StateDir 'blocked.err'),1000)
Assert (-not $result.Started -and $null -eq $result.ExitCode -and $result.Error) 'Capture failure launched a child'
Pass 'capture-file-unwritable-refuses-launch'
if($windows) {
 Assert (IsAdmin) 'Run the Windows native ACL checks elevated'
 # Calls only affect this fixture directory, never ProgramData project/driver/COM.
 SecureStateDirectory;SessionPermissions
 Pass 'real-icacls-owner-grants-session-zero'
 $sidType=[Security.Principal.SecurityIdentifier]
 $acl=DirectoryAcl $StateDir
 Assert ($acl.GetOwner($sidType).Value -eq 'S-1-5-32-544') 'icacls owner readback differs'
 Assert $acl.AreAccessRulesProtected 'Root still inherits uncontrolled permissions'
 foreach($entry in @(@{path=$StateDir;modify=$false},@{path=$LogDirectory;modify=$false},@{path=(Join-Path $StateDir 'session');modify=$true})) {
  $acl=DirectoryAcl $entry.path
  $rules=@($acl.GetAccessRules($true,$true,$sidType))
  foreach($sid in @('S-1-5-18','S-1-5-32-544','S-1-5-32-545')) {
   $rights=0
   foreach($rule in $rules) {
    if($rule.IdentityReference.Value -eq $sid) {
     Assert ($rule.AccessControlType -eq [Security.AccessControl.AccessControlType]::Allow) 'Unexpected deny ACE'
     $rights=$rights -bor [int]$rule.FileSystemRights
    }
   }
   if($sid -eq 'S-1-5-32-545') {
    Assert (($rights -band [int][Security.AccessControl.FileSystemRights]::ReadAndExecute) -eq [int][Security.AccessControl.FileSystemRights]::ReadAndExecute) 'Users cannot read project diagnostics'
    $write=($rights -band [int][Security.AccessControl.FileSystemRights]::Write) -ne 0
    Assert ($write -eq $entry.modify) 'Users write scope differs from root/log RX and session Modify'
   } else {
    Assert (($rights -band [int][Security.AccessControl.FileSystemRights]::FullControl) -eq [int][Security.AccessControl.FileSystemRights]::FullControl) 'SYSTEM/Administrators lost FullControl'
   }
  }
 }
 Pass 'actual-ACL-owner-root-log-RX-session-modify-readback'
 $lockPath=Join-Path $StateDir 'installation.lock'
 $lock=[IO.File]::Open($lockPath,'OpenOrCreate','ReadWrite','None')
 try {$failed=$false;try{$other=[IO.File]::Open($lockPath,'OpenOrCreate','ReadWrite','None');$other.Dispose()}catch{$failed=$true};Assert $failed 'Lock not exclusive'}finally{$lock.Dispose()}
 $lock=[IO.File]::Open($lockPath,'OpenOrCreate','ReadWrite','None');$lock.Dispose();Pass 'installation-lock-release'
 $code=ProcessRun (Join-Path $env:windir 'System32/icacls.exe') ('"'+(Join-Path $StateDir 'missing-directory')+'" /verify')
 Assert ($code -ne 0 -and $LastProcessCode -eq $code) 'icacls error falsely succeeded'
 Assert ((Get-Item (Raw '.err')).Length -gt 0 -or (Get-Item (Raw '.out')).Length -gt 0) 'icacls error evidence missing'
 Pass 'real-icacls-error-code-output'
 # Invalid PrintUI invocation could display a modal dialog; do not invoke it as a test.
}
$report=@('OS='+[Environment]::OSVersion.VersionString,'PS='+$PSVersionTable.PSVersion,'CLR='+[Environment]::Version,'LegacyHost='+$legacy,'Cases='+$cases.Count,'Physical=NOT EXECUTED')+$cases
[IO.File]::WriteAllLines((Join-Path $base 'RESULTS.txt'),[string[]]$report,[Text.Encoding]::UTF8)
Write-Host ('PASS '+$cases.Count+' REAL process tests; evidence='+$base+'; LegacyHost='+$legacy)
