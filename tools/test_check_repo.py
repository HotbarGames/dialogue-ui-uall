"""Tests for tools/check_repo.py, and the check itself on this repo.

python3 -m unittest discover -s tools
"""
import json
import os
import subprocess
import sys
import tempfile
import unittest

HERE = os.path.dirname(os.path.abspath(__file__))
SCRIPT = os.path.join(HERE, "check_repo.py")
REPO = os.path.dirname(HERE)


def run(cwd, *args):
    return subprocess.run([sys.executable, SCRIPT, *args], cwd=cwd, capture_output=True, text=True)


class ThisRepo(unittest.TestCase):
    def test_this_repo_passes(self):
        out = run(REPO)
        self.assertEqual(out.returncode, 0, out.stdout + out.stderr)


class Guard(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.root = self.tmp.name
        subprocess.run(["git", "init", "-q", self.root], check=True)

    def tearDown(self):
        self.tmp.cleanup()

    def write(self, path, text):
        full = os.path.join(self.root, path)
        os.makedirs(os.path.dirname(full), exist_ok=True)
        with open(full, "w", encoding="utf-8", newline="\n") as f:
            f.write(text)
        subprocess.run(["git", "add", "-f", path], cwd=self.root, check=True)

    def budget(self, files, ignore=()):
        self.write("size-budget.json", json.dumps({"files": files, "ignore": list(ignore)}))

    def read_budget(self):
        with open(os.path.join(self.root, "size-budget.json"), encoding="utf-8") as f:
            return json.load(f)

    def test_301_line_new_file_fails(self):
        self.write("a.lua", "x\n" * 301)
        out = run(self.root)
        self.assertEqual(out.returncode, 1)
        self.assertIn("a.lua: lines (301 > 300)", out.stdout)
        self.assertIn("--update", out.stdout)

    def test_300_lines_ok(self):
        self.write("a.lua", "x\n" * 300)
        self.assertEqual(run(self.root).returncode, 0)

    def test_bytes_and_long_line_fail(self):
        self.write("b.md", "y" * 401 + "\n")
        self.write("c.md", ("z" * 99 + "\n") * 251)
        out = run(self.root)
        self.assertEqual(out.returncode, 1)
        self.assertIn("b.md: longest line (chars) (401 > 400)", out.stdout)
        self.assertIn("c.md: bytes (25100 > 25000)", out.stdout)

    def test_budget_file_that_grew_fails(self):
        self.write("a.lua", "x\n" * 351)
        self.budget({"a.lua": {"lines": 350}})
        out = run(self.root)
        self.assertEqual(out.returncode, 1)
        self.assertIn("a.lua: lines over its budget (351 > 350)", out.stdout)

    def test_budget_file_that_shrank_ok(self):
        self.write("a.lua", "x\n" * 340)
        self.budget({"a.lua": {"lines": 350}})
        self.assertEqual(run(self.root).returncode, 0)

    def test_budget_file_under_all_limits_asks_to_remove(self):
        self.write("a.lua", "x\n" * 10)
        self.budget({"a.lua": {"lines": 350}})
        out = run(self.root)
        self.assertEqual(out.returncode, 0)
        self.assertIn("a.lua: now under all limits", out.stdout)

    def test_budget_entry_for_missing_file_fails(self):
        self.budget({"gone.lua": {"lines": 350}})
        out = run(self.root)
        self.assertEqual(out.returncode, 1)
        self.assertIn("gone.lua: in size-budget.json", out.stdout)

    def test_leaks_fail_at_any_level(self):
        for path in (".claude/x", ".mcp.json", "CLAUDE.local.md", "sub/.claude/settings.json", "sub/.mcp.json"):
            self.write(path, "{}\n")
        out = run(self.root)
        self.assertEqual(out.returncode, 1)
        for path in (".claude/x", ".mcp.json", "CLAUDE.local.md", "sub/.claude/settings.json", "sub/.mcp.json"):
            self.assertIn(f"{path}: claude-config file must never be committed", out.stdout)

    def test_claude_md_with_marker_blocks_ok(self):
        self.write("CLAUDE.md", "# x\n\n<!-- claude-config:demo START (managed by claude-config) -->\n"
                                "## Demo\n.claude/hooks/x.sh and .mcp.json are named here\n"
                                "<!-- claude-config:demo END -->\n")
        self.assertEqual(run(self.root).returncode, 0)

    def test_update_never_raises_or_adds(self):
        self.write("grew.lua", "x\n" * 400)
        self.write("shrank.lua", "x\n" * 320 + "y" * 410 + "\n")
        self.write("under.lua", "x\n" * 5)
        self.write("new.lua", "x\n" * 500)
        self.budget({"grew.lua": {"lines": 350}, "shrank.lua": {"lines": 350, "maxLine": 500},
                     "under.lua": {"lines": 350}, "gone.lua": {"lines": 350}})
        out = run(self.root, "--update")
        self.assertEqual(out.returncode, 1)  # grew.lua and new.lua still fail
        self.assertEqual(self.read_budget()["files"], {
            "grew.lua": {"lines": 350},
            "shrank.lua": {"lines": 321, "maxLine": 410},
        })

    def test_init_records_only_numbers_over_limits_and_runs_once(self):
        self.write("a.lua", "x\n" * 310)
        self.write("b.lua", "x\n" * 10)
        self.assertEqual(run(self.root, "--init").returncode, 0)
        self.assertEqual(self.read_budget()["files"], {"a.lua": {"lines": 310}})
        self.assertNotEqual(run(self.root, "--init").returncode, 0)

    def test_skips_lockfiles_binaries_generated_and_ignored(self):
        self.write("package-lock.json", "x\n" * 999)
        self.write("dist/out.js", "x\n" * 999)
        self.write("Libs/Ace.lua", "x\n" * 999)
        self.write("app.min.js", "x" * 999)
        self.write("pic.dat", "\0" + "x\n" * 999)
        self.write("data/big.csv", "x\n" * 999)
        self.budget({}, ignore=[{"glob": "data/*.csv", "reason": "test data"}])
        out = run(self.root)
        self.assertEqual(out.returncode, 0, out.stdout)

    def test_untracked_files_do_not_count(self):
        with open(os.path.join(self.root, "local.lua"), "w") as f:
            f.write("x\n" * 999)
        os.makedirs(os.path.join(self.root, ".claude"))
        with open(os.path.join(self.root, ".claude", "x"), "w") as f:
            f.write("x\n")
        self.assertEqual(run(self.root).returncode, 0)


if __name__ == "__main__":
    unittest.main()
