import unittest

from tools.source_patches import apply_unified


class SourcePatchTests(unittest.TestCase):
    def test_multiple_hunks_and_insertions(self):
        original = "a\nb\nc\nd\ne\n"
        patch = "--- a/test.as\n+++ b/test.as\n@@ -1,2 +1,3 @@\n a\n-b\n+B\n+new\n@@ -5 +6 @@\n-e\n+E\n"
        self.assertEqual(apply_unified(original, patch), "a\nB\nnew\nc\nd\nE\n")

    def test_drift_rejected(self):
        with self.assertRaises(ValueError):
            apply_unified("wrong\n", "--- a/test\n+++ b/test\n@@ -1 +1 @@\n-original\n+modified\n")

    def test_count_mismatch_rejected(self):
        with self.assertRaises(ValueError):
            apply_unified("a\n", "--- a/test\n+++ b/test\n@@ -1,2 +1 @@\n-a\n+b\n")
