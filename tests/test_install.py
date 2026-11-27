from pathlib import Path
import json
import tempfile
import unittest

from modkit.install import install_game, uninstall_game
from modkit.patcher import InstallError
from modkit.bundle import build_game_bundle
import test_patcher as fixtures


class InstallationTests(unittest.TestCase):
    tearDown = fixtures.PatcherTests.tearDown

    def setUp(self):
        fixtures.PatcherTests.setUp(self)
        build_game_bundle(self.source, self.root / "bundle", self.payload)

    def test_uninstall_preserves_added_and_modified_files(self):
        target = self.root / "installed"
        install_game(target, self.root, shortcuts=False)
        (target / "personal.txt").write_text("keep")
        (target / "Adobe AIR/runtime.dll").write_bytes(b"user-modified")
        report = uninstall_game(target)
        self.assertTrue((target / "personal.txt").exists())
        self.assertTrue((target / "Adobe AIR/runtime.dll").exists())
        self.assertFalse((target / "Orion.swf").exists())
        self.assertEqual(len(report["preserved_modified"]), 1)
        self.assertTrue((self.source / "Orion.swf").exists())

    def test_clean_uninstall_removes_only_installation(self):
        target = self.root / "installed"
        install_game(target, self.root, shortcuts=False)
        report = uninstall_game(target)
        self.assertFalse(report["remaining_folder"])
        self.assertTrue(self.source.exists())

    def test_tampered_ownership_record_fails_closed(self):
        target = self.root / "installed"
        install_game(target, self.root, shortcuts=False)
        marker = target / "mod-install.json"
        record = json.loads(marker.read_text(encoding="utf-8"))
        record["owned_files"].append({"path": "../original/Orion.swf", "sha256": "x"})
        marker.write_text(json.dumps(record), encoding="utf-8")
        with self.assertRaises(InstallError):
            uninstall_game(target)
        self.assertTrue((target / "Orion.swf").exists())
        self.assertTrue((self.source / "Orion.swf").exists())


if __name__ == "__main__":
    unittest.main()
