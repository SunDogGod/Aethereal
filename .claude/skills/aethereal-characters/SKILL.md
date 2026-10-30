---
name: aethereal-characters
description: Change or add Aethereal characters, outfits, faces, hair and animations through the Blender Python pipeline and rebuild them into Godot. Use for any character look or animation request.
---

# Characters

Read `tools/blender/README.md` first (file table, face tuning). The author's picture folder
(`OneDrive - Ucio IT Services/Pictures/Aethereal`) is a big inspiration for looks, but never copy its old pixel-art designs of the main crew.

- Looks: `tools/blender/<name>.py` (+ `_gear`, `_parts`, `_hair`), faces via `face.py` / `face_paint.py`
  (`FACE = face.look(...)`), Agency heads in `agency_heads.py`.
- Animations: `anims_*.py` and `<name>_anims.py` on the shared rig (`rig.py`, IK in `natural_arm.py`).
  Story poses are listed in `scripts/character_story.gd`.
- Rebuild: `powershell tools/blender/rebuild.ps1 aeneas,kael` (comma-separated). Wrapper scenes
  `scenes/characters/*_model.tscn` come from `make_wrapper.gd`.
- Keep hooks working: Scabbard/Knife bones, `set_arm_severed` (captain), `LamentoDrawn/LamentoBlood`
  (Kael), `attach/detach`, the `Visor` mesh guards need for their sight light.
- Check: load each wrapper scene and play a few animations headless; render face close-ups and full body
  windowed; run tests/test_hall.gd and the stealth/combat tests if fighters changed.
Canon looks: Aeneas Jim Hawkins-like with a poncho in arc 1, sword sheathed with left hand on the
scabbard; Isabella red robe; Kael long black coat, white hair, Lamento on his back; the Agency in white;
the captain one-armed (left) with his coat on his shoulders, no helmet.
