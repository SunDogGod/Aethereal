---
name: aethereal-performance
description: Keep Aethereal fast - load times (New Game should take ~2 s), frame spikes, shader hitches, heavy dressing. Use when adding lots of props or a new level, when loading feels slow or freezes, or when asked for performance fixes.
---

# Performance

## What already keeps it fast (don't undo it)
- Scenes load on a thread behind the fade (`scripts/scene_loader.gd`), with a LOADING line after 0.3 s.
- Block meshes are built once and shared between identical Blocks; prop meshes and materials are shared
  resources, not per-instance copies.
- Only the current zone of the world is active; fog, light and music blend between zones.
- Windows renders through Vulkan (revert: Project Settings > Rendering > Rendering Device > Driver (Windows) = d3d12).

## Rules for new content
- Repeated clutter (trash, rubble, sand tufts, roof tiles): one MultiMeshInstance3D, not hundreds of nodes.
- Small props get a `visibility_range_end` (20-60 m depending on size).
- Reuse materials (`materials/*.tres`); a per-object material copy only when it really must differ (e.g. a flickering sign).
- Collision only where the player can reach; none on decoration.
- Procedural props (`@tool` scripts that build meshes) must cache their mesh, not rebuild every load.
- Avoid real-time shadows on many small lights; use a few shadowed key lights.

## Measuring
- Load time: time `New Game` to control in a windowed run (log timestamps around `scene_loader` start/finish).
  Compare before and after; the target is ~2 s.
- Frame time: during a route walk (tests/walk_level.gd), record `Performance.get_monitor(Performance.TIME_PROCESS)`
  and draw calls (`RENDER_TOTAL_DRAW_CALLS_IN_FRAME`) each frame; report the worst frames and where they happen.
- Shader hitches: the first sight of a new effect stalls once. Warm the shader up behind the loading fade
  (spawn the effect off-camera for a frame).
- Node count per level: count descendants; a sudden jump means clutter that should be a MultiMesh.

After changes, run the full battery (skill: aethereal-test-battery).
