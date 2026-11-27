import json
import shutil
import unittest
import zipfile

from modkit.bundle import build_game_bundle, extract_game, file_hash
from modkit.patcher import InstallError
import test_patcher as fixtures


class BundleTests(unittest.TestCase):
    tearDown = fixtures.PatcherTests.tearDown

    def setUp(self):
        fixtures.PatcherTests.setUp(self)
        self.bundle = self.root / "bundle"
        build_game_bundle(self.source, self.bundle, self.payload)

    def update_manifest(self, edit):
        path = self.bundle / "manifest.json"
        manifest = json.loads(path.read_text(encoding="utf-8"))
        edit(manifest)
        path.write_text(json.dumps(manifest), encoding="utf-8")

    def test_install_without_source_or_patch_files(self):
        shutil.rmtree(self.source)
        shutil.rmtree(self.payload)
        target = self.root / "standalone"
        record = extract_game(self.bundle, target)
        self.assertEqual((target / "Orion.swf").read_bytes(), self.packed)
        self.assertEqual(record["installation_type"], "standalone")
        self.assertTrue((target / "Adobe AIR/runtime.dll").is_file())

    def test_archive_tampering_leaves_no_installation(self):
        with (self.bundle / "game.zip").open("ab") as stream:
            stream.write(b"tampered")
        target = self.root / "standalone"
        with self.assertRaises(InstallError):
            extract_game(self.bundle, target)
        self.assertFalse(target.exists())

    def test_file_hash_failure_removes_staging(self):
        self.update_manifest(lambda manifest: manifest["files"][0].update(sha256="0" * 64))
        target = self.root / "standalone"
        with self.assertRaises(InstallError):
            extract_game(self.bundle, target)
        self.assertFalse(target.exists())
        self.assertEqual(list(self.root.glob(".ome-stage-*")), [])

    def test_traversal_rejected_before_writing(self):
        self.update_manifest(lambda manifest: manifest["files"][0].update(path="../outside.txt"))
        with self.assertRaises(InstallError):
            extract_game(self.bundle, self.root / "standalone")
        self.assertFalse((self.root / "outside.txt").exists())

    def test_unlisted_archive_entry_rejected(self):
        archive = self.bundle / "game.zip"
        with zipfile.ZipFile(archive, "a") as package:
            package.writestr("unexpected.dll", b"not listed")
        self.update_manifest(lambda manifest: manifest.update(archive_sha256=file_hash(archive), archive_size=archive.stat().st_size))
        with self.assertRaises(InstallError):
            extract_game(self.bundle, self.root / "standalone")

    def test_existing_destination_preserved(self):
        target = self.root / "standalone"
        target.mkdir()
        (target / "personal.txt").write_text("keep")
        with self.assertRaises(InstallError):
            extract_game(self.bundle, target)
        self.assertEqual((target / "personal.txt").read_text(), "keep")
