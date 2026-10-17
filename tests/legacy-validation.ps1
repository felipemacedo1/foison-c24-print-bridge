#requires -version 2.0
# Run manually in a licensed, OFFLINE Win7 Professional SP1 x64 VM, elevated.
# No installer/queue/serial changes here; tests touch only temporary fixture ACLs.
$ErrorActionPreference='Stop'
$repo=Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$os=Get-WmiObject Win32_OperatingSystem
if($os.Version -ne '6.1.7601' -or $os.ProductType -ne 1 -or $os.ServicePackMajorVersion -lt 1 -or [IntPtr]::Size -ne 8 -or $PSVersionTable.PSVersion.Major -ne 2 -or [Environment]::Version.Major -ne 2){throw 'This evidence requires real Win7 SP1 x64 + PS2 + CLR2. No fallback to modern PowerShell.'}
$identity=[Security.Principal.WindowsIdentity]::GetCurrent()
try{$principal=New-Object Security.Principal.WindowsPrincipal($identity);if(-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)){throw 'Execute como administrador'}}finally{$identity.Dispose()}
$evidence=Join-Path $env:TEMP ('foison-matrix-legacy-'+[Guid]::NewGuid().ToString('N'))
[IO.Directory]::CreateDirectory($evidence)|Out-Null
$envText=@(('Caption='+$os.Caption),('Version='+$os.Version),('SP='+$os.ServicePackMajorVersion),('Architecture='+$os.OSArchitecture),('PowerShell='+$PSVersionTable.PSVersion),('CLR='+[Environment]::Version),'Installer=NOT EXECUTED','Queue=NOT EXECUTED','CorelDRAW=NOT EXECUTED','Physical=NOT EXECUTED')
[IO.File]::WriteAllLines((Join-Path $evidence 'environment.properties'),[string[]]$envText,[Text.Encoding]::UTF8)
# Preserve actual PS2 command metadata; modern syntax is not proof of old parameter sets.
Get-Command Start-Process -Syntax | Out-File (Join-Path $evidence 'Start-Process-syntax.txt') -Encoding UTF8
& (Join-Path $repo 'tests/process-runner.ps1') -RequireLegacy
if(-not $?){throw 'Real legacy subprocess tests failed'}
& (Join-Path $repo 'tests/provisioning-matrix.ps1')
if(-not $?){throw 'Legacy orchestration model failed'}
[IO.File]::WriteAllText((Join-Path $evidence 'PASS.txt'),'PASS legacy runtime tests; installation, queue, CorelDRAW and hardware remain separate.',[Text.Encoding]::UTF8)
Write-Host ('Evidências: '+$evidence+'. Validar instalador/fila separadamente; nenhum movimento autorizado.')
