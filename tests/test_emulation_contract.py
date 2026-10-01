"""Frontend launch contract: every extension ES-DE lists must be a file run-emulator can hand
to the emulator as-is (run-emulator never extracts or converts ROMs)."""

import os
import re
import unittest
import xml.etree.ElementTree as ET
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
LIB = ROOT / "modules/emulation/lib.nix"
LAUNCHERS = ROOT / "modules/emulation/launchers.nix"

# Azahar 2126 boots NCSD (.3ds/.cci/.zcci), NCCH (.cxi/.zcxi) and 3DSX (.3dsx/.z3dsx) paths
# directly; .cia/.zcia must be installed first and archives are not opened at all.
N3DS_LAUNCHABLE = {".3ds", ".cci", ".zcci", ".cxi", ".zcxi", ".3dsx", ".z3dsx"}
N3DS_FORBIDDEN = {".zip", ".7z", ".rar", ".cia", ".zcia"}


def extensions(text: str) -> set[str]:
    return {e.lower() for e in text.split()}


def system_block(source: str, system_id: str) -> str:
    match = re.search(r'\{\s*id = "%s";(.*?)\n    \}' % re.escape(system_id), source, re.S)
    if not match:
        raise AssertionError(f"system {system_id} not found")
    return match.group(1)


class EmulationContractTests(unittest.TestCase):
    def test_3ds_lists_only_files_azahar_boots_directly(self):
        source = LIB.read_text()
        block = system_block(source, "n3ds")
        self.assertIn("extensions = n3dsLaunchExtensions;", block)
        value = re.search(r'n3dsLaunchExtensions = "([^"]*)";', source).group(1)
        self.assertEqual(extensions(value), N3DS_LAUNCHABLE)

    def test_psp_lists_chd(self):
        block = system_block(LIB.read_text(), "psp")
        self.assertIn(".chd .CHD", block)

    def test_run_emulator_passes_3ds_and_psp_paths_untransformed(self):
        source = LAUNCHERS.read_text()
        self.assertRegex(source, r'azahar\)\n\s+azahar_bin="\$\(first_command azahar azahar-qt\)"'
                         r'\n\s+cmd=\("\$azahar_bin" "\$rom_path"\)')
        self.assertRegex(source, r'ppsspp\)\n\s+ppsspp_bin="\$\(first_command PPSSPPSDL ppsspp '
                         r'ppsspp-sdl\)"\n\s+cmd=\("\$ppsspp_bin" "\$rom_path"\)')

    @unittest.skipUnless(os.environ.get("EMULATION_ES_SYSTEMS_XML"),
                         "emitted es_systems.xml is checked by the emulation-frontend-contract check")
    def test_emitted_es_systems(self):
        tree = ET.parse(os.environ["EMULATION_ES_SYSTEMS_XML"])
        systems = {s.findtext("name"): s for s in tree.getroot().iter("system")}
        n3ds = extensions(systems["n3ds"].findtext("extension"))
        self.assertEqual(n3ds, N3DS_LAUNCHABLE)
        self.assertFalse(n3ds & N3DS_FORBIDDEN)
        self.assertTrue(systems["n3ds"].findtext("command").startswith("run-emulator n3ds azahar "))
        psp = systems["psp"].findtext("extension").split()
        self.assertIn(".chd", psp)
        self.assertIn(".CHD", psp)
        self.assertEqual(systems["psp"].findtext("command"), "run-emulator psp ppsspp %ROM%")


if __name__ == "__main__":
    unittest.main()
