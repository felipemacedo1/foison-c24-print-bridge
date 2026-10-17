# Windows CMD and actual Windows PowerShell startup failures; no spooler/COM access.
$ErrorActionPreference='Stop'
$root=Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$base=Join-Path $env:TEMP ('foison-bootstrap-'+[Guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory $base | Out-Null
foreach($case in @('missing-ps1','missing-powershell','syntax-error','exit23','fallback','raw-stream-unwritable','unicode-path','zero-without-receipt','valid-receipt','stale-receipt','ps2-runtime-error','ps2-valid-receipt')) {
  $dir=Join-Path $base $case
  if($case -eq 'unicode-path') {$dir=Join-Path $base 'ação & teste'}
  New-Item -ItemType Directory $dir|Out-Null
  Copy-Item (Join-Path $root 'packaging/windows/Install-Queue-Win7.cmd') $dir
  if($case.StartsWith('ps2-')) {
    $cmd=Join-Path $dir 'Install-Queue-Win7.cmd'
    $content=[IO.File]::ReadAllText($cmd).Replace('"%PS%" -NoLogo','"%PS%" -Version 2 -NoLogo')
    [IO.File]::WriteAllText($cmd,$content,[Text.Encoding]::ASCII)
  }
  if($case -ne 'missing-ps1') {
    $source='[Console]::OutputEncoding=New-Object Text.UTF8Encoding($false);Write-Host "stdout: Instalação";[Console]::Error.WriteLine("stderr evidence");exit 23'
    if($case -eq 'syntax-error') {$source='function Broken { param( }'}
    if($case -eq 'zero-without-receipt') {$source='exit 0'}
    if($case -eq 'ps2-runtime-error') {$source='$ErrorActionPreference="Stop";$hash=[Security.Cryptography.SHA256]::Create();$hash.Dispose()'}
    if(@('valid-receipt','stale-receipt','ps2-valid-receipt') -contains $case) {
      $source='param($Operation,$RunId,$LogDirectory,$CompletionId);$text="SUCCESS Operation="+$Operation+" RunId="+$RunId+" CompletionId="+$CompletionId;[IO.File]::WriteAllText((Join-Path $LogDirectory ("install-"+$RunId+"-"+$CompletionId+"-complete.txt")),$text+"`r`n",[Text.Encoding]::ASCII);exit 0'
      if($case -eq 'stale-receipt') {$source=$source.Replace('+$CompletionId;','+"stale";')}
    }
    [IO.File]::WriteAllText((Join-Path $dir 'Install-Queue-Win7.ps1'),$source,[Text.Encoding]::UTF8)
  }
  $start=New-Object Diagnostics.ProcessStartInfo
  $start.FileName=$env:ComSpec;$start.UseShellExecute=$false;$start.CreateNoWindow=$true
  $start.Arguments='/d /c ""'+(Join-Path $dir 'Install-Queue-Win7.cmd')+'" install --noninteractive '+$case+'"'
  $start.EnvironmentVariables['ProgramData']=$dir
  $start.EnvironmentVariables['TEMP']=$dir
  if($case -eq 'missing-powershell') {$start.EnvironmentVariables['SystemRoot']=$dir}
  if($case -eq 'fallback') { [IO.File]::WriteAllText((Join-Path $dir 'blocked'),'x');$start.EnvironmentVariables['ProgramData']=Join-Path $dir 'blocked' }
  if($case -eq 'raw-stream-unwritable') {
    $blocked=Join-Path $dir ('FoisonC24/Logs/install-'+$case+'-stdout.raw')
    New-Item -ItemType Directory -Force $blocked|Out-Null
  }
  $p=[Diagnostics.Process]::Start($start)
  if(-not $p.WaitForExit(30000)) {$p.Kill();throw 'Noninteractive CMD paused/hung'}
  $expected=23
  if($case -eq 'missing-ps1') {$expected=66}
  if($case -eq 'missing-powershell') {$expected=69}
  if($case -eq 'syntax-error') {$expected=1}
  if(@('zero-without-receipt','stale-receipt','ps2-runtime-error') -contains $case) {$expected=74}
  if(@('valid-receipt','ps2-valid-receipt') -contains $case) {$expected=0}
  if($case -eq 'raw-stream-unwritable') {if($p.ExitCode -eq 0){throw 'Stream failure reported success'};$expected=$p.ExitCode}
  if($p.ExitCode -ne $expected) {throw "$case code=$($p.ExitCode); expected=$expected"}
  $logs=@(Get-ChildItem $dir -Recurse -Filter 'install-*-cmd.log')
  if($logs.Count -ne 1) {throw "${case}: CMD diagnostic missing"}
  $text=[IO.File]::ReadAllText($logs[0].FullName,[Text.Encoding]::Default)
  if(-not $text.Contains('ExitCode='+$expected)) {throw 'Missing propagated exit evidence'}
  if($case -eq 'syntax-error' -or $case -eq 'exit23') {
    $err=@(Get-ChildItem $dir -Recurse -Filter '*-stderr.raw')
    if($err.Count -ne 1 -or $err[0].Length -eq 0) {throw 'Startup/process stderr lost'}
  }
  if($case -eq 'ps2-runtime-error') {
    if(-not $text.Contains('PowerShellExitCode=0') -or -not $text.Contains('completion receipt is missing/invalid')) {throw 'PS2 zero-on-error was not positively diagnosed'}
    $err=@(Get-ChildItem $dir -Recurse -Filter '*-stderr.raw')
    if($err.Count -ne 1 -or $err[0].Length -eq 0){throw 'PS2 runtime error bytes lost'}
  }
  Write-Host "PASS actual Windows bootstrap $case ExitCode=$expected evidence=$($logs[0].FullName)"
  $p.Dispose()
}
