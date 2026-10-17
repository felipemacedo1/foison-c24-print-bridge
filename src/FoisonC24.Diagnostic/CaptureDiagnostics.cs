using System;
using System.IO;
using System.Linq;
using System.Management;
using System.ServiceProcess;
using System.Text;
using Microsoft.Win32;

namespace FoisonC24.Diagnostic
{
    // Read-only. Never probes serial, prints a test, changes a queue or restarts Spooler.
    internal static class CaptureDiagnostics
    {
        internal static string Collect(string data)
        {
            var report=new StringBuilder();
            report.AppendLine("Foison C24 — diagnóstico da captura (somente leitura)");
            report.AppendLine("UTC="+DateTime.UtcNow.ToString("O"));
            report.AppendLine("OS="+Environment.OSVersion+" Process64="+Environment.Is64BitProcess);
            report.AppendLine("Captures="+Path.Combine(data,"captures"));
            Section(report,"CAPTURE_FOLDER",()=> {
                string folder=Path.Combine(data,"captures");
                if(!Directory.Exists(folder)) { report.AppendLine("Pasta de capturas ausente. Receiver ainda não criou saída neste destino.");return; }
                var raw=Directory.GetFiles(folder,"job-*.raw");var json=Directory.GetFiles(folder,"job-*.json");
                report.AppendLine("Raw="+raw.Length+" Ready="+json.Length+" Pares="+json.Count(f=>File.Exists(Path.ChangeExtension(f,"raw"))));
                report.AppendLine("ReceiverErrorLog="+File.Exists(Path.Combine(folder,"receiver-errors.log")));
                report.AppendLine("Arquivos de trabalho não são lidos por este diagnóstico.");
            });
            Section(report,"SPOOLER",()=> { using(var service=new ServiceController("Spooler"))report.AppendLine("Spooler="+service.Status); });
            Section(report,"QUEUE",()=> {
                var options=new EnumerationOptions { Timeout=TimeSpan.FromSeconds(5),ReturnImmediately=false };
                using(var query=new ManagementObjectSearcher(new ManagementScope(@"root\cimv2"),new ObjectQuery("SELECT DriverName,PortName,WorkOffline,PrinterStatus,DetectedErrorState,PrintProcessor,PrintJobDataType FROM Win32_Printer WHERE Name='Foison C24 (Teste)'"),options))
                using(var printers=query.Get())
                {
                    report.AppendLine("BridgeQueues="+printers.Count);
                    foreach(ManagementObject printer in printers)
                    using(printer)
                    {
                        foreach(string property in new[]{"DriverName","PortName","WorkOffline","PrinterStatus","DetectedErrorState","PrintProcessor","PrintJobDataType"})report.AppendLine(property+"="+printer[property]);
                        string port=Convert.ToString(printer["PortName"]);
                        if(!System.Text.RegularExpressions.Regex.IsMatch(port,@"^FOISONC24[1-9][0-9]*:$")) { report.AppendLine("Porta fora do namespace Bridge; nenhuma alteração realizada.");continue; }
                        Section(report,"REDMON",()=> {
                            using(var key=Registry.LocalMachine.OpenSubKey(@"SYSTEM\CurrentControlSet\Control\Print\Monitors\Redirected Port\Ports\"+port,false))
                            {
                                if(key==null) { report.AppendLine("Configuração RedMon não encontrada.");return; }
                                // Fixed fields only; no document names, credentials or print content.
                                foreach(string field in new[]{"Command","Output","Show","RunUser","Delay","LogFileUse","LogFileName","LogFileDebug","PrintError"})report.AppendLine("RedMon."+field+"="+key.GetValue(field,"<ausente>"));
                                report.AppendLine("RedMon.ArgumentsEmpty="+String.IsNullOrEmpty(Convert.ToString(key.GetValue("Arguments",""))));
                                string command=Convert.ToString(key.GetValue("Command",""));
                                report.AppendLine("ReceiverExists="+File.Exists(command));
                                report.AppendLine("ReceiverConfigExists="+File.Exists(command+".config"));
                            }
                        });
                    }
                }
            });
            report.AppendLine("Lista vazia não comprova falha do Corel, permissões ou formato. Correlacione fila, Receiver e logs.");
            report.AppendLine("Coleta não abriu COM nem enviou movimentos. Instalação não comprova captura; captura não comprova corte.");
            return report.ToString();
        }
        private static void Section(StringBuilder report,string stage,Action action)
        {
            report.AppendLine("["+stage+"]");
            try { action(); }
            catch(Exception error) { report.AppendLine("ERROR "+error.GetType().Name+": "+error.Message); }
        }
    }
}
