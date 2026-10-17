using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Threading;
using FoisonC24.Core;

static class Program
{
    static int count;
    static void Check(bool ok,string name) { if(!ok) throw new Exception(name); Console.WriteLine("PASS "+name); count++; }
    static void Reject(Action action,string name) { bool rejected=false; try { action(); } catch { rejected=true; } Check(rejected,name); }
    static MachineProfile Profile() => new MachineProfile { Revision="SIMULATOR ONLY",EvidenceSha256=new string('a',64),UnitsPerMm=40,WidthMm=30,HeightMm=30,InitializationVerified=true,AbsoluteMovesVerified=true,BladeUpDownVerified=true,ResolutionVerified=true };
    static Authorization Approve(CutPlan p) => new Authorization { PlanHash=p.Hash,DeveloperApproved=true,GeometryMeasured=true,OriginAndLimitsChecked=true,OperatorConfirmed=true,BladeRemovedForMotion=true,MotionObserved=true };
    static string Trace(string paths) => "<document><page mediabox='0 0 100 100'>"+paths+"</page></document>";
    static string Stroke(string path,string extra="") => "<stroke_path transform='1 0 0 -1 0 100' "+extra+">"+path+"</stroke_path>";
    const string Line="<moveto x='0' y='0'/><lineto x='20' y='0'/>";
    static void Main(string[] args)
    {
        // Framework redirected stdin uses Console.InputEncoding. No encoding
        // preamble may be injected into the binary RedMon-pipe simulation.
        Console.InputEncoding=new System.Text.UTF8Encoding(false);
        var ps=System.Text.Encoding.ASCII.GetBytes("%!PS-Adobe-3.0\nshowpage");
        Check(PostScriptEnvelope.Normalize(new byte[]{4}.Concat(ps).Concat(new byte[]{4}).ToArray()).SequenceEqual(ps),"PScript EOT wrapper normalized without modifying original");
        var pjl=System.Text.Encoding.ASCII.GetBytes("\x1b%-12345X@PJL JOB NAME=TEST\r\n@PJL ENTER LANGUAGE=POSTSCRIPT\r\n").Concat(ps).Concat(System.Text.Encoding.ASCII.GetBytes("\x04\x1b%-12345X@PJL EOJ\r\n\x1b%-12345X")).ToArray();
        Check(PostScriptEnvelope.Normalize(pjl).SequenceEqual(ps),"bounded PJL PostScript envelope normalized");
        Reject(()=>PostScriptEnvelope.Normalize(System.Text.Encoding.ASCII.GetBytes("\x1b%-12345X@PJL ENTER LANGUAGE=PCL\n%!PS-Adobe-3.0")),"PCL cannot be disguised as PS");
        var p=Profile(); var hash=new string('b',64);
        var drawing=TraceParser.Parse(Trace(Stroke("<moveto x='10' y='10'/><lineto x='30' y='10'/><lineto x='30' y='30'/><lineto x='10' y='30'/><closepath/>")));
        Check(Math.Abs(drawing.Width-20*25.4/72)<1e-9,"points to millimetres");
        Check(drawing.Paths[0].Closed && drawing.Points.First().Y>0,"orientation and closure");
        var open=TraceParser.Parse(Trace(Stroke(Line))); Check(!open.Paths[0].Closed,"open path preserved");
        Reject(()=>TraceParser.Parse(Trace("<fill_image/>")),"raster rejected");
        Reject(()=>TraceParser.Parse(Trace("<fill_text/>")),"text not silently omitted");
        Reject(()=>TraceParser.Parse("<!DOCTYPE x [<!ENTITY e SYSTEM 'file:///etc/passwd'>]><document>&e;</document>"),"DTD prohibited");
        Reject(()=>TraceParser.Parse(Trace(Stroke(Line,"alpha='0.5'"))),"transparency rejected");
        Reject(()=>TraceParser.Parse(Trace(Stroke(Line,"dash='1 2'"))),"dashed stroke rejected");
        Reject(()=>TraceParser.Parse(Trace(Stroke("<moveto x='NaN' y='0'/><lineto x='1' y='1'/>"))),"NaN rejected");
        Reject(()=>TraceParser.Parse("<document><page/><page/></document>"),"multipage rejected");
        var curve=TraceParser.Parse(Trace(Stroke("<moveto x='0' y='0'/><curveto x1='0' y1='50' x2='50' y2='50' x3='50' y3='0'/>")));
        Check(curve.Points.Count()>10 && Math.Abs(curve.Height-37.5*25.4/72)<0.01,"Bezier flattened within 0.01 mm");
        var reversal=new List<Point>{new Point(0,0)};Bezier.Flatten(reversal,reversal[0],new Point(100,0),new Point(-100,0),new Point(1,0));
        Check(reversal.Any(x=>x.X>20) && reversal.Any(x=>x.X< -20),"collinear curve reversal preserved");
        var cut=Hpgl.Build(drawing,hash,p,false); var motion=Hpgl.Build(drawing,hash,p,true);
        var operatorDrawing=new Drawing();var operatorPath=new CutPath { Closed=false };
        operatorPath.Points.AddRange(new[]{new Point(10,20),new Point(30,20),new Point(30,30)});operatorDrawing.Paths.Add(operatorPath);
        var identity=new CutSettings().Apply(operatorDrawing);
        Check(identity.Width==20 && identity.Height==10 && identity.Points.First().X==0 && identity.Points.First().Y==0,"cut settings default 100% preserves mm, normalized origin");
        Check(operatorDrawing.Points.First().X==10 && !Object.ReferenceEquals(identity.Paths[0],operatorPath),"cut settings never mutate original geometry");
        var rotated=new CutSettings(100,90).Apply(operatorDrawing);
        Check(rotated.Width==10 && rotated.Height==20 && rotated.Points.First().X==10 && rotated.Points.Last().X==0,"90-degree operator rotation preserves exact asymmetric coordinates");
        var half=new CutSettings(50,270,true).Apply(operatorDrawing);
        Check(half.Width==5 && half.Height==10 && !half.Paths[0].Closed && half.Points.First().X==0 && half.Points.First().Y==0,"operator mirror, rotation, reduction preserve open paths");
        var twice=new CutSettings(100,180,false,true).Apply(operatorDrawing);
        Check(twice.Points.First().X==20 && twice.Points.First().Y==0 && twice.Width==20,"mirror Y before 180-degree rotation exact coordinates");
        Check(new CutSettings(25).Apply(drawing).Paths[0].Closed,"closed paths remain closed after operator settings");
        Check(new CutSettings(50).Apply(operatorDrawing).Width==10 && new CutSettings().Apply(operatorDrawing).Width==20,"reapplying settings from original does not accumulate scale");
        foreach(double scale in new[]{0d,101d,Double.NaN,Double.PositiveInfinity})
            Reject(()=>new CutSettings(scale),"unsafe operator scale rejected "+scale);
        Reject(()=>new CutSettings(100,45),"unsupported operator angle rejected");
        var originalMotion=Hpgl.Build(identity,hash,p,true);var rotatedMotion=Hpgl.Build(rotated,hash,p,true);
        Check(originalMotion.Hash!=rotatedMotion.Hash && originalMotion.ProfileHash==rotatedMotion.ProfileHash,"rehearsal bound to changed geometry even with same source and machine");
        Check(rotatedMotion.Commands.Contains("PU480,80;") && rotatedMotion.Commands.Contains("PU80,880;"),"operator preview geometry becomes exact HPGL coordinates");
        var outside=new Drawing();var outsidePath=new CutPath { Closed=false };outsidePath.Points.AddRange(new[]{new Point(0,0),new Point(40,40)});outside.Paths.Add(outsidePath);
        Reject(()=>Hpgl.Build(new CutSettings().Apply(outside),hash,p,false),"operator settings do not bypass measured machine limits");
        Check(cut.Commands.First()=="IN;" && cut.Commands.Last()=="PU;" && cut.Commands.Any(x=>x.StartsWith("PD")),"HPGL initialization and blade control");
        Check(!motion.Commands.Any(x=>x.StartsWith("PD")),"motion only never lowers blade");
        Reject(()=>Hpgl.Build(drawing,hash,new MachineProfile(),false),"unverified protocol blocked");
        p.WidthMm=5;Reject(()=>Hpgl.Build(drawing,hash,p,false),"limits block movement");p.WidthMm=30;
        var folder=Path.Combine(Path.GetTempPath(),"foison-tests-"+Guid.NewGuid());
        var sender=new Sender(folder); var wire=new FakeWire();
        Reject(()=>sender.Send(cut,new Authorization(),()=>wire,CancellationToken.None),"default authorization blocked");Check(!wire.Opened,"blocked job never opens serial");
        sender.Send(cut,Approve(cut),()=>wire,CancellationToken.None);Check(wire.Data.SequenceEqual(cut.Commands),"simulated serial complete exact stream");
        Reject(()=>sender.Send(cut,Approve(cut),()=>new FakeWire(),CancellationToken.None),"persistent idempotency");
        var bad=new FakeWire { Fail=true };var folder2=folder+"-fail";
        Reject(()=>new Sender(folder2).Send(motion,Approve(motion),()=>bad,CancellationToken.None),"write failure propagated");
        Check(bad.Aborted && File.Exists(Path.Combine(folder2,"INTERRUPTED")),"abort and uncertainty latch");
        Reject(()=>new Sender(folder2).Send(cut,Approve(cut),()=>new FakeWire(),CancellationToken.None),"latched session blocks further jobs");
        var cts=new CancellationTokenSource();cts.Cancel();var unopened=new FakeWire();
        Reject(()=>new Sender(folder+"cancel").Send(cut,Approve(cut),()=>unopened,cts.Token),"cancel before open");Check(!unopened.Opened,"cancelled job sends nothing");
        var mismatch=Approve(cut);mismatch.PlanHash=motion.Hash;
        Reject(()=>new Sender(folder+"mismatch").Send(cut,mismatch,()=>new FakeWire(),CancellationToken.None),"authorization bound to exact plan");
        var busyWire=new FakeWire { Occupied=true };string busyFolder=folder+"busy";
        Reject(()=>new Sender(busyFolder).Send(cut,Approve(cut),()=>busyWire,CancellationToken.None),"occupied serial port blocks without forcing");
        Check(!Directory.GetFiles(busyFolder,"*.sent").Any() && !busyWire.Data.Any(),"occupied port writes zero commands and no consumed attempt");
        using(var midCancel=new CancellationTokenSource())
        {
            var cancelWire=new FakeWire { AfterWrite=()=>midCancel.Cancel() };
            Reject(()=>new Sender(folder+"midcancel").Send(cut,Approve(cut),()=>cancelWire,midCancel.Token),"cancel during send");
            Check(cancelWire.Data.Count==1 && cancelWire.Aborted && File.Exists(Path.Combine(folder+"midcancel","INTERRUPTED")),"no commands after cancellation, persistent uncertain latch");
        }
        bool contention=false;var contendedWire=new FakeWire();
        var firstWire=new FakeWire { AfterWrite=()=> {
            if(contention)return;contention=true;
            Check(File.Exists(Path.Combine(folder+"concurrent","INTERRUPTED")),"crash-safety latch exists before first serial byte");
            Reject(()=>new Sender(folder+"concurrent").Send(motion,Approve(motion),()=>contendedWire,CancellationToken.None),"second sender excluded by shared journal lock");
        } };
        new Sender(folder+"concurrent").Send(cut,Approve(cut),()=>firstWire,CancellationToken.None);
        Check(!contendedWire.Opened,"concurrent sender cannot open serial");
        var asym=TraceParser.Parse(Trace(Stroke("<moveto x='10' y='20'/><lineto x='30' y='20'/><lineto x='30' y='30'/>")));
        Check(Math.Abs(asym.Paths[0].Points[0].X-10*25.4/72)<1e-9 && Math.Abs(asym.Paths[0].Points[0].Y-20*25.4/72)<1e-9,"asymmetric affine coordinates and Y-up verified numerically");
        p.SwapAxes=true;p.ReverseY=true;
        var mapped=Hpgl.Build(asym,hash,p,false);
        Check(mapped.Commands.Contains("PU80,362;") && mapped.Commands.Contains("PD221,80;"),"explicit axis mapping without scale-to-fit");
        p=Profile();
        if(args.Length>=3)
        {
            var converted=new Converter(args[0],args[1]).Convert(Path.Combine(args[2],"square-20mm.ps"),folder+"-convert",CancellationToken.None);
            Check(Math.Abs(converted.Width-20)<0.01 && Math.Abs(converted.Height-20)<0.01,"REAL PostScript interpreter square 20 x 20 mm");
            var end=Hpgl.Build(converted,hash,Profile(),false);var serial=new FakeWire();new Sender(folder+"-e2e").Send(end,Approve(end),()=>serial,CancellationToken.None);
            Check(serial.Data.Contains("PD880,880;"),"E2E PostScript to simulated serial exact 800-unit square");
        }
        
        if(args.Length>=3)
        {
            var converter=new Converter(args[0],args[1]);
            var clipped=converter.Convert(Path.Combine(args[2],"page-clip.ps"),folder+"-pageclip",CancellationToken.None);
            Check(Math.Abs(clipped.Width-20)<0.01 && Math.Abs(clipped.Height-20)<0.01,"REAL nonintersecting rectangular driver/page clip preserves square");
            var curves=converter.Convert(Path.Combine(args[2],"curves-open-closed.ps"),folder+"-curves",CancellationToken.None);
            Check(curves.Paths.Count==2 && !curves.Paths[0].Closed && curves.Paths[1].Closed,"REAL bound PostScript procedures, curves, open and filled closed paths");
            Check(Math.Abs(curves.Paths[0].Points.Max(x=>x.X)-curves.Paths[0].Points.Min(x=>x.X)-20)<0.01,"REAL transformed curve scale");
            foreach(var file in new[]{"reject-raster.ps","reject-clip.ps","reject-multipage.ps"})
                Reject(()=>converter.Convert(Path.Combine(args[2],file),folder+file,CancellationToken.None),"REAL reject "+file);
            using(var cancellation=new CancellationTokenSource(300))
                Reject(()=>converter.Convert(Path.Combine(args[2],"reject-loop.ps"),folder+"loop",cancellation.Token),"REAL infinite PS bounded by cancellation");
        }
        if(args.Length>=4)
        {
            string captures=folder+"-spool";Directory.CreateDirectory(captures);
            bool dll=args[3].EndsWith(".dll",StringComparison.OrdinalIgnoreCase);
            for(int i=0;i<2;i++)
            {
                var start=new System.Diagnostics.ProcessStartInfo(dll?"dotnet":args[3],(dll?Converter.Quote(args[3])+" ":"")+"--output-dir "+Converter.Quote(captures)) { UseShellExecute=false,RedirectStandardInput=true };
                start.EnvironmentVariables["FOISON_RUN_ID"]="receiver-contract-test";
                using(var receiver=System.Diagnostics.Process.Start(start))
                {
                    byte[] bytes=File.ReadAllBytes(Path.Combine(args[2],"square-20mm.ps"));
                    receiver.StandardInput.BaseStream.Write(bytes,0,bytes.Length);receiver.StandardInput.Close();
                    if(!receiver.WaitForExit(10000)) {receiver.Kill();throw new Exception("receiver timeout");}
                    Check(receiver.ExitCode==0,"simulated spooler stdin accepted #"+i);
                }
            }
            Check(Directory.GetFiles(captures,"*.raw").Length==2 && Directory.GetFiles(captures,"*.json").Length==2,"atomic capture markers and unique concurrent identities");
            Check(Directory.GetFiles(Path.Combine(captures,"diagnostics"),"receiver-*.log").Length==2,"each Receiver attempt logged before parser and UI");
            Check(Directory.GetFiles(captures,"*.json").All(f=>File.ReadAllText(f).Contains("receiver-contract-test") && File.ReadAllText(f).Contains("\"status\": \"captured\"")),"accepted capture metadata carries correlated RunId");
            Check(Directory.GetFiles(Path.Combine(captures,"diagnostics"),"receiver-*.log").All(f=>File.ReadAllText(f).Contains("STDIN_EOF") && File.ReadAllText(f).Contains("QUEUE_REGISTERED") && File.ReadAllText(f).Contains("sha256=")),"Receiver logs EOF, hash and queue publication");
            string raw=Directory.GetFiles(captures,"*.raw")[0];
            Check(MachineProfile.FileHash(raw)==MachineProfile.FileHash(Path.Combine(args[2],"square-20mm.ps")),"binary spool simulation preserves exact SHA256 without encoding preamble");
            var d=new Converter(args[0],args[1]).Convert(raw,folder+"-spool-convert",CancellationToken.None);
            var plan=Hpgl.Build(d,MachineProfile.FileHash(raw),Profile(),false);var serial=new FakeWire();
            new Sender(folder+"-spool-send").Send(plan,Approve(plan),()=>serial,CancellationToken.None);
            Check(serial.Data.Contains("PD880,880;"),"E2E receiver stdin → actual interpreters → geometry → HPGL → fake serial");
            string rejected=folder+"-reject";Directory.CreateDirectory(rejected);
            var rejectStart=new System.Diagnostics.ProcessStartInfo(dll?"dotnet":args[3],(dll?Converter.Quote(args[3])+" ":"")+"--output-dir "+Converter.Quote(rejected)) { UseShellExecute=false,RedirectStandardInput=true };
            using(var receiver=System.Diagnostics.Process.Start(rejectStart))
            {
                byte[] unknown=new byte[]{0,255,13,10,0x7f,0x80};receiver.StandardInput.BaseStream.Write(unknown,0,unknown.Length);receiver.StandardInput.Close();
                if(!receiver.WaitForExit(10000)) {receiver.Kill();throw new Exception("unsupported-format receiver timeout");}
                Check(receiver.ExitCode==2,"unsupported binary format returns nonzero rather than false success");
            }
            Check(Directory.GetFiles(rejected,"*.raw").Length==0 && Directory.GetFiles(Path.Combine(rejected,"attempts"),"attempt-*.json").Length==1,"rejected bytes are not retained; rejection metadata survives");
            Check(Directory.GetFiles(Path.Combine(rejected,"diagnostics"),"receiver-*.log").Select(File.ReadAllText).Any(x=>x.Contains("unsupported print stream format") && x.Contains("EXIT") && x.Contains("exit_code=2")),"unsupported-format failure is diagnosable with stage and exit code");
        }
        Console.WriteLine(count+" checks passed. No physical hardware used.");
    }
    sealed class FakeWire : IWire
    {
        public bool Opened,Aborted,Fail,Occupied;public Action AfterWrite;public List<string> Data=new List<string>();
        public void Open() { if(Occupied)throw new IOException("busy");Opened=true; }
        public void Write(string c,CancellationToken t) { t.ThrowIfCancellationRequested();if(Fail) throw new TimeoutException();Data.Add(c);AfterWrite?.Invoke(); }
        public void Drain(CancellationToken t) { t.ThrowIfCancellationRequested(); }
        public void Abort() { Aborted=true; }
        public void Dispose() { }
    }
}
