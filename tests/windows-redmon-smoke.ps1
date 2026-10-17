# Runs ONLY on disposable CI runner, not on the client's Windows/FlexiSIGN setup.
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$pack = Join-Path $root 'packaging/windows'
$provisioner = Join-Path $pack 'FoisonC24Provisioner.exe'
$port = 'FOISONC2499:'
function InvokeChecked($file, $arguments) {
  & $file @arguments
  if ($LASTEXITCODE -ne 0) { throw "Native operation failed: $file ($LASTEXITCODE)" }
}
Start-Service Spooler
$p = Start-Process (Join-Path $pack 'setup64.exe') -ArgumentList '/s' -PassThru
if (-not $p.WaitForExit(30000)) { $p.Kill(); throw 'RedMon setup timeout' }
if ($p.ExitCode -ne 0) { throw "RedMon setup failed: $($p.ExitCode)" }
$ports = @(& $provisioner list-ports)
if ($LASTEXITCODE -ne 0 -or $ports -contains $port) { throw 'Cannot reserve isolated test port' }
$created = $false
try {
  InvokeChecked $provisioner @('monitor-status')
  InvokeChecked $provisioner @('add-port', $port)
  $created = $true
  InvokeChecked $provisioner @('configure-port', $port, (Join-Path $pack 'FoisonC24Receiver.exe'), '0123456789abcdef0123456789abcdef')
  InvokeChecked $provisioner @('verify-port', $port, (Join-Path $pack 'FoisonC24Receiver.exe'), '0123456789abcdef0123456789abcdef')
  $ports = @(& $provisioner list-ports)
  if ($LASTEXITCODE -ne 0 -or $ports -notcontains $port) { throw 'Port did not enumerate' }
  # Reconfiguration is a tested idempotent read-back, no printer/physical port.
  InvokeChecked $provisioner @('configure-port', $port, (Join-Path $pack 'FoisonC24Receiver.exe'), '0123456789abcdef0123456789abcdef')
  InvokeChecked $provisioner @('verify-port', $port, (Join-Path $pack 'FoisonC24Receiver.exe'), '0123456789abcdef0123456789abcdef')
  Write-Host 'PASS real Windows 2022 spooler RedMon AddPort/GetConfig/SetConfig/read-back/EnumPorts'
}
finally {
  if ($created) { InvokeChecked $provisioner @('remove-port', $port) }
}
$ports = @(& $provisioner list-ports)
if ($LASTEXITCODE -ne 0 -or $ports -contains $port) { throw 'Port cleanup not verified' }
Write-Host 'PASS isolated port cleanup; Windows 7/CorelDRAW/physical cutting NOT tested'

# Keep the native Win32 cause, not only the wrapper's exit=1/HRESULT.
$env:FOISON_RUN_ID='ci-redmon-negative'
$nativeLog=Join-Path $root 'dist/native-redmon-error.log'
$p=Start-Process $provisioner -ArgumentList @('verify-port',$port,('"'+(Join-Path $pack 'FoisonC24Receiver.exe')+'"')) -PassThru -RedirectStandardError $nativeLog
$handle=$p.Handle
if(-not $p.WaitForExit(30000)) {$p.Kill();throw 'Negative diagnostic timeout'}
$p.Refresh()
if($p.ExitCode -ne 1) {throw 'Missing-port negative diagnostic did not fail'}
$p.Dispose()
$text=[IO.File]::ReadAllText($nativeLog)
if($text -notmatch 'NativeErrorCode=[0-9]+') {throw 'Native Win32 error cause was lost'}
Write-Host ('PASS expected missing-port failure with '+$matches[0]+'; evidence='+$nativeLog)
