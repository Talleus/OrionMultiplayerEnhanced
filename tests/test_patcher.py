import json
from pathlib import Path
import struct
import tempfile
import unittest
import zlib

import bsdiff4

from modkit.patcher import InstallError, compress_swf, expand_swf, patch_swf, prepare_game, sha256


def swf(body=b"original", compressed=True):
    head = b"FWS\x1f" + struct.pack("<I", len(body) + 8)
    return b"CWS" + head[3:] + zlib.compress(body) if compressed else head + body


class PatcherTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.root = Path(self.temp.name)
        self.source = self.root / "original"
        self.source.mkdir()
        self.payload = self.root / "payload"
        self.payload.mkdir()
        self.original = swf()
        self.modified = expand_swf(swf(b"modded bytecode"))
        self.packed = compress_swf(self.modified)
        patch = bsdiff4.diff(expand_swf(self.original), self.modified)
        self.manifest = {
            "schema": 1, "project": "OrionMultiplayerEnhanced", "version": "test",
            "base": {"file_sha256": sha256(self.original), "expanded_sha256": sha256(expand_swf(self.original))},
            "target": {"file_sha256": sha256(self.packed), "expanded_sha256": sha256(self.modified)},
            "patch": {"sha256": sha256(patch), "size": len(patch)},
        }
        (self.payload / "orion.patch").write_bytes(patch)
        (self.payload / "manifest.json").write_text(json.dumps(self.manifest), encoding="utf-8")
        (self.source / "Orion.swf").write_bytes(self.original)
        (self.source / "Orion Sandbox Enhanced.exe").write_bytes(b"owned launcher")
        (self.source / "Adobe AIR").mkdir()
        (self.source / "Adobe AIR/runtime.dll").write_bytes(b"owned runtime")
        (self.source / "META-INF/AIR").mkdir(parents=True)
        (self.source / "META-INF/AIR/application.xml").write_bytes(
            b"<application><id>OrionSandboxEnhanced</id><name>Orion Sandbox Enhanced</name>"
            b"<filename>Orion Sandbox Enhanced</filename><initialWindow>"
            b"<title>Orion Sandbox Enhanced</title></initialWindow></application>"
        )

    def tearDown(self):
        self.temp.cleanup()

    def test_round_trip_and_already_patched(self):
        patch = (self.payload / "orion.patch").read_bytes()
        self.assertEqual(patch_swf(self.original, self.manifest, patch), self.packed)
        self.assertEqual(patch_swf(self.packed, self.manifest, patch), self.packed)

    def test_rejects_wrong_version_before_writing(self):
        (self.source / "Orion.swf").write_bytes(swf(b"unsupported"))
        target = self.root / "install"
        with self.assertRaises(InstallError):
            prepare_game(self.source, target, self.payload)
        self.assertFalse(target.exists())
        self.assertEqual((self.source / "Orion.swf").read_bytes(), swf(b"unsupported"))

    def test_tampered_payload_rejected(self):
        with (self.payload / "orion.patch").open("ab") as f:
            f.write(b"tamper")
        with self.assertRaises(InstallError):
            prepare_game(self.source, self.root / "install", self.payload)

    def test_install_copies_runtime_renames_and_preserves_source(self):
        (self.source / "private-save.sol").write_bytes(b"private")
        (self.source / "_dev").mkdir()
        (self.source / "_dev/private.txt").write_text("private")
        target = self.root / "install"
        prepare_game(self.source, target, self.payload)
        self.assertEqual((self.source / "Orion.swf").read_bytes(), self.original)
        self.assertEqual((target / "Orion.swf").read_bytes(), self.packed)
        self.assertTrue((target / "OrionMultiplayerEnhanced.exe").exists())
        self.assertFalse((target / "Orion Sandbox Enhanced.exe").exists())
        self.assertFalse((target / "private-save.sol").exists())
        self.assertFalse((target / "_dev").exists())
        descriptor = (target / "META-INF/AIR/application.xml").read_text()
        self.assertIn("<id>OrionSandboxEnhanced</id>", descriptor)
        self.assertIn("<title>OrionMultiplayerEnhanced</title>", descriptor)

    def test_refuses_existing_and_nested_destinations(self):
        for target in [self.source, self.source / "nested", self.root]:
            with self.assertRaises(InstallError):
                prepare_game(self.source, target, self.payload)

    def test_rejects_corrupt_swf(self):
        for data in [b"bad", self.original[:-2], self.original + b"trailing", b"FWS\x1f\xff\xff\xff\xff"]:
            with self.assertRaises(InstallError):
                expand_swf(data)


if __name__ == "__main__":
    unittest.main()
