#requires -version 2.0
param([string]$Operation = "install", [string]$RunId = "", [string]$LogDirectory = "")
$ErrorActionPreference = "Stop"
$Root = Split-Path -Parent $MyInvocation.MyCommand.Path
$PrinterName = "Foison C24 (Teste)"
$StateDir = Join-Path $env:ProgramData "FoisonC24"
$StatePath = Join-Path $StateDir "install-state.properties"
$LegacyPath = Join-Path $StateDir "install-state.json"
$LogPath = $null
$Version = "unknown"
$Step = "INITIALIZE"
$LastProcessCode = $null
$Utf8 = New-Object Text.UTF8Encoding($true)

function InitializeLogging {
  if ($RunId -notmatch "^[a-zA-Z0-9_-]{1,80}$") { $script:RunId = [Guid]::NewGuid().ToString("N") }
  $candidates = @((Join-Path $StateDir "Logs"), (Join-Path ([IO.Path]::GetTempPath()) "FoisonC24/Logs"))
  if ($LogDirectory) { $candidates = @($LogDirectory) + $candidates }
  foreach ($directory in $candidates) {
    try {
      if ((Test-Path $StateDir) -and ((Get-Item $StateDir).Attributes -band [IO.FileAttributes]::ReparsePoint)) { throw "Diretório de estado é um redirecionamento; não será seguido." }
      [IO.Directory]::CreateDirectory($directory) | Out-Null
      if ((Get-Item $directory).Attributes -band [IO.FileAttributes]::ReparsePoint) { throw "Destino de log redirecionado; recusado." }
      $path = Join-Path $directory ("install-" + $RunId + "-powershell.log")
      # Append only: verify after CMD bootstrap without truncating previous evidence.
      [IO.File]::AppendAllText($path, "", $Utf8)
      $script:LogDirectory = $directory; $script:LogPath = $path
      try { [IO.File]::WriteAllText((Join-Path $directory "installation-latest.log"), "RunId=" + $RunId + "`r`nLog=" + $path + "`r`n", $Utf8) } catch { }
      # Keep at least 30 days; bounded to 200 oldest completed run files, never current.
      try {
        $old = @(Get-ChildItem $directory -Filter "install-*" | Where-Object { $_.Name -notlike ("*"+$RunId+"*") -and $_.LastWriteTimeUtc -lt [DateTime]::UtcNow.AddDays(-30) } | Sort-Object LastWriteTimeUtc -Descending)
        if ($old.Count -gt 200) { $old | Select-Object -Skip 200 | Remove-Item -Force }
      } catch { }
      try { [Console]::OutputEncoding = New-Object Text.UTF8Encoding($false) } catch { Log "Console sem suporte a UTF-8; bytes stdout/stderr preservados como .raw." "WARN" }
      $env:FOISON_RUN_ID = $RunId
      Log "Iniciando Foison C24 Print Bridge; log UTF-8; sem conteúdo de impressão."
      return
    } catch { Write-Host ("Falha no destino de log: " + $_.Exception.Message) }
  }
  throw "Nenhum destino de diagnóstico gravável em ProgramData ou TEMP."
}
function Log($message, $level = "INFO", $component = "powershell") {
  if (@("DEBUG","INFO","WARN","ERROR","FATAL") -notcontains $level) { throw "Nivel de log invalido." }
  $line = [DateTime]::UtcNow.ToString("o") + " [" + $level + "] [" + $RunId + "] [" + $component + "] [" + $Step + "] " + $message
  Write-Host $line
  if ($LogPath) { [IO.File]::AppendAllText($LogPath, $line + "`r`n", $Utf8) }
}
function Stage($name) {
  if ($Step) { Log ("END " + $Step) "DEBUG" }
  $script:Step = $name
  Log ("BEGIN " + $name)
}
function LogException($errorRecord) {
  $e = $errorRecord.Exception
  $where = $errorRecord.InvocationInfo
  $detail = "Exception=" + $e.GetType().FullName + " Message=" + $e.Message + " File=" + $where.ScriptName + " Line=" + $where.ScriptLineNumber + " Command=" + $where.MyCommand + " ExitCode=" + $LastProcessCode
  if ($errorRecord.PSObject.Properties["ScriptStackTrace"]) { $detail += " Stack=" + $errorRecord.ScriptStackTrace }
  $inner = $e.InnerException
  while ($inner) { $detail += " Inner=" + $inner.GetType().FullName + ": " + $inner.Message; $inner = $inner.InnerException }
  Log $detail "ERROR"
}
function IsAdmin {
  $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
  try {
    $principal = New-Object Security.Principal.WindowsPrincipal($identity)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
  } finally { $identity.Dispose() }
}
function OperatingSystem { return (Get-WmiObject Win32_OperatingSystem) }
function Printer { return (Get-WmiObject Win32_Printer -Filter "Name='$PrinterName'") }
function PortUsers($port) { return @(Get-WmiObject Win32_Printer | Where-Object { $_.PortName -eq $port }) }
function ProcessRun($file, $arguments, $timeoutMs = 120000) {
  $watch = [Diagnostics.Stopwatch]::StartNew()
  $p = $null; $code = $null; $timedOut = $false
  $component = [IO.Path]::GetFileNameWithoutExtension($file).ToLowerInvariant()
  $id = [Guid]::NewGuid().ToString("N")
  $stdout = Join-Path $LogDirectory ("process-" + $id + ".out")
  $stderr = Join-Path $LogDirectory ("process-" + $id + ".err")
  $componentLog = Join-Path $LogDirectory ("install-" + $RunId + "-" + $component + ".log")
  $command = 'exe="' + $file + '" args=' + $arguments
  Log ("PROCESS " + $command) "INFO" $component
  try {
    $p = Start-Process -FilePath $file -ArgumentList $arguments -PassThru -WindowStyle Hidden -RedirectStandardOutput $stdout -RedirectStandardError $stderr
    $handle = $p.Handle
    if (-not $p.WaitForExit($timeoutMs)) {
      $timedOut = $true
      $p.Kill()
      # Bound cleanup too: no indefinite WaitForExit()/stdout pipe read.
      $p.WaitForExit(5000) | Out-Null
      throw "Timeout no processo criado pelo Bridge; nenhuma repetição automática."
    }
    $p.Refresh(); $code = $p.ExitCode
    if ($null -eq $code) { throw "Processo sem código de saída verificável." }
    $script:LastProcessCode = [int]$code
    return [int]$code
  } finally {
    $watch.Stop()
    $summary = [DateTime]::UtcNow.ToString("o") + " [" + $RunId + "] [" + $Step + "] " + $command + " ExitCode=" + $code + " Timeout=" + $timedOut + " DurationMs=" + $watch.ElapsedMilliseconds
    [IO.File]::AppendAllText($componentLog, $summary + "`r`n", $Utf8)
    foreach ($path in @($stdout,$stderr)) {
      if (Test-Path $path) {
        # Native output encoding is not guaranteed. Preserve raw bytes independently;
        # decode only a bounded excerpt, never concatenate OEM bytes into UTF-8 logs.
        $stream = [IO.File]::OpenRead($path)
        try {
          $bytes = New-Object byte[] 16384
          $count = $stream.Read($bytes,0,$bytes.Length)
          $strictUtf8 = New-Object Text.UTF8Encoding($false,$true)
          try { $content = $strictUtf8.GetString($bytes,0,$count) } catch { $content = [Text.Encoding]::GetEncoding([Globalization.CultureInfo]::CurrentCulture.TextInfo.OEMCodePage).GetString($bytes,0,$count) }
          $content = $content.Replace([string][char]0xfffd,"?")
          [IO.File]::AppendAllText($componentLog, [IO.Path]::GetExtension($path) + "=" + $content + "`r`n", $Utf8)
        } finally { $stream.Dispose() }
        [IO.File]::Move($path, (Join-Path $LogDirectory ("install-" + $RunId + "-" + $component + "-" + $id + [IO.Path]::GetExtension($path) + ".raw")))
      }
    }
    if ($p) { $p.Dispose() }
    Log $summary "INFO" $component
  }
}
function Run($file,$arguments) {
  $code = ProcessRun $file $arguments
  if ($code -ne 0) { throw "Falha em $([IO.Path]::GetFileName($file)): codigo $code. Consulte o log de diagnóstico." }
}
function Provision($arguments) { Run (Join-Path $Root "FoisonC24Provisioner.exe") $arguments }
function MonitorPresent {
  $code = ProcessRun (Join-Path $Root "FoisonC24Provisioner.exe") "monitor-status"
  if ($code -eq 0) { return $true }
  if ($code -eq 3) { return $false }
  throw "Nao foi possivel comprovar o monitor RedMon x64 (codigo $code)."
}
function EnsureMonitor {
  if (-not (MonitorPresent)) { Run (Join-Path $Root "setup64.exe") "/s" }
  if (-not (MonitorPresent)) { throw "setup64 terminou, mas Redirected Port/redmon64.dll nao foi registrado. Nenhuma fila sera criada." }
  Log "MONITOR verificado Redirected Port / redmon64.dll"
}
function ListProjectPort {
  # The helper writes an explicit file, avoiding parsing or losing native exit codes.
  $list = Join-Path $StateDir "ports.txt"
  Provision ('list-ports-file "' + $list + '"')
  try { return @([IO.File]::ReadAllLines($list)) } finally { if (Test-Path $list) { [IO.File]::Delete($list) } }
}
function ValidateDependencies {
  foreach ($name in @("VERSION","FoisonC24Receiver.exe.config","FoisonC24Diagnostic.exe.config","FoisonC24Provisioner.exe.config","FoisonC24Diagnostic.exe","FoisonC24Receiver.exe","FoisonC24Provisioner.exe","FoisonC24.Core.dll","setup64.exe","redmon64.dll","redmon.chm","unredmon64.exe","tools\gs\bin\gswin64c.exe","tools\gs\bin\gsdll64.dll","tools\mupdf\mutool.exe","testes\square-20mm.ps")) {
    $path = Join-Path $Root $name
    if (-not (Test-Path $path -PathType Leaf) -or (Get-Item $path).Length -eq 0) { throw "Componente ausente/vazio: $name. Execute o instalador completo." }
  }
  $release = (Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\NET Framework Setup\NDP\v4\Full" -Name Release).Release
  if ($release -lt 528040) { throw ".NET Framework 4.8 necessario. Execute o instalador completo." }
  Run (Join-Path $Root "FoisonC24Diagnostic.exe") "--selftest"
}
function ReadProperties($path) {
  $state = @{}
  foreach ($line in [IO.File]::ReadAllLines($path,[Text.Encoding]::UTF8)) {
    if ($line.Trim().Length -eq 0 -or $line.StartsWith("#")) { continue }
    $at = $line.IndexOf("=")
    if ($at -lt 1) { throw "Manifesto invalido; preservado: $path" }
    $key = $line.Substring(0,$at)
    if ($state.ContainsKey($key)) { throw "Manifesto com chave duplicada; preservado." }
    $state[$key] = $line.Substring($at+1)
  }
  return $state
}
function ReadState {
  if ((Test-Path $StatePath) -and (Test-Path $LegacyPath)) {
    $a = ReadProperties $StatePath; $b = ReadProperties $LegacyPath
    if ($a.product -ne $b.product -or $a.printer -ne $b.printer -or $a.port -ne $b.port -or $a.driver -ne $b.driver) { throw "Manifestos conflitantes; nenhuma configuracao sera alterada." }
  }
  if (Test-Path $StatePath) { return (ReadProperties $StatePath) }
  if (Test-Path $LegacyPath) { return (ReadProperties $LegacyPath) }
  return $null
}
function WriteState($state) {
  $state["version"] = $Version
  $lines = @("# Foison Bridge literal UTF-8 key=value; no escape expansion")
  foreach ($key in @($state.Keys | Sort-Object)) {
    $value = [string]$state[$key]
    if ($key -notmatch "^[a-z_]+$" -or $value.IndexOfAny([char[]]"`r`n") -ge 0) { throw "Valor de manifesto invalido." }
    $lines += $key + "=" + $value
  }
  $temp = $StatePath + "." + [Guid]::NewGuid().ToString("N") + ".tmp"
  try {
    [IO.File]::WriteAllLines($temp, [string[]]$lines, [Text.Encoding]::UTF8)
    if (Test-Path $StatePath) { [IO.File]::Replace($temp,$StatePath,($temp+".bak")); [IO.File]::Delete($temp+".bak") } else { [IO.File]::Move($temp,$StatePath) }
  } finally { if (Test-Path $temp) { [IO.File]::Delete($temp) } }
  Log ("STATE stage=" + $state.stage + " queue=" + $state.printer + " port=" + $state.port + " driver=" + $state.driver)
}
function ValidateState($state) {
  if (-not $state -or $state.product -ne "Foison C24 Print Bridge" -or $state.printer -ne $PrinterName -or $state.port -notmatch "^FOISONC24[1-9][0-9]*:$" -or -not $state.driver) { throw "Propriedade dos recursos nao comprovada; manifesto preservado." }
}
function PortOwned($state) {
  $nativeArgs = 'verify-port ' + $state.port + ' "' + (Join-Path $Root "FoisonC24Receiver.exe") + '"'
  if ($state.owner) { $nativeArgs += ' ' + $state.owner }
  Provision $nativeArgs
}
function QueueFingerprint($queue, $ignoreComment = $false) {
  $comment = $queue.Comment; if ($ignoreComment) { $comment = "migration" }
  $text = @($queue.Name,$queue.PortName,$queue.DriverName,$comment,$queue.PrintProcessor,$queue.Shared,$queue.ShareName,$queue.RawOnly,$queue.Location,$queue.SeparatorFile,$queue.Parameters,$queue.Priority,$queue.DefaultPriority,$queue.StartTime,$queue.UntilTime,$queue.KeepPrintedJobs,$queue.Direct,$queue.Queued,$queue.EnableBIDI,$queue.EnableDevQueryPrint,$queue.DoCompleteFirst,$queue.Published) -join "|"
  $sha = [Security.Cryptography.SHA256]::Create()
  try { return ([BitConverter]::ToString($sha.ComputeHash([Text.Encoding]::UTF8.GetBytes($text))).Replace("-","").ToLowerInvariant()) } finally { $sha.Dispose() }
}
function QueueOwned($state,$queue) {
  if (-not $queue -or $queue.Name -ne $state.printer -or $queue.PortName -ne $state.port -or $queue.DriverName -ne $state.driver) { throw "Fila alterada externamente ou nao pertence comprovadamente ao Bridge; preservada." }
  if ($state.owner -and $queue.Comment -ne ("Foison C24 Print Bridge " + $state.owner)) { throw "Marcador de propriedade da fila foi alterado; preservada." }
  if ($state.queue_fingerprint -and (QueueFingerprint $queue) -ne $state.queue_fingerprint) { throw "Propriedades da fila mudaram externamente; preservada." }
}
function MigrateState($state) {
  ValidateState $state
  if (-not $state.owner) {
    # Legacy manifest alone is not proof: require queue and actual RedMon config.
    QueueOwned $state (Printer)
    PortOwned $state
    $state["owner"] = [Guid]::NewGuid().ToString("N")
    $state["migration_comment"] = [string](Printer).Comment
    $state["migration_fingerprint"] = QueueFingerprint (Printer) $true
    $state["schema"] = "2"; $state["stage"] = "adopting"
    WriteState $state # durable intent BEFORE touching a legacy resource
  }
  if ($state.stage -eq "adopting") {
    $queue = Printer
    if (-not $queue -or (QueueFingerprint $queue $true) -ne $state.migration_fingerprint -or ($queue.Comment -ne $state.migration_comment -and $queue.Comment -ne ("Foison C24 Print Bridge " + $state.owner))) { throw "Fila mudou durante migração; preservada." }
    Provision ('verify-port ' + $state.port + ' "' + (Join-Path $Root "FoisonC24Receiver.exe") + '"')
    Provision ('adopt-queue "' + $PrinterName + '" ' + $state.port + ' "' + $state.driver + '" ' + $state.owner)
    Provision ('configure-port ' + $state.port + ' "' + (Join-Path $Root "FoisonC24Receiver.exe") + '" ' + $state.owner)
    $state["stage"] = "complete"
    $state["queue_fingerprint"] = QueueFingerprint (Printer)
    $state["receiver"] = Join-Path $Root "FoisonC24Receiver.exe"
    $state.Remove("migration_comment"); $state.Remove("migration_fingerprint")
    WriteState $state
  }
  if (Test-Path $LegacyPath) {
    $backup = $LegacyPath + ".legacy.properties.bak"
    if (Test-Path $backup) { throw "Backup de migracao ja existe; preserve e consulte o desenvolvedor." }
    [IO.File]::Move($LegacyPath,$backup)
    Log "MIGRATION legado key=value preservado em .legacy.properties.bak"
  }
  return $state
}
function VerifyDriver($driver) {
  $matches = @(Get-WmiObject Win32_PrinterDriver | Where-Object { ($_.Name -split ",")[0] -eq $driver -and $_.SupportedPlatform -eq "Windows x64" -and [IO.Path]::GetFileName($_.DriverPath) -ieq "PSCRIPT5.DLL" })
  if ($matches.Count -ne 1) { throw "Driver PScript5 x64 '$driver' ausente ou ambiguo ($($matches.Count)); nenhuma alternativa arbitraria sera usada." }
}
function EnsureDriver {
  $driver = "MS Publisher Imagesetter"
  $matches = @(Get-WmiObject Win32_PrinterDriver | Where-Object { ($_.Name -split ",")[0] -eq $driver -and $_.SupportedPlatform -eq "Windows x64" })
  if ($matches.Count -eq 0) {
    $inf = Join-Path $env:windir "inf\ntprint.inf"
    if (-not (Test-Path $inf)) { throw "ntprint.inf do Windows ausente; nao sera substituido." }
    Run (Join-Path $env:windir "System32\rundll32.exe") ('printui.dll,PrintUIEntry /ia /m "' + $driver + '" /h x64 /v "Type 3 - User Mode" /f "' + $inf + '"')
  }
  VerifyDriver $driver
  return $driver
}
function RemoveOwned($state, $allowEmptyPort = $false) {
  ValidateState $state
  $ports = @(ListProjectPort)
  $queue = Printer
  if ($queue) { QueueOwned $state $queue }
  if ($ports -contains $state.port) {
    try { PortOwned $state } catch {
      if ($allowEmptyPort -and @("reserved","port-created") -contains $state.stage) { Provision ("verify-empty-port " + $state.port) } else { throw }
    }
  }
  if ($queue) { Provision ('remove-queue "' + $PrinterName + '" ' + $state.port + ' "' + $state.driver + '" ' + $state.owner) }
  if (Printer) { throw "Fila ainda presente; porta e manifesto preservados." }
  if (@(PortUsers $state.port).Count -ne 0) { throw "Porta referenciada por outra fila; preservada." }
  if ($ports -contains $state.port) { Provision ('remove-port ' + $state.port) }
  if (@(ListProjectPort) -contains $state.port) { throw "Remocao da porta nao comprovada; manifesto preservado." }
  if (Test-Path $StatePath) { [IO.File]::Delete($StatePath) }
  Log "REMOVE somente fila/porta registradas foram removidas; monitor/driver compartilhados preservados"
}
function VerifyInstallation($state) {
  ValidateState $state
  if ($state.stage -ne "complete") { throw "Instalacao incompleta; nao e sucesso." }
  if (-not (MonitorPresent)) { throw "Monitor nao registrado." }
  VerifyDriver $state.driver
  PortOwned $state
  QueueOwned $state (Printer)
  Log ("VERIFIED version=" + $Version + " queue=" + $state.printer + " driver=" + $state.driver + " port=" + $state.port + " physical_cut_enabled=false")
}
function SecureStateDirectory {
  # Only this project's data root; logs remain readable, NOT writable by Users.
  Run (Join-Path $env:windir "System32\icacls.exe") ('"' + $StateDir + '" /setowner *S-1-5-32-544')
  Run (Join-Path $env:windir "System32\icacls.exe") ('"' + $StateDir + '" /inheritance:r /grant:r *S-1-5-18:(OI)(CI)F *S-1-5-32-544:(OI)(CI)F *S-1-5-32-545:(OI)(CI)RX')
}
function SessionPermissions {
  $session = Join-Path $StateDir "session"
  [IO.Directory]::CreateDirectory($session) | Out-Null
  Run (Join-Path $env:windir "System32\icacls.exe") ('"' + $session + '" /grant *S-1-5-32-545:(OI)(CI)M')
}
function Invoke-BridgeSetup($mode) {
  $setupWatch = [Diagnostics.Stopwatch]::StartNew()
  $lock = $null; $current = $null; $createdThisRun = $false; $portCreatedThisRun = $false
  try {
    InitializeLogging
    Stage "ADMIN"
    if (-not (IsAdmin)) { throw "Execute o instalador como administrador (UAC). Nenhuma politica global foi alterada." }
    Stage "OPERATING_SYSTEM"
    $os = OperatingSystem
    if ($os.Version -notmatch "^6\.1\." -or $os.ProductType -ne 1 -or $os.ServicePackMajorVersion -lt 1 -or $os.OSArchitecture -notmatch "64" -or [IntPtr]::Size -ne 8) { throw "Necessario Windows 7 SP1 x64 e PowerShell de 64 bits." }
    Log ("OS=" + $os.Version + " SP=" + $os.ServicePackMajorVersion + " Arch=" + $os.OSArchitecture + " PowerShell=" + $PSVersionTable.PSVersion)
    Stage "LOCK"
    [IO.Directory]::CreateDirectory($StateDir) | Out-Null
    SecureStateDirectory
    $lock = [IO.File]::Open((Join-Path $StateDir "installation.lock"),[IO.FileMode]::OpenOrCreate,[IO.FileAccess]::ReadWrite,[IO.FileShare]::None)
    if (Test-Path (Join-Path $Root "VERSION")) { $script:Version = [IO.File]::ReadAllText((Join-Path $Root "VERSION")).Trim() }
    Log ("START operation=" + $mode + " version=" + $Version + " powershell=" + $PSVersionTable.PSVersion)
    if (@("install","uninstall","verify","capture-test") -notcontains $mode) { throw "Operacao desconhecida." }
    # Uninstall must remain possible without conversion engines/runtimes beyond the helper.
    if ($mode -eq "uninstall") {
      Stage "UNINSTALL"
      $current = ReadState
      if ($current) {
        if (-not (MonitorPresent)) { throw "Monitor ausente; recursos/manifesto preservados para recuperacao." }
        $current = MigrateState $current
        RemoveOwned $current
      } elseif (Printer) { throw "Fila sem manifesto de propriedade; preservada." }
      return 0
    }
    Stage "DEPENDENCIES"
    ValidateDependencies
    if ($mode -eq "verify") { VerifyInstallation (ReadState); return 0 }
    if ($mode -eq "capture-test") {
      Stage "CAPTURE_TEST"
      $state = ReadState; VerifyInstallation $state
      $captures = Join-Path $StateDir "captures"
      $before = @(); if (Test-Path $captures) { $before = @(Get-ChildItem $captures -Filter "job-*.json" | ForEach-Object { $_.FullName }) }
      Provision ('probe-queue "' + $PrinterName + '" ' + $state.port + ' "' + $state.driver + '" ' + $state.owner)
      $deadline = [DateTime]::UtcNow.AddSeconds(60)
      do {
        $new = @(); if (Test-Path $captures) { $new = @(Get-ChildItem $captures -Filter "job-*.json" | Where-Object { $before -notcontains $_.FullName }) }
        if ($new.Count -gt 0) { break }; Start-Sleep -Milliseconds 500
      } while ([DateTime]::UtcNow -lt $deadline)
      if ($new.Count -ne 1) { throw "Captura da sonda ausente ou ambígua; não comprova a cadeia. Consulte receiver-errors.log." }
      $raw = [IO.Path]::ChangeExtension($new[0].FullName,"raw")
      Run (Join-Path $Root "FoisonC24Diagnostic.exe") ('--capture-check "' + $raw + '"')
      Log "PASS fila -> PScript -> RedMon -> Receiver -> vetor 20 mm; serial/corte/CorelDRAW NÃO testados."
      return 0
    }
    $current = ReadState
    if (-not $current -and (Printer)) { throw "Impressora homonima nao pertence comprovadamente ao Bridge; preservada." }
    # Required order: prove monitor registration before enumeration/reservation.
    Stage "REDMON_INSTALL"
    EnsureMonitor
    if ($current) {
      $current = MigrateState $current
      if ($current.stage -eq "complete") { VerifyInstallation $current; return 0 }
      # Incomplete state: delete only if ownership can be proved, otherwise fail closed.
      RemoveOwned $current
      $current = $null
    }
    Stage "PORT_RESERVATION"
    $ports = @(ListProjectPort)
    $selected = $null
    for ($i=1;$i -le 99;$i++) { $candidate="FOISONC24${i}:"; if ($ports -notcontains $candidate) { $selected=$candidate;break } }
    if (-not $selected) { throw "Nenhuma porta exclusiva FOISONC24n: disponivel." }
    $current = @{schema="2";product="Foison C24 Print Bridge";printer=$PrinterName;port=$selected;driver="MS Publisher Imagesetter";owner=[Guid]::NewGuid().ToString("N");receiver=(Join-Path $Root "FoisonC24Receiver.exe");stage="reserved";physical_cut_enabled="false";created_utc=[DateTime]::UtcNow.ToString("o")}
    WriteState $current
    $createdThisRun = $true
    Provision ('add-port ' + $selected)
    $portCreatedThisRun = $true
    $current["stage"]="port-created";WriteState $current
    Stage "PORT_CONFIGURATION"
    Provision ('configure-port ' + $selected + ' "' + $current.receiver + '" ' + $current.owner)
    $current["stage"]="configured";WriteState $current
    Stage "DRIVER"
    $driver = EnsureDriver
    $current["driver"]=$driver;WriteState $current
    Stage "QUEUE_CREATE"
    Provision ('add-queue "' + $PrinterName + '" ' + $selected + ' "' + $driver + '" ' + $current.owner)
    QueueOwned $current (Printer)
    $current["queue_fingerprint"]=QueueFingerprint (Printer)
    $current["stage"]="complete";WriteState $current
    SessionPermissions
    Stage "VERIFY_FINAL"
    VerifyInstallation $current
    Log "Instalação concluída com sucesso. Propriedades da fila e conversão verificadas; captura via impressão ainda requer teste; corte físico bloqueado."
    return 0
  } catch {
    $record = $_; $failure = $_.Exception.Message; $failedStep = $Step; $failureExternalCode = $LastProcessCode
    try { LogException $record; Log ("InstallationState=" + $(if ($current) { $current.stage + " port=" + $current.port } else { "not-loaded" })) "ERROR" } catch { Write-Host ("FATAL: " + $failure + " / Logging=" + $_.Exception.Message) }
    if ($lock -and $createdThisRun -and $current) {
      try { Stage "ROLLBACK"; RemoveOwned $current $portCreatedThisRun } catch { try { LogException $_; Log "ROLLBACK preservou recursos sem prova de propriedade." "ERROR" } catch { Write-Host $_.Exception.Message } }
    }
    try { [IO.File]::WriteAllText((Join-Path $LogDirectory ("install-" + $RunId + "-summary.txt")), "ERROR Stage=" + $failedStep + " ExternalExit=" + $failureExternalCode + " ExitCode=1", [Text.Encoding]::ASCII) } catch { Write-Host $_.Exception.Message }
    Write-Host ("ERRO: " + $failure + "`r`nEtapa: " + $failedStep + "`r`nCódigo de saída externo: " + $failureExternalCode + "`r`nLog: " + $LogPath + "`r`nA instalação não foi concluída.")
    return 1
  } finally {
    if ($lock) { $lock.Dispose() }
    $setupWatch.Stop()
    try { Log ("END operation=" + $mode + " lock_released=true DurationMs=" + $setupWatch.ElapsedMilliseconds) } catch { Write-Host $_.Exception.Message }
  }
}
if ($MyInvocation.InvocationName -ne ".") { exit (Invoke-BridgeSetup $Operation) }
