using System;
using System.ComponentModel;
using System.Runtime.InteropServices;
using System.Text;

namespace FoisonC24.Provisioner
{
    internal static class Program
    {
        private const uint ServerAdminister = 0x00000001;

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

        private static int Main(string[] args)
        {
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
