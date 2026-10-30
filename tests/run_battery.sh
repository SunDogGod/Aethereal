#!/bin/bash
# The full headless test battery. Run from anywhere: bash tests/run_battery.sh
# Logs go to tests/logs (or BATTERY_LOGS); _summary.txt lists each test's exit code and time.
# Read each log's last PASS/FAIL line; see .claude/skills/aethereal-test-battery for known quirks.
S="$(cd "$(dirname "$0")" && pwd)"
P="$(dirname "$S")"
G="/c/Users/ArmandoSanchez/OneDrive - Ucio IT Services/Documents/Godot_v4.7.2-stable_win64_console.exe"
L="${BATTERY_LOGS:-$S/logs}"; mkdir -p "$L"
run() {  # name, timeout, script, [env...]
  local name="$1" to="$2" script="$3"; shift 3
  local t0=$(date +%s)
  env "$@" timeout "$to" "$G" --headless --path "$P" -s "$script" > "$L/$name.txt" 2>&1
  local rc=$?
  echo "$name rc=$rc secs=$(( $(date +%s) - t0 ))" >> "$L/_summary.txt"
}
: > "$L/_summary.txt"
run load_all 300 "$S/load_all.gd"
run check_overlaps 300 "$S/check_overlaps.gd"
run check_overlaps_bs 300 "$S/check_overlaps.gd" OVERLAP_SCENE=res://scenes/levels/black_sand.tscn
run check_overlaps_vs 300 "$S/check_overlaps.gd" OVERLAP_SCENE=res://scenes/levels/vacuum_station.tscn
run check_overlaps_mas 300 "$S/check_overlaps.gd" OVERLAP_SCENE=res://scenes/levels/massacre.tscn
run audit_props_8 300 "$S/audit_props_8.gd"
run audit_props_5 300 "$S/audit_props_5.gd"
run test_hall 300 "$S/test_hall.gd"
run test_hall_death 300 "$S/test_hall_death.gd"
run test_combat 300 "$S/test_combat.gd"
run test_stealth 300 "$S/test_stealth.gd"
run test_fall 300 "$S/test_fall.gd"
run test_drop 300 "$S/test_drop.gd"
run test_air 300 "$S/test_air.gd"
run test_bed 300 "$S/test_bed.gd"
run test_story 300 "$S/test_story.gd"
run test_inspect 300 "$S/test_inspect.gd" TEST_SCENE=res://scenes/levels/empty_town.tscn
run chase_captain 300 "$S/test_stage_chase.gd" CHASE_FIGHT=CaptainFight
run chase_hall 300 "$S/test_stage_chase.gd" CHASE_FIGHT=HallFight
run test_assist 300 "$S/round7combat/test_assist.gd"
run test_choreo 300 "$S/round7combat/test_choreo.gd"
run test_flashlight 300 "$S/vs_r4/test_flashlight.gd"
run test_menus 300 "$S/round3/menus/test_menus.gd"
run test_world 300 "$S/world/test_world.gd"
run test_hall_world 300 "$S/world/test_hall_world.gd"
run test_world_story 300 "$S/world/test_world_story.gd"
run walk_town 590 "$S/walk_level.gd" WALK_PEACEFUL=1 WALK_LEVEL=res://scenes/levels/empty_town.tscn "WALK_ROUTE=$(cat "$S/route_town.json")"
run walk_bs 590 "$S/walk_level.gd" WALK_PEACEFUL=1 WALK_LEVEL=res://scenes/levels/black_sand.tscn "WALK_ROUTE=$(cat "$S/route_black_sand.json")"
run walk_vs 590 "$S/walk_level.gd" WALK_PEACEFUL=1 WALK_LEVEL=res://scenes/levels/vacuum_station.tscn "WALK_ROUTE=$(cat "$S/route_vacuum_station.json")"
run walk_world 590 "$S/world/walk_world.gd" WALK_PEACEFUL=1 WALK_LEVEL=res://scenes/world/world.tscn WALK_SPOT=res://scenes/levels/black_sand.tscn WALK_START=0,24,104 "WALK_ROUTE=$(cat "$S/world/route_world.json")"
run test_save_file 300 "$S/overnight/saving_impl/test_save_file.gd"
# test_save_town (overnight/saving_impl) dropped: stale expectations; story26/test_save_town covers it
run test_save_rest 590 "$S/overnight/saving_impl/test_save_rest.gd"
run test_skip 590 "$S/batch9/sound-skip/test_skip.gd"
run test_skip_edges 590 "$S/batch9/sound-skip/test_edges.gd"
run test_hall_fx 590 "$S/batch9/hall-cutscenes/test_hall_fx.gd"
run test_save_town26 590 "$S/story26/test_save_town.gd"
echo DONE >> "$L/_summary.txt"
# One line per test: its last verdict line.
for f in "$L"/*.txt; do n=$(basename "$f" .txt); [ "$n" = _summary ] && continue
  printf '%-20s %s\n' "$n" "$(grep -hE 'PASS|FAIL|DONE|COMPLETE|LOSS|problems|STUCK|DIFF|CHAIN|FALL:|WITNESSED|REPLAY' "$f" | tail -1 | head -c 110)"; done
grep -l "SCRIPT ERROR\|Parse Error" "$L"/*.txt 2>/dev/null | sed 's|^|SCRIPT ERRORS IN: |'
