using System;
using System.Diagnostics;
using System.IO;
using System.Security.Cryptography;
using System.Security.Principal;
using System.Text;

namespace FoisonC24.WindowsReceiver
{
    internal static class Program
    {
        private const long MaxBytes = 64L * 1024L * 1024L;

        private static int Main(string[] args)
        {
            string output = GetArgument(args, "--output-dir") ?? DefaultCaptureDirectory();
            string attemptId = DateTime.UtcNow.ToString("yyyyMMddTHHmmssfffZ") + "-" +
                Process.GetCurrentProcess().Id + "-" + Guid.NewGuid().ToString("N");
            string runId = SafeValue(Environment.GetEnvironmentVariable("FOISON_RUN_ID"));
            if (runId.Length == 0) runId = attemptId;
            string logPath = null;
            string stage = "START";
            long bytesRead = 0;
            bool eof = false;
            string hash = "";
            string format = "unknown";
            int exitCode = 2;
            Stopwatch clock = Stopwatch.StartNew();
            MemoryStream buffer = null;
            try
            {
                logPath = OpenAttemptLog(output, attemptId);
                Log(logPath, runId, attemptId, "INFO", "START", "Receiver iniciado; pid=" + Process.GetCurrentProcess().Id +
                    "; identidade=" + Identity() + "; args=" + SafeArguments(args) +
                    "; REDMON_PORT=" + Env("REDMON_PORT") + "; REDMON_JOB=" + Env("REDMON_JOB") +
                    "; REDMON_PRINTER=" + Env("REDMON_PRINTER") + "; REDMON_DOCNAME=" +
                    (String.IsNullOrEmpty(Environment.GetEnvironmentVariable("REDMON_DOCNAME")) ? "absent" : "present-redacted"));

                stage = "STDIN_OPEN";
                Stream input = Console.OpenStandardInput();
                Log(logPath, runId, attemptId, "INFO", stage, "stdin aberto");
                buffer = new MemoryStream();
                byte[] chunk = new byte[64 * 1024];
                int count;
                bool firstByte = true;
                bool oversized = false;
                using (SHA256 streamHash = SHA256.Create())
                {
                    while ((count = input.Read(chunk, 0, chunk.Length)) > 0)
                    {
                        if (firstByte)
                        {
                            firstByte = false;
                            Log(logPath, runId, attemptId, "INFO", "FIRST_BYTE", "primeiro byte recebido; bytes_no_bloco=" + count);
                        }
                        streamHash.TransformBlock(chunk, 0, count, chunk, 0);
                        if (!oversized && bytesRead <= MaxBytes - count) buffer.Write(chunk, 0, count);
                        else oversized = true;
                        bytesRead += count;
                    }
                    streamHash.TransformFinalBlock(new byte[0], 0, 0);
                    hash = BitConverter.ToString(streamHash.Hash).Replace("-", "").ToLowerInvariant();
                }
                eof = true;
                Log(logPath, runId, attemptId, "INFO", "STDIN_EOF", "EOF; total_bytes=" + bytesRead);
                if (oversized) throw new InvalidDataException("print stream exceeds size limit");
                byte[] data = buffer.ToArray();
                format = DetectFormat(data);
                Log(logPath, runId, attemptId, "INFO", "FORMAT", "formato=" + format + "; bytes=" + bytesRead + "; sha256=" + hash);
                if (data.Length == 0) throw new InvalidDataException("empty print stream");
                if (format == "unknown") throw new InvalidDataException("unsupported print stream format");

                stage = "PERSIST_RAW";
                Directory.CreateDirectory(output);
                string jobId = DateTime.UtcNow.ToString("yyyyMMdd-HHmmss") + "-" + hash.Substring(0, 12) + "-" + Guid.NewGuid().ToString("N");
                string rawPath = Path.Combine(output, "job-" + jobId + ".raw");
                File.WriteAllBytes(rawPath, data);
                Log(logPath, runId, attemptId, "INFO", stage, "dados originais gravados; arquivo=" + Path.GetFileName(rawPath));

                stage = "PERSIST_METADATA";
                string report = Path.Combine(output, "job-" + jobId + ".json");
                File.WriteAllText(report + ".tmp", JobJson(jobId, runId, attemptId, format, bytesRead, hash, "captured", ""), new UTF8Encoding(false));
                File.Move(report + ".tmp", report);
                Log(logPath, runId, attemptId, "INFO", "QUEUE_REGISTERED", "marcador de trabalho publicado; id=" + jobId);
                exitCode = 0;
            }
            catch (Exception error)
            {
                string detail = error.GetType().FullName + ": " + error.Message;
                Log(logPath, runId, attemptId, "ERROR", stage, detail + "; stack=" + error.StackTrace);
                try
                {
                    Directory.CreateDirectory(output);
                    string rejectedDirectory = Path.Combine(output, "attempts");
                    Directory.CreateDirectory(rejectedDirectory);
                    string rejected = Path.Combine(rejectedDirectory, "attempt-" + attemptId + ".json");
                    File.WriteAllText(rejected, JobJson(attemptId, runId, attemptId, format, bytesRead, hash,
                        "rejected", detail), new UTF8Encoding(false));
                    Log(logPath, runId, attemptId, "INFO", "REJECTION_METADATA", "metadados da entrada rejeitada preservados; raw não armazenado");
                }
                catch (Exception metadataError)
                {
                    Log(logPath, runId, attemptId, "ERROR", "PERSIST_REJECTION_METADATA", metadataError.GetType().FullName + ": " + metadataError.Message);
                }
                try { Console.Error.WriteLine("Foison C24 capture failed: " + error.Message); } catch { }
                exitCode = 2;
            }
            finally
            {
                if (buffer != null) buffer.Dispose();
                clock.Stop();
                Log(logPath, runId, attemptId, exitCode == 0 ? "INFO" : "ERROR", "EXIT",
                    "exit_code=" + exitCode + "; elapsed_ms=" + clock.ElapsedMilliseconds + "; bytes=" + bytesRead +
                    "; eof=" + eof.ToString().ToLowerInvariant() + "; sha256=" + hash + "; format=" + format);
            }
            return exitCode;
        }

        private static string DefaultCaptureDirectory()
        {
            return Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.CommonApplicationData), "FoisonC24", "captures");
        }

        private static string OpenAttemptLog(string output, string attemptId)
        {
            string common = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.CommonApplicationData), "FoisonC24", "Logs");
#if NET8_0_OR_GREATER
            if (!OperatingSystem.IsWindows())
            {
                string local = Path.Combine(output, "diagnostics");
                try { Directory.CreateDirectory(local); string localPath = Path.Combine(local, "receiver-" + attemptId + ".log"); using (FileStream stream = new FileStream(localPath, FileMode.CreateNew, FileAccess.Write, FileShare.Read)) { } return localPath; }
                catch { }
            }
#endif
            string[] candidates = { common, Path.Combine(output, "diagnostics"), Path.Combine(Path.GetTempPath(), "FoisonC24", "Logs") };
            foreach (string directory in candidates)
            {
                try
                {
                    Directory.CreateDirectory(directory);
                    string path = Path.Combine(directory, "receiver-" + attemptId + ".log");
                    using (FileStream stream = new FileStream(path, FileMode.CreateNew, FileAccess.Write, FileShare.Read)) { }
                    return path;
                }
                catch (Exception e) { try { Console.Error.WriteLine("Receiver log fallback: " + e.GetType().Name); } catch { } }
            }
            return null;
        }

        private static void Log(string path, string runId, string attemptId, string level, string stage, string message)
        {
            if (String.IsNullOrEmpty(path)) return;
            try
            {
                string line = DateTime.UtcNow.ToString("o") + " [" + level + "] [" + runId + "] [receiver] [" + stage + "] [" + attemptId + "] " +
                    (message ?? "").Replace("\r", " ").Replace("\n", " ") + Environment.NewLine;
                File.AppendAllText(path, line, new UTF8Encoding(false));
            }
            catch { /* Diagnostics must never replace the actual capture result. */ }
        }

        private static string JobJson(string id, string runId, string attemptId, string format, long bytes, string hash, string status, string error)
        {
            return "{\r\n" +
                "  \"job_id\": \"" + Json(id) + "\",\r\n" +
                "  \"run_id\": \"" + Json(runId) + "\",\r\n" +
                "  \"attempt_id\": \"" + Json(attemptId) + "\",\r\n" +
                "  \"format\": \"" + Json(format) + "\",\r\n" +
                "  \"bytes\": " + bytes + ",\r\n" +
                "  \"sha256\": \"" + Json(hash) + "\",\r\n" +
                "  \"simulation_mode\": true,\r\n" +
                "  \"physical_cut_enabled\": false,\r\n" +
                "  \"status\": \"" + Json(status) + "\",\r\n" +
                "  \"error\": \"" + Json(error) + "\"\r\n}\r\n";
        }

        private static string Json(string value)
        {
            if (value == null) return "";
            return value.Replace("\\", "\\\\").Replace("\"", "\\\"").Replace("\r", "\\r").Replace("\n", "\\n").Replace("\t", "\\t");
        }

        private static string Identity()
        {
#if NET8_0_OR_GREATER
            if (!OperatingSystem.IsWindows()) return Environment.UserName + "; sid=unavailable-non-windows";
#endif
            try { using (WindowsIdentity identity = WindowsIdentity.GetCurrent()) return identity.Name + "; sid=" + (identity.User == null ? "unavailable" : identity.User.Value); }
            catch (Exception e) { return "unknown(" + e.GetType().Name + ")"; }
        }

        private static string Env(string name) { return SafeValue(Environment.GetEnvironmentVariable(name)); }
        private static string SafeValue(string value)
        {
            if (String.IsNullOrEmpty(value)) return "absent";
            return value.Replace("\r", " ").Replace("\n", " ").Replace(";", "_");
        }

        private static string SafeArguments(string[] args)
        {
            string output = "";
            for (int i = 0; i < args.Length; i++)
            {
                if (args[i] == "--output-dir" && i + 1 < args.Length) { output = args[++i]; continue; }
                output += " " + args[i];
            }
            return String.IsNullOrWhiteSpace(output) ? "(none)" : output.Trim().Replace("\r", " ").Replace("\n", " ");
        }

        private static byte[] ReadStandardInput()
        {
            using (MemoryStream result = new MemoryStream())
            {
                byte[] buffer = new byte[64 * 1024];
                int read;
                while ((read = Console.OpenStandardInput().Read(buffer, 0, buffer.Length)) > 0)
                {
                    if (result.Length + read > MaxBytes) throw new InvalidDataException("print stream exceeds size limit");
                    result.Write(buffer, 0, read);
                }
                return result.ToArray();
            }
        }

        private static string DetectFormat(byte[] data)
        {
            if (data.Length >= 6 && data[0] == 4 && Encoding.ASCII.GetString(data, 1, 5) == "%!PS-") return "postscript/eot";
            if (data.Length >= 5 && Encoding.ASCII.GetString(data, 0, 5) == "%!PS-") return "postscript";
            if (data.Length >= 9 && Encoding.ASCII.GetString(data, 0, 9) == "\x1b%-12345X") return "pcl/ujf";
            return "unknown";
        }

        private static string GetArgument(string[] args, string name)
        {
            for (int i = 0; i + 1 < args.Length; i++)
                if (String.Equals(args[i], name, StringComparison.OrdinalIgnoreCase)) return args[i + 1];
            return null;
        }
    }
}
