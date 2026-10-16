using System;
using System.ComponentModel;
using System.Runtime.InteropServices;
using System.Text;
using System.Collections.Generic;
using System.IO;
using System.Text.RegularExpressions;

namespace FoisonC24.Provisioner
{
    internal static class Program
    {
        private const uint ServerAdminister = 0x00000001;
        private const uint LevelOne = 1;

        // RedMon 1.9 src/redmon.c RECONFIG, src/portmon.h MAXSTR=512.
        // DWORD and WCHAR only: layout is identical on x86/x64 (6180 bytes).
        [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)]
        private struct RedMonConfig
        {
            public uint Size, Version;
            [MarshalAs(UnmanagedType.ByValTStr, SizeConst=512)] public string Port;
            [MarshalAs(UnmanagedType.ByValTStr, SizeConst=512)] public string Description;
            [MarshalAs(UnmanagedType.ByValTStr, SizeConst=512)] public string Command;
            [MarshalAs(UnmanagedType.ByValTStr, SizeConst=512)] public string Arguments;
            [MarshalAs(UnmanagedType.ByValTStr, SizeConst=512)] public string Printer;
            public uint Output, Show, RunUser, Delay, LogFileUse;
            [MarshalAs(UnmanagedType.ByValTStr, SizeConst=512)] public string LogFileName;
            public uint LogFileDebug, PrintError;
        }

        [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)]
        private struct PortInfo
        {
            public string pName;
        }

        [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)]
        private struct PrinterDefaults
        {
            public IntPtr pDatatype;
            public IntPtr pDevMode;
            public uint DesiredAccess;
        }

        [DllImport("winspool.drv", CharSet = CharSet.Unicode, SetLastError = true)]
        private static extern bool OpenPrinter(string name, out IntPtr handle,
            ref PrinterDefaults defaults);

        [DllImport("winspool.drv", SetLastError = true)]
        private static extern bool ClosePrinter(IntPtr handle);

        [DllImport("winspool.drv", EntryPoint="XcvDataW", ExactSpelling=true, CharSet=CharSet.Unicode, SetLastError = true)]
        private static extern int XcvData(IntPtr handle, string dataName,
            IntPtr input, uint inputSize, IntPtr output, uint outputSize,
            out uint outputNeeded, out uint status);

        [DllImport("winspool.drv", CharSet = CharSet.Unicode, SetLastError = true)]
        private static extern bool EnumPorts(string name, uint level, IntPtr buffer,
            uint bufferSize, out uint needed, out uint returned);

        private static int Main(string[] args)
        {
            if (args.Length == 3 && args[0] == "configure-port")
            {
                try { ConfigureReceiver(args[1],args[2]); return 0; }
                catch(Exception e) { Console.Error.WriteLine(e.Message);return 1; }
            }
            if (args.Length == 1 && String.Equals(args[0], "list-ports",
                StringComparison.OrdinalIgnoreCase))
            {
                foreach (string port in ListPorts()) Console.WriteLine(port);
                return 0;
            }
            if (args.Length != 2 ||
                (!String.Equals(args[0], "add-port", StringComparison.OrdinalIgnoreCase) &&
                 !String.Equals(args[0], "remove-port", StringComparison.OrdinalIgnoreCase)))
            {
                Console.Error.WriteLine("Usage: FoisonC24Provisioner.exe add-port|remove-port FOISONC24n:; configure-port FOISONC24n: receiver.exe");
                return 64;
            }

            try
            {
                if (String.Equals(args[0], "add-port", StringComparison.OrdinalIgnoreCase))
                    ConfigureRedMonPort(args[1], "AddPort");
                else
                    ConfigureRedMonPort(args[1], "DeletePort");
                return 0;
            }
            catch (Exception error)
            {
                Console.Error.WriteLine(error.Message);
                return 1;
            }
        }

        private static IEnumerable<string> ListPorts()
        {
            uint needed, returned;
            EnumPorts(null, LevelOne, IntPtr.Zero, 0, out needed, out returned);
            if (needed == 0) throw new Win32Exception(Marshal.GetLastWin32Error(),
                "Não foi possível enumerar as portas do spooler.");
            IntPtr buffer = Marshal.AllocHGlobal((int)needed);
            try
            {
                if (!EnumPorts(null, LevelOne, buffer, needed, out needed, out returned))
                    throw new Win32Exception(Marshal.GetLastWin32Error(),
                        "Não foi possível enumerar as portas do spooler.");
                int size = Marshal.SizeOf(typeof(PortInfo));
                for (int i = 0; i < returned; i++)
                {
                    PortInfo info = (PortInfo)Marshal.PtrToStructure(
                        new IntPtr(buffer.ToInt64() + i * size), typeof(PortInfo));
                    if (!String.IsNullOrEmpty(info.pName)) yield return info.pName;
                }
            }
            finally { Marshal.FreeHGlobal(buffer); }
        }

        private static void ConfigureRedMonPort(string portName, string operation)
        {
            if (!Regex.IsMatch(portName ?? "", "^FOISONC24[0-9]+:$"))
                throw new ArgumentException("Somente portas exclusivas FOISONC24n: são permitidas.");
            IntPtr handle;
            PrinterDefaults defaults = new PrinterDefaults { DesiredAccess = ServerAdminister };
            if (!OpenPrinter(",XcvMonitor Redirected Port", out handle, ref defaults))
                throw new Win32Exception(Marshal.GetLastWin32Error(),
                    "Não foi possível abrir o monitor RedMon. Instale setup64.exe primeiro.");
            try
            {
                byte[] bytes = Encoding.Unicode.GetBytes(portName + "\0");
                IntPtr input = Marshal.AllocHGlobal(bytes.Length);
                try
                {
                    Marshal.Copy(bytes, 0, input, bytes.Length);
                    uint needed, status;
                    int result = XcvData(handle, operation, input, (uint)bytes.Length,
                        IntPtr.Zero, 0, out needed, out status);
                    if (result == 0 || status != 0)
                        throw new Win32Exception(result == 0 ? Marshal.GetLastWin32Error() : (int)status,
                            "O monitor RedMon não conseguiu executar " + operation + " para " + portName + ".");
                }
                finally { Marshal.FreeHGlobal(input); }
            }
            finally { ClosePrinter(handle); }
        }

        private static void ConfigureReceiver(string port, string receiver)
        {
            if (!Regex.IsMatch(port ?? "", "^FOISONC24[0-9]+:$") || !File.Exists(receiver) || receiver.Length >= 512)
                throw new ArgumentException("Porta/caminho do receptor inválidos.");
            IntPtr handle;
            var defaults=new PrinterDefaults { DesiredAccess=ServerAdminister };
            if(!OpenPrinter(",XcvMonitor Redirected Port",out handle,ref defaults)) throw new Win32Exception(Marshal.GetLastWin32Error());
            int size=Marshal.SizeOf(typeof(RedMonConfig));
            IntPtr input=Marshal.StringToHGlobalUni(port), buffer=Marshal.AllocHGlobal(size);
            try
            {
                if(size!=6180) throw new InvalidOperationException("Layout RECONFIG inesperado.");
                CallXcv(handle,"GetConfig",input,(uint)((port.Length+1)*2),buffer,(uint)size);
                var config=(RedMonConfig)Marshal.PtrToStructure(buffer,typeof(RedMonConfig));
                if(config.Size!=size || config.Version!=190 || config.Port!=port)
                    throw new InvalidOperationException("RedMon não corresponde ao contrato 1.9 verificado; configuração preservada.");
                config.Command=Path.GetFullPath(receiver);config.Arguments="";config.Output=0;config.Show=0;config.RunUser=0;
                config.Delay=30;config.LogFileUse=0;config.LogFileDebug=0;config.PrintError=0;
                Marshal.StructureToPtr(config,buffer,false);
                CallXcv(handle,"SetConfig",buffer,(uint)size,IntPtr.Zero,0);
                CallXcv(handle,"GetConfig",input,(uint)((port.Length+1)*2),buffer,(uint)size);
                var actual=(RedMonConfig)Marshal.PtrToStructure(buffer,typeof(RedMonConfig));
                if(actual.Command!=config.Command || actual.Arguments!="" || actual.Output!=0 || actual.RunUser!=0 || actual.Delay!=30)
                    throw new InvalidOperationException("Configuração RedMon não persistiu conforme esperado.");
            }
            finally { Marshal.FreeHGlobal(input);Marshal.FreeHGlobal(buffer);ClosePrinter(handle); }
        }
        private static void CallXcv(IntPtr handle,string operation,IntPtr input,uint length,IntPtr output,uint capacity)
        {
            uint needed,status;
            int result=XcvData(handle,operation,input,length,output,capacity,out needed,out status);
            if(result==0 || status!=0) throw new Win32Exception(result==0?Marshal.GetLastWin32Error():(int)status,"RedMon "+operation+" falhou.");
        }
    }
}
