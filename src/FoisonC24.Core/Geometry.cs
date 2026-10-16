using System;
using System.Collections.Generic;
using System.Globalization;
using System.Linq;

namespace FoisonC24.Core
{
    public struct Point
    {
        public readonly double X, Y;
        public Point(double x, double y) { X = Finite(x); Y = Finite(y); }
        public static double Finite(double x)
        {
            if (Double.IsNaN(x) || Double.IsInfinity(x) || Math.Abs(x) > 10000000)
                throw new InvalidOperationException("Coordenada não finita ou excessiva.");
            return x;
        }
        public static Point Mid(Point a, Point b) => new Point((a.X+b.X)/2, (a.Y+b.Y)/2);
    }
    public sealed class CutPath
    {
        public List<Point> Points { get; } = new List<Point>();
        public bool Closed { get; set; }
    }
    public sealed class Drawing
    {
        public List<CutPath> Paths { get; } = new List<CutPath>();
        public IEnumerable<Point> Points => Paths.SelectMany(p => p.Points);
        public double MinX => Points.Min(p => p.X);
        public double MinY => Points.Min(p => p.Y);
        public double Width => Points.Max(p => p.X) - MinX;
        public double Height => Points.Max(p => p.Y) - MinY;
        public string SizeLabel => Width.ToString("F3", CultureInfo.InvariantCulture) + " × " + Height.ToString("F3", CultureInfo.InvariantCulture) + " mm";
        public void Validate()
        {
            if (Paths.Count == 0 || Paths.Count > 10000 || Points.Count() > 100000)
                throw new InvalidOperationException("Desenho vazio ou complexo demais (10000 caminhos / 100000 pontos).");
            if (Paths.Any(p => p.Points.Count < 2)) throw new InvalidOperationException("Caminho sem movimento.");
            foreach (var p in Points) { Point.Finite(p.X); Point.Finite(p.Y); }
        }
    }
    public static class Bezier
    {
        // Convex-hull distance to the chord bounds error, including collinear reversals.
        public static void Flatten(List<Point> output, Point a, Point b, Point c, Point d, int depth = 0)
        {
            if (output.Count >= 100000) throw new InvalidOperationException("Curva complexa demais.");
            if (Math.Max(Distance(b,a,d), Distance(c,a,d)) <= 0.01) { output.Add(d); return; }
            if (depth >= 24) throw new InvalidOperationException("Tolerância da curva não convergiu.");
            var ab = Point.Mid(a,b); var bc = Point.Mid(b,c); var cd = Point.Mid(c,d);
            var abc = Point.Mid(ab,bc); var bcd = Point.Mid(bc,cd); var mid = Point.Mid(abc,bcd);
            Flatten(output,a,ab,abc,mid,depth+1); Flatten(output,mid,bcd,cd,d,depth+1);
        }
        private static double Distance(Point p, Point a, Point b)
        {
            double x=b.X-a.X, y=b.Y-a.Y, l=x*x+y*y;
            double t=l==0 ? 0 : Math.Max(0,Math.Min(1,((p.X-a.X)*x+(p.Y-a.Y)*y)/l));
            return Math.Sqrt(Math.Pow(p.X-a.X-t*x,2)+Math.Pow(p.Y-a.Y-t*y,2));
        }
    }
}
