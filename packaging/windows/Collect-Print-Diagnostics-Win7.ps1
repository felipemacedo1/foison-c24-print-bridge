param([string]$OutputPath = "", [string]$RunId = "")

# Windows PowerShell 2.0 compatible, read-only snapshot. Does not read print
# document contents/titles, change the spooler, or access a serial port.
$snapshotId = [Guid]::NewGuid().ToString("N")
if ([String]::IsNullOrEmpty($RunId)) { $RunId = [Guid]::NewGuid().ToString("N") }
if (-not [Regex]::IsMatch($RunId, "^[A-Za-z0-9_-]{1,64}$")) { throw "RunId must contain only ASCII letters, digits, underscore, or hyphen (max 64)." }
$ErrorActionPreference = "Continue"
$started = [DateTime]::UtcNow
$lines = New-Object System.Collections.ArrayList
function Add-Line([string]$Text) { [void]$script:lines.Add($Text) }
function Add-Section([string]$Name) { Add-Line "[$Name]" }
function Add-Error([string]$Where, [System.Exception]$Exception) {
  Add-Line ("ERROR {0} {1}: {2}" -f $Where, $Exception.GetType().FullName, $Exception.Message)
}
function Get-SafeFileSummary([string]$Folder, [string]$Filter) {
  try {
    if (-not (Test-Path -LiteralPath $Folder)) { Add-Line ("FolderExists=False Path={0}" -f $Folder); return }
    $items = @(Get-ChildItem -LiteralPath $Folder -Filter $Filter -ErrorAction Stop | Where-Object { -not $_.PSIsContainer })
    $total = 0L; foreach ($item in $items) { $total += [Int64]$item.Length }
    Add-Line ("FolderExists=True Count={0} TotalBytes={1}" -f $items.Count, $total)
    if ($items.Count -gt 0) {
      $latest = $items | Sort-Object LastWriteTimeUtc -Descending | Select-Object -First 1
      Add-Line ("LatestBytes={0} LatestWriteUtc={1}" -f $latest.Length, $latest.LastWriteTimeUtc.ToString("o"))
    }
  } catch { Add-Error ("Files " + $Folder) $_.Exception }
}

if ([String]::IsNullOrEmpty($OutputPath)) {
  $base = [Environment]::GetFolderPath([Environment+SpecialFolder]::DesktopDirectory)
  if ([String]::IsNullOrEmpty($base) -or -not (Test-Path -LiteralPath $base)) { $base = [IO.Path]::GetTempPath() }
  $OutputPath = Join-Path $base ("FoisonC24-print-diagnostic-{0}-{1}.txt" -f $RunId, $snapshotId)
}

Add-Line "Foison C24 Print Bridge - diagnóstico somente leitura"
Add-Line ("RunId={0}" -f $RunId)
Add-Line ("SnapshotId={0}" -f $snapshotId)
Add-Line ("StartedUtc={0}" -f $started.ToString("o"))
Add-Line ("PowerShell={0}; CLR={1}; Process64={2}" -f $PSVersionTable.PSVersion, [Environment]::Version, ([IntPtr]::Size -eq 8))
try {
  $os = Get-WmiObject Win32_OperatingSystem -ErrorAction Stop
  Add-Line ("OS={0}; Version={1}; ServicePack={2}; Architecture={3}" -f $os.Caption, $os.Version, $os.CSDVersion, $os.OSArchitecture)
} catch { Add-Error "Win32_OperatingSystem" $_.Exception }

Add-Section "SPOOLER"
try { $svc = Get-Service Spooler -ErrorAction Stop; Add-Line ("Status={0}" -f $svc.Status) } catch { Add-Error "Service" $_.Exception }

Add-Section "BRIDGE_QUEUES"
$bridgeNames = @()
$printers = @()
try {
  $printers = @(Get-WmiObject Win32_Printer -ErrorAction Stop)
  foreach ($printer in $printers) {
    if ($printer.Name -match "(?i)^Foison C24") {
      $bridgeNames += [String]$printer.Name
      Add-Line ("Name={0}; Driver={1}; Port={2}; Processor={3}; DataType={4}; Offline={5}; Status={6}; DetectedError={7}" -f $printer.Name, $printer.DriverName, $printer.PortName, $printer.PrintProcessor, $printer.PrintJobDataType, $printer.WorkOffline, $printer.PrinterStatus, $printer.DetectedErrorState)
    }
  }
  if ($bridgeNames.Count -eq 0) { Add-Line "No Foison C24 queue found by WMI." }
} catch { Add-Error "Win32_Printer" $_.Exception }

Add-Section "ACTIVE_JOBS_NO_DOCUMENT_TITLES"
try {
  $jobs = @(Get-WmiObject Win32_PrintJob -ErrorAction Stop)
  foreach ($job in $jobs) {
    $printerName = [String]$job.Name
    $comma = $printerName.LastIndexOf(",")
    if ($comma -ge 0) { $printerName = $printerName.Substring(0, $comma) }
    if ($bridgeNames -contains $printerName) {
      Add-Line ("Printer={0}; JobId={1}; DataType={2}; Size={3}; Status={4}; TimeSubmitted={5}" -f $printerName, $job.JobId, $job.DataType, $job.Size, $job.Status, $job.TimeSubmitted)
    }
  }
  Add-Line ("WmiJobCount={0}; only Bridge jobs emitted" -f $jobs.Count)
} catch { Add-Error "Win32_PrintJob" $_.Exception }

Add-Section "REDMON_READBACK"
try {
  $monitor = "HKLM:\SYSTEM\CurrentControlSet\Control\Print\Monitors\Redirected Port"
  if (Test-Path -LiteralPath $monitor) { Add-Line "MonitorRegistryPresent=True" } else { Add-Line "MonitorRegistryPresent=False" }
  foreach ($printer in $printers) {
    if ($printer.Name -notmatch "(?i)^Foison C24" -or $printer.PortName -notmatch "(?i)^FOISONC24[1-9][0-9]*:$") { continue }
    $portKey = Join-Path ($monitor + "\Ports") ([String]$printer.PortName)
    if (-not (Test-Path -LiteralPath $portKey)) { Add-Line ("Port={0}; ConfigPresent=False" -f $printer.PortName); continue }
    $cfg = Get-ItemProperty -LiteralPath $portKey -ErrorAction Stop
    $receiver = [String]$cfg.Command
    Add-Line ("Port={0}; ConfigPresent=True; ReceiverExists={1}; Output={2}; RunUser={3}; ShowWindow={4}; Delay={5}; RedMonLogUse={6}; Debug={7}; ArgumentsEmpty={8}" -f $printer.PortName, (Test-Path -LiteralPath $receiver), $cfg.Output, $cfg.RunUser, $cfg.ShowWindow, $cfg.Delay, $cfg.LogFileUse, $cfg.LogFileDebug, [String]::IsNullOrEmpty([String]$cfg.Arguments))
  }
} catch { Add-Error "RedMonRegistry" $_.Exception }

Add-Section "PROCESSES"
try {
  $procs = @(Get-Process -ErrorAction Stop | Where-Object { $_.ProcessName -match "(?i)FoisonC24Receiver|FoisonC24Diagnostic|spoolsv" })
  foreach ($proc in $procs) { Add-Line ("Name={0}; PID={1}; StartTime={2}" -f $proc.ProcessName, $proc.Id, $(try { $proc.StartTime.ToUniversalTime().ToString("o") } catch { "Unavailable" })) }
  Add-Line ("MatchingProcessCount={0}" -f $procs.Count)
} catch { Add-Error "Processes" $_.Exception }

$common = [Environment]::GetFolderPath([Environment+SpecialFolder]::CommonApplicationData)
$data = Join-Path $common "FoisonC24"
Add-Section "CAPTURE_METADATA_ONLY"
Add-Line ("CapturePath={0}" -f (Join-Path $data "captures"))
Get-SafeFileSummary (Join-Path $data "captures") "job-*.raw"
Get-SafeFileSummary (Join-Path $data "captures") "job-*.json"
Get-SafeFileSummary (Join-Path $data "captures") "receiver-errors.log"
Add-Section "SPOOL_FILE_METADATA_ONLY"
Get-SafeFileSummary (Join-Path $env:windir "System32\spool\PRINTERS") "*.SPL"
Get-SafeFileSummary (Join-Path $env:windir "System32\spool\PRINTERS") "*.SHD"

Add-Section "PRINTSERVICE_CHANNEL"
try {
  $channel = [Microsoft.Win32.Registry]::LocalMachine.OpenSubKey("SOFTWARE\Microsoft\Windows\CurrentVersion\WINEVT\Channels\Microsoft-Windows-PrintService/Operational", $false)
  if ($null -eq $channel) { Add-Line "ChannelRegistryPresent=False; use wevtutil el to confirm channel availability." }
  else {
    try { Add-Line ("ChannelRegistryPresent=True; Enabled={0}" -f $channel.GetValue("Enabled", "<missing>")) }
    finally { $channel.Close() }
  }
} catch { Add-Error "wevtutil" $_.Exception }

Add-Line "No settings changed; no job content read; no COM opened; no movement sent."
Add-Line ("FinishedUtc={0}" -f [DateTime]::UtcNow.ToString("o"))
try {
  $encoding = New-Object System.Text.UTF8Encoding($true)
  [IO.File]::WriteAllLines($OutputPath, [String[]]$lines.ToArray(), $encoding)
  Write-Output ("Relatório salvo em: {0}" -f $OutputPath)
} catch {
  Write-Error ("Não foi possível salvar o relatório em {0}: {1}" -f $OutputPath, $_.Exception.Message)
  exit 2
}
