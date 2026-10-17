using System;
using System.ComponentModel;
using System.Runtime.InteropServices;
using System.Text;
using System.Collections.Generic;
using System.IO;
using System.Text.RegularExpressions;
using System.Linq;

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

        private const string QueueName = "Foison C24 (Teste)";
        [StructLayout(LayoutKind.Sequential, CharSet=CharSet.Unicode)]
        private struct MonitorInfo { public string Name, Environment, Dll; }
        [StructLayout(LayoutKind.Sequential, CharSet=CharSet.Unicode)]
        private struct PrinterInfo
        {
            public string Server, Name, Share, Port, Driver, Comment, Location;
            public IntPtr DevMode;
            public string Separator, Processor, Datatype, Parameters;
            public IntPtr Security;
            public uint Attributes, Priority, DefaultPriority, StartTime, UntilTime, Status, Jobs, AveragePpm;
        }
        [DllImport("winspool.drv",CharSet=CharSet.Unicode,SetLastError=true)]
        private static extern bool EnumMonitors(string name,uint level,IntPtr data,uint size,out uint needed,out uint count);
        [DllImport("winspool.drv",CharSet=CharSet.Unicode,SetLastError=true)]
        private static extern IntPtr AddPrinter(string server,uint level,ref PrinterInfo info);
        [DllImport("winspool.drv",CharSet=CharSet.Unicode,SetLastError=true)]
        private static extern bool GetPrinter(IntPtr handle,uint level,IntPtr data,uint size,out uint needed);
        [DllImport("winspool.drv",CharSet=CharSet.Unicode,SetLastError=true)]
        private static extern bool SetPrinter(IntPtr handle,uint level,ref PrinterInfo info,uint command);
        [DllImport("winspool.drv",SetLastError=true)]
        private static extern bool DeletePrinter(IntPtr handle);

        private static int Main(string[] args)
        {
            try
            {
                Console.OutputEncoding=new System.Text.UTF8Encoding(false);
                if(args.Length==1 && args[0]=="monitor-status") return MonitorPresent()?0:3;
                if(args.Length==1 && args[0]=="list-ports") { foreach(var p in ListPorts())Console.WriteLine(p);return 0; }
                if(args.Length==2 && args[0]=="list-ports-file") { File.WriteAllLines(args[1],ListPorts());return 0; }
                if(args.Length==2 && (args[0]=="add-port" || args[0]=="remove-port")) { ConfigureRedMonPort(args[1],args[0]=="add-port"?"AddPort":"DeletePort");return 0; }
                if((args.Length==3 || args.Length==4) && args[0]=="configure-port") { ConfigureReceiver(args[1],args[2],args.Length==4?args[3]:null);return 0; }
                if((args.Length==3 || args.Length==4) && args[0]=="verify-port") { VerifyPort(args[1],args[2],args.Length==4?args[3]:null);return 0; }
                if(args.Length==2 && args[0]=="verify-empty-port") { var c=ReadConfig(args[1]);if(!String.IsNullOrEmpty(c.Command) || !String.IsNullOrEmpty(c.Arguments))throw new InvalidOperationException("Porta ja configurada externamente; preservada.");return 0; }
                if(args.Length==5 && (args[0]=="add-queue" || args[0]=="remove-queue" || args[0]=="adopt-queue" || args[0]=="probe-queue")) { QueueOperation(args[0],args[1],args[2],args[3],args[4]);if(args[0]=="probe-queue")PrintSquare();return 0; }
                Console.Error.WriteLine("Uso: monitor-status | list-ports[-file path] | add-port/remove-port FOISONC24n: | configure-port/verify-port port receiver [owner] | add-queue/remove-queue/adopt-queue name port driver owner");return 64;
            }
            catch(Exception e) { Console.Error.WriteLine("RunId="+Environment.GetEnvironmentVariable("FOISON_RUN_ID")+" "+e);return 1; }
        }
        private static bool MonitorPresent()
        {
            uint needed,count;
            bool result=EnumMonitors(null,2,IntPtr.Zero,0,out needed,out count);
            int error=Marshal.GetLastWin32Error();
            if(needed==0) { if(result)return false;throw new Win32Exception(error,"EnumMonitors falhou."); }
            IntPtr data=Marshal.AllocHGlobal(checked((int)needed));
            try
            {
                if(!EnumMonitors(null,2,data,needed,out needed,out count))throw new Win32Exception(Marshal.GetLastWin32Error());
                bool found=false;int size=Marshal.SizeOf(typeof(MonitorInfo));
                for(int i=0;i<count;i++)
                {
                    var m=(MonitorInfo)Marshal.PtrToStructure(IntPtr.Add(data,i*size),typeof(MonitorInfo));
                    if(m.Name!="Redirected Port")continue;
                    if(found || !String.Equals(Path.GetFileName(m.Dll),"redmon64.dll",StringComparison.OrdinalIgnoreCase) || m.Environment!="Windows x64")throw new InvalidOperationException("Monitor Redirected Port conflitante; nao sera substituido.");
                    found=true;
                }
                return found;
            }
            finally { Marshal.FreeHGlobal(data); }
        }
        private static void ValidatePort(string port) { if(!Regex.IsMatch(port??"","^FOISONC24[1-9][0-9]*:$"))throw new ArgumentException("Porta fora do namespace Bridge."); }
        private static string Owner(string owner) { if(!Regex.IsMatch(owner??"","^[a-f0-9]{32}$"))throw new ArgumentException("Identificador de propriedade invalido.");return "Foison C24 Print Bridge "+owner; }
        private static RedMonConfig ReadConfig(string port)
        {
            ValidatePort(port);IntPtr handle;
            var defaults=new PrinterDefaults { DesiredAccess=ServerAdminister };
            if(!OpenPrinter(",XcvMonitor Redirected Port",out handle,ref defaults))throw new Win32Exception(Marshal.GetLastWin32Error());
            int size=Marshal.SizeOf(typeof(RedMonConfig));IntPtr input=Marshal.StringToHGlobalUni(port),buffer=Marshal.AllocHGlobal(size);
            try
            {
                if(size!=6180)throw new InvalidOperationException("Layout RECONFIG inesperado.");
                CallXcv(handle,"GetConfig",input,(uint)((port.Length+1)*2),buffer,(uint)size);
                var c=(RedMonConfig)Marshal.PtrToStructure(buffer,typeof(RedMonConfig));
                if(c.Size!=size || c.Version!=190 || c.Port!=port)throw new InvalidOperationException("Contrato RedMon 1.9 nao comprovado.");
                return c;
            }
            finally { Marshal.FreeHGlobal(input);Marshal.FreeHGlobal(buffer);ClosePrinter(handle); }
        }
        private static void VerifyPort(string port,string receiver,string owner)
        {
            var c=ReadConfig(port);
            if(!String.Equals(c.Command,Path.GetFullPath(receiver),StringComparison.OrdinalIgnoreCase) || c.Arguments!="" || c.Output!=0 || c.RunUser!=0 || c.Show!=0 || c.Delay!=30 || c.LogFileUse!=0 || c.LogFileDebug!=0 || c.PrintError!=0 || (owner!=null && c.Description!=Owner(owner)))
                throw new InvalidOperationException("Configuracao/propriedade RedMon divergente; preservada.");
        }
        private static void QueueOperation(string op,string name,string port,string driver,string owner)
        {
            ValidatePort(port);string marker=Owner(owner);
            if(name!=QueueName || String.IsNullOrWhiteSpace(driver))throw new ArgumentException("Fila/driver invalido.");
            if(op=="add-queue")
            {
                var info=new PrinterInfo { Name=name,Port=port,Driver=driver,Comment=marker,Processor="WinPrint",Datatype="RAW",Attributes=0x40,Priority=1,DefaultPriority=1 };
                IntPtr created=AddPrinter(null,2,ref info);
                if(created==IntPtr.Zero)throw new Win32Exception(Marshal.GetLastWin32Error(),"AddPrinter nao criou a fila.");
                ClosePrinter(created);return;
            }
            IntPtr handle;var defaults=new PrinterDefaults { DesiredAccess=0x000F000C }; // PRINTER_ALL_ACCESS, including GetPrinter/SetPrinter rights
            if(!OpenPrinter(name,out handle,ref defaults))throw new Win32Exception(Marshal.GetLastWin32Error());
            IntPtr buffer=IntPtr.Zero;
            try
            {
                uint needed;GetPrinter(handle,2,IntPtr.Zero,0,out needed);
                if(needed==0)throw new Win32Exception(Marshal.GetLastWin32Error());
                buffer=Marshal.AllocHGlobal(checked((int)needed));
                if(!GetPrinter(handle,2,buffer,needed,out needed))throw new Win32Exception(Marshal.GetLastWin32Error());
                var info=(PrinterInfo)Marshal.PtrToStructure(buffer,typeof(PrinterInfo));
                if(info.Name!=name || info.Port!=port || info.Driver!=driver || ((op=="remove-queue" || op=="probe-queue") && info.Comment!=marker))throw new InvalidOperationException("Fila alterada externamente; preservada.");
                if(op=="adopt-queue")
                {
                    if(!String.IsNullOrEmpty(info.Comment) && !info.Comment.StartsWith("Foison C24 Print Bridge ",StringComparison.Ordinal))throw new InvalidOperationException("Comentario legado externo; fila preservada.");
                    info.Comment=marker;
                    if(!SetPrinter(handle,2,ref info,0))throw new Win32Exception(Marshal.GetLastWin32Error());
                }
                else if(op=="remove-queue" && !DeletePrinter(handle))throw new Win32Exception(Marshal.GetLastWin32Error());
            }
            finally { if(buffer!=IntPtr.Zero)Marshal.FreeHGlobal(buffer);ClosePrinter(handle); }
        }

        // Only a verified Bridge queue receives this GDI vector probe. Receiver never
        // transmits; this is not a CorelDRAW test and cannot prove physical cutting.
        private static void PrintSquare()
        {
            using(var document=new System.Drawing.Printing.PrintDocument())
            {
                document.PrinterSettings.PrinterName=QueueName;
                document.PrintController=new System.Drawing.Printing.StandardPrintController();
                document.DocumentName="Foison capture probe 20mm - no serial";
                document.PrintPage+=(sender,e)=> {
                    e.Graphics.PageUnit=System.Drawing.GraphicsUnit.Millimeter;
                    using(var pen=new System.Drawing.Pen(System.Drawing.Color.Black,0.01f)) e.Graphics.DrawRectangle(pen,20,20,20,20);
                    e.HasMorePages=false;
                };
                document.Print();
                Console.WriteLine("Spool submitted; capture/conversion still require independent verification. Physical cut NOT performed.");
            }
        }

        private static IEnumerable<string> ListPorts()
        {
            uint needed, returned;
            bool probe = EnumPorts(null, LevelOne, IntPtr.Zero, 0, out needed, out returned);
            if (needed == 0 && probe) yield break;
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

        private static void ConfigureReceiver(string port, string receiver, string owner)
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
                if(owner!=null)config.Description=Owner(owner);
                config.Command=Path.GetFullPath(receiver);config.Arguments="";config.Output=0;config.Show=0;config.RunUser=0;
                config.Delay=30;config.LogFileUse=0;config.LogFileDebug=0;config.PrintError=0;
                Marshal.StructureToPtr(config,buffer,false);
                CallXcv(handle,"SetConfig",buffer,(uint)size,IntPtr.Zero,0);
                CallXcv(handle,"GetConfig",input,(uint)((port.Length+1)*2),buffer,(uint)size);
                var actual=(RedMonConfig)Marshal.PtrToStructure(buffer,typeof(RedMonConfig));
                if(actual.Command!=config.Command || actual.Arguments!="" || actual.Output!=0 || actual.RunUser!=0 || actual.Delay!=30 || (owner!=null && actual.Description!=Owner(owner)))
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
