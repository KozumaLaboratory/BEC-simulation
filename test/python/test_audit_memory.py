"""Exercise the auditor's public CLI against isolated memory trees."""
import importlib.util
import io
import pathlib
import sys
import tempfile
import unittest
from contextlib import redirect_stdout, redirect_stderr
from unittest.mock import patch

ROOT = pathlib.Path(__file__).resolve().parents[2]
spec = importlib.util.spec_from_file_location("audit_memory", ROOT / "scripts/audit_memory.py")
audit = importlib.util.module_from_spec(spec)
spec.loader.exec_module(audit)


class MemoryAuditTests(unittest.TestCase):
    def check_store(self, files, *options):
        with tempfile.TemporaryDirectory() as tmp:
            store = pathlib.Path(tmp) / "memory"
            for name, text in files.items():
                path = store / name
                path.parent.mkdir(parents=True, exist_ok=True)
                path.write_text(text, encoding="utf-8")
            output = io.StringIO()
            argv = ["audit_memory", "--memory-dir", str(store), "--repo", str(ROOT), *options]
            # Path-history classification is separate from the navigation gate.
            with patch.object(sys, "argv", argv), patch.object(audit, "path_report", return_value=({}, {}, {}, {})), redirect_stdout(output), redirect_stderr(output):
                status = audit.main()
            return status, output.getvalue()

    def test_empty_index_is_valid(self):
        self.assertEqual(self.check_store({"MEMORY.md": "# Memory\n"})[0], 0)

    def test_disconnected_index_and_its_notes_fail(self):
        files = {"MEMORY.md": "[live](live.md)", "live.md": "",
                 "memory_index_lost.md": "[[lost]]", "lost.md": "[[memory_index_lost]]"}
        status, report = self.check_store(files)
        self.assertEqual(status, 1)
        self.assertIn("unreachable files   : 2", report)
        # Repair the actual missing edge, without moving or deleting the notes.
        files["MEMORY.md"] += "\n[index](memory_index_lost.md)"
        self.assertEqual(self.check_store(files)[0], 0)

    def test_mixed_link_spellings_and_long_chain(self):
        files = {"MEMORY.md": "[[a-b_c]] [d](d_e_f.md)", "a-b_c.md": "[[n0]]", "d_e_f.md": ""}
        files.update({f"n{i}.md": f"[[n{i+1}]]" for i in range(8)})
        files["n8.md"] = "[[a-b_c]]"
        self.assertEqual(self.check_store(files)[0], 0)

    def test_code_examples_do_not_create_links(self):
        status, report = self.check_store({"MEMORY.md": "`[[note]]`\n```\n[n](note.md)\n```", "note.md": ""})
        self.assertEqual(status, 1)
        self.assertIn("unreachable files   : 1", report)

    def test_archived_unlinked_notes_are_exempt(self):
        self.assertEqual(self.check_store({"MEMORY.md": "", "archive/old.md": ""})[0], 0)

    def test_missing_store_or_entry_point_fails_before_repairs(self):
        for files in ({}, {"note.md": ""}):
            for option in ((), ("--fix-links",), ("--fix-relocations",)):
                with self.subTest(files=files, option=option):
                    self.assertEqual(self.check_store(files, *option)[0], 2)

    def test_budget_is_bytes_and_not_a_truncation_claim(self):
        status, report = self.check_store({"MEMORY.md": "ああ"}, "--limit", "5")
        self.assertEqual(status, 1)
        self.assertIn("6 / 5 bytes", report)
        self.assertNotIn("will be truncated", report)


if __name__ == "__main__":
    unittest.main()
