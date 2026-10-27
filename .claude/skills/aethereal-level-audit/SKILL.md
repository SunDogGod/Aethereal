---
name: aethereal-level-audit
description: Hunt for bugs and glitches in an Aethereal level - broken or stretched textures, z-fighting, see-through or inside-out walls, floating props, stuck spots, camera clipping, story steps pointing at missing nodes, sound and UI faults. Use before handing a level to the author, after dressing a level, or when asked for a cleanup or bug hunt.
---

# Level audit

Work per level: `scenes/levels/empty_town.tscn`, `black_sand.tscn`, `vacuum_station.tscn`, `massacre.tscn`,
and the joined `scenes/world/world.tscn`. Godot closed while editing scene files.

## 1. Automatic checks (headless)
- Overlaps and props inside walls: `tests/check_overlaps.gd` with `OVERLAP_SCENE=res://scenes/levels/<level>.tscn`.
- Prop audits: `tests/audit_props_5.gd`, `tests/audit_props_8.gd`.
- Walk the level's route: `tests/walk_level.gd` with `WALK_LEVEL` and `WALK_ROUTE` (routes: `tests/route_*.json`,
  world: `tests/world/walk_world.gd` + `route_world.json`). A STUCK leg = a blocked path or missing floor.
- Every log: grep for `SCRIPT ERROR`, `ERROR`, `WARNING`, missing `ext_resource` paths.

## 2. Look at it (windowed screenshots)
Write a small SceneTree script that loads the level, places a Camera3D at points along the route and
saves PNGs (`get_viewport().get_texture().get_image()` after `await RenderingServer.frame_post_draw`;
windowed only). Look for: magenta (missing material), stretched UVs, flicker/z-fighting (coplanar faces:
offset one by ~1 cm), floating or sunken props, light leaks, wrong fog per zone, text floating in the world.
Lesson: an inside-out mesh looks fine in screenshots from outside. Test winding with a camera INSIDE a
closed box (Godot's front faces are clockwise).

## 3. Play-feel probes
Stuck spots, walls you can walk through (collision only on what the player can reach), guards seeing
through walls, companion pathing, the camera in narrow spots (record camera distance per frame through
the spot: no sudden jumps), pausing or skipping during a fight, death during a cutscene, Continue after
saving there.

## 4. Report
Only findings with evidence (log line, probe number, screenshot path). Fix at the root, rerun what you
touched, then the full battery (skill: aethereal-test-battery). Tell the author in plain words what you
could not see or hear (sound, motion, real controller feel).
