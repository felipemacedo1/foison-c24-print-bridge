using System;
using System.Diagnostics;
using System.Drawing;
using System.IO;
using System.IO.Compression;
using System.Linq;
using System.Threading;
using System.Threading.Tasks;
using System.Windows.Forms;
using FoisonC24.Core;

namespace FoisonC24.Diagnostic
{
    internal static class Program
    {
        internal static readonly string Home=AppDomain.CurrentDomain.BaseDirectory;
        internal static Converter Converter() => new Converter(Path.Combine(Home,"tools","gs","bin","gswin64c.exe"),Path.Combine(Home,"tools","mupdf","mutool.exe"));
        [STAThread]
        private static int Main(string[] args)
        {
            if(args.Contains("--selftest") || (args.Length==2 && args[0]=="--capture-check"))
            {
                Console.SetOut(new StreamWriter(Console.OpenStandardOutput(),new System.Text.UTF8Encoding(false)) { AutoFlush=true });
                Console.SetError(new StreamWriter(Console.OpenStandardError(),new System.Text.UTF8Encoding(false)) { AutoFlush=true });
                string scratch=Path.Combine(Path.GetTempPath(),"FoisonC24-selftest-"+Guid.NewGuid());
                string evidence=Path.Combine(Path.GetTempPath(),"FoisonC24-selftest-error.txt");
                try
                {
                    string input=args[0]=="--capture-check"?args[1]:Path.Combine(Home,"testes","square-20mm.ps");
                    var d=Converter().Convert(input,scratch,CancellationToken.None);
                    if(Math.Abs(d.Width-20)>0.05 || Math.Abs(d.Height-20)>0.05) throw new InvalidDataException("Escala inválida: "+d.SizeLabel+"; esperado 20 x 20 mm.");
                    Console.WriteLine("RunId="+Environment.GetEnvironmentVariable("FOISON_RUN_ID")+" PASS vetor "+d.SizeLabel+"; serial não aberta; corte físico NÃO executado.");
                    return 0;
                }
                catch(Exception e) {
                    string detail="RunId="+Environment.GetEnvironmentVariable("FOISON_RUN_ID")+" "+e;
                    Console.Error.WriteLine(detail);
                    File.WriteAllText(evidence,detail,System.Text.Encoding.UTF8);return 2;
                }
                finally { if(Directory.Exists(scratch))Directory.Delete(scratch,true); }
            }
            Application.EnableVisualStyles(); Application.SetCompatibleTextRenderingDefault(false);
            if(args.Length==3 && args[0]=="--ui-smoke")
            {
                using(var form=new MainForm())
                {
                    form.SmokeDrawing=Converter().Convert(args[2],Path.Combine(Path.GetTempPath(),"FoisonC24-ui-"+Guid.NewGuid()),CancellationToken.None);
                    form.Show(); Application.DoEvents();
                    if(!form.PhysicalButtonsBlocked) throw new InvalidOperationException("UI physical gate not blocked by default");
                    using(var bitmap=new Bitmap(form.Width,form.Height)) { form.DrawToBitmap(bitmap,new Rectangle(0,0,form.Width,form.Height)); bitmap.Save(args[1]); }
                    form.SmokeSettings();
                    using(var dialog=new CutSettingsDialog(new CutSettings(),"COM2",form.PreviewDrawing))
                    {
                        dialog.Show(form);Application.DoEvents();
                        using(var bitmap=new Bitmap(dialog.Width,dialog.Height)) { dialog.DrawToBitmap(bitmap,new Rectangle(0,0,dialog.Width,dialog.Height));bitmap.Save(Path.Combine(Path.GetDirectoryName(args[1]),Path.GetFileNameWithoutExtension(args[1])+"-settings.png")); }
                        dialog.Close();
                    }
                    form.Close();return 0;
                }
            }
            Application.Run(new MainForm());return 0;
        }
    }
    internal sealed class MainForm : Form
    {
        private readonly string data=Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.CommonApplicationData),"FoisonC24");
        private readonly ListBox jobs=new ListBox { Dock=DockStyle.Fill };
        private readonly Label status=new Label { Dock=DockStyle.Top,Height=105 };
        private readonly PictureBox preview=new PictureBox { Dock=DockStyle.Fill,BackColor=Color.White };
        private readonly FlowLayoutPanel buttons=new FlowLayoutPanel { Dock=DockStyle.Bottom,Height=100,AutoScroll=true };
        private readonly System.Windows.Forms.Timer timer=new System.Windows.Forms.Timer { Interval=2000 };
        private Drawing drawing,originalDrawing; private string source,jobHash,motionKey;
        private CutSettings settings=new CutSettings();
        private readonly Label settingsLabel=new Label { Dock=DockStyle.Top,Height=48 };
        private MachineProfile profile; private CancellationTokenSource cancel;
        private readonly TextBox port=new TextBox { Text="COM2",Width=70 };
        private Button stop,motionButton,cutButton;
        internal Drawing SmokeDrawing { set { originalDrawing=value;drawing=settings.Apply(value);preview.Invalidate(); } }
        internal Drawing PreviewDrawing => drawing;
        internal void SmokeSettings()
        {
            double width=originalDrawing.Width,height=originalDrawing.Height;
            ApplySettings(new CutSettings(50,90,true),"COM2");
            if(Math.Abs(drawing.Width-height/2)>0.001 || Math.Abs(drawing.Height-width/2)>0.001 || !PhysicalButtonsBlocked)
                throw new InvalidOperationException("Cut settings preview/gate regression");
            ApplySettings(new CutSettings(),"COM2");
            if(Math.Abs(drawing.Width-width)>0.001 || Math.Abs(drawing.Height-height)>0.001 || !PhysicalButtonsBlocked)
                throw new InvalidOperationException("Cut settings accumulated geometry or authorized physical output");
        }
        internal bool PhysicalButtonsBlocked => !motionButton.Enabled && !cutButton.Enabled;
        public MainForm()
        {
            Text="Foison C24 — painel de corte (sessão acompanhada)";Width=1150;Height=790;
            MinimumSize=new Size(1020,720);
            status.Text="1. No CorelDRAW, abra o quadrado 20 mm e imprima em Foison C24 (Teste), escala 100%.\r\n2. Selecione o trabalho e confira a prévia. O envio começa BLOQUEADO.\r\n3. O desenvolvedor valida a máquina; cada movimento/corte exige nova confirmação.";
            var guide=new Label { Dock=DockStyle.Top,Height=65,Text="CONFIGURAÇÕES DE CORTE: use este painel, não as Propriedades PostScript do CorelDRAW.\r\n1. Imprima 100%, uma cópia → 2. Selecione e abra a prévia → 3. Configurações de corte → 4. Validar máquina (dev) → ensaio → corte.\r\nForça e velocidade: painel da plotter. Não altere a impressora/FTDI/FlexiSIGN para configurar o Bridge." };
            Controls.Add(preview);Controls.Add(buttons);Controls.Add(settingsLabel);Controls.Add(status);Controls.Add(guide);
            var left=new Panel { Dock=DockStyle.Left,Width=230 };left.Controls.Add(jobs);Controls.Add(left);
            Add("Atualizar trabalhos",RefreshJobs);Add("Pré-visualizar",async()=>await ConvertSelected());
            Add("Configurações de corte",ConfigureCut);
            Add("Validar máquina (dev)",ApproveMachine);Add("Diagnóstico",Diagnose);Add("Exportar relatório",Export);
            buttons.Controls.Add(port);motionButton=Add("Movimento sem lâmina",async()=>await Send(true));cutButton=Add("Primeiro corte",async()=>await Send(false));
            stop=Add("INTERROMPER ENVIO",()=> { cancel?.Cancel(); status.Text="Cancelando envio. Use PAUSE/OFFLINE no painel. Fechar COM não garante parar o buffer da plotter. Não repita o trabalho."; });
            stop.BackColor=Color.MistyRose;
            port.TextChanged+=(s,e)=> { profile=null;motionKey=null;UpdateGates(); };
            jobs.SelectedIndexChanged+=(s,e)=> { if(cancel!=null)return;drawing=null;originalDrawing=null;source=null;jobHash=null;motionKey=null;preview.Invalidate();UpdateGates(); };
            preview.Paint+=PaintPreview;
            timer.Tick+=(s,e)=> { if(cancel==null) { try { RefreshJobs(); } catch(Exception error) { timer.Stop();Error(error); } } };timer.Start();RefreshJobs();UpdateGates();
            FormClosing+=(s,e)=> { if(cancel!=null) { cancel.Cancel();e.Cancel=true;MessageBox.Show("Aguarde a interrupção e use o painel da plotter. O buffer pode continuar executando."); } };
        }
        private Button Add(string text,Action action)
        {
            var button=new Button { Text=text,AutoSize=true,Height=32 };
            button.Click+=(s,e)=> { try { action(); } catch(Exception error) { Error(error); } };buttons.Controls.Add(button);return button;
        }
        private void Busy(bool value)
        { foreach(Control c in buttons.Controls) c.Enabled=!value; stop.Enabled=value; jobs.Enabled=!value;UpdateGates(); }
        private void UpdateGates()
        {
            settingsLabel.Text=settings.Summary+"\r\n"+port.Text+" · 38400 8N1 Xon/Xoff | origem + 2 mm | força/velocidade no painel | uma cópia";
            stop.Enabled=cancel!=null;
            motionButton.Enabled=cancel==null && drawing!=null && profile!=null;
            cutButton.Enabled=motionButton.Enabled && motionKey!=null && motionKey==Hpgl.Build(drawing,jobHash,profile,true).Hash;
        }
        private void ConfigureCut()
        {
            using(var dialog=new CutSettingsDialog(settings,port.Text,originalDrawing))
            {
                if(dialog.ShowDialog(this)!=DialogResult.OK)return;
                ApplySettings(dialog.Settings,dialog.PortName);
            }
        }
        private void ApplySettings(CutSettings next,string portName)
        {
            settings=next;motionKey=null;
            port.Text=portName; // Port changes also revoke the device profile.
            drawing=originalDrawing==null?null:settings.Apply(originalDrawing);
            status.Text=drawing==null?"Ajustes aplicados. Imprima no CorelDRAW e abra a prévia.":"Prévia de corte: "+drawing.SizeLabel+". Ajustes aplicados a partir do original, sem acumular escala/rotação.\r\nEnsaio anterior invalidado: confira a geometria e repita o movimento sem lâmina antes do corte.";
            preview.Invalidate();UpdateGates();
        }
        private void Error(Exception e)
        {
            UpdateGates();
            status.Text="BLOQUEADO — "+e.Message;
            try { Directory.CreateDirectory(Path.Combine(data,"session"));File.AppendAllText(Path.Combine(data,"session","diagnostic.log"),DateTime.UtcNow.ToString("O")+" "+e.GetType().Name+": "+e.Message+Environment.NewLine); } catch(IOException) { }
            MessageBox.Show(e.Message+"\r\nNenhum reenvio automático será feito. Se houve transmissão, confira PAUSE/OFFLINE no painel.",Text,MessageBoxButtons.OK,MessageBoxIcon.Warning);
        }
        private void RefreshJobs()
        {
            string folder=Path.Combine(data,"captures");if(!Directory.Exists(folder))return;
            foreach(var file in Directory.GetFiles(folder,"job-*.json").OrderBy(f=>f))
            {
                string name=Path.GetFileNameWithoutExtension(file);
                if(File.Exists(Path.Combine(folder,name+".raw")) && !jobs.Items.Contains(name)) jobs.Items.Add(name);
            }
            if(jobs.SelectedIndex<0 && jobs.Items.Count>0) jobs.SelectedIndex=jobs.Items.Count-1;
        }
        private async Task ConvertSelected()
        {
            if(jobs.SelectedItem==null) { MessageBox.Show("Imprima pelo CorelDRAW e selecione o trabalho na lista.");return; }
            cancel=new CancellationTokenSource();Busy(true);drawing=null;originalDrawing=null;motionKey=null;
            try
            {
                source=Path.Combine(data,"captures",jobs.SelectedItem+".raw");jobHash=MachineProfile.FileHash(source);
                string scratch=Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),"FoisonC24","conversion-"+Guid.NewGuid());
                originalDrawing=await Task.Run(()=>Program.Converter().Convert(source,scratch,cancel.Token));
                if(MachineProfile.FileHash(source)!=jobHash) throw new IOException("Captura mudou durante a conversão.");
                drawing=settings.Apply(originalDrawing);
                status.Text="Prévia: "+drawing.SizeLabel+" — "+drawing.Paths.Count+" caminhos.\r\nX → direita; Y ↑. Origem do desenho normalizada, sem escala automática; margem de 2 mm no envio.\r\nContornos são linhas centrais; preenchimentos viram perímetros. Confira caminhos e remova fundo/duplicatas. Envio ainda exige validação.";
                preview.Invalidate();
            }
            catch(Exception e) { drawing=null;originalDrawing=null;Error(e); }
            finally { cancel.Dispose();cancel=null;Busy(false); }
        }
        private void ApproveMachine()
        {
            profile=null;motionKey=null;
            using(var dialog=new MachineDialog())
                if(dialog.ShowDialog(this)==DialogResult.OK) { profile=dialog.Profile;status.Text="Perfil verificado nesta sessão. Nenhum comando foi enviado. Confira prévia, escala, origem e material antes de cada autorização."; }
            UpdateGates();
        }
        private async Task Send(bool motion)
        {
            if(drawing==null || profile==null) { MessageBox.Show("Envio BLOQUEADO. Abra a prévia e peça ao desenvolvedor para validar a máquina.");return; }
            try
            {
                if(MachineProfile.FileHash(source)!=jobHash) throw new IOException("Captura alterada. Converta novamente.");
                var plan=Hpgl.Build(drawing,jobHash,profile,motion);
                // Bind rehearsal to the exact transformed trajectory, not just the raw file.
                string key=Hpgl.Build(drawing,jobHash,profile,true).Hash;
                if(!motion && motionKey!=key) throw new InvalidOperationException("Faça e observe primeiro o movimento sem lâmina deste desenho/perfil.");
                using(var confirm=new ConfirmationDialog(drawing.SizeLabel,motion,port.Text,profile,plan,settings.Summary))
                {
                    if(confirm.ShowDialog(this)!=DialogResult.OK)return;
                }
                var approval=new Authorization { PlanHash=plan.Hash,DeveloperApproved=true,GeometryMeasured=true,OriginAndLimitsChecked=true,OperatorConfirmed=true,BladeRemovedForMotion=motion,MotionObserved=motionKey==key };
                string portName=port.Text;
                cancel=new CancellationTokenSource();Busy(true);
                try
                {
                    await Task.Run(()=>new Sender(Path.Combine(data,"session")).Send(plan,approval,()=>new SerialWire(portName),cancel.Token));
                    status.Text="Bytes entregues ao driver serial. Isso NÃO confirma execução física. Confira a máquina; não repita automaticamente.";
                    if(motion && MessageBox.Show("O desenvolvedor observou o movimento completo, lâmina removida, direções/origem corretas, limites respeitados e escala medida?\r\nO spooler/USB não confirma o término físico. Aguarde a máquina parar antes de responder.",Text,MessageBoxButtons.YesNo,MessageBoxIcon.Warning,MessageBoxDefaultButton.Button2)==DialogResult.Yes) motionKey=key;
                }
                finally { cancel.Dispose();cancel=null;Busy(false); }
            }
            catch(Exception e) { motionKey=null;Error(e); }
        }
        private void PaintPreview(object sender,PaintEventArgs e)
        {
            if(drawing==null)return;
            float scale=(float)Math.Min((preview.Width-70)/Math.Max(1,drawing.Width),(preview.Height-70)/Math.Max(1,drawing.Height));
            using(var pen=new Pen(Color.DarkBlue,1))
            foreach(var path in drawing.Paths)
            {
                var points=path.Points.Select(p=>new PointF(35+(float)(p.X-drawing.MinX)*scale,preview.Height-35-(float)(p.Y-drawing.MinY)*scale)).ToArray();
                e.Graphics.DrawLines(pen,points);if(path.Closed)e.Graphics.DrawLine(pen,points.Last(),points.First());
            }
            e.Graphics.DrawString(drawing.SizeLabel+" | X →  Y ↑",Font,Brushes.Black,5,5);
        }
        private void Diagnose()
        {
            string spooler;
            try { using(var s=new System.ServiceProcess.ServiceController("Spooler")) spooler=s.Status.ToString(); } catch(Exception e) { spooler=e.Message; }
            string processes=String.Join(", ",Process.GetProcesses().Where(p=>p.ProcessName.IndexOf("flexi",StringComparison.OrdinalIgnoreCase)>=0 || p.ProcessName.IndexOf("production",StringComparison.OrdinalIgnoreCase)>=0).Select(p=>p.ProcessName));
            string report="Spooler: "+spooler+"\r\nPortas visíveis: "+String.Join(", ",System.IO.Ports.SerialPort.GetPortNames())+"\r\nProcessos possivelmente relevantes: "+processes+" (não identifica proprietário da porta)\r\n"+
                "Instalação: "+(File.Exists(Path.Combine(data,"install-state.properties"))?"manifesto presente":"sem manifesto do Bridge")+"\r\nFila e driver devem ser confirmados no CorelDRAW.\r\nInterrupção pendente: "+File.Exists(Path.Combine(data,"session","INTERRUPTED"))+"\r\n"+
                "Configuração serial: "+port.Text+" / 38400 / 8N1 / Xon/Xoff. Nenhuma sondagem ou escrita foi feita.\r\n"+
                "Cancelamento descarta somente o buffer do PC. PAUSE/OFFLINE no painel é obrigatório. Nunca envie reset desconhecido.\r\n"+
                "Falhas de captura: veja receiver-errors.log; conversão: diagnóstico exportável. FTDI/FlexiSIGN não são alterados.";
            status.Text=report;MessageBox.Show(report,Text);
        }
        private void Export()
        {
            using(var dialog=new SaveFileDialog { Filter="ZIP|*.zip",FileName="FoisonC24-diagnostico.zip",OverwritePrompt=true })
            {
                if(dialog.ShowDialog()!=DialogResult.OK)return;
                using(var f=new FileStream(dialog.FileName,FileMode.Create))
                using(var zip=new ZipArchive(f,ZipArchiveMode.Create))
                {
                    foreach(var folder in new[]{data,Path.Combine(data,"captures"),Path.Combine(data,"session"),Path.Combine(data,"Logs")})
                    if(Directory.Exists(folder)) foreach(var file in Directory.GetFiles(folder).Where(x=>x.EndsWith(".properties") || x.EndsWith(".json") || x.EndsWith(".log") || x.EndsWith(".sent") || Path.GetFileName(x)=="INTERRUPTED")) zip.CreateEntryFromFile(file,Path.GetFileName(folder)+"/"+Path.GetFileName(file));
                }
                MessageBox.Show("Relatório exportado sem arquivos brutos/PDF/vetores. Revise os erros antes de compartilhar: podem conter caminhos locais ou trechos de mensagens do interpretador.");
            }
        }
    }
}
