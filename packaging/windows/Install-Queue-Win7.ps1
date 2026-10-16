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
  $p = Start-Process -FilePath $file -ArgumentList $arguments -PassThru -WindowStyle Hidden
  if (-not $p.WaitForExit(120000)) {
    $p.Kill()
    Fail "Tempo excedido no provisionamento. Verifique fila e logs; nenhuma repetição automática."
  }
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
  if ($state.port -notmatch "^FOISONC24[0-9]+:$") { Fail "Porta não pertence ao namespace do Bridge; preservada." }
  $queue = Printer $PrinterName
  if ($queue -and ($queue.PortName -ne $state.port -or $queue.DriverName -ne $state.driver)) { Fail "Fila alterada externamente; manifesto e recursos preservados." }
  if ($queue) {
    Run "$env:windir\System32\rundll32.exe" "printui.dll,PrintUIEntry /dl /n `"$PrinterName`" /q"
    if (Printer $PrinterName) { Fail "Fila ainda presente; porta e manifesto preservados." }
  }
  $users = @(Get-WmiObject Win32_Printer | Where-Object { $_.PortName -eq $state.port })
  if ($users.Count -ne 0) { Fail "Porta em uso por outra fila; preservada." }
  $ports = @(& $Provisioner list-ports)
  if ($LASTEXITCODE -ne 0) { Fail "Não foi possível verificar a porta; manifesto preservado." }
  if ($ports -contains $state.port) { Run $Provisioner "remove-port $($state.port)" }

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
function VerifyPostScriptDriver($driver) {
  $matches = @(Get-WmiObject Win32_PrinterDriver | Where-Object {
    $name = ($_.Name -split ",")[0]
    $name -eq $driver -and $_.SupportedPlatform -eq "Windows x64" -and
      [IO.Path]::GetFileName($_.DriverPath) -ieq "PSCRIPT5.DLL"
  })
  if ($matches.Count -ne 1) { Fail "Driver '$driver' não possui correspondência x64 PScript5 única verificável ($($matches.Count))." }
  return $driver
}
function SelectPostScriptDriver {
  # This exact inbox model is requested through Microsoft's own INF, not a
  # guessed installed model or an arbitrary vendor/FTDI driver.
  $driver = "MS Publisher Imagesetter"
  $installed = @(Get-WmiObject Win32_PrinterDriver | Where-Object { ($_.Name -split ",")[0] -eq $driver -and $_.SupportedPlatform -eq "Windows x64" })
  if ($installed.Count -eq 0) {
    Run "$env:windir\System32\rundll32.exe" "printui.dll,PrintUIEntry /ia /m `"$driver`" /h x64 /v `"Type 3 - User Mode`" /f `"$DriverInf`""
  }
  return (VerifyPostScriptDriver $driver)
}

# One installer/uninstaller at a time; unrelated queues and serial ports are untouched.
New-Item -ItemType Directory -Force -Path $StateDir | Out-Null
$installLock = [IO.File]::Open((Join-Path $StateDir "installation.lock"), [IO.FileMode]::OpenOrCreate, [IO.FileAccess]::ReadWrite, [IO.FileShare]::None)

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

  $runtimeLog = Join-Path $StateDir "installation.log"
  New-Item -ItemType Directory -Force -Path $StateDir | Out-Null
  $sessionDir = Join-Path $StateDir "session"
  New-Item -ItemType Directory -Force -Path $sessionDir | Out-Null
  # Journal only: no permission changes to FTDI, serial device, spooler or other queues.
  Run "$env:windir\System32\icacls.exe" "`"$sessionDir`" /grant *S-1-5-32-545:(OI)(CI)M"
  Run (Join-Path $Root "FoisonC24Diagnostic.exe") "--selftest"

  $existing = Printer $PrinterName
  $owned = OwnState
  if ($existing) {
    if ($owned -and $owned.product -eq "Foison C24 Print Bridge" -and
        $existing.PortName -eq $owned.port -and $existing.DriverName -eq $owned.driver) {
      VerifyPostScriptDriver $owned.driver | Out-Null
      Run $Provisioner "configure-port $($owned.port) `"$Receiver`""
      Write-Host "Fila do Bridge já está instalada; nenhuma configuração existente foi removida."
      exit 0
    }
    Fail "Já existe uma impressora '$PrinterName' que não pertence comprovadamente a esta instalação. Ela foi preservada."
  }

  if ($owned -and -not $existing) {
    # Recover only resources registered by a prior incomplete invocation.
    RemoveOwnedResources
  }
  $driver = SelectPostScriptDriver
  $selectedPort = SelectProjectPort
  Run $RedMonSetup "/s"
  Run $Provisioner "add-port $selectedPort"
  $createdPort = $true
  SaveState $selectedPort $driver
  Run $Provisioner "configure-port $selectedPort `"$Receiver`""

  $printArgs = "printui.dll,PrintUIEntry /if /b `"$PrinterName`" /r `"$selectedPort`" /m `"$driver`" /f `"$DriverInf`""
  $p = Start-Process rundll32.exe -ArgumentList $printArgs -Wait -PassThru -WindowStyle Hidden
  $queue = Printer $PrinterName
  if ($p.ExitCode -ne 0 -and -not $queue) { Fail "PrintUIEntry não criou a fila (codigo $($p.ExitCode))." }
  if ($queue -and $queue.PortName -eq $selectedPort) { $createdPrinter = $true }
  if (-not $queue -or $queue.PortName -ne $selectedPort) {
    Fail "A fila não foi verificada com a porta exclusiva esperada."
  }
  if ($queue.DriverName -and $queue.DriverName -ne $driver) {
    Fail "A fila foi associada a um driver diferente do validado."
  }
  SaveState $selectedPort $driver
  "Fila e porta verificadas; teste físico desabilitado." | Set-Content -Encoding UTF8 $runtimeLog
  Write-Host "Fila criada: $PrinterName / $selectedPort / $driver"
  exit 0
}
catch {
  $failure = $_.Exception.Message
  try { New-Item -ItemType Directory -Force -Path $StateDir | Out-Null; $failure | Set-Content -Encoding UTF8 (Join-Path $StateDir "installation-error.log") } catch { }
  Write-Warning $failure
  if ($createdPort -and $selectedPort) {
    try { RemoveOwnedResources }
    catch { Write-Warning "Rollback incompleto; manifesto preservado para diagnóstico: $($_.Exception.Message)" }
  }
  exit 1
}
