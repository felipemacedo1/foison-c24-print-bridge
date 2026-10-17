#requires -version 2.0
# Real NSIS /S OS rejection: never run on the supported target (would install).
$ErrorActionPreference='Stop'
if([Environment]::OSVersion.Version.Major -lt 10){throw 'This rejection test requires Windows 10/Server2022+, never the Win7 target.'}
$repo=Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
. (Join-Path $repo 'packaging/windows/Install-Queue-Win7.ps1')
$StateDir=Join-Path $env:TEMP ('foison-matrix-nsis-log-'+[Guid]::NewGuid().ToString('N'))
$LogDirectory='';$RunId='nsis-regression';InitializeLogging
$version=[IO.File]::ReadAllText((Join-Path $repo 'VERSION')).Trim()
$exe=Join-Path $repo ('dist/'+$version+'/FoisonC24-Setup-Win7-x64.exe')
$dir=Join-Path $env:ProgramData 'FoisonC24/Logs'
$before=@();if(Test-Path $dir){$before=@(Get-ChildItem $dir -Filter '*-nsis.log'|ForEach-Object {$_.FullName})}
$code=ProcessRun $exe '/S' 30000
if($code -ne 50){throw ('Expected actual unsupported-OS code 50, received '+$code)}
$new=@(Get-ChildItem $dir -Filter '*-nsis.log'|Where-Object {$before -notcontains $_.FullName})
if($new.Count -ne 1){throw 'NSIS correlated log missing or ambiguous'}
$data=[IO.File]::ReadAllBytes($new[0].FullName)
if($data.Length -lt 4 -or $data[0] -ne 255 -or $data[1] -ne 254){throw 'NSIS UTF16 BOM overwritten'}
$text=[Text.Encoding]::Unicode.GetString($data)
foreach($phrase in @('NSIS Unicode; log UTF-16LE; RunId=','BEGIN setup.','Verificando Windows 7 SP1 x64.','ERROR ExitCode=50','instalação falhou/foi interrompida. ExitCode=50')){
 if(-not $text.Contains($phrase)){throw ('NSIS append/Unicode lost: '+$phrase)}
}
if($text.IndexOf('BEGIN setup.') -gt $text.IndexOf('ERROR ExitCode=50')){throw 'NSIS chronology reversed'}
if($text.Contains([string][char]0xfffd)){throw 'NSIS replacement character'}
[IO.File]::Copy($new[0].FullName,(Join-Path $StateDir $new[0].Name))
Write-Host ('PASS actual NSIS silent exit50, append chronology, BOM and Portuguese. Evidence='+$StateDir)
