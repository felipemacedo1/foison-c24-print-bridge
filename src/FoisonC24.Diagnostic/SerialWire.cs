using System;
using System.Diagnostics;
using System.IO;
using System.IO.Ports;
using System.Threading;
using FoisonC24.Core;

namespace FoisonC24.Diagnostic
{
    internal sealed class SerialWire : IWire
    {
        private readonly SerialPort port;
        private readonly Stopwatch deadline = new Stopwatch();
        public SerialWire(string name)
        {
            if (!System.Text.RegularExpressions.Regex.IsMatch(name,"^COM[1-9][0-9]*$")) throw new ArgumentException("Porta COM inválida.");
            port = new SerialPort(name,38400,Parity.None,8,StopBits.One) {
                Handshake=Handshake.XOnXOff, DtrEnable=false, RtsEnable=false,
                ReadTimeout=500,WriteTimeout=1000,WriteBufferSize=1024
            };
        }
        public void Open()
        {
            try { port.Open(); deadline.Start(); }
            catch(UnauthorizedAccessException e) { throw new IOException("Porta ocupada ou acesso negado. Feche o FlexiSIGN/Production Manager normalmente; não será forçada a liberação. O proprietário da porta não foi identificado.",e); }
        }
        private void Check(CancellationToken cancel)
        { cancel.ThrowIfCancellationRequested(); if(deadline.ElapsedMilliseconds>30000) throw new TimeoutException("Envio excedeu 30 segundos. O estado físico é incerto."); }
        public void Write(string command,CancellationToken cancel)
        {
            Check(cancel);
            // Small, complete ASCII commands only. No replay or undocumented reset/force/speed commands.
            while(port.BytesToWrite>0) { Check(cancel); Thread.Sleep(10); }
            port.Write(command); Check(cancel);
        }
        public void Drain(CancellationToken cancel)
        { while(port.BytesToWrite>0) { Check(cancel); Thread.Sleep(10); } Check(cancel); }
        public void Abort()
        {
            try { if(port.IsOpen) port.DiscardOutBuffer(); } catch(IOException) { }
            finally { if(port.IsOpen) port.Close(); }
        }
        public void Dispose() { port.Dispose(); }
    }
}
