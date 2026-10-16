using System;
using System.IO;
using System.Security.Cryptography;
using System.Text;

namespace FoisonC24.WindowsReceiver
{
    internal static class Program
    {
        private const long MaxBytes = 64L * 1024L * 1024L;

        private static int Main(string[] args)
        {
            string output = GetArgument(args, "--output-dir") ??
                Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.CommonApplicationData),
                    "FoisonC24", "captures");
            try
            {
                Directory.CreateDirectory(output);
                byte[] data = ReadStandardInput();
                if (data.Length == 0) throw new InvalidDataException("empty print stream");
                string format = DetectFormat(data);
                if (format == "unknown")
                    throw new InvalidDataException("unsupported print stream format");
                string hash;
                using (SHA256 sha = SHA256.Create())
                    hash = BitConverter.ToString(sha.ComputeHash(data)).Replace("-", "").ToLowerInvariant();
                string jobId = DateTime.UtcNow.ToString("yyyyMMdd-HHmmss") + "-" + hash.Substring(0, 12) + "-" + Guid.NewGuid().ToString("N");
                File.WriteAllBytes(Path.Combine(output, "job-" + jobId + ".raw"), data);
                string report = Path.Combine(output, "job-" + jobId + ".json");
                File.WriteAllText(report + ".tmp",
                    "{\r\n" +
                    "  \"job_id\": \"" + jobId + "\",\r\n" +
                    "  \"format\": \"" + format + "\",\r\n" +
                    "  \"bytes\": " + data.Length + ",\r\n" +
                    "  \"sha256\": \"" + hash + "\",\r\n" +
                    "  \"simulation_mode\": true,\r\n" +
                    "  \"physical_cut_enabled\": false,\r\n" +
                    "  \"status\": \"captured\"\r\n}\r\n",
                    Encoding.UTF8);
                File.Move(report + ".tmp", report); // ready marker published only after raw and report are complete
                return 0;
            }
            catch (Exception error)
            {
                try
                {
                    Directory.CreateDirectory(output);
                    File.AppendAllText(Path.Combine(output, "receiver-errors.log"),
                        DateTime.UtcNow.ToString("O") + " " + error + Environment.NewLine);
                }
                catch (IOException) { }
                Console.Error.WriteLine("Foison C24 capture failed: " + error.Message);
                return 2;
            }
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
