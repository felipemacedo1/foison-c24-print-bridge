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
