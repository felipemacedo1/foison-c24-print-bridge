using System;
using System.Collections.Generic;
using System.Globalization;
using System.IO;
using System.Linq;
using System.Xml;
using System.Xml.Linq;

namespace FoisonC24.Core
{
    // MuPDF trace coordinates are points, transformed to page coordinates (Y down).
    // The cutting model is mm, X right / Y up, relative to page bottom left.
    public static class TraceParser
    {
        private const double Mm = 25.4 / 72;
        private static double N(string s) => Point.Finite(Double.Parse(s, CultureInfo.InvariantCulture));
        private static double A(XElement e, string name) => N((string)e.Attribute(name) ?? throw new InvalidDataException("Falta " + name));
        public static Drawing Parse(string xml)
        {
            if (xml.Length > 32*1024*1024) throw new InvalidDataException("Trace acima de 32 MiB.");
            XDocument doc;
            using (var reader = XmlReader.Create(new StringReader(xml), new XmlReaderSettings { DtdProcessing = DtdProcessing.Prohibit, XmlResolver = null, MaxCharactersInDocument = 32*1024*1024 }))
                doc = XDocument.Load(reader);
            var pages = doc.Descendants("page").ToArray();
            if (pages.Length != 1) throw new InvalidDataException("Imprima somente uma página por trabalho.");
            var box = ((string)pages[0].Attribute("mediabox") ?? "").Split(new[]{' '}, StringSplitOptions.RemoveEmptyEntries).Select(N).ToArray();
            if (box.Length != 4 || box[2] <= box[0] || box[3] <= box[1]) throw new InvalidDataException("Página inválida.");
            var drawing = new Drawing();
            foreach (var op in pages[0].Elements())
            {
                string name = op.Name.LocalName;
                if (name == "set_default_colorspaces") continue;
                if (name != "stroke_path" && name != "fill_path")
                    throw new InvalidDataException("Conteúdo não suportado para corte: " + name + ". Converta texto em curvas; remova imagens, efeitos e recortes.");
                var alpha = (string)op.Attribute("alpha");
                if (alpha != null && N(alpha) != 1) throw new InvalidDataException("Transparência não suportada.");
                if (name == "stroke_path" && op.Attribute("dash") != null && ((string)op.Attribute("dash")).Trim().Length > 0)
                    throw new InvalidDataException("Tracejado não suportado; converta o contorno em curvas.");
                var m = ((string)op.Attribute("transform") ?? "1 0 0 1 0 0").Split(new[]{' '}, StringSplitOptions.RemoveEmptyEntries).Select(N).ToArray();
                if (m.Length != 6 || Math.Abs(m[0]*m[3]-m[1]*m[2]) < 1e-12) throw new InvalidDataException("Transformação singular.");
                Func<XElement,string,string,Point> point = (e,x,y) => {
                    double px=A(e,x), py=A(e,y);
                    return new Point((m[0]*px+m[2]*py+m[4]-box[0])*Mm, (box[3]-m[1]*px-m[3]*py-m[5])*Mm);
                };
                CutPath path = null;
                Action finish = () => {
                    if (path == null) return;
                    if (name == "fill_path") path.Closed = true;
                    if (path.Points.Count > 1) drawing.Paths.Add(path);
                    path = null;
                };
                foreach (var node in op.Elements())
                {
                    switch (node.Name.LocalName)
                    {
                        case "moveto": finish(); path = new CutPath(); path.Points.Add(point(node,"x","y")); break;
                        case "lineto": Require(path); path.Points.Add(point(node,"x","y")); break;
                        case "curveto": Require(path); Bezier.Flatten(path.Points,path.Points.Last(),point(node,"x1","y1"),point(node,"x2","y2"),point(node,"x3","y3")); break;
                        case "closepath": Require(path); path.Closed=true; break;
                        default: throw new InvalidDataException("Operação vetorial desconhecida: " + node.Name);
                    }
                    if (drawing.Paths.Count > 10000 || (path != null && path.Points.Count > 100000)) throw new InvalidDataException("Complexidade excedida.");
                }
                finish();
            }
            drawing.Validate();
            // Never cut outside the printed page, even if a malicious trace bypasses clipping.
            if (drawing.MinX < -0.01 || drawing.MinY < -0.01 || drawing.Points.Any(p => p.X > (box[2]-box[0])*Mm+0.01 || p.Y > (box[3]-box[1])*Mm+0.01))
                throw new InvalidDataException("Geometria fora da página.");
            return drawing;
        }
        private static void Require(CutPath p) { if (p == null || p.Closed) throw new InvalidDataException("Sequência de caminho inválida."); }
    }
}
