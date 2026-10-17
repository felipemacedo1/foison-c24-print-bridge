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
  $detail = "Exception=" + $e.GetType().FullName + " Message=" + $e.Message + " File=" + $where.ScriptName + " Line=" + $where.ScriptLineNumber + " Command=" + $where.MyCommand + " ExitCode=" + $(if ($null -eq $LastProcessCode) { "UNKNOWN" } else { $LastProcessCode })
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
function InitializeProcessRunner {
  if ('FoisonBridge.LegacyProcess' -as [type]) { return }
  # C# 2 / CLR 2 API surface: no Task, async, CopyTo, or PowerShell callbacks.
  # Reader threads preserve bytes. On Windows PeekNamedPipe avoids a blocked read
  # when a descendant inherits a pipe after the direct child has exited.
  Add-Type -TypeDefinition @'
using System;
using System.IO;
using System.Diagnostics;
using System.Threading;
using System.ComponentModel;
using System.Runtime.InteropServices;
namespace FoisonBridge {
 public sealed class ProcessResult {
  public bool Started, TimedOut, CaptureComplete;
  public int ProcessId, NativeErrorCode;
  public int? ExitCode;
  public string Error = "", KillError = "";
 }
 public static class LegacyProcess {
  sealed class Pump {
   internal readonly Stream Source;
   internal readonly FileStream Target;
   internal readonly Thread Worker;
   internal volatile bool Stop;
   internal string Error = "";
   internal bool Eof;
   internal bool Running;
   readonly bool windows;
   IntPtr handle;
   [DllImport("kernel32.dll", SetLastError=true)]
   static extern bool PeekNamedPipe(IntPtr pipe, IntPtr buffer, uint size,
       IntPtr read, out uint available, IntPtr left);
   internal Pump(Stream source, FileStream target) {
    Source=source; Target=target;
    windows=Environment.OSVersion.Platform==PlatformID.Win32NT;
    if (windows) {
     // .NET 2 uses FileStream; newer runtimes use AnonymousPipeClientStream.
     System.Reflection.PropertyInfo property=source.GetType().GetProperty("SafeFileHandle");
     if (property==null) property=source.GetType().GetProperty("SafePipeHandle");
     if (property==null) throw new IOException("Pipe handle unavailable; capture refused.");
     SafeHandle safe=(SafeHandle)property.GetValue(source,null);
     handle=safe.DangerousGetHandle(); // Source stays alive until Worker joins.
    }
    Worker=new Thread(new ThreadStart(Copy)); Worker.IsBackground=true;
   }
   void Copy() {
    try {
     byte[] buffer=new byte[16384];
     while (!Stop) {
      int wanted=buffer.Length;
      if (windows) {
       uint available;
       if (!PeekNamedPipe(handle,IntPtr.Zero,0,IntPtr.Zero,out available,IntPtr.Zero)) {
        int code=Marshal.GetLastWin32Error();
        if (code==109 || code==233) { Eof=true; break; }
        throw new Win32Exception(code,"PeekNamedPipe");
       }
       if (available==0) { Thread.Sleep(10); continue; }
       wanted=(int)Math.Min((uint)buffer.Length,available);
      }
      int count=Source.Read(buffer,0,wanted);
      if (count==0) { Eof=true; break; }
      Target.Write(buffer,0,count);
     }
    } catch(Exception e) { Error=e.ToString(); }
    finally { try { Target.Dispose(); } catch(Exception e) { Error+=" Close: "+e.ToString(); } }
   }
   internal void Start() { Worker.Start(); Running=true; }
   internal bool Join(int milliseconds) { if(!Running) { try { Target.Dispose(); } catch(Exception e) { Error+=" Close: "+e.ToString(); } return true; } return Worker.Join(milliseconds); }
  }
  public static ProcessResult Run(string file,string arguments,string stdout,string stderr,int timeout) {
   if(timeout<1) throw new ArgumentOutOfRangeException("timeout");
   ProcessResult result=new ProcessResult();
   Process process=new Process(); Pump output=null, error=null;
   FileStream outFile=null, errFile=null;
   bool exited=false;
   try {
    // Open both evidence files BEFORE starting. No process runs if capture cannot start.
    outFile=new FileStream(stdout,FileMode.CreateNew,FileAccess.Write,FileShare.Read);
    errFile=new FileStream(stderr,FileMode.CreateNew,FileAccess.Write,FileShare.Read);
    ProcessStartInfo info=new ProcessStartInfo();
    info.FileName=file; info.Arguments=arguments;
    info.UseShellExecute=false; info.CreateNoWindow=true;
    info.RedirectStandardOutput=true; info.RedirectStandardError=true;
    // No credentials/Verb: inherit the already validated elevated token.
    process.StartInfo=info;
    if(!process.Start()) throw new IOException("Process.Start returned false.");
    result.Started=true; result.ProcessId=process.Id;
    output=new Pump(process.StandardOutput.BaseStream,outFile); outFile=null; output.Start();
    error=new Pump(process.StandardError.BaseStream,errFile); errFile=null; error.Start();
    exited=process.WaitForExit(timeout);
    if(!exited) { result.TimedOut=true; result.Error="Timeout; no automatic retry."; }
    else { result.ExitCode=process.ExitCode; }
   } catch(Exception e) {
    result.Error=e.ToString();
    Win32Exception native=e as Win32Exception;
    if(native!=null) result.NativeErrorCode=native.NativeErrorCode;
   } finally {
    if(result.Started && !exited) {
     try { if(!process.HasExited) process.Kill(); exited=process.WaitForExit(5000); }
     catch(Exception e) { result.KillError=e.ToString(); }
     if(!exited) result.KillError+=" Direct child termination unconfirmed.";
    }
    // Bounded drain, shared deadline; never parameterless WaitForExit/ReadToEnd.
    Stopwatch drain=Stopwatch.StartNew();
    bool outDone=output==null || output.Join(2000);
    int remaining=Math.Max(0,2000-(int)drain.ElapsedMilliseconds);
    bool errDone=error==null || error.Join(remaining);
    if(output!=null) output.Stop=true;
    if(error!=null) error.Stop=true;
    if(!outDone && output!=null) outDone=output.Join(500);
    if(!errDone && error!=null) errDone=error.Join(500);
    result.CaptureComplete=output!=null && error!=null && outDone && errDone &&
        output.Eof && error.Eof && output.Error.Length==0 && error.Error.Length==0;
    if(output!=null && output.Error.Length>0) result.Error+=" Stdout: "+output.Error;
    if(error!=null && error.Error.Length>0) result.Error+=" Stderr: "+error.Error;
    if(!result.CaptureComplete && result.Started) result.Error+=" Capture incomplete; raw evidence retained.";
    if(outFile!=null) outFile.Dispose();
    if(errFile!=null) errFile.Dispose();
    // Windows pumps never wait on an empty pipe; owned handles close after join.
    // A non-Windows inherited-pipe fixture may leave a background reader until EOF.
    if(outDone && errDone) process.Dispose();
   }
   return result;
  }
 }
}
'@
}
function InvokeProcessAdapter($file,$arguments,$stdout,$stderr,$timeoutMs) {
  InitializeProcessRunner
  return [FoisonBridge.LegacyProcess]::Run($file,$arguments,$stdout,$stderr,$timeoutMs)
}
function ProcessRun($file, $arguments, $timeoutMs = 120000) {
  $script:LastProcessCode = $null
  $watch = [Diagnostics.Stopwatch]::StartNew()
  $code = $null; $result = $null; $failure = $null
  $component = [IO.Path]::GetFileNameWithoutExtension($file).ToLowerInvariant()
  $id = [Guid]::NewGuid().ToString("N")
  $prefix = Join-Path $LogDirectory ("install-" + $RunId + "-" + $component + "-" + $id)
  $stdout = $prefix + ".out.raw"; $stderr = $prefix + ".err.raw"
  $componentLog = Join-Path $LogDirectory ("install-" + $RunId + "-" + $component + ".log")
  $command = 'exe="' + $file + '" args=' + $arguments
  try {
    Log ("PROCESS " + $command) "INFO" $component
    $result = InvokeProcessAdapter $file $arguments $stdout $stderr $timeoutMs
    # Unknown is never zero. Preserve a real non-timeout code even if capture fails.
    if ($null -ne $result.ExitCode -and -not $result.TimedOut) {
      $code = [int]$result.ExitCode; $script:LastProcessCode = $code
    }
    if ($result.Error -or $result.KillError -or -not $result.CaptureComplete -or $null -eq $code) {
      throw ("Não foi possível executar o processo. Started=" + $result.Started + " PID=" + $result.ProcessId + " Timeout=" + $result.TimedOut + " NativeErrorCode=" + $result.NativeErrorCode + " Error=" + $result.Error + " KillError=" + $result.KillError)
    }
    return $code
  } catch { $failure = $_; throw } finally {
    $watch.Stop()
    $exitText = "UNKNOWN"; if ($null -ne $code) { $exitText = [string]$code }
    $details = "Started=UNKNOWN Timeout=False CaptureComplete=False"
    if ($result) { $details = "Started=" + $result.Started + " PID=" + $result.ProcessId + " Timeout=" + $result.TimedOut + " CaptureComplete=" + $result.CaptureComplete + " NativeErrorCode=" + $result.NativeErrorCode + " Error=" + $result.Error + " KillError=" + $result.KillError }
    $summary = [DateTime]::UtcNow.ToString("o") + " [" + $RunId + "] [" + $Step + "] " + $command + " ExitCode=" + $exitText + " " + $details + " DurationMs=" + $watch.ElapsedMilliseconds + " StdoutRaw=" + $stdout + " StderrRaw=" + $stderr
    if ($failure) { $summary += " Exception=" + $failure.Exception.ToString() }
    # Diagnostic failure must not replace the original launch/timeout exception.
    try {
      [IO.File]::AppendAllText($componentLog, $summary + "`r`n", $Utf8)
      foreach ($path in @($stdout,$stderr)) {
        if (Test-Path $path) {
          $stream = [IO.File]::Open($path,[IO.FileMode]::Open,[IO.FileAccess]::Read,[IO.FileShare]::ReadWrite)
          try {
            $bytes = New-Object byte[] 16384
            $count = $stream.Read($bytes,0,$bytes.Length)
            $strictUtf8 = New-Object Text.UTF8Encoding($false,$true)
            $encodingName = "UTF-8 (validated excerpt; raw authoritative)"
            try { $content = $strictUtf8.GetString($bytes,0,$count) } catch {
              $encoding = [Text.Encoding]::GetEncoding([Globalization.CultureInfo]::CurrentCulture.TextInfo.OEMCodePage)
              $encodingName = "OEM heuristic " + $encoding.CodePage + " (raw authoritative)"
              $content = $encoding.GetString($bytes,0,$count)
            }
            $content = $content.Replace([string][char]0xfffd,"?")
            [IO.File]::AppendAllText($componentLog, "RawFile=" + $path + " ExcerptEncoding=" + $encodingName + " Excerpt=" + $content + "`r`n", $Utf8)
          } finally { $stream.Dispose() }
        }
      }
      $level = "INFO"; if ($failure -or ($null -ne $code -and $code -ne 0)) { $level = "ERROR" }
      Log $summary $level $component
    } catch {
      Write-Host ("FATAL: Falha ao registrar processo: " + $_.Exception.Message + "; " + $summary)
      if (-not $failure) { throw }
    }
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
    Log ("ElevatedTokenAdmin=true PID=" + $PID + " CLR=" + [Environment]::Version + " ProcessBits=" + ([IntPtr]::Size*8))
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
    $record = $_; $failure = $_.Exception.Message; $failedStep = $Step; $failureExternalCode = $LastProcessCode; if ($null -eq $failureExternalCode) { $failureExternalCode = "UNKNOWN" }
    try { LogException $record; Log ("InstallationState=" + $(if ($current) { $current.stage + " port=" + $current.port } else { "not-loaded" })) "ERROR" } catch { Write-Host ("FATAL: " + $failure + " / Logging=" + $_.Exception.Message) }
    if ($lock -and $createdThisRun -and $current) {
      try { Stage "ROLLBACK"; RemoveOwned $current $portCreatedThisRun } catch { try { LogException $_; Log "ROLLBACK preservou recursos sem prova de propriedade." "ERROR" } catch { Write-Host $_.Exception.Message } }
    }
    try { [IO.File]::WriteAllText((Join-Path $LogDirectory ("install-" + $RunId + "-summary.txt")), "ERROR Stage=" + $failedStep + " ExternalExit=" + $failureExternalCode + " ExitCode=1", [Text.Encoding]::ASCII) } catch { Write-Host $_.Exception.Message }
    Write-Host ("ERRO: " + $failure + "`r`nEtapa: " + $failedStep + "`r`nCódigo de saída externo: " + $failureExternalCode + "`r`nLog: " + $LogPath + "`r`nA instalação não foi concluída.")
    return 1
  } finally {
    $lockState = "not-acquired"
    if ($lock) { $lock.Dispose(); $lockState = "released" }
    $setupWatch.Stop()
    try { Log ("END operation=" + $mode + " lock_state=" + $lockState + " DurationMs=" + $setupWatch.ElapsedMilliseconds) } catch { Write-Host $_.Exception.Message }
  }
}
if ($MyInvocation.InvocationName -ne ".") { exit (Invoke-BridgeSetup $Operation) }
