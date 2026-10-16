import unittest
from pathlib import Path


ROOT = Path(__file__).parents[1]
SCRIPT = (ROOT / "packaging/windows/Install-Queue-Win7.ps1").read_text()
NSIS = (ROOT / "packaging/windows/FoisonC24-Setup.nsi").read_text()


class WindowsProvisioningContractTests(unittest.TestCase):
    def test_existing_queue_is_preserved_and_owned_state_is_required(self):
        self.assertIn("não pertence comprovadamente", SCRIPT)
        self.assertIn("install-state.json", SCRIPT)
        self.assertIn("ConvertFrom-StringData", SCRIPT)
        self.assertNotIn("if (Printer $PrinterName) { Remove-Queue }", SCRIPT)

    def test_ports_are_enumerated_and_project_owned(self):
        self.assertIn("list-ports", SCRIPT)
        self.assertIn("FOISONC24", SCRIPT)
        self.assertIn("EnumPorts", (ROOT / "src/FoisonC24.Provisioner/Program.cs").read_text())
        self.assertNotIn('$PortName = "RPT1:"', SCRIPT)

    def test_driver_selection_is_unambiguous(self):
        self.assertIn("matches.Count -ne 1", SCRIPT)
        self.assertIn("ntprint.inf", SCRIPT)
        self.assertNotIn("$drivers[0]", SCRIPT)

    def test_installer_attempts_rollback_and_does_not_remove_shared_redmon(self):
        self.assertIn('Install-Queue-Win7.cmd" uninstall', NSIS)
        self.assertIn("Nenhuma fila ou porta pertencente", NSIS)
        self.assertNotIn("unredmon", NSIS.lower())

    def test_physical_cut_remains_disabled(self):
        self.assertIn("physical_cut_enabled=false", SCRIPT)
        self.assertNotIn("COM2", SCRIPT)


if __name__ == "__main__":
    unittest.main()
