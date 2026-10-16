using System;
using System.Diagnostics;
using System.IO;
using System.IO.Compression;
using System.Linq;
using System.Windows.Forms;

namespace FoisonC24.Diagnostic
{
    internal static class Program
    {
        [STAThread]
        private static void Main()
        {
            Application.EnableVisualStyles();
            Application.SetCompatibleTextRenderingDefault(false);
            Application.Run(new MainForm());
        }
    }

    internal sealed class MainForm : Form
    {
        private readonly string captureDirectory = Path.Combine(
            Environment.GetFolderPath(Environment.SpecialFolder.CommonApplicationData),
            "FoisonC24", "captures");
        private readonly Label status = new Label();

        public MainForm()
        {
            Text = "Foison C24 Print Bridge - Diagnóstico";
            Width = 560;
            Height = 220;
            status.AutoSize = false;
            status.Dock = DockStyle.Top;
            status.Height = 100;
            status.Text = "Modo simulação ativo.\r\nNenhum comando será enviado à COM2.";
            Controls.Add(status);
            Button refresh = new Button { Text = "Atualizar estado", Left = 20, Top = 115, Width = 150 };
            refresh.Click += (sender, args) => RefreshStatus();
            Controls.Add(refresh);
            Button export = new Button { Text = "Exportar diagnóstico", Left = 190, Top = 115, Width = 180 };
            export.Click += (sender, args) => Export();
            Controls.Add(export);
            RefreshStatus();
        }

        private void RefreshStatus()
        {
            int jobs = Directory.Exists(captureDirectory)
                ? Directory.GetFiles(captureDirectory, "job-*.json").Length : 0;
            status.Text = "Modo simulação ativo.\r\nTrabalhos capturados: " + jobs +
                "\r\nPasta: " + captureDirectory;
        }

        private void Export()
        {
            if (!Directory.Exists(captureDirectory))
            {
                MessageBox.Show("Ainda não há diagnóstico para exportar.", Text,
                    MessageBoxButtons.OK, MessageBoxIcon.Information);
                return;
            }
            using (SaveFileDialog dialog = new SaveFileDialog { Filter = "ZIP|*.zip",
                FileName = "FoisonC24-diagnostico-" + DateTime.Now.ToString("yyyyMMdd-HHmmss") + ".zip" })
            {
                if (dialog.ShowDialog() != DialogResult.OK) return;
                if (File.Exists(dialog.FileName)) File.Delete(dialog.FileName);
                using (ZipArchive archive = ZipFile.Open(dialog.FileName, ZipArchiveMode.Create))
                    foreach (string file in Directory.GetFiles(captureDirectory)
                        .Where(path => Path.GetExtension(path).Equals(".json", StringComparison.OrdinalIgnoreCase)
                            || Path.GetFileName(path).Equals("receiver-errors.log", StringComparison.OrdinalIgnoreCase)))
                        archive.CreateEntryFromFile(file, Path.GetFileName(file));
                MessageBox.Show("Diagnóstico exportado sem os documentos brutos.", Text,
                    MessageBoxButtons.OK, MessageBoxIcon.Information);
            }
        }
    }
}
