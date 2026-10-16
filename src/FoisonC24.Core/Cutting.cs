using System;
using System.Collections.Generic;
using System.Globalization;
using System.IO;
using System.Linq;
using System.Security.Cryptography;
using System.Text;
using System.Threading;

namespace FoisonC24.Core
{
    public sealed class MachineProfile
    {
        public string Revision, EvidenceSha256;
        public double UnitsPerMm, WidthMm, HeightMm;
        public bool SwapAxes, ReverseX, ReverseY;
        public bool InitializationVerified, AbsoluteMovesVerified, BladeUpDownVerified, ResolutionVerified;
        public void Validate()
        {
            if(String.IsNullOrWhiteSpace(Revision) || EvidenceSha256==null || EvidenceSha256.Length!=64 || !EvidenceSha256.All(Uri.IsHexDigit)
                || !InitializationVerified || !AbsoluteMovesVerified || !BladeUpDownVerified || !ResolutionVerified)
                throw new InvalidOperationException("Protocolo da revisão não aprovado: evidência, IN/PA/PU/PD e resolução devem ser verificados pelo desenvolvedor.");
            if(!Valid(UnitsPerMm,1,1000) || !Valid(WidthMm,1,50) || !Valid(HeightMm,1,50))
                throw new InvalidOperationException("Primeira sessão limitada a área medida de no máximo 50 × 50 mm; unidades/mm devem ser comprovadas.");
        }
        private static bool Valid(double x,double min,double max) => !Double.IsNaN(x) && !Double.IsInfinity(x) && x>=min && x<=max;
        public string Fingerprint => Hash(Revision+"|"+EvidenceSha256+"|"+UnitsPerMm.ToString("R",CultureInfo.InvariantCulture)+"|"+WidthMm.ToString("R",CultureInfo.InvariantCulture)+"|"+HeightMm.ToString("R",CultureInfo.InvariantCulture)+"|"+SwapAxes+"|"+ReverseX+"|"+ReverseY);
        public static string Hash(string value) { using(var sha=SHA256.Create()) return BitConverter.ToString(sha.ComputeHash(Encoding.UTF8.GetBytes(value))).Replace("-","").ToLowerInvariant(); }
        public static string FileHash(string file) { using(var sha=SHA256.Create()) using(var f=File.OpenRead(file)) return BitConverter.ToString(sha.ComputeHash(f)).Replace("-","").ToLowerInvariant(); }
    }
    public sealed class CutPlan
    {
        private readonly string[] commands;
        public IReadOnlyList<string> Commands => Array.AsReadOnly(commands);
        public string JobHash { get; }
        public string ProfileHash { get; }
        public string Hash { get; }
        public bool MotionOnly { get; }
        internal CutPlan(string[] commands, string jobHash, MachineProfile p, bool motionOnly)
        { this.commands=commands; JobHash=jobHash; ProfileHash=p.Fingerprint; MotionOnly=motionOnly; Hash=MachineProfile.Hash(String.Join("",commands)+jobHash+ProfileHash+motionOnly); }
    }
    public static class Hpgl
    {
        public static CutPlan Build(Drawing drawing, string jobHash, MachineProfile profile, bool motionOnly)
        {
            profile.Validate(); drawing.Validate();
            if(jobHash==null || jobHash.Length!=64 || !jobHash.All(Uri.IsHexDigit)) throw new InvalidOperationException("Trabalho sem identidade válida.");
            double minX=drawing.MinX, minY=drawing.MinY;
            double width=profile.SwapAxes ? drawing.Height : drawing.Width, height=profile.SwapAxes ? drawing.Width : drawing.Height;
            const double margin=2;
            if(width+2*margin>profile.WidthMm || height+2*margin>profile.HeightMm) throw new InvalidOperationException("Desenho excede a área medida (incluindo margem de 2 mm).");
            Func<Point,string> coordinate = p => {
                double x=p.X-minX, y=p.Y-minY;
                if(profile.SwapAxes) { double t=x;x=y;y=t; }
                if(profile.ReverseX) x=width-x;
                if(profile.ReverseY) y=height-y;
                x+=margin;y+=margin;
                int ix=checked((int)Math.Round(x*profile.UnitsPerMm,MidpointRounding.AwayFromZero));
                int iy=checked((int)Math.Round(y*profile.UnitsPerMm,MidpointRounding.AwayFromZero));
                if(ix<0 || iy<0 || ix/profile.UnitsPerMm>profile.WidthMm || iy/profile.UnitsPerMm>profile.HeightMm) throw new InvalidOperationException("Coordenada quantizada fora da área.");
                return ix.ToString(CultureInfo.InvariantCulture)+","+iy.ToString(CultureInfo.InvariantCulture);
            };
            var commands=new List<string>{"IN;","PA;","PU;"};
            foreach(var path in drawing.Paths)
            {
                commands.Add("PU"+coordinate(path.Points[0])+";");
                foreach(var point in path.Points.Skip(1)) commands.Add((motionOnly ? "PU" : "PD")+coordinate(point)+";");
                if(path.Closed) commands.Add((motionOnly ? "PU" : "PD")+coordinate(path.Points[0])+";");
                commands.Add("PU;");
            }
            if(commands.Sum(c=>c.Length)>256*1024) throw new InvalidOperationException("Primeiro ensaio limitado a 256 KiB de HPGL.");
            return new CutPlan(commands.ToArray(),jobHash,profile,motionOnly);
        }
    }
    public interface IWire : IDisposable
    {
        void Open();
        void Write(string command, CancellationToken cancel);
        void Drain(CancellationToken cancel);
        void Abort();
    }
    public sealed class Authorization
    {
        public string PlanHash;
        public bool DeveloperApproved, GeometryMeasured, OriginAndLimitsChecked, OperatorConfirmed, BladeRemovedForMotion, MotionObserved;
        public void Validate(CutPlan plan)
        {
            if(PlanHash!=plan.Hash || !DeveloperApproved || !GeometryMeasured || !OriginAndLimitsChecked || !OperatorConfirmed
                || (plan.MotionOnly ? !BladeRemovedForMotion : !MotionObserved))
                throw new InvalidOperationException("Envio bloqueado: confirme protocolo, geometria, origem/área e autorização deste trabalho. Movimento exige lâmina removida; corte exige ensaio observado.");
        }
    }
    public sealed class Sender
    {
        private readonly string journal;
        public Sender(string journal) { this.journal=journal; }
        // No automatic retry/reconnect. Journal survives crash, application restart and reinstallation.
        public void Send(CutPlan plan, Authorization approval, Func<IWire> wireFactory, CancellationToken cancel)
        {
            approval.Validate(plan); cancel.ThrowIfCancellationRequested();
            Directory.CreateDirectory(journal);
            using(var guard=new FileStream(Path.Combine(journal,"sender.lock"),FileMode.OpenOrCreate,FileAccess.ReadWrite,FileShare.None))
            {
                if(File.Exists(Path.Combine(journal,"INTERRUPTED"))) throw new InvalidOperationException("Interrupção anterior: desenvolvedor deve verificar buffer/hardware antes de liberar a sessão.");
                string record=Path.Combine(journal,MachineProfile.Hash(plan.JobHash+plan.MotionOnly)+".sent");
                if(File.Exists(record)) throw new InvalidOperationException("Trabalho já tentado. Reimprima após verificar o hardware; não há repetição automática.");
                using(var wire=wireFactory())
                {
                    wire.Open();
                    using(var f=new FileStream(record,FileMode.CreateNew,FileAccess.Write,FileShare.None))
                    using(var writer=new StreamWriter(f)) { writer.Write(plan.Hash+"\nstarted; physical completion unknown"); writer.Flush(); f.Flush(true); }
                    try
                    {
                        foreach(var command in plan.Commands) { cancel.ThrowIfCancellationRequested(); wire.Write(command,cancel); }
                        wire.Drain(cancel);
                        File.AppendAllText(record,"\nhost transmission complete; verify physical result manually");
                    }
                    catch
                    {
                        // Persist the uncertain state before attempting to purge/close the host buffer.
                        File.WriteAllText(Path.Combine(journal,"INTERRUPTED"),plan.Hash+"\nDo not resend. Check plotter buffer and physical state.");
                        wire.Abort(); throw;
                    }
                }
            }
        }
    }
}
