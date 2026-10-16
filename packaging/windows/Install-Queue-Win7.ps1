$ErrorActionPreference = "Stop"
$PrinterName = "Foison C24 (Teste)"
$PortPrefix = "FOISONC24"
$Root = Split-Path -Parent $MyInvocation.MyCommand.Path
$Receiver = Join-Path $Root "FoisonC24Receiver.exe"
$Provisioner = Join-Path $Root "FoisonC24Provisioner.exe"
$RedMonSetup = Join-Path $Root "setup64.exe"
$RedMonDll = Join-Path $Root "redmon64.dll"
$DriverInf = Join-Path $env:windir "inf\ntprint.inf"
$StateDir = Join-Path $env:ProgramData "FoisonC24"
$StatePath = Join-Path $StateDir "install-state.json"
$createdPrinter = $false
$createdPort = $false
$selectedPort = $null

function Fail($message) { throw $message }
function Run($file, $arguments) {
  $p = Start-Process -FilePath $file -ArgumentList $arguments -Wait -PassThru -WindowStyle Hidden
  if ($p.ExitCode -ne 0) { Fail "Falha ao executar $file (codigo $($p.ExitCode))." }
}
function Printer($name) {
  Get-WmiObject -Class Win32_Printer -Filter ("Name='" + $name.Replace("'", "''") + "'")
}
function OwnState {
  if (Test-Path $StatePath) {
    return (Get-Content $StatePath | Out-String | ConvertFrom-StringData)
  }
  return $null
}
function SaveState($port, $driver) {
  New-Item -ItemType Directory -Force -Path $StateDir | Out-Null
  @("product=Foison C24 Print Bridge", "printer=$PrinterName", "port=$port",
    "driver=$driver", "physical_cut_enabled=false",
    "created_utc=$([DateTime]::UtcNow.ToString("o"))") |
    Set-Content -Encoding UTF8 $StatePath
}
function RemoveOwnedResources {
  $state = OwnState
  if (-not $state -or $state.product -ne "Foison C24 Print Bridge" -or
      $state.printer -ne $PrinterName) { return }
  $queue = Printer $PrinterName
  if ($queue -and $queue.PortName -eq $state.port) {
    $p = Start-Process rundll32.exe -ArgumentList "printui.dll,PrintUIEntry /dl /n `"$PrinterName`" /q" -Wait -PassThru -WindowStyle Hidden
    if ($p.ExitCode -ne 0 -and (Printer $PrinterName)) {
      Write-Warning "Nao foi possivel remover a fila criada pelo Bridge."
    }
  }
  if (Test-Path $Provisioner) {
    & $Provisioner remove-port $state.port | Out-Null
  }
  Remove-Item -Force -ErrorAction SilentlyContinue $StatePath
}
function SelectProjectPort {
  $ports = @(& $Provisioner list-ports)
  if ($LASTEXITCODE -ne 0) { Fail "Não foi possível verificar conflitos de portas." }
  for ($i = 1; $i -le 99; $i++) {
    $candidate = "{0}{1}:" -f $PortPrefix, $i
    if ($ports -notcontains $candidate) { return $candidate }
  }
  Fail "Não há uma porta exclusiva FOISONC24 disponível."
}
function SelectPostScriptDriver {
  $matches = @(Get-WmiObject Win32_PrinterDriver | Where-Object {
    $name = if ($_.DriverName) { $_.DriverName } else { $_.Name }
    $inf = if ($_.InfName) { $_.InfName } else { "" }
    ($name -match "^(Microsoft PS|Microsoft PostScript|PScript)") -and
      (($inf -eq "ntprint.inf") -or ($inf -match "^oem[0-9]+\.inf$"))
  })
  if ($matches.Count -ne 1) {
    Fail "Foi encontrado um número ambíguo de drivers PostScript compatíveis ($($matches.Count)). Nenhuma fila foi alterada."
  }
  $driver = if ($matches[0].DriverName) { $matches[0].DriverName } else { $matches[0].Name }
  if ([String]::IsNullOrWhiteSpace($driver)) { Fail "Driver PostScript sem nome verificável." }
  return $driver
}

if ($args -contains "uninstall") {
  RemoveOwnedResources
  exit 0
}

try {
  $os = Get-WmiObject Win32_OperatingSystem
  if ($os.Caption -notmatch "Windows 7" -or $os.ServicePackMajorVersion -lt 1 -or $os.OSArchitecture -notmatch "64") {
    Fail "É necessário Windows 7 SP1 de 64 bits."
  }
  foreach ($file in @($Receiver, $Provisioner, $RedMonSetup, $RedMonDll)) {
    if (-not (Test-Path $file)) { Fail "Componente ausente: $file" }
  }
  if (-not (Test-Path $DriverInf)) { Fail "NTPRINT.INF não foi encontrado no Windows." }

  $existing = Printer $PrinterName
  $owned = OwnState
  if ($existing) {
    if ($owned -and $owned.product -eq "Foison C24 Print Bridge" -and
        $existing.PortName -eq $owned.port) {
      Write-Host "Fila do Bridge já está instalada; nenhuma configuração existente foi removida."
      exit 0
    }
    Fail "Já existe uma impressora '$PrinterName' que não pertence comprovadamente a esta instalação. Ela foi preservada."
  }

  $driver = SelectPostScriptDriver
  $selectedPort = SelectProjectPort
  Run $RedMonSetup "/s"
  Run $Provisioner "add-port $selectedPort"
  $createdPort = $true
  $receiverArguments = '--output-dir "' + (Join-Path $env:ProgramData "FoisonC24\captures") + '"'
  $redmonArguments = '"' + $RedMonDll + ',RedMonConfigurePortW" Port="' + $selectedPort +
    '" Command="' + $Receiver + '" Arguments="' + $receiverArguments +
    '" Output=0 LogFileUse=0 RunUser=0'
  $p = Start-Process rundll32.exe -ArgumentList $redmonArguments -Wait -PassThru -WindowStyle Hidden
  if ($p.ExitCode -ne 0) { Fail "RedMon não aceitou a configuração do receptor." }

  $printArgs = "printui.dll,PrintUIEntry /if /b `"$PrinterName`" /r `"$selectedPort`" /m `"$driver`" /f `"$DriverInf`""
  $p = Start-Process rundll32.exe -ArgumentList $printArgs -Wait -PassThru -WindowStyle Hidden
  if ($p.ExitCode -ne 0) { Fail "PrintUIEntry não criou a fila (codigo $($p.ExitCode))." }
  $createdPrinter = $true
  $queue = Printer $PrinterName
  if (-not $queue -or $queue.PortName -ne $selectedPort) {
    Fail "A fila não foi verificada com a porta exclusiva esperada."
  }
  if ($queue.DriverName -and $queue.DriverName -ne $driver) {
    Fail "A fila foi associada a um driver diferente do validado."
  }
  SaveState $selectedPort $driver
  Write-Host "Fila criada: $PrinterName / $selectedPort / $driver"
  exit 0
}
catch {
  Write-Error $_.Exception.Message
  if ($createdPrinter -and $selectedPort) {
    Start-Process rundll32.exe -ArgumentList "printui.dll,PrintUIEntry /dl /n `"$PrinterName`" /q" -Wait -WindowStyle Hidden
  }
  if ($createdPort -and $selectedPort) {
    try { & $Provisioner remove-port $selectedPort | Out-Null }
    catch { Write-Warning "Nao foi possivel remover a porta criada: $selectedPort" }
  }
  exit 1
}
