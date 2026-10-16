using System;
using System.IO;
using System.Text;
using System.Text.RegularExpressions;

namespace FoisonC24.Core
{
    public static class PostScriptEnvelope
    {
        private const string Uel="\x1b%-12345X";
        public static byte[] Normalize(byte[] raw)
        {
            if(raw.Length==0 || raw.Length>64*1024*1024) throw new InvalidDataException("Trabalho vazio ou acima de 64 MiB.");
            int start=raw[0]==4 ? 1 : 0;
            if(At(raw,start,Uel))
            {
                int limit=Math.Min(raw.Length,start+8192), ps=-1;
                for(int i=start+Uel.Length;i+5<=limit;i++)
                    if(At(raw,i,"%!PS-") && (raw[i-1]==10 || raw[i-1]==13)) { ps=i;break; }
                if(ps<0) throw new InvalidDataException("Envelope PJL sem PostScript verificável.");
                for(int i=start+Uel.Length;i<ps;i++) if(raw[i]>126 || (raw[i]<32 && raw[i]!=9 && raw[i]!=10 && raw[i]!=13)) throw new InvalidDataException("Cabeçalho PJL binário não suportado.");
                var lines=Encoding.ASCII.GetString(raw,start+Uel.Length,ps-start-Uel.Length).Split(new[]{'\r','\n'},StringSplitOptions.RemoveEmptyEntries);
                bool enter=false;
                foreach(var line in lines)
                {
                    string text=line.Trim();
                    if(Regex.IsMatch(text,"^@PJL ENTER LANGUAGE\\s*=\\s*POSTSCRIPT$",RegexOptions.IgnoreCase)) { if(enter)throw new InvalidDataException("PJL ambíguo.");enter=true; }
                    else if(enter || !Regex.IsMatch(text,"^@PJL (JOB|SET|COMMENT)( |$)",RegexOptions.IgnoreCase)) throw new InvalidDataException("Comando PJL não suportado.");
                }
                if(!enter) throw new InvalidDataException("PJL não declara LANGUAGE=POSTSCRIPT.");
                start=ps;
            }
            if(!At(raw,start,"%!PS-")) throw new InvalidDataException("A fila não produziu PostScript verificável. Confirme o driver PScript e saída ASCII.");
            int end=raw.Length;
            // A bounded terminal PJL wrapper is metadata only; it is never executed or sent to serial.
            for(int i=Math.Max(start,raw.Length-8192);i<=raw.Length-Uel.Length;i++)
                if(At(raw,i,Uel))
                {
                    string tail=Encoding.ASCII.GetString(raw,i,raw.Length-i).Replace(Uel,"");
                    if(!Regex.IsMatch(tail,"^[\\x04\\r\\n\\t ]*(?:@PJL EOJ[^\\x00-\\x08\\x0b\\x0c\\x0e-\\x1f]*[\\r\\n]*)?$",RegexOptions.IgnoreCase))
                        throw new InvalidDataException("Trailer PJL não suportado.");
                    end=i;break;
                }
            while(end>start && (raw[end-1]==10 || raw[end-1]==13 || raw[end-1]==32 || raw[end-1]==9))end--;
            if(end>start && raw[end-1]==4)end--;
            var result=new byte[end-start];Array.Copy(raw,start,result,0,result.Length);return result;
        }
        private static bool At(byte[] raw,int offset,string text)
        {
            if(offset<0 || offset+text.Length>raw.Length)return false;
            for(int i=0;i<text.Length;i++)if(raw[offset+i]!=(byte)text[i])return false;
            return true;
        }
    }
}
