using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Drawing;
using System.IO;
using System.IO.Compression;
using System.Linq;
using System.Management;
using System.Security.Principal;
using System.Text;
using System.Threading;
using System.Threading.Tasks;
using System.Windows.Forms;
using Microsoft.Win32;

namespace FoisonC24.Diagnostic
{
    // Operator-guided, read-only spooler observation. This class never opens a serial port.
    internal sealed class GuidedDiagnosticForm : Form
    {
        private readonly string data = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.CommonApplicationData), "FoisonC24");
        private readonly string runId = DateTime.UtcNow.ToString("yyyyMMddTHHmmssZ") + "-" + Guid.NewGuid().ToString("N");
        private readonly DateTime diagnosticStarted = DateTime.UtcNow;
        private string logPath;
        private readonly TextBox transcript = new TextBox { Dock = DockStyle.Fill, Multiline = true, ReadOnly = true, ScrollBars = ScrollBars.Vertical };
        private readonly FlowLayoutPanel actions = new FlowLayoutPanel { Dock = DockStyle.Top, Height = 88, AutoScroll = true };
        private readonly System.Windows.Forms.Timer poll = new System.Windows.Forms.Timer { Interval = 1000 };
        private ManagementEventWatcher starts, stops;
        private bool monitoring, pollBusy;
        private DateTime monitorStarted;
        private bool monitorExecuted;
        private int receiverStarted, receiverStopped, bytesObserved, persisted;
        private int rejectionMetadata;
        private string spoolerState = "UNKNOWN", queueState = "UNKNOWN", redmonState = "UNKNOWN";
        private string uiConfirmation = "UNKNOWN";
        private string parserConfirmation = "UNKNOWN";
        private string initialPrinterSnapshot = "Not collected";
        private string finalPrinterSnapshot = "Not collected";
        private readonly object logSync = new object();
        private readonly Dictionary<string, string> lastState = new Dictionary<string, string>(StringComparer.Ordinal);
        private readonly object stateLock = new object();

        internal GuidedDiagnosticForm()
        {
            Text = "Foison C24 — diagnóstico guiado da impressão";
            Width = 900; Height = 640; MinimumSize = new Size(760, 500);
            logPath = InitializeLogPath();
            monitorStarted = diagnosticStarted; // exclude older receiver logs from this run's snapshot.
            var intro = new Label { Dock = DockStyle.Top, Height = 76, Padding = new Padding(10),
                Text = "Este diagnóstico não envia comandos à plotter e não abre COM2. Faça primeiro o teste binário direto; depois inicie o monitoramento e imprima somente o quadrado sintético de 20 × 20 mm no CorelDRAW." };
            Controls.Add(transcript); Controls.Add(actions); Controls.Add(intro);
            AddButton("Experimento A — Receiver direto", RunDirectExperiment);
            AddButton("Abrir painel para conferir a lista", OpenApplication);
            AddButton("Iniciar monitoramento da impressão", StartMonitoring);
            AddButton("Concluir/Cancelar monitoramento", FinishMonitoring);
            AddButton("Exportar ZIP de diagnóstico", ExportReport);
            poll.Tick += async (s, e) => await PollAsync();
            FormClosing += (s, e) => { StopWatching(); };
            Write("INFO", "START", "RunId=" + runId + "; PID=" + Process.GetCurrentProcess().Id + "; OS=" + Environment.OSVersion + "; 64-bit=" + Environment.Is64BitProcess);
            Write("INFO", "SAFETY", "Nenhuma fila, driver, FTDI, COM2, FlexiSIGN ou máquina foi alterada; corte físico desabilitado.");
            AddLine("RunId: " + runId + "\r\nLog local: " + logPath);
            Shown += async (s, e) =>
            {
                await Task.Run((Action)ValidateEnvironment);
                await Task.Run((Action)PollState);
                initialPrinterSnapshot = await Task.Run(() => CaptureDiagnostics.Collect(data));
                Write("INFO", "INITIAL_SNAPSHOT", "estado inicial da fila/Spooler/RedMon capturado; nenhum conteúdo de impressão lido");
            };
        }

        private void AddButton(string label, Action action)
        {
            var button = new Button { Text = label, AutoSize = true, Height = 36, Margin = new Padding(6) };
            button.Click += (s, e) => { try { action(); } catch (Exception error) { WriteError("UI_ACTION", error); MessageBox.Show(this, error.Message, Text, MessageBoxButtons.OK, MessageBoxIcon.Error); } };
            actions.Controls.Add(button);
        }

        private void AddLine(string message)
        {
            if (IsDisposed) return;
            if (InvokeRequired) { BeginInvoke((Action)(() => AddLine(message))); return; }
            transcript.AppendText(DateTime.Now.ToString("HH:mm:ss") + " " + message + Environment.NewLine);
        }

        private void Write(string level, string stage, string message)
        {
            try
            {
                Directory.CreateDirectory(Path.GetDirectoryName(logPath));
                lock (logSync) File.AppendAllText(logPath, DateTime.UtcNow.ToString("o") + " [" + level + "] [" + runId + "] [guided-diagnostic] [" + stage + "] " +
                    (message ?? "").Replace("\r", " ").Replace("\n", " ") + Environment.NewLine, new UTF8Encoding(false));
            }
            catch { }
            AddLine("[" + level + "] " + stage + " — " + message);
        }

        private string InitializeLogPath()
        {
            string[] roots = { Path.Combine(data, "Logs"), Path.Combine(Path.GetTempPath(), "FoisonC24", "Logs") };
            foreach (string root in roots)
            {
                try
                {
                    Directory.CreateDirectory(root);
                    string probe = Path.Combine(root, ".write-probe-" + Guid.NewGuid().ToString("N"));
                    using (FileStream stream = new FileStream(probe, FileMode.CreateNew, FileAccess.Write, FileShare.None)) { stream.WriteByte(0); }
                    File.Delete(probe);
                    return Path.Combine(root, "diagnostic-" + runId + ".log");
                }
                catch { }
            }
            return Path.Combine(Path.GetTempPath(), "FoisonC24-diagnostic-" + runId + ".log");
        }

        private void WriteError(string stage, Exception error)
        {
            Write("ERROR", stage, error.GetType().FullName + ": " + error.Message + "; " + error.StackTrace);
        }

        private void ValidateEnvironment()
        {
            Write("INFO", "ENVIRONMENT", "identity=" + CurrentIdentity() + "; OS=" + Environment.OSVersion + "; OS64=" + Environment.Is64BitOperatingSystem +
                "; process64=" + Environment.Is64BitProcess + "; CLR=" + Environment.Version);
            try
            {
                using (var search = new ManagementObjectSearcher("SELECT Caption, Version, CSDVersion, OSArchitecture FROM Win32_OperatingSystem"))
                using (var rows = search.Get())
                    foreach (ManagementObject row in rows)
                    using (row) Write("INFO", "OS_WMI", "caption=" + row["Caption"] + "; version=" + row["Version"] + "; service_pack=" + row["CSDVersion"] + "; architecture=" + row["OSArchitecture"]);
            }
            catch (Exception error) { WriteError("OS_WMI", error); }
            foreach (string path in new[]{Path.Combine(Program.Home,"FoisonC24Diagnostic.exe"),Path.Combine(Program.Home,"FoisonC24Receiver.exe"),Path.Combine(Program.Home,"FoisonC24.Core.dll"),Path.Combine(Program.Home,"testes","square-20mm.ps")})
                Write(File.Exists(path) ? "INFO" : "ERROR", "REQUIRED_FILE", Path.GetFileName(path) + "=" + (File.Exists(path) ? "present" : "missing"));
            foreach (string folder in new[]{Path.Combine(data,"captures"),Path.Combine(data,"Logs")})
            {
                string result="writable";
                try { Directory.CreateDirectory(folder); string probe=Path.Combine(folder,".write-probe-"+Guid.NewGuid().ToString("N")); using(FileStream stream=new FileStream(probe,FileMode.CreateNew,FileAccess.Write,FileShare.None))stream.WriteByte(0); File.Delete(probe); }
                catch(Exception error) { result="unavailable: "+error.GetType().Name+": "+error.Message; WriteError("DIRECTORY_PERMISSION",error); }
                Write(result=="writable"?"INFO":"ERROR","DIRECTORY",folder+"; "+result);
            }
        }

        private void RunDirectExperiment()
        {
            if (monitoring) { MessageBox.Show(this, "Conclua o monitoramento atual antes do experimento A."); return; }
            string receiver = Path.Combine(Program.Home, "FoisonC24Receiver.exe");
            string fixture = Path.Combine(Program.Home, "testes", "square-20mm.ps");
            string captures = Path.Combine(data, "captures");
            if (!File.Exists(receiver) || !File.Exists(fixture)) throw new FileNotFoundException("Receiver ou fixture sintética não encontrado.");
            byte[] expected = File.ReadAllBytes(fixture);
            string expectedHash = Hash(expected);
            string run = runId + "-A";
            var start = new ProcessStartInfo(receiver, "--output-dir " + Quote(captures)) { UseShellExecute = false, RedirectStandardInput = true, CreateNoWindow = true };
            start.EnvironmentVariables["FOISON_RUN_ID"] = run;
            Write("INFO", "A_RECEIVER_START", "receiver=" + receiver + "; fixture=square-20mm.ps; expected_bytes=" + expected.Length + "; sha256=" + expectedHash);
            using (Process child = Process.Start(start))
            {
                if (child == null) throw new InvalidOperationException("Receiver não iniciou.");
                child.StandardInput.BaseStream.Write(expected, 0, expected.Length); // binary-exact; no CMD/text conversion
                child.StandardInput.BaseStream.Flush();
                child.StandardInput.Close();
                if (!child.WaitForExit(15000)) { try { child.Kill(); } catch { } throw new TimeoutException("Receiver direto excedeu 15 segundos."); }
                if (child.ExitCode != 0) throw new InvalidOperationException("Receiver retornou ExitCode=" + child.ExitCode);
            }
            string raw = Directory.GetFiles(captures, "job-*.json").Where(f => File.ReadAllText(f, Encoding.UTF8).Contains("\"run_id\": \"" + run + "\""))
                .Select(f => Path.Combine(captures, Path.GetFileNameWithoutExtension(f) + ".raw")).FirstOrDefault(File.Exists);
            if (raw == null || HashFile(raw) != expectedHash) throw new InvalidDataException("Bytes persistidos não correspondem à fixture binária.");
            string metadata = Path.ChangeExtension(raw, ".json");
            if (!File.Exists(metadata)) throw new InvalidDataException("Metadados do trabalho não foram publicados.");
            string scratch = Path.Combine(Path.GetTempPath(), "FoisonC24-diag-" + Guid.NewGuid().ToString("N"));
            try
            {
                var drawing = Program.Converter().Convert(raw, scratch, CancellationToken.None);
                if (Math.Abs(drawing.Width - 20) > 0.05 || Math.Abs(drawing.Height - 20) > 0.05)
                    throw new InvalidDataException("Parser converteu escala inesperada: " + drawing.SizeLabel);
                Write("INFO", "A_PASS", "bytes exatos; formato PostScript; parser PASS; escala=" + drawing.SizeLabel + "; persistência PASS; raw omitido do relatório.");
            }
            catch (Exception error) { WriteError("A_PARSER", error); throw; }
            finally { try { if (Directory.Exists(scratch)) Directory.Delete(scratch, true); } catch { } }
            MessageBox.Show(this, "Experimento A passou: Receiver, bytes, parser e persistência verificados.\r\nAgora abra o painel e confirme visualmente se o trabalho sintético aparece na lista.", Text, MessageBoxButtons.OK, MessageBoxIcon.Information);
            var answer = MessageBox.Show(this, "O trabalho 'square-20mm' aparece na lista do painel Foison C24?", Text, MessageBoxButtons.YesNoCancel, MessageBoxIcon.Question);
            uiConfirmation = answer == DialogResult.Yes ? "PASS" : answer == DialogResult.No ? "FAIL" : "UNKNOWN";
            Write("INFO", "A_UI_CONFIRMATION", "operador=" + uiConfirmation);
        }

        private void OpenApplication()
        {
            string exe = Path.Combine(Program.Home, "FoisonC24Diagnostic.exe");
            var start = new ProcessStartInfo(exe) { UseShellExecute = false };
            start.EnvironmentVariables["FOISON_RUN_ID"] = runId;
            Process.Start(start);
            Write("INFO", "OPEN_UI", "Aplicação aberta para conferência manual; o resultado é confirmado pelo operador.");
        }

        private void StartMonitoring()
        {
            if (monitoring) return;
            monitorStarted = DateTime.UtcNow;
            monitorExecuted = true;
            receiverStarted = receiverStopped = bytesObserved = persisted = rejectionMetadata = 0;
            Write("INFO", "B_MONITOR_START", "Monitoramento ativo; peça ao operador imprimir apenas o quadrado sintético no CorelDRAW. Nenhum comando serial será enviado.");
            try
            {
                starts = new ManagementEventWatcher(new WqlEventQuery("SELECT * FROM Win32_ProcessStartTrace"));
                starts.EventArrived += OnProcessStart; starts.Start();
                stops = new ManagementEventWatcher(new WqlEventQuery("SELECT * FROM Win32_ProcessStopTrace"));
                stops.EventArrived += OnProcessStop; stops.Start();
                Write("INFO", "WMI_PROCESS_WATCH", "Win32_ProcessStartTrace/StopTrace ativos.");
            }
            catch (Exception error) { WriteError("WMI_PROCESS_WATCH", error); StopWatchers(); }
            monitoring = true;
            poll.Start();
            MessageBox.Show(this, "Monitoramento ligado. Agora, no CorelDRAW, imprima uma vez o arquivo sintético quadrado de 20 × 20 mm na fila Foison C24 (Teste).\r\n\r\nVolte a esta janela e clique 'Concluir/Cancelar monitoramento'.", Text, MessageBoxButtons.OK, MessageBoxIcon.Information);
        }

        private void OnProcessStart(object sender, EventArrivedEventArgs e)
        {
            try
            {
                string name = Convert.ToString(e.NewEvent["ProcessName"]);
                if (!String.Equals(name, "FoisonC24Receiver.exe", StringComparison.OrdinalIgnoreCase)) return;
                Interlocked.Increment(ref receiverStarted);
                Write("INFO", "RECEIVER_PROCESS_START", "PID=" + e.NewEvent["ProcessID"] + "; parentPID=" + e.NewEvent["ParentProcessID"] + "; nome=" + name);
            }
            catch (Exception error) { WriteError("RECEIVER_PROCESS_START_EVENT", error); }
        }

        private void OnProcessStop(object sender, EventArrivedEventArgs e)
        {
            try
            {
                string name = Convert.ToString(e.NewEvent["ProcessName"]);
                if (!String.Equals(name, "FoisonC24Receiver.exe", StringComparison.OrdinalIgnoreCase)) return;
                Interlocked.Increment(ref receiverStopped);
                Write("INFO", "RECEIVER_PROCESS_STOP", "PID=" + e.NewEvent["ProcessID"] + "; ExitStatus=" + e.NewEvent["ExitStatus"]);
            }
            catch (Exception error) { WriteError("RECEIVER_PROCESS_STOP_EVENT", error); }
        }

        private async Task PollAsync()
        {
            if (!monitoring || pollBusy) return;
            pollBusy = true;
            try { await Task.Run((Action)PollState); }
            catch (Exception error) { WriteError("POLL", error); }
            finally { pollBusy = false; }
        }

        private void PollState()
        {
            try
            {
                using (var service = new System.ServiceProcess.ServiceController("Spooler"))
                {
                    spoolerState = service.Status == System.ServiceProcess.ServiceControllerStatus.Running ? "PASS" : "FAIL";
                    WriteIfChanged("SPOOLER_STATE", "status=" + service.Status);
                }
            }
            catch (Exception error) { spoolerState = "UNKNOWN"; WriteOnce("SPOOLER_UNKNOWN", error.GetType().Name + ": " + error.Message); }
            try
            {
                using (var search = new ManagementObjectSearcher("SELECT Name, DriverName, PortName, PrintProcessor FROM Win32_Printer WHERE Name='Foison C24 (Teste)'"))
                using (var rows = search.Get())
                {
                    bool found = false;
                    foreach (ManagementObject row in rows)
                    using (row)
                    {
                        found = true;
                        string port = Convert.ToString(row["PortName"]);
                        queueState = "PASS";
                        WriteIfChanged("QUEUE_STATE", "presente; driver=" + row["DriverName"] + "; port=" + port + "; processor=" + row["PrintProcessor"]);
                        using (RegistryKey key = Registry.LocalMachine.OpenSubKey(@"SYSTEM\CurrentControlSet\Control\Print\Monitors\Redirected Port\Ports\" + port, false))
                        {
                            if (key == null) redmonState = "FAIL";
                            else
                            {
                                string command = Convert.ToString(key.GetValue("Command", ""));
                                int output = -1; try { output = Convert.ToInt32(key.GetValue("Output", -1)); } catch { }
                                bool receiverExists = File.Exists(command);
                                redmonState = receiverExists && output == 0 ? "PASS" : "FAIL";
                                WriteIfChanged("REDMON_STATE", "porta registrada; Output=" + output + "; ReceiverExists=" + receiverExists + "; ArgumentsEmpty=" + String.IsNullOrEmpty(Convert.ToString(key.GetValue("Arguments", ""))));
                            }
                        }
                    }
                    if (!found) { queueState = "FAIL"; WriteIfChanged("QUEUE_STATE", "fila Foison C24 (Teste) ausente"); }
                }
            }
            catch (Exception error) { queueState = redmonState = "UNKNOWN"; WriteOnce("QUEUE_UNKNOWN", error.GetType().Name + ": " + error.Message); }
            try
            {
                using (var search = new ManagementObjectSearcher("SELECT Name, JobId, DataType, Size, Status FROM Win32_PrintJob"))
                using (var rows = search.Get())
                    foreach (ManagementObject row in rows)
                    using (row)
                    {
                        string name = Convert.ToString(row["Name"]);
                        if (name.IndexOf("Foison C24", StringComparison.OrdinalIgnoreCase) >= 0)
                            WriteOnce("PRINT_JOB_" + row["JobId"], "printer=" + name.Split(',')[0] + "; job_id=" + row["JobId"] + "; datatype=" + row["DataType"] + "; size=" + row["Size"] + "; status=" + row["Status"]);
                    }
            }
            catch (Exception error) { WriteOnce("PRINT_JOBS_UNKNOWN", error.GetType().Name + ": " + error.Message); }
            try
            {
                string captures = Path.Combine(data, "captures");
                if (Directory.Exists(captures))
                {
                    foreach (string file in Directory.GetFiles(captures, "job-*.json"))
                        if (File.GetLastWriteTimeUtc(file) >= monitorStarted) { Interlocked.Exchange(ref persisted, 1); WriteOnce("CAPTURE_METADATA", "novo marcador JSON detectado: " + Path.GetFileName(file)); }
                    string attempts = Path.Combine(captures, "attempts");
                    if (Directory.Exists(attempts))
                        foreach (string file in Directory.GetFiles(attempts, "attempt-*.json"))
                            if (File.GetLastWriteTimeUtc(file) >= monitorStarted) { Interlocked.Exchange(ref rejectionMetadata, 1); WriteOnce("REJECTED_METADATA", "metadados da tentativa rejeitada preservados: " + Path.GetFileName(file)); }
                }
                string[] logFolders = { Path.Combine(data, "Logs"), Path.Combine(captures, "diagnostics"), Path.Combine(Path.GetTempPath(), "FoisonC24", "Logs") };
                foreach (string logs in logFolders)
                if (Directory.Exists(logs))
                    foreach (string file in Directory.GetFiles(logs, "receiver-*.log"))
                    {
                        var info = new FileInfo(file);
                        if (info.LastWriteTimeUtc < monitorStarted) continue;
                        string content = File.ReadAllText(file, Encoding.UTF8);
                        foreach (string line in content.Split(new[]{"\r\n","\n"}, StringSplitOptions.RemoveEmptyEntries))
                        {
                            if (line.IndexOf("[START]", StringComparison.Ordinal) >= 0 && WriteOnce("RECEIVER_LOG_START_" + Path.GetFileName(file), line)) Interlocked.Increment(ref receiverStarted);
                            else if (line.IndexOf("STDIN_EOF", StringComparison.Ordinal) >= 0)
                            {
                                string marker = "total_bytes=";
                                int at = line.IndexOf(marker, StringComparison.Ordinal);
                                long value;
                                if (at >= 0 && Int64.TryParse(line.Substring(at + marker.Length).Split(';')[0].Trim(), out value) && value > 0)
                                    Interlocked.Exchange(ref bytesObserved, 1);
                                WriteOnce("RECEIVER_EOF_" + Path.GetFileName(file), line);
                            }
                            else if (line.IndexOf("QUEUE_REGISTERED", StringComparison.Ordinal) >= 0)
                            { Interlocked.Exchange(ref persisted, 1); WriteOnce("RECEIVER_QUEUE_" + Path.GetFileName(file), line); }
                            else if (line.IndexOf("ERROR", StringComparison.Ordinal) >= 0) WriteOnce("RECEIVER_ERROR_" + Path.GetFileName(file) + line.GetHashCode(), line);
                        }
                    }
            }
            catch (Exception error) { WriteOnce("CAPTURE_WATCH_UNKNOWN", error.GetType().Name + ": " + error.Message); }
        }

        private readonly HashSet<string> once = new HashSet<string>();
        private readonly object onceLock = new object();
        private bool WriteOnce(string key, string value)
        {
            lock (onceLock) { if (!once.Add(key)) return false; }
            Write("INFO", key, value);return true;
        }

        private void WriteIfChanged(string key, string value)
        {
            lock (stateLock)
            {
                string previous;
                if (lastState.TryGetValue(key, out previous) && String.Equals(previous, value, StringComparison.Ordinal)) return;
                lastState[key] = value;
            }
            Write("INFO", key, value);
        }

        private void FinishMonitoring()
        {
            if (!monitoring) { Write("INFO", "MONITOR_CANCELLED", "nenhum período de impressão ativo"); return; }
            poll.Stop();
            PollState();
            monitoring = false;
            StopWatchers();
            try { finalPrinterSnapshot = CaptureDiagnostics.Collect(data); }
            catch (Exception error) { WriteError("FINAL_SNAPSHOT", error); finalPrinterSnapshot = "Snapshot final indisponível: " + error.Message; }
            Write("INFO", "B_MONITOR_END", "duracao_seg=" + (DateTime.UtcNow - monitorStarted).TotalSeconds.ToString("F1") +
                "; receiver_start=" + receiverStarted + "; receiver_stop=" + receiverStopped + "; bytes_eof=" + bytesObserved + "; persisted=" + persisted + "; rejected_metadata=" + rejectionMetadata);
            var answer = MessageBox.Show(this, "Durante a impressão, o trabalho apareceu na lista do painel Foison C24?", Text, MessageBoxButtons.YesNoCancel, MessageBoxIcon.Question);
            uiConfirmation = answer == DialogResult.Yes ? "PASS" : answer == DialogResult.No ? "FAIL" : "UNKNOWN";
            Write("INFO", "B_UI_CONFIRMATION", "operador=" + uiConfirmation);
            var parsed = MessageBox.Show(this, "Você selecionou esse trabalho no painel e clicou Pré-visualizar? A geometria apareceu sem erro?", Text, MessageBoxButtons.YesNoCancel, MessageBoxIcon.Question);
            parserConfirmation = parsed == DialogResult.Yes ? "PASS" : parsed == DialogResult.No ? "FAIL" : "UNKNOWN";
            Write("INFO", "B_PARSER_CONFIRMATION", "operador=" + parserConfirmation);
        }

        private void StopWatching() { poll.Stop(); monitoring = false; StopWatchers(); }
        private void StopWatchers()
        {
            foreach (var watcher in new[]{starts, stops})
                if (watcher != null) { try { watcher.Stop(); watcher.Dispose(); } catch { } }
            starts = stops = null;
        }

        private void ExportReport()
        {
            if (monitoring) { MessageBox.Show(this, "Encerre o monitoramento antes de exportar."); return; }
            using (var dialog = new SaveFileDialog { Filter = "Relatório ZIP|*.zip", FileName = "FoisonC24-Diagnostico-" + runId + ".zip", OverwritePrompt = true })
            {
                if (dialog.ShowDialog(this) != DialogResult.OK) return;
                string temp = Path.Combine(Path.GetTempPath(), "FoisonC24-report-" + Guid.NewGuid().ToString("N"));
                Directory.CreateDirectory(temp);
                try
                {
                    string snapshot = finalPrinterSnapshot == "Not collected" ? CaptureDiagnostics.Collect(data) : finalPrinterSnapshot;
                    string env = "{\r\n  \"run_id\":\"" + Json(runId) + "\",\r\n  \"utc\":\"" + DateTime.UtcNow.ToString("o") + "\",\r\n  \"os\":\"" + Json(Environment.OSVersion.ToString()) + "\",\r\n  \"os_64_bit\":" + Environment.Is64BitOperatingSystem.ToString().ToLowerInvariant() + ",\r\n  \"process_64_bit\":" + Environment.Is64BitProcess.ToString().ToLowerInvariant() + ",\r\n  \"clr\":\"" + Json(Environment.Version.ToString()) + "\",\r\n  \"identity\":\"" + Json(CurrentIdentity()) + "\"\r\n}\r\n";
                    File.WriteAllText(Path.Combine(temp, "environment.json"), env, new UTF8Encoding(false));
                    File.WriteAllText(Path.Combine(temp, "printer-state.json"), "{\r\n  \"captured_utc\":\"" + DateTime.UtcNow.ToString("o") + "\",\r\n  \"initial_details\":\"" + Json(initialPrinterSnapshot) + "\",\r\n  \"final_details\":\"" + Json(snapshot) + "\"\r\n}\r\n", new UTF8Encoding(false));
                    string redmon = "INITIAL\r\n" + initialPrinterSnapshot + "\r\nFINAL\r\n" + snapshot;
                    File.WriteAllText(Path.Combine(temp, "redmon-state.txt"), String.Join(Environment.NewLine, redmon.Split(new[]{"\r\n","\n"}, StringSplitOptions.None).Where(x => x.Contains("REDMON") || x.Contains("RedMon") || x.Contains("ReceiverExists") || x.Contains("DriverName") || x.Contains("PortName"))), new UTF8Encoding(false));
                    File.Copy(logPath, Path.Combine(temp, "application.log"), true);
                    string receiverCombined = CollectReceiverLogs(Path.Combine(temp, "receiver.log"), diagnosticStarted);
                    string appLog = Path.Combine(data, "Logs", "application-" + runId + ".log");
                    if (File.Exists(appLog)) File.AppendAllText(Path.Combine(temp, "application.log"), Environment.NewLine + File.ReadAllText(appLog, Encoding.UTF8), new UTF8Encoding(false));
                    var errors = File.ReadAllLines(Path.Combine(temp, "application.log")).Where(x => x.Contains("[ERROR]") || x.Contains("UNKNOWN")).ToList();
                    errors.AddRange(receiverCombined.Split(new[]{"\r\n","\n"}, StringSplitOptions.RemoveEmptyEntries).Where(x => x.Contains("[ERROR]")));
                    File.WriteAllText(Path.Combine(temp, "errors.log"), String.Join(Environment.NewLine, errors) + Environment.NewLine, new UTF8Encoding(false));
                    string captureMetadata = CollectLatestMetadata(Path.Combine(temp, "capture-metadata.json"), diagnosticStarted);
                    string summary = Summary(receiverCombined, captureMetadata);
                    File.WriteAllText(Path.Combine(temp, "summary.txt"), summary, new UTF8Encoding(false));
                    var files = Directory.GetFiles(temp).ToDictionary(Path.GetFileName, x => HashFile(x), StringComparer.OrdinalIgnoreCase);
                    File.WriteAllLines(Path.Combine(temp, "checksums.txt"), files.OrderBy(x => x.Key).Select(x => x.Value + "  " + x.Key), new UTF8Encoding(false));
                    GuidedDiagnosticReport.CreateZip(dialog.FileName, temp);
                    Write("INFO", "REPORT_EXPORTED", "ZIP=" + dialog.FileName + "; raw documentos excluídos");
                    MessageBox.Show(this, "Relatório diagnóstico salvo. O ZIP não inclui dados brutos dos trabalhos.\r\n\r\n" + summary, Text, MessageBoxButtons.OK, MessageBoxIcon.Information);
                }
                catch (Exception error) { WriteError("REPORT_EXPORT", error); MessageBox.Show(this, error.Message); }
                finally { try { Directory.Delete(temp, true); } catch { } }
            }
        }

        private string CollectReceiverLogs(string destination, DateTime since)
        {
            string captures = Path.Combine(data, "captures");
            string[] folders = { Path.Combine(data, "Logs"), Path.Combine(captures, "diagnostics"), Path.Combine(Path.GetTempPath(), "FoisonC24", "Logs") };
            var selected = folders.Where(Directory.Exists).SelectMany(x => Directory.GetFiles(x, "receiver-*.log")).Distinct(StringComparer.OrdinalIgnoreCase)
                .Where(x => File.GetLastWriteTimeUtc(x) >= since).OrderBy(x => x).ToArray();
            var output = new StringBuilder();
            foreach (string file in selected) { output.AppendLine("### " + Path.GetFileName(file)); output.Append(File.ReadAllText(file, Encoding.UTF8)); }
            File.WriteAllText(destination, output.ToString(), new UTF8Encoding(false));
            return output.ToString();
        }

        private string CollectLatestMetadata(string destination, DateTime since)
        {
            string folder = Path.Combine(data, "captures");
            string attempts = Path.Combine(folder, "attempts");
            string latest = Directory.Exists(folder) ? Directory.GetFiles(folder, "job-*.json")
                .Concat(Directory.Exists(attempts) ? Directory.GetFiles(attempts, "attempt-*.json") : new string[0])
                .Where(f => File.GetLastWriteTimeUtc(f) >= since).OrderByDescending(File.GetLastWriteTimeUtc).FirstOrDefault() : null;
            if (latest == null) { File.WriteAllText(destination, "{\"status\":\"no-accepted-capture-observed\"}\r\n", new UTF8Encoding(false)); return ""; }
            string text = File.ReadAllText(latest, Encoding.UTF8);
            File.WriteAllText(destination, text, new UTF8Encoding(false)); return text;
        }

        private string Summary(string receiver, string metadata)
        {
            bool parserA = File.ReadAllText(logPath).IndexOf("A_PASS", StringComparison.Ordinal) >= 0;
            string received = bytesObserved != 0 ? "PASS" : "UNKNOWN";
            string saved = persisted != 0 ? "PASS" : "UNKNOWN";
            return "RunId: " + runId + "\r\n" +
                "Experimento A — Receiver direto: " + (File.ReadAllText(logPath).Contains("A_PASS") ? "PASS" : "UNKNOWN/FAIL; consultar application.log") + "\r\n" +
                "Experimento B — CorelDRAW/spooler/RedMon: período monitorado=" + (monitorExecuted ? "SIM" : "NÃO EXECUTADO") + "\r\n" +
                "Windows Spooler:    " + spoolerState + " — serviço consultado em snapshots\r\n" +
                "Fila Foison:        " + queueState + " — WMI Win32_Printer\r\n" +
                "RedMon:             " + redmonState + " — porta/Receiver/Output lidos do Registro\r\n" +
                "Receiver iniciado:  " + (!monitorExecuted ? "UNKNOWN" : receiverStarted > 0 ? "PASS" : "UNKNOWN") + " — WMI/log; B não executado quando UNKNOWN\r\n" +
                "Bytes recebidos:    " + (!monitorExecuted ? "UNKNOWN" : received) + " — marcador stdin EOF; veja receiver.log\r\n" +
                "Parser:             A=" + (parserA ? "PASS" : "UNKNOWN") + "; B=" + parserConfirmation + " — geometria visualizada pelo operador\r\n" +
                "Persistência:       " + (saved == "PASS" ? "PASS" : rejectionMetadata != 0 ? "FAIL (entrada rejeitada; causa/metadados preservados)" : "UNKNOWN") + " — novo marcador JSON observado durante B; metadados em capture-metadata.json\r\n" +
                "Interface:          " + uiConfirmation + " — confirmação manual do operador\r\n" +
                "Corte físico:       NÃO EXECUTADO; COM2 não foi aberta.\r\n" +
                "Observação: PASS do experimento A não comprova o caminho CorelDRAW/RedMon.";
        }

        private static string CurrentIdentity()
        {
            try { using (WindowsIdentity id = WindowsIdentity.GetCurrent()) return id.Name; }
            catch { return Environment.UserName; }
        }
        private static string Hash(byte[] bytes) { using (var sha = System.Security.Cryptography.SHA256.Create()) return BitConverter.ToString(sha.ComputeHash(bytes)).Replace("-", "").ToLowerInvariant(); }
        private static string HashFile(string file) { using (var input = File.OpenRead(file)) using (var sha = System.Security.Cryptography.SHA256.Create()) return BitConverter.ToString(sha.ComputeHash(input)).Replace("-", "").ToLowerInvariant(); }
        private static string Quote(string value) { return "\"" + value.Replace("\"", "\\\"") + "\""; }
        private static string Json(string value) { return (value ?? "").Replace("\\", "\\\\").Replace("\"", "\\\"").Replace("\r", "\\r").Replace("\n", "\\n"); }
    }
}
