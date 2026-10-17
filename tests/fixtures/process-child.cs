// C# 2 / CLR 2 fixture. Only temporary files/std streams; never device APIs.
using System;
using System.IO;
using System.Text;
using System.Threading;
public static class ProcessChild {
 public static int Main(string[] args) {
  Stream output=Console.OpenStandardOutput(), error=Console.OpenStandardError();
  string mode=args[0];
  if(mode=="args") {
   for(int i=1;i<args.Length;i++) {
    byte[] line=Encoding.ASCII.GetBytes(Convert.ToBase64String(Encoding.UTF8.GetBytes(args[i]))+"\n");
    output.Write(line,0,line.Length);
   }
   return 0;
  }
  if(mode=="flood") {
   byte[] data=new byte[16384];for(int i=0;i<data.Length;i++)data[i]=(byte)(i%256);
   for(int i=0;i<128;i++){output.Write(data,0,data.Length);error.Write(data,0,data.Length);}
   return 0;
  }
  if(mode=="binary") {
   byte[] data=new byte[256];for(int i=0;i<256;i++)data[i]=(byte)i;
   output.Write(data,0,data.Length);error.Write(data,0,data.Length);return 0;
  }
  if(mode=="oem") {
   byte[] data=Encoding.GetEncoding(850).GetBytes("Configuração da impressora Foison C24.\r\n");
   output.Write(data,0,data.Length);error.Write(data,0,data.Length);return 0;
  }
  byte[] text=File.ReadAllBytes(args[1]);output.Write(text,0,text.Length);
  byte[] failure=Encoding.UTF8.GetBytes("stderr evidence: Não foi possível executar o processo.\r\n");
  error.Write(failure,0,failure.Length);
  if(mode=="timeout")Thread.Sleep(10000);
  return mode=="zero" ? 0 : 27;
 }
}
