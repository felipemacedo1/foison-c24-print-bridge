$ErrorActionPreference = "Stop"
$PrinterName = "Foison C24 (Teste)"
$PortName = "RPT1:"
$Root = Split-Path -Parent $MyInvocation.MyCommand.Path
$Receiver = Join-Path $Root "FoisonC24Receiver.exe"
$Provisioner = Join-Path $Root "FoisonC24Provisioner.exe"
$RedMonSetup = Join-Path $Root "setup64.exe"
$RedMonDll = Join-Path $Root "redmon64.dll"
$DriverInf = Join-Path $env:windir "inf\ntprint.inf"
$createdPrinter = $false
$createdPort = $false

function Fail($message) { throw $message }
function Run($file, $arguments) {
  $p = Start-Process -FilePath $file -ArgumentList $arguments -Wait -PassThru -WindowStyle Hidden
  if ($p.ExitCode -ne 0) { Fail "Falha ao executar $file (codigo $($p.ExitCode))." }
}
function Printer($name) {
  Get-WmiObject -Class Win32_Printer -Filter ("Name='" + $name.Replace("'", "''") + "'")
}
function Remove-Queue {
  $p = Printer $PrinterName
  if ($p) { $p.Delete() | Out-Null }
  $p = Start-Process rundll32.exe -ArgumentList "printui.dll,PrintUIEntry /dl /n `"$PrinterName`" /q" -Wait -PassThru -WindowStyle Hidden
  if ($p.ExitCode -ne 0 -and (Printer $PrinterName)) { Write-Warning "Nao foi possivel remover a fila." }
}

if ($args -contains "uninstall") {
  Remove-Queue
  exit 0
}

try {
  $os = Get-WmiObject Win32_OperatingSystem
  if ($os.Caption -notmatch "Windows 7" -or $os.ServicePackMajorVersion -lt 1 -or $os.OSArchitecture -notmatch "64") {
    Fail "É necessário Windows 7 SP1 de 64 bits."
  }
  if (-not (Test-Path $Receiver)) { Fail "Receptor ausente." }
  if (-not (Test-Path $Provisioner)) { Fail "Provisionador ausente." }
  if (-not (Test-Path $RedMonSetup)) { Fail "Instalador RedMon x64 ausente." }
  if (-not (Test-Path $DriverInf)) { Fail "NTPRINT.INF não foi encontrado no Windows." }
  if (Printer $PrinterName) { Remove-Queue }

  Run $RedMonSetup "/s"
  Run $Provisioner "add-port $PortName"
  $createdPort = $true
  $receiverArguments = '--output-dir "' + (Join-Path $env:ProgramData "FoisonC24\captures") + '"'
  $redmonArguments = '"' + $RedMonDll + ',RedMonConfigurePortW" Port="' + $PortName +
    '" Command="' + $Receiver + '" Arguments="' + $receiverArguments +
    '" Output=0 LogFileUse=0 RunUser=0'
  $p = Start-Process rundll32.exe -ArgumentList $redmonArguments -Wait -PassThru -WindowStyle Hidden
  if ($p.ExitCode -ne 0) { Fail "RedMon não aceitou a configuração do receptor." }

  $drivers = @(Get-WmiObject Win32_PrinterDriver | ForEach-Object { $_.Name; $_.DriverName } |
    Where-Object { $_ -match "PostScript|PScript|Microsoft PS" } | Select-Object -Unique)
  if ($drivers.Count -eq 0) {
    Fail "Nenhum driver PostScript/PScript instalado foi encontrado. O Windows precisa fornecer um driver compatível."
  }
  $driver = $drivers[0]
  $args = "printui.dll,PrintUIEntry /if /b `"$PrinterName`" /r `"$PortName`" /m `"$driver`" /f `"$DriverInf`""
  $p = Start-Process rundll32.exe -ArgumentList $args -Wait -PassThru -WindowStyle Hidden
  if ($p.ExitCode -ne 0) { Fail "PrintUIEntry não criou a fila (codigo $($p.ExitCode))." }
  $createdPrinter = $true
  $queue = Printer $PrinterName
  if (-not $queue) { Fail "A fila não apareceu no spooler após a instalação." }
  if ($queue.PortName -ne $PortName) { Fail "A fila aponta para '$($queue.PortName)' em vez de '$PortName'." }
  Write-Host "Fila criada: $PrinterName"
  Write-Host "Driver detectado: $driver"
  Write-Host "Porta: $PortName"
  exit 0
}
catch {
  Write-Error $_.Exception.Message
  if ($createdPrinter) { Remove-Queue }
  if ($createdPort) {
    try { & $Provisioner remove-port $PortName | Out-Null }
    catch { Write-Warning "Nao foi possivel remover a porta $PortName durante o rollback." }
  }
  exit 1
}
