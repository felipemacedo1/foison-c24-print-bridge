# Windows CMD and actual Windows PowerShell startup failures; no spooler/COM access.
$ErrorActionPreference='Stop'
$root=Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$base=Join-Path $env:TEMP ('foison-bootstrap-'+[Guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory $base | Out-Null
foreach($case in @('missing-ps1','missing-powershell','syntax-error','exit23','fallback')) {
  $dir=Join-Path $base $case;New-Item -ItemType Directory $dir|Out-Null
  Copy-Item (Join-Path $root 'packaging/windows/Install-Queue-Win7.cmd') $dir
  if($case -ne 'missing-ps1') {
    $source='[Console]::OutputEncoding=New-Object Text.UTF8Encoding($false);Write-Host "stdout: Instalação";[Console]::Error.WriteLine("stderr evidence");exit 23'
    if($case -eq 'syntax-error') {$source='function Broken { param( }'}
    [IO.File]::WriteAllText((Join-Path $dir 'Install-Queue-Win7.ps1'),$source,[Text.Encoding]::UTF8)
  }
  $start=New-Object Diagnostics.ProcessStartInfo
  $start.FileName=$env:ComSpec;$start.UseShellExecute=$false;$start.CreateNoWindow=$true
  $start.Arguments='/d /c ""'+(Join-Path $dir 'Install-Queue-Win7.cmd')+'" install --noninteractive '+$case+'"'
  $start.EnvironmentVariables['ProgramData']=$dir
  $start.EnvironmentVariables['TEMP']=$dir
  if($case -eq 'missing-powershell') {$start.EnvironmentVariables['SystemRoot']=$dir}
  if($case -eq 'fallback') { [IO.File]::WriteAllText((Join-Path $dir 'blocked'),'x');$start.EnvironmentVariables['ProgramData']=Join-Path $dir 'blocked' }
  $p=[Diagnostics.Process]::Start($start)
  if(-not $p.WaitForExit(30000)) {$p.Kill();throw 'Noninteractive CMD paused/hung'}
  $expected=23
  if($case -eq 'missing-ps1') {$expected=66}
  if($case -eq 'missing-powershell') {$expected=69}
  if($case -eq 'syntax-error') {$expected=1}
  if($p.ExitCode -ne $expected) {throw "$case code=$($p.ExitCode); expected=$expected"}
  $logs=@(Get-ChildItem $dir -Recurse -Filter '*-cmd.log')
  if($logs.Count -ne 1) {throw "${case}: CMD diagnostic missing"}
  $text=[IO.File]::ReadAllText($logs[0].FullName,[Text.Encoding]::Default)
  if(-not $text.Contains('ExitCode='+$expected)) {throw 'Missing propagated exit evidence'}
  if($case -eq 'syntax-error' -or $case -eq 'exit23') {
    $err=@(Get-ChildItem $dir -Recurse -Filter '*-stderr.raw')
    if($err.Count -ne 1 -or $err[0].Length -eq 0) {throw 'Startup/process stderr lost'}
  }
  Write-Host "PASS actual Windows bootstrap $case ExitCode=$expected evidence=$($logs[0].FullName)"
  $p.Dispose()
}
