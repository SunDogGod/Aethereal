---
name: aethereal-test-battery
description: Run Aethereal's full headless test battery (load, overlaps, stealth, combat, hall, story, skip, saves, menus, route walks) and read the results. Use after any change to the game, before committing a round, or when the author asks "does everything still work?".
---

# Aethereal test battery

Godot must be closed (the editor holding the project can rewrite files mid-test).

## Run it
```bash
bash tests/run_battery.sh
```
About 30 minutes, 34 tests. Run it in the background. Logs go to `tests/logs/` (one file per test plus
`_summary.txt` with exit codes and seconds). The script ends by printing one verdict line per test
and naming any log with a SCRIPT ERROR.

## Reading results
- Pass lines: `... PASS`, `OVERLAP CHECK DONE: 0 problems`, `ROUTE COMPLETE`, `LOSS: current scene is now Massacre`
  (the hall and captain fights are meant to be lost), `CHAIN: 3 taps -> 3 hits`, `WITNESSED ... SPOTTED`,
  `FALL: card 'FELL'`, `REPLAY: ... plays again=false`.
- `rc=124` means the test timed out: look for a SCRIPT ERROR near the top of its log.
- End-of-run noise (`Unreferenced static string`, `RID allocations ... leaked`, `PagedAllocator`) is Godot's
  headless shutdown, not a bug.

## Known quirks
- `test_skip` reports two tiny diffs that are fine: the Dragger ~0.16 m apart, and a hidden Valentina's facing.
- Tests that capture frames (`RenderingServer.frame_post_draw`) hang headless. Run those windowed
  (drop `--headless`) with a timeout. Never kill Godot processes by hand; rely on `timeout`.
- When the story or a level changes, a test can go stale (a node renamed or moved, a route now crossing
  new props such as the hall bonfire). Decide if it's a regression or a stale test; fix the game or the
  test, and say which.
- A single test: `"$G" --headless --path . -s tests/<file>.gd` (some read env vars; copy the line from
  `tests/run_battery.sh`).

## Adding a test
Put it in `tests/` (extends SceneTree, prints a clear `... PASS` / `... FAIL` line, calls `quit()`), add a
`run` line to `tests/run_battery.sh`. Route walks take a JSON list of `["label", x, y, z]` waypoints.
