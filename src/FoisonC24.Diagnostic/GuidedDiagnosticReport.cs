using System;
using System.IO;
using System.IO.Compression;
using System.Linq;
using System.Text;

namespace FoisonC24.Diagnostic
{
    internal static class GuidedDiagnosticReport
    {
        private static readonly string[] Entries = { "summary.txt", "environment.json", "printer-state.json", "redmon-state.txt", "receiver.log", "capture-metadata.json", "application.log", "errors.log", "checksums.txt" };

        internal static void CreateZip(string destination, string directory)
        {
            string[] files = Directory.GetFiles(directory).Select(Path.GetFileName).OrderBy(x => x, StringComparer.Ordinal).ToArray();
            if (!files.OrderBy(x => x, StringComparer.Ordinal).SequenceEqual(Entries.OrderBy(x => x, StringComparer.Ordinal), StringComparer.Ordinal))
                throw new InvalidDataException("Relatório contém arquivo ausente ou fora da allowlist.");
            if (files.Any(x => x.EndsWith(".raw", StringComparison.OrdinalIgnoreCase) || x.EndsWith(".pdf", StringComparison.OrdinalIgnoreCase)))
                throw new InvalidDataException("Relatório não pode incluir conteúdo bruto de trabalho.");
            using (var stream = new FileStream(destination, FileMode.Create, FileAccess.ReadWrite, FileShare.None))
            using (var archive = new ZipArchive(stream, ZipArchiveMode.Create))
                foreach (string file in files) archive.CreateEntryFromFile(Path.Combine(directory, file), file, CompressionLevel.Optimal);
        }

        internal static void CreateSyntheticSmoke(string destination)
        {
            string directory = Path.Combine(Path.GetTempPath(), "FoisonC24-report-smoke-" + Guid.NewGuid().ToString("N"));
            Directory.CreateDirectory(directory);
            try
            {
                Write(directory, "summary.txt", "Foison C24 diagnostic ZIP builder smoke\r\nWindows Spooler: UNKNOWN\r\nFila Foison: UNKNOWN\r\nRedMon: UNKNOWN\r\nReceiver iniciado: UNKNOWN\r\nBytes recebidos: UNKNOWN\r\nParser: UNKNOWN\r\nPersistência: UNKNOWN\r\nInterface: UNKNOWN\r\nImpressão e corte físico: NÃO EXECUTADOS\r\n");
                Write(directory, "environment.json", "{\"run_id\":\"synthetic-report-smoke\",\"os\":\"CI only\",\"physical_hardware\":false}\r\n");
                Write(directory, "printer-state.json", "{\"initial_details\":\"synthetic; no spooler queried\",\"final_details\":\"synthetic; no spooler queried\"}\r\n");
                Write(directory, "redmon-state.txt", "Synthetic report builder smoke; RedMon not queried.\r\n");
                Write(directory, "receiver.log", "Synthetic report builder smoke; Receiver not launched.\r\n");
                Write(directory, "capture-metadata.json", "{\"status\":\"synthetic-no-capture\"}\r\n");
                Write(directory, "application.log", "Synthetic report builder smoke; no user data.\r\n");
                Write(directory, "errors.log", "No diagnostic operation was performed.\r\n");
                var checks = Entries.Where(x => x != "checksums.txt").OrderBy(x => x, StringComparer.Ordinal)
                    .Select(x => Hash(Path.Combine(directory, x)) + "  " + x);
                Write(directory, "checksums.txt", String.Join("\r\n", checks) + "\r\n");
                CreateZip(destination, directory);
            }
            finally { try { Directory.Delete(directory, true); } catch { } }
        }

        private static void Write(string directory, string name, string content)
        {
            File.WriteAllText(Path.Combine(directory, name), content, new UTF8Encoding(false));
        }

        private static string Hash(string path)
        {
            using (var input = File.OpenRead(path))
            using (var sha = System.Security.Cryptography.SHA256.Create())
                return BitConverter.ToString(sha.ComputeHash(input)).Replace("-", "").ToLowerInvariant();
        }
    }
}
