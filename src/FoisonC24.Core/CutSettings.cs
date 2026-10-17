using System;

namespace FoisonC24.Core
{
    // Operator geometry is independent of the verified device axes/protocol.
    // No settings file can authorize a physical send.
    public sealed class CutSettings
    {
        public double ScalePercent { get; }
        public int RotationDegrees { get; }
        public bool MirrorX { get; }
        public bool MirrorY { get; }
        public CutSettings(double scalePercent=100, int rotationDegrees=0, bool mirrorX=false, bool mirrorY=false)
        {
            if(Double.IsNaN(scalePercent) || Double.IsInfinity(scalePercent) || scalePercent<1 || scalePercent>100)
                throw new InvalidOperationException("Escala de corte deve estar entre 1 e 100%. Para ampliar, altere o desenho no CorelDRAW e imprima novamente (100%, sem ajustar à página).");
            if(rotationDegrees!=0 && rotationDegrees!=90 && rotationDegrees!=180 && rotationDegrees!=270)
                throw new InvalidOperationException("Rotação deve ser 0, 90, 180 ou 270 graus.");
            ScalePercent=scalePercent;RotationDegrees=rotationDegrees;MirrorX=mirrorX;MirrorY=mirrorY;
        }
        public string Summary => "Escala "+ScalePercent.ToString("0.###",System.Globalization.CultureInfo.InvariantCulture)+"% | rotação "+RotationDegrees+"° | espelhar X: "+(MirrorX?"sim":"não")+" / Y: "+(MirrorY?"sim":"não");
        public Drawing Apply(Drawing original)
        {
            original.Validate();
            double minX=original.MinX,minY=original.MinY,width=original.Width,height=original.Height,scale=ScalePercent/100;
            var result=new Drawing();
            foreach(var path in original.Paths)
            {
                var transformed=new CutPath { Closed=path.Closed };
                foreach(var p in path.Points)
                {
                    double x=p.X-minX,y=p.Y-minY;
                    if(MirrorX)x=width-x;
                    if(MirrorY)y=height-y;
                    double tx=x,ty=y;
                    switch(RotationDegrees)
                    {
                        case 90: tx=height-y;ty=x;break;
                        case 180: tx=width-x;ty=height-y;break;
                        case 270: tx=y;ty=width-x;break;
                    }
                    transformed.Points.Add(new Point(tx*scale,ty*scale));
                }
                result.Paths.Add(transformed);
            }
            result.Validate();return result;
        }
    }
}
