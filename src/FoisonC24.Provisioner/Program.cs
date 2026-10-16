using System;
using System.ComponentModel;
using System.Runtime.InteropServices;
using System.Text;
using System.Collections.Generic;

namespace FoisonC24.Provisioner
{
    internal static class Program
    {
        private const uint ServerAdminister = 0x00000001;
        private const uint LevelOne = 1;

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

        [DllImport("winspool.drv", CharSet = CharSet.Unicode, SetLastError = true)]
        private static extern int XcvData(IntPtr handle, string dataName,
            IntPtr input, uint inputSize, IntPtr output, uint outputSize,
            out uint outputNeeded, out uint status);

        [DllImport("winspool.drv", CharSet = CharSet.Unicode, SetLastError = true)]
        private static extern bool EnumPorts(string name, uint level, IntPtr buffer,
            uint bufferSize, out uint needed, out uint returned);

        private static int Main(string[] args)
        {
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
                Console.Error.WriteLine("Usage: FoisonC24Provisioner.exe add-port|remove-port RPT1:");
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
            if (String.IsNullOrWhiteSpace(portName) || !portName.EndsWith(":"))
                throw new ArgumentException("A porta deve terminar com ':'");
            IntPtr handle;
            PrinterDefaults defaults = new PrinterDefaults { DesiredAccess = ServerAdminister };
            if (!OpenPrinter(",XcvMonitor RedMon", out handle, ref defaults))
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
                        throw new Win32Exception((int)status,
                            "O monitor RedMon não conseguiu executar " + operation + " para " + portName + ".");
                }
                finally { Marshal.FreeHGlobal(input); }
            }
            finally { ClosePrinter(handle); }
        }
    }
}
