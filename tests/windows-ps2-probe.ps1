#requires -version 2.0
# Non-invasive probe: never installs/enables an obsolete OS feature.
# If PS2/CLR2 already exists, execute the REAL tests in it; never call that Win7.
$ErrorActionPreference='Stop'
$repo=Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
. (Join-Path $repo 'packaging/windows/Install-Queue-Win7.ps1')
$StateDir=Join-Path $env:TEMP ('foison-matrix-ps2-probe-'+[Guid]::NewGuid().ToString('N'))
$LogDirectory='';$RunId='ps2-probe';InitializeLogging
$exe=Join-Path $env:windir 'System32/WindowsPowerShell/v1.0/powershell.exe'
$probe='if($PSVersionTable.PSVersion.Major -ne 2 -or [Environment]::Version.Major -ne 2){exit 42};[Console]::WriteLine("PS2_CLR2_CONFIRMED");exit 0'
$encoded=[Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($probe))
$code=ProcessRun $exe ('-Version 2 -NoLogo -NoProfile -NonInteractive -EncodedCommand '+$encoded) 30000
$raw=@(Get-ChildItem $LogDirectory -Filter '*.out.raw'|Sort-Object LastWriteTimeUtc -Descending)[0].FullName
$text=[IO.File]::ReadAllText($raw)
$state='PS2_CLR2_NOT_CONFIRMED'
if($code -eq 0 -and $text.Contains('PS2_CLR2_CONFIRMED')) {
 $testArgs='-Version 2 -NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass -File "'+(Join-Path $repo 'tests/process-runner.ps1')+'"'
 $result=ProcessRun $exe $testArgs 240000
 if($result -ne 0){throw ('Actual PS2/CLR2 process regressions failed: '+$result)}
 $state='PS2_CLR2_PROCESS_TESTS_PASSED_ON_THIS_HOST'
}
[IO.File]::WriteAllLines((Join-Path $StateDir 'compatibility.properties'),[string[]]@('State='+$state,'ProbeExit='+$code,'Host='+[Environment]::OSVersion.VersionString,'Win7=NOT EXECUTED','Installation=NOT EXECUTED','Physical=NOT EXECUTED'),[Text.Encoding]::UTF8)
Write-Host ($state+'; Win7/installation/hardware NOT EXECUTED; evidence='+$StateDir)
