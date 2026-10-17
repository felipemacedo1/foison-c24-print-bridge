# Behavioral model tests: real orchestration, persistence, rollback and logs;
# adapters replace unavailable Windows APIs. NOT proof of PS2/Win7 execution.
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
if (-not $env:ProgramData) { $env:ProgramData = [IO.Path]::GetTempPath() }
. (Join-Path $root 'packaging/windows/Install-Queue-Win7.ps1')
$OriginalProcessRun = ${function:ProcessRun}
$results = @()
$base = Join-Path ([IO.Path]::GetTempPath()) ('foison-matrix-' + [Guid]::NewGuid().ToString('N'))
[IO.Directory]::CreateDirectory($base) | Out-Null
function Assert($condition,$message) { if (-not $condition) { throw $message } }
function ResetModel($name) {
  $script:StateDir = Join-Path $base $name
  $script:StatePath = Join-Path $StateDir 'install-state.properties'
  $script:LegacyPath = Join-Path $StateDir 'install-state.json'
  $script:LogDirectory = ''; $script:RunId = $name; $script:LogPath = $null
  $script:Step = 'INITIALIZE'; $script:LastProcessCode = $null
  $script:fake = @{admin=$true;monitor=$false;register=$true;ports=@{};queue=$null;driver=$true;deps=$true;fail='';calls=@()}
}
function IsAdmin { return $fake.admin }
function OperatingSystem { return (New-Object PSObject -Property @{Version='6.1.7601';ProductType=1;ServicePackMajorVersion=1;OSArchitecture='64-bit'}) }
function Printer { return $fake.queue }
function PortUsers($port) { if ($fake.queue -and $fake.queue.PortName -eq $port) { return @($fake.queue) };return @() }
function ValidateDependencies { if (-not $fake.deps) { throw 'Componente ausente: FoisonC24Diagnostic.exe' } }
function EnsureDriver { if (-not $fake.driver) { throw 'Driver PScript5 indisponível.' };return 'MS Publisher Imagesetter' }
function VerifyDriver($driver) { if (-not $fake.driver) { throw 'Driver indisponível.' } }
function SessionPermissions { }
function SecureStateDirectory { }
function ProcessRun($file,$arguments) {
  $fake.calls += [IO.Path]::GetFileName($file) + ' ' + $arguments
  if ([IO.Path]::GetFileName($file) -eq 'setup64.exe') { $fake.monitor = $fake.register;return 0 }
  if ($arguments -eq 'monitor-status') { if ($fake.monitor) { return 0 };return 3 }
  $a = @([regex]::Matches($arguments,'"([^"]*)"|([^ ]+)') | ForEach-Object { if ($_.Groups[1].Success) { $_.Groups[1].Value } else { $_.Groups[2].Value } })
  if ($fake.fail -eq $a[0]) { $script:LastProcessCode=37;return 37 }
  switch ($a[0]) {
    'list-ports-file' { [IO.File]::WriteAllLines($a[1],[string[]]@($fake.ports.Keys));return 0 }
    'add-port' { Assert (-not $fake.ports.ContainsKey($a[1])) 'Port collision'; $fake.ports[$a[1]]='empty';return 0 }
    'configure-port' { $fake.ports[$a[1]]=$a[3];return 0 }
    'verify-port' { if (-not $fake.ports.ContainsKey($a[1]) -or $fake.ports[$a[1]] -eq 'empty' -or ($a.Count -gt 3 -and $fake.ports[$a[1]] -ne $a[3])) { return 9 };return 0 }
    'verify-empty-port' { if ($fake.ports[$a[1]] -eq 'empty') { return 0 };return 9 }
    'remove-port' { $fake.ports.Remove($a[1]);return 0 }
    'add-queue' { Assert (-not $fake.queue) 'Queue collision';$fake.queue=New-Object PSObject -Property @{Name=$a[1];PortName=$a[2];DriverName=$a[3];Comment=('Foison C24 Print Bridge '+$a[4]);PrintProcessor='WinPrint';Shared=$false;ShareName='';RawOnly=$true};return 0 }
    'adopt-queue' { $fake.queue.Comment='Foison C24 Print Bridge '+$a[4];return 0 }
    'remove-queue' { $fake.queue=$null;return 0 }
  }
  throw ('Unknown fake command: '+$arguments)
}
function CheckFailure($code,$step) {
  Assert ($code -eq 1) 'Failure exit code was not propagated'
  Assert (Test-Path $LogPath) 'Persistent error log missing'
  $log=[IO.File]::ReadAllText($LogPath)
  Assert ($log.Contains('[ERROR]') -and $log.Contains($step) -and $log.Contains('Exception=')) 'Missing exception/stage evidence'
  $lock=Join-Path $StateDir 'installation.lock'
  if ($RunId -ne 'concurrent-lock' -and (Test-Path $lock)) { $f=[IO.File]::Open($lock,'Open','ReadWrite','None');$f.Dispose() }
}
function Case($name,$test) {
  ResetModel $name
  & $test
  $script:results += $name
  Write-Host ('PASS '+$name)
}
Case 'clean-order' {
  Assert ((Invoke-BridgeSetup 'install') -eq 0) 'Clean installation failed'
  $calls=$fake.calls -join '|'
  Assert ($calls.IndexOf('setup64.exe') -lt $calls.IndexOf('list-ports-file')) 'Ports enumerated before monitor'
  Assert ((ReadState).stage -eq 'complete') 'No complete receipt'
}
Case 'reinstall-uninstall-reinstall' {
  Assert ((Invoke-BridgeSetup 'install') -eq 0) 'First install'
  $owner=(ReadState).owner
  Assert ((Invoke-BridgeSetup 'install') -eq 0 -and (ReadState).owner -eq $owner) 'Not idempotent'
  Assert ((Invoke-BridgeSetup 'verify') -eq 0) 'Separate verification failed'
  Assert ((Invoke-BridgeSetup 'uninstall') -eq 0 -and -not $fake.queue -and $fake.monitor) 'Unsafe uninstall'
  Assert ((Invoke-BridgeSetup 'install') -eq 0) 'Reinstall failed'
}
Case 'no-admin' { $fake.admin=$false;CheckFailure (Invoke-BridgeSetup 'install') 'ADMIN';Assert ($fake.calls.Count -eq 0) 'Admin check too late' }
Case 'missing-dependency' { $fake.deps=$false;CheckFailure (Invoke-BridgeSetup 'install') 'DEPENDENCIES' }
Case 'silent-redmon-failed-registration' { $fake.register=$false;CheckFailure (Invoke-BridgeSetup 'install') 'REDMON_INSTALL';Assert (-not (($fake.calls -join '|').Contains('list-ports-file'))) 'Unregistered monitor used' }
Case 'existing-redmon-port-conflict' { $fake.monitor=$true;$fake.ports['FOISONC241:']='third-party';Assert ((Invoke-BridgeSetup 'install') -eq 0) 'Occupied port not handled';Assert ((ReadState).port -eq 'FOISONC242:') 'Occupied port reused';Assert (-not (($fake.calls -join '|').Contains('setup64.exe'))) 'Shared monitor reinstalled' }
Case 'name-conflict' { $fake.queue=New-Object PSObject -Property @{Name=$PrinterName;PortName='COM2'};CheckFailure (Invoke-BridgeSetup 'install') 'DEPENDENCIES';Assert ($fake.queue.PortName -eq 'COM2') 'External queue touched' }
Case 'provisioner-failure' { $fake.fail='add-port';CheckFailure (Invoke-BridgeSetup 'install') 'PORT_RESERVATION';Assert (-not (Test-Path $StatePath)) 'Reserved manifest not cleared' }
Case 'configuration-failure' { $fake.fail='configure-port';CheckFailure (Invoke-BridgeSetup 'install') 'PORT_CONFIGURATION';Assert ($fake.ports.Count -eq 0) 'Owned empty port not rolled back' }
Case 'driver-missing' { $fake.driver=$false;CheckFailure (Invoke-BridgeSetup 'install') 'DRIVER';Assert ($fake.ports.Count -eq 0) 'Owned port leak' }
Case 'queue-create-failed' { $fake.fail='add-queue';CheckFailure (Invoke-BridgeSetup 'install') 'QUEUE_CREATE';Assert (-not $fake.queue -and $fake.ports.Count -eq 0) 'Rollback failed' }
Case 'external-modification' { Assert ((Invoke-BridgeSetup 'install') -eq 0) 'Setup';$fake.queue.Shared=$true;CheckFailure (Invoke-BridgeSetup 'uninstall') 'UNINSTALL';Assert ($fake.queue -and (Test-Path $StatePath)) 'Modified queue deleted' }
Case 'interrupted-owned-state' { Assert ((Invoke-BridgeSetup 'install') -eq 0) 'Setup';$s=ReadState;$s['stage']='configured';WriteState $s;Assert ((Invoke-BridgeSetup 'install') -eq 0) 'Incomplete proven state not recovered' }
Case 'interrupted-unproven-port' { Assert ((Invoke-BridgeSetup 'install') -eq 0) 'Setup';$s=ReadState;$s['stage']='reserved';WriteState $s;$fake.queue=$null;$fake.ports[$s.port]='empty';CheckFailure (Invoke-BridgeSetup 'install') 'REDMON_INSTALL';Assert ($fake.ports.ContainsKey($s.port)) 'Unprovable interrupted port deleted' }
Case 'concurrent-lock' { [IO.Directory]::CreateDirectory($StateDir)|Out-Null;$h=[IO.File]::Open((Join-Path $StateDir 'installation.lock'),'OpenOrCreate','ReadWrite','None');try {CheckFailure (Invoke-BridgeSetup 'install') 'LOCK'} finally {$h.Dispose()} }
Case 'legacy-literal-path' {
  Assert ((Invoke-BridgeSetup 'install') -eq 0) 'Setup'
  $s=ReadState;$s.Remove('owner');$s.Remove('queue_fingerprint');$s['receiver']='C:\new\test\Receiver.exe';WriteState $s
  [IO.File]::Move($StatePath,$LegacyPath);$fake.queue.Comment='';$fake.ports[$s.port]='legacy'
  Assert ((Invoke-BridgeSetup 'install') -eq 0) 'Migration'
  Assert ((Test-Path ($LegacyPath+'.legacy.properties.bak')) -and (ReadState).owner) 'Legacy not preserved'
  Assert ((ReadProperties ($LegacyPath+'.legacy.properties.bak')).receiver -eq 'C:\new\test\Receiver.exe') 'Backslash escapes corrupted'
}
Case 'logging-fallback' { $script:LogDirectory=Join-Path $StateDir 'not-a-directory';[IO.Directory]::CreateDirectory($StateDir)|Out-Null;[IO.File]::WriteAllText($LogDirectory,'blocked');$badLog=$LogDirectory;$fake.admin=$false;CheckFailure (Invoke-BridgeSetup 'install') 'ADMIN';Assert ($LogPath -notlike ($badLog+'/*')) 'Fallback unavailable' }
Case 'programdata-unwritable' {
  [IO.Directory]::CreateDirectory($StateDir)|Out-Null
  $script:StateDir=Join-Path $StateDir 'blocked';[IO.File]::WriteAllText($StateDir,'file')
  $script:StatePath=Join-Path $StateDir 'install-state.properties';$fake.admin=$false
  CheckFailure (Invoke-BridgeSetup 'install') 'ADMIN'
  Assert ($LogPath.StartsWith((Join-Path ([IO.Path]::GetTempPath()) 'FoisonC24'))) 'TEMP fallback not selected'
  [IO.File]::Copy($LogPath,(Join-Path $base 'fallback-evidence.log'))
}
Case 'legacy-interrupted-adoption' {
  Assert ((Invoke-BridgeSetup 'install') -eq 0) 'Setup'
  $s=ReadState;$s.Remove('owner');$s.Remove('queue_fingerprint');WriteState $s
  [IO.File]::Move($StatePath,$LegacyPath);$fake.queue.Comment='';$fake.ports[$s.port]='legacy'
  $fake.fail='configure-port';CheckFailure (Invoke-BridgeSetup 'install') 'REDMON_INSTALL'
  Assert ((ReadState).stage -eq 'adopting') 'Migration intent not durable'
  $fake.fail='';Assert ((Invoke-BridgeSetup 'install') -eq 0) 'Interrupted adoption not recovered'
}
# Exercise wrapper diagnostics with a result adapter, never replace ProcessRun/Run.
# This is explicitly a model; actual ProcessStartInfo tests run separately.
function InvokeProcessAdapter($file,$arguments,$stdout,$stderr,$timeoutMs) {
  [IO.File]::WriteAllText($stdout,'stdout evidence: Instalação concluída com sucesso.')
  [IO.File]::WriteAllText($stderr,'stderr evidence')
  $r=New-Object PSObject -Property @{Started=$true;ProcessId=123;ExitCode=27;TimedOut=$false;CaptureComplete=$true;NativeErrorCode=0;Error='';KillError=''}
  if ($fake.fail -eq 'start') { $r.Started=$false;$r.ExitCode=$null;$r.CaptureComplete=$false;$r.Error='Process launch denied' }
  if ($fake.fail -eq 'timeout') { $r.TimedOut=$true;$r.ExitCode=$null;$r.Error='Timeout' }
  return $r
}
${function:ProcessRun} = $OriginalProcessRun
foreach ($failure in @('exit27','timeout','start')) {
  ResetModel ('process-'+$failure);InitializeLogging;$fake.fail=$failure
  try { Run 'FoisonC24Provisioner.exe' 'monitor-status';throw 'Unexpected success' } catch { LogException $_ }
  $log=[IO.File]::ReadAllText((Join-Path $LogDirectory ('install-'+$RunId+'-foisonc24provisioner.log')))
  Assert ($log.Contains('stdout evidence: Instalação concluída com sucesso.') -and $log.Contains('stderr evidence') -and $log.Contains('DurationMs=')) 'Process diagnostics lost'
  if ($failure -eq 'timeout') {Assert ($log.Contains('Timeout=True')) 'Timeout missing'}
  if ($failure -eq 'exit27') {Assert ($LastProcessCode -eq 27) 'Process code lost'}
  $results += 'process-'+$failure
}
[IO.File]::WriteAllLines((Join-Path $base 'RESULTS.txt'),[string[]]$results,[Text.Encoding]::UTF8)
Write-Host ('PASS '+$results.Count+' model/process cases; evidence='+$base+'; PS2/Win7 NOT EXECUTED')
