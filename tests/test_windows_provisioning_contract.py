import unittest
from pathlib import Path
ROOT = Path(__file__).parents[1]
SCRIPT = (ROOT/'packaging/windows/Install-Queue-Win7.ps1').read_text(encoding='utf-8-sig')
NSIS = (ROOT/'packaging/windows/FoisonC24-Setup.nsi').read_text(encoding='utf-8-sig')
CMD = (ROOT/'packaging/windows/Install-Queue-Win7.cmd').read_text(encoding='ascii')
class WindowsProvisioningContractTests(unittest.TestCase):
    def test_ps2_surface(self):
        for forbidden in ['ConvertTo-Json','ConvertFrom-Json','ConvertFrom-StringData','Add-Printer','Add-PrinterPort','Get-CimInstance','::new(', ' -in ', ' -notin ']:
            self.assertNotIn(forbidden,SCRIPT)
        self.assertIn('#requires -version 2.0',SCRIPT)
    def test_state_safety(self):
        for text in ['install-state.properties','install-state.json','File]::Replace','queue_fingerprint','FileShare]::None','finally','legacy.properties.bak']:
            self.assertIn(text,SCRIPT)
    def test_verified_monitor_precedes_first_port_enumeration(self):
        body=SCRIPT[SCRIPT.index('function Invoke-BridgeSetup'):]
        self.assertLess(body.index('    EnsureMonitor'),body.index('    $ports = @(ListProjectPort)'))
        self.assertIn('if (-not (MonitorPresent)) { throw',SCRIPT)
    def test_driver_and_dependency_validation(self):
        for text in ['matches.Count -ne 1','ntprint.inf','PSCRIPT5.DLL','FoisonC24Diagnostic.exe','redmon.chm','unredmon64.exe']:
            self.assertIn(text,SCRIPT)
    def test_no_false_success_or_shared_redmon_removal(self):
        self.assertIn('INDEPENDENT_VERIFY',NSIS)
        self.assertIn('verify --noninteractive',NSIS)
        self.assertNotRegex(NSIS.lower(),r'exec(?:wait)?[^\n]*unredmon')
        self.assertIn('physical_cut_enabled=false',SCRIPT)
        self.assertNotIn('COM2',SCRIPT)
    def test_bootstrap_diagnostics_and_noninteractive_failure(self):
        for text in ['PS1Exists=false','PowerShellExists=false','PowerShellExitCode=','stdout.raw','stderr.raw','ProgramData','%TEMP%','--noninteractive','exit /b %BRIDGE_EXIT%','Sysnative','pause >nul']:
            self.assertIn(text,CMD)
        self.assertLess(CMD.index('call :open_log'),CMD.index('"%PS%" -NoLogo'))
        self.assertIn('BEGIN bootstrap',CMD[CMD.index(':open_log\n'):])
    def test_unicode_installer(self):
        self.assertIn('Unicode true',NSIS)
        self.assertIn('MUI_LANGUAGE "PortugueseBR"',NSIS)
        self.assertIn('FileWriteUTF16LE /BOM',NSIS)
        self.assertNotIn('chcp 65001',CMD)

    def test_process_executor_avoids_ps2_parameter_sets_and_modern_clr_apis(self):
        self.assertNotIn('Start-Process',SCRIPT)
        for item in ['UseShellExecute=false','CreateNoWindow=true','RedirectStandardOutput=true','RedirectStandardError=true','ProcessStartInfo','FileMode.CreateNew','PeekNamedPipe','Worker.Join(milliseconds)','ExitCode=','UNKNOWN']:
            self.assertIn(item,SCRIPT)
        for item in ['ReadToEnd(', 'WaitForExit()', 'CopyTo(', 'WaitForExitAsync(', 'Task.Run(', '-Verb RunAs']:
            self.assertNotIn(item,SCRIPT)
    def test_nsis_append_preserves_bom_and_propagates_actual_code(self):
        log=NSIS.split('Function ${PREFIX}Log\n',1)[1].split('FunctionEnd',1)[0]
        self.assertLess(log.index('FileOpen'),log.index('FileSeek $LogHandle 0 END'))
        self.assertLess(log.index('FileSeek $LogHandle 0 END'),log.index('FileWriteUTF16LE'))
        self.assertIn('Function ${PREFIX}Fail\n  StrCpy $FailureCode $0',NSIS)

    def test_nsis_launch_failure_cannot_reuse_previous_zero(self):
        macro=NSIS.split('!macro CheckedExec PREFIX COMMAND\n',1)[1].split('!macroend',1)[0]
        self.assertLess(macro.index('StrCpy $0 9009'),macro.index('ExecWait'))
        self.assertIn('${If} ${Errors}',macro)
        self.assertIn('Call ${PREFIX}Fail',macro)
        self.assertEqual(NSIS.count('  ExecWait '),1)
        self.assertEqual(NSIS.count('!insertmacro CheckedExec'),5)

    def test_client_readme_matches_effective_version(self):
        version=(ROOT/'VERSION').read_text().strip()
        header=(ROOT/'packaging/windows/LEIA-ME.txt').read_text(encoding='utf-8-sig').splitlines()[0]
        self.assertIn('Foison C24 Print Bridge '+version+' ',header)
