using System;
using System.IO;
using System.Windows.Forms;
using FoisonC24.Core;

namespace FoisonC24.Diagnostic
{
    internal sealed class MachineDialog : Form
    {
        public MachineProfile Profile { get; private set; }
        private readonly FlowLayoutPanel body=new FlowLayoutPanel { Dock=DockStyle.Fill,FlowDirection=FlowDirection.TopDown,WrapContents=false,AutoScroll=true };
        public MachineDialog()
        {
            Text="Somente desenvolvedor — validar revisão real, não HPGL genérico";Width=790;Height=790;Controls.Add(body);
            body.Controls.Add(new Label { Text="Sem evidência da revisão real, cancele. Importar arquivo não comprova compatibilidade.\r\nConsulte docs/protocol.md e PRIMEIRA-SESSAO. Não presuma 40 unidades/mm pela precisão mecânica.",AutoSize=true });
            var revision=Field("Modelo/revisão/firmware observado","");
            var evidence=Field("Arquivo de evidência técnica ou saída FILE do FlexiSIGN (não .prt nativo)","");
            var browse=new Button { Text="Selecionar evidência",AutoSize=true };body.Controls.Add(browse);
            browse.Click+=(s,e)=> { using(var d=new OpenFileDialog()) if(d.ShowDialog()==DialogResult.OK)evidence.Text=d.FileName; };
            var units=Number("Unidades HPGL por mm comprovadas (não há valor padrão)",1,1000,0);
            var width=Number("Largura física livre medida, a partir da origem (mm, máximo 50)",1,50,0);
            var height=Number("Avanço físico livre medido, a partir da origem (mm, máximo 50)",1,50,0);
            var swap=Check("Trocar X e Y (somente se comprovado)");var rx=Check("Inverter X no desenho");var ry=Check("Inverter Y no desenho");
            var init=Check("Comprovei IN; sem movimento/descida inesperados na revisão real.");
            var absolute=Check("Comprovei PA; e PUx,y; (movimento absoluto), e estado de origem após IN.");
            var blade=Check("Comprovei PDx,y; para descer/mover e PU; para levantar. Nenhum comando adicional é necessário.");
            var resolution=Check("Comprovei resolução, eixos, escala 1:1, 38400/8N1/Xon-Xoff e estado de DTR/RTS desligados.");
            var limits=Check("Medi área livre e origem física. Força/velocidade baixas ajustadas no painel; não inferi área pelo modelo.");
            var risk=Check("Conheço PAUSE/OFFLINE e buffer da máquina. FlexiSIGN foi fechado normalmente. Não há trabalho pendente.");
            var ok=new Button { Text="Aprovar SOMENTE esta sessão",AutoSize=true };body.Controls.Add(ok);
            ok.Click+=(s,e)=> {
                try
                {
                    if(!limits.Checked || !risk.Checked)throw new InvalidOperationException("Condições de área e interrupção não confirmadas.");
                    if(!File.Exists(evidence.Text) || new FileInfo(evidence.Text).Length==0 || new FileInfo(evidence.Text).Length>16*1024*1024) throw new InvalidOperationException("Evidência deve ser arquivo local não vazio de até 16 MiB.");
                    var p=new MachineProfile { Revision=revision.Text,EvidenceSha256=MachineProfile.FileHash(evidence.Text),UnitsPerMm=(double)units.Value,WidthMm=(double)width.Value,HeightMm=(double)height.Value,
                        SwapAxes=swap.Checked,ReverseX=rx.Checked,ReverseY=ry.Checked,InitializationVerified=init.Checked,AbsoluteMovesVerified=absolute.Checked,BladeUpDownVerified=blade.Checked,ResolutionVerified=resolution.Checked };
                    p.Validate();Profile=p;DialogResult=DialogResult.OK;
                }
                catch(Exception error) { MessageBox.Show(error.Message); }
            };
        }
        private TextBox Field(string label,string text)
        { body.Controls.Add(new Label { Text=label,AutoSize=true });var c=new TextBox { Text=text,Width=730 };body.Controls.Add(c);return c; }
        private NumericUpDown Number(string label,decimal min,decimal max,decimal value)
        {
            body.Controls.Add(new Label { Text=label,AutoSize=true });
            // Zero is deliberately invalid until a measured value is entered.
            var c=new NumericUpDown { Minimum=0,Maximum=max,Value=value,DecimalPlaces=3,Width=160 };body.Controls.Add(c);return c;
        }
        private CheckBox Check(string text) { var c=new CheckBox { Text=text,AutoSize=true,MaximumSize=new System.Drawing.Size(740,0) };body.Controls.Add(c);return c; }
    }
    internal sealed class ConfirmationDialog : Form
    {
        public ConfirmationDialog(string size,bool motion,string port,MachineProfile p,CutPlan plan)
        {
            Text=motion ? "Autorizar movimento SEM lâmina" : "Autorizar CORTE FÍSICO";Width=770;Height=500;
            var body=new FlowLayoutPanel { Dock=DockStyle.Fill,FlowDirection=FlowDirection.TopDown,WrapContents=false };Controls.Add(body);
            body.Controls.Add(new Label { Text=(motion?"A máquina VAI se mover. Remova fisicamente a lâmina antes de continuar.":"A máquina VAI CORTAR. Insira a ferramenta somente com máquina parada, conforme o manual.")+"\r\nDesenho: "+size+"; origem normalizada + 2 mm; SEM ajuste de escala.\r\nPorta: "+port+" / 38400 8N1 Xon/Xoff; área "+p.WidthMm+" × "+p.HeightMm+" mm.\r\nUnidades/mm: "+p.UnitsPerMm+"; troca XY="+p.SwapAxes+"; inverter X="+p.ReverseX+"; Y="+p.ReverseY+".\r\nPlano: "+plan.Hash.Substring(0,16)+"\r\nCancelar no PC não garante parar movimentos já recebidos: use PAUSE/OFFLINE no painel.",AutoSize=true,MaximumSize=new System.Drawing.Size(740,0) });
            var geometry=new CheckBox { Text="Conferi a prévia, dimensões, orientação e contornos com o desenho no CorelDRAW (100%).",AutoSize=true };body.Controls.Add(geometry);
            var area=new CheckBox { Text="Origem física, margens e área livre foram conferidas. Ninguém está próximo do carro/material.",AutoSize=true };body.Controls.Add(area);
            var blade=new CheckBox { Text=motion?"Lâmina REMOVIDA; movimento com ferramenta erguida foi comprovado para esta revisão.":"Movimento anterior terminou e foi medido. Ferramenta/material e força/velocidade no painel estão seguros.",AutoSize=true,MaximumSize=new System.Drawing.Size(740,0) };body.Controls.Add(blade);
            var operatorCheck=new CheckBox { Text="Sou o operador e AUTORIZO este único envio, acompanhado pelo desenvolvedor.",AutoSize=true };body.Controls.Add(operatorCheck);
            var ok=new Button { Text=motion?"Autorizar movimento":"Autorizar corte",AutoSize=true };body.Controls.Add(ok);
            ok.Click+=(s,e)=> { if(geometry.Checked && area.Checked && blade.Checked && operatorCheck.Checked)DialogResult=DialogResult.OK;else MessageBox.Show("Todas as confirmações são obrigatórias."); };
            var back=new Button { Text="Não enviar",AutoSize=true };back.Click+=(s,e)=>DialogResult=DialogResult.Cancel;body.Controls.Add(back);CancelButton=back;
        }
    }
}
