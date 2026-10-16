using System;
using System.Diagnostics;
using System.IO;
using System.Text;
using System.Threading;
using System.Threading.Tasks;

namespace FoisonC24.Core
{
    public sealed class Converter
    {
        private readonly string ghostscript, mutool;
        public Converter(string ghostscript, string mutool) { this.ghostscript=ghostscript; this.mutool=mutool; }
        public Drawing Convert(string input, string work, CancellationToken cancel)
        {
            if (!File.Exists(input) || new FileInfo(input).Length > 64L*1024*1024) throw new InvalidDataException("Entrada ausente ou acima de 64 MiB.");
            using (var f = File.OpenRead(input))
            {
                var h = new byte[5];
                if (f.Read(h,0,5)!=5 || Encoding.ASCII.GetString(h)!="%!PS-")
                    throw new InvalidDataException("A fila não produziu PostScript. Verifique o driver PScript e desative saída binária/PJL.");
            }
            Directory.CreateDirectory(work);
            string pdf=Path.GetFullPath(Path.Combine(work,"drawing.pdf"));
            string xml=Path.GetFullPath(Path.Combine(work,"trace.xml"));
            // Entire interpreter is a separate bounded process. No shell, PS hooks or raster tracing.
            Run(ghostscript,"-q -dSAFER -dBATCH -dNOPAUSE -dNoOutputFonts -sDEVICE=pdfwrite -dCompatibilityLevel=1.7 " + Quote("-sOutputFile="+pdf) + " -f " + Quote(Path.GetFullPath(input)),work,cancel,pdf);
            Run(mutool,"draw -q -r 72 -F trace -o " + Quote(xml) + " " + Quote(pdf),work,cancel,xml);
            return TraceParser.Parse(File.ReadAllText(xml));
        }
        public static string Quote(string s)
        {
            if (s.IndexOfAny(new[]{'"','\r','\n'})>=0 || s.EndsWith("\\")) throw new ArgumentException("Caminho inválido.");
            return "\""+s+"\"";
        }
        private static void Run(string exe, string args, string work, CancellationToken cancel, string output)
        {
            if (!File.Exists(exe)) throw new FileNotFoundException("Interpretador vetorial ausente. Reinstale o pacote completo.",exe);
            var start = new ProcessStartInfo(exe,args) { UseShellExecute=false, CreateNoWindow=true, WorkingDirectory=work,
                RedirectStandardError=true, RedirectStandardOutput=true };
            using (var p = new Process { StartInfo=start })
            {
                var log=new StringBuilder(); object sync=new object();
                int totalOutput=0;
                Action<StreamReader> pump=reader=> {
                    char[] buffer=new char[1024];int read;
                    while((read=reader.Read(buffer,0,buffer.Length))>0)
                    {
                        Interlocked.Add(ref totalOutput,read);
                        lock(sync) { if(log.Length<16000) log.Append(buffer,0,Math.Min(read,16000-log.Length)); }
                    }
                };
                p.Start();
                var stdout=Task.Run(()=>pump(p.StandardOutput));var stderr=Task.Run(()=>pump(p.StandardError));
                var clock=Stopwatch.StartNew();
                try
                {
                    while (!p.WaitForExit(50))
                    {
                        cancel.ThrowIfCancellationRequested();
                        if(clock.ElapsedMilliseconds>30000) throw new TimeoutException("Conversão excedeu 30 segundos.");
                        if(Volatile.Read(ref totalOutput)>1024*1024) throw new InvalidDataException("Saída de diagnóstico excessiva do interpretador.");
                        long memory = 0;
                        try { p.Refresh(); memory=p.WorkingSet64; }
                        catch (InvalidOperationException) { if (!p.HasExited) throw; }
                        if(memory>512L*1024*1024 || (File.Exists(output) && new FileInfo(output).Length>32L*1024*1024))
                            throw new InvalidDataException("Conversão excedeu os limites de memória/arquivo.");
                    }
                    p.WaitForExit(); Task.WaitAll(stdout,stderr); cancel.ThrowIfCancellationRequested();
                    if(totalOutput>1024*1024) throw new InvalidDataException("Saída de diagnóstico excessiva do interpretador.");
                    if(p.ExitCode!=0) throw new InvalidDataException("Falha do interpretador ("+p.ExitCode+"): "+log);
                    if(!File.Exists(output) || new FileInfo(output).Length>32L*1024*1024) throw new InvalidDataException("Saída vetorial ausente/excessiva.");
                }
                finally { if(!p.HasExited) { p.Kill(); p.WaitForExit(5000); } Task.WaitAll(new[]{stdout,stderr},5000); }
            }
        }
    }
}
