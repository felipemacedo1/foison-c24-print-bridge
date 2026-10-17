"""UI integration contracts supplement (not replace) actual C# geometry/UI tests."""
import unittest
from pathlib import Path

ROOT = Path(__file__).parents[1]


class CutSettingsContractTests(unittest.TestCase):
    def test_ui_uses_one_transformed_model_for_preview_and_hpgl(self):
        ui = (ROOT / 'src/FoisonC24.Diagnostic/Program.cs').read_text(encoding='utf-8')
        self.assertIn('drawing=settings.Apply(originalDrawing)', ui)
        self.assertIn('foreach(var path in drawing.Paths)', ui)
        self.assertIn('Hpgl.Build(drawing,jobHash,profile,motion)', ui)
        self.assertIn('Hpgl.Build(drawing,jobHash,profile,true).Hash', ui)
        apply = ui.split('private void ApplySettings(', 1)[1].split('private void Error(', 1)[0]
        self.assertIn('motionKey=null', apply)
        self.assertNotIn('new SerialWire', apply)
        self.assertIn('settings.Summary', ui)
        dialog = (ROOT / 'src/FoisonC24.Diagnostic/Dialogs.cs').read_text(encoding='utf-8')
        self.assertIn('+settingsSummary+', dialog)

    def test_shortcut_is_owned_and_safe_to_uninstall(self):
        nsis = (ROOT / 'packaging/windows/FoisonC24-Setup.nsi').read_text(encoding='utf-8-sig')
        name = '$DESKTOP\\Foison C24 - Configurações de corte.lnk'
        self.assertIn('CreateShortCut "' + name + '"', nsis)
        self.assertIn('Delete "' + name + '"', nsis)
        self.assertNotIn('rundll32', nsis.lower())

    def test_documented_driver_boundary_and_unverified_commands(self):
        guide = (ROOT / 'docs/corel-cut-settings.md').read_text(encoding='utf-8')
        for text in ['não adiciona', 'Força, velocidade', 'ainda não executados', '1–100%']:
            self.assertIn(text, guide)

    def test_capture_diagnostic_is_read_only_and_exported_without_job_content(self):
        diagnostic = (ROOT / 'src/FoisonC24.Diagnostic/CaptureDiagnostics.cs').read_text(encoding='utf-8')
        for forbidden in ['SerialPort', 'new SerialWire', '.Print(', '.StartService(', '.SetValue(', 'File.ReadAllBytes', 'DocumentName']:
            self.assertNotIn(forbidden, diagnostic)
        for required in ['CAPTURE_FOLDER', 'SPOOLER', 'QUEUE', 'REDMON', 'TimeSpan.FromSeconds(5)', 'ArgumentsEmpty=']:
            self.assertIn(required, diagnostic)
        ui = (ROOT / 'src/FoisonC24.Diagnostic/Program.cs').read_text(encoding='utf-8')
        self.assertIn('zip.CreateEntry("capture-diagnostics.txt")', ui)

    def test_win7_spooler_snapshot_is_packaged_and_read_only(self):
        script = (ROOT / 'packaging/windows/Collect-Print-Diagnostics-Win7.ps1').read_text(encoding='utf-8-sig')
        nsis = (ROOT / 'packaging/windows/FoisonC24-Setup.nsi').read_text(encoding='utf-8-sig')
        build = (ROOT / 'scripts/build-release.py').read_text(encoding='utf-8')
        workflow = (ROOT / '.github/workflows/windows-build.yml').read_text(encoding='utf-8')
        report_builder = (ROOT / 'src/FoisonC24.Diagnostic/GuidedDiagnosticReport.cs').read_text(encoding='utf-8')
        for required in ['Get-WmiObject Win32_Printer', 'Get-WmiObject Win32_PrintJob', 'REDMON_READBACK', 'CAPTURE_METADATA_ONLY', 'No settings changed', 'UTF8Encoding($true)']:
            self.assertIn(required, script)
        for forbidden in ['Set-ItemProperty', 'Set-Service', 'Restart-Service', 'SerialPort', 'File.ReadAllBytes', 'DocumentName', 'JobName']:
            self.assertNotIn(forbidden, script)
        self.assertIn('File "Collect-Print-Diagnostics-Win7.ps1"', nsis)
        self.assertIn("'Collect-Print-Diagnostics-Win7.ps1'", build)

    def test_guided_capture_diagnostic_is_packaged_and_observes_live_print(self):
        receiver = (ROOT / 'src/FoisonC24.WindowsReceiver/Program.cs').read_text(encoding='utf-8')
        guided = (ROOT / 'src/FoisonC24.Diagnostic/GuidedDiagnosticForm.cs').read_text(encoding='utf-8')
        diagnostic = (ROOT / 'src/FoisonC24.Diagnostic/Program.cs').read_text(encoding='utf-8')
        cmd = (ROOT / 'packaging/windows/FoisonC24-Diagnostico.cmd').read_text(encoding='ascii')
        nsis = (ROOT / 'packaging/windows/FoisonC24-Setup.nsi').read_text(encoding='utf-8-sig')
        build = (ROOT / 'scripts/build-release.py').read_text(encoding='utf-8')
        workflow = (ROOT / '.github/workflows/windows-build.yml').read_text(encoding='utf-8')
        report_builder = (ROOT / 'src/FoisonC24.Diagnostic/GuidedDiagnosticReport.cs').read_text(encoding='utf-8')
        for marker in ['STDIN_OPEN', 'FIRST_BYTE', 'STDIN_EOF', 'FORMAT', 'QUEUE_REGISTERED', 'REJECTION_METADATA', 'exit_code=', 'sha256=']:
            self.assertIn(marker, receiver)
        for marker in ['Win32_ProcessStartTrace', 'Win32_ProcessStopTrace', 'Win32_PrintJob', 'StartMonitoring', 'RunDirectExperiment', 'EnvironmentVariables["FOISON_RUN_ID"]', 'capture-metadata.json', 'checksums.txt', 'COM2 não foi aberta']:
            self.assertIn(marker, guided)
        self.assertIn('--guided-diagnosis', diagnostic)
        self.assertIn('--guided-diagnosis', cmd)
        self.assertIn('File "FoisonC24-Diagnostico.cmd"', nsis)
        self.assertIn('Diagnóstico da captura.lnk', nsis)
        self.assertIn("'FoisonC24-Diagnostico.cmd'", build)
        self.assertIn('--diagnostic-report-smoke', diagnostic)
        self.assertIn('GuidedDiagnosticReport.CreateZip', guided)
        self.assertIn('diagnostic-report-smoke', workflow)
        self.assertIn('files.Any', report_builder)
        self.assertIn('checksums.txt', report_builder)
