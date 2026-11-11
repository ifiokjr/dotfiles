"""Run the deployed pruner with fake system commands; never delete real targets."""

import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest


SCRIPT = (
  Path(__file__).resolve().parents[1]
  / "Configs/scripts/.local/share/secscan/target-prune.sh"
)


class TargetPruneTests(unittest.TestCase):
  def run_pruner(self, probes, percent=98):
    with tempfile.TemporaryDirectory() as temporary:
      root = Path(temporary)
      home = root / "home"
      logs = home / ".local/share/secscan"
      logs.mkdir(parents=True)
      target = home / "project/target"
      target.mkdir(parents=True)
      # Descendant writes do not keep the target root's mtime fresh.
      os.utime(target, (1, 1))
      (target / "live-test-output").write_text("running")
      commands = root / "bin"
      commands.mkdir()
      state = root / "state.json"
      state.write_text(json.dumps({"probes": probes, "calls": []}))
      driver = f"""#!{os.sys.executable}
import json
import os
from pathlib import Path
import sys
state = Path(os.environ['PRUNE_TEST_STATE'])
data = json.loads(state.read_text())
name = Path(sys.argv[0]).name
data['calls'].append([name, *sys.argv[1:]])
code = 0
if name == 'df':
    print('Filesystem 1024-blocks Used Available Capacity Mounted on')
    print('test 100 98 2 {percent}% /test')
elif name == 'pgrep':
    code = data['probes'].pop(0) if data['probes'] else 1
elif name == 'find' and sys.argv[1] == os.environ['HOME']:
    print(Path(os.environ['HOME']) / 'project/target')
elif name == 'du':
    print('1024\\t' + sys.argv[-1])
state.write_text(json.dumps(data))
sys.exit(code)
"""
      for name in ["df", "pgrep", "find", "du", "rm"]:
        command = commands / name
        command.write_text(driver)
        command.chmod(0o755)
      environment = os.environ.copy()
      environment.update(
        HOME=str(home), PATH=f"{commands}:/usr/bin:/bin", PRUNE_TEST_STATE=str(state)
      )
      subprocess.run(["/bin/zsh", str(SCRIPT)], env=environment, check=True)
      self.assertEqual((target / "live-test-output").read_text(), "running")
      return (
        json.loads(state.read_text())["calls"],
        (logs / "prune.log").read_text(),
        str(target),
      )

  def test_active_rust_commands_keep_old_targets_even_when_disk_is_full(self):
    for percent in [85, 98]:
      with self.subTest(percent=percent):
        calls, log, _ = self.run_pruner([0], percent)
        self.assertFalse(any(call[0] in ["find", "du", "rm"] for call in calls))
        probe = next(call for call in calls if call[0] == "pgrep")
        for command in [
          "cargo",
          "cargo-nextest",
          "cargo-clippy",
          "rustc",
          "rustdoc",
          "clippy-driver",
          "mbx",
        ]:
          self.assertIn(command, probe[-1].split("|"))
        self.assertIn("skipping target pruning", log)

  def test_work_starting_during_the_walk_stops_target_deletion(self):
    calls, log, target = self.run_pruner([1, 0])
    self.assertTrue(any(call[0] == "du" for call in calls))
    self.assertFalse(any(call[0] == "rm" and target in call for call in calls))
    self.assertIn("stopping target pruning", log)

  def test_process_lookup_errors_keep_targets_at_both_checks(self):
    for probes in [[2], [1, 2]]:
      with self.subTest(probes=probes):
        calls, _, target = self.run_pruner(probes)
        self.assertFalse(any(call[0] == "rm" and target in call for call in calls))

  def test_inactive_stale_targets_are_still_selected_for_cleanup(self):
    calls, log, target = self.run_pruner([1, 1])
    self.assertIn(["rm", "-rf", target], calls)
    self.assertIn(f"pruned {target}", log)

  def test_below_threshold_does_not_walk_or_delete_targets(self):
    calls, log, _ = self.run_pruner([1], 84)
    self.assertFalse(any(call[0] in ["find", "du", "rm"] for call in calls))
    self.assertIn("below threshold", log)


if __name__ == "__main__":
  unittest.main()
