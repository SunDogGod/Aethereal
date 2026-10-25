# Characters (Blender scripts)

Every character is built by a Python script here, run by Blender with no window. Nothing is
modelled by hand, so to change a character you change a number in its script and rebuild.

## Rebuild a character
Close the Godot editor, then in PowerShell from the project folder:

```
.\tools\blender\rebuild.ps1 aeneas          # one character
.\tools\blender\rebuild.ps1                 # all of them
```

That runs the character's script in Blender, imports the result into Godot, and rebuilds its
model scene. Open Godot again and press F5.

## What's where
| File | What it does |
| --- | --- |
| `aeneas.py` | Aeneas: colours (top of the file), jacket / collar / sleeve / boot shapes, hair locks, face paint, his sword Rocinante, knife and rifle |
| `grey_bodies.py` | Plain grey stand-ins for Kael, Isabella and the guards, until their own scripts exist |
| `rig.py` | The shared skeleton and its bone names |
| `anims_loco.py` | idle, walk, run, sprint, crouch_idle, crouch_walk, jump, fall |
| `anims_combat.py` | the sword swings, block, dodge roll, hit, knife stab, death; the guards' telegraph, strike, stagger; Isabella's cast |
| `base_body.py`, `body.py`, `props.py` | shapes every character is made of (torso, limbs, head, hair locks, hands, boots, swords) |
| `mesh.py`, `paint.py`, `pose.py` | the machinery: tubes of polygons, the painted texture, posing and keying |
| `preview.py` | contact sheets of animations rendered in Blender (handy before going into Godot) |
| `make_wrapper.gd` | (Godot) builds `scenes/characters/<name>_model.tscn` from the export |

Outputs land in `models/characters/` (`<name>.glb` with every animation, `<name>_props.glb`,
`<name>.png` the 256 px texture, `<name>_mat.tres` the PS1 material) and
`scenes/characters/<name>_model.tscn`, which `player.tscn`, `kael.tscn`, `isabella.tscn` and
`guard.tscn` use as their **Model**.

## Tuning
- **Colours**: the `C = {...}` table at the top of `aeneas.py`.
- **Shapes**: the profile tables (`JACKET`, `SLEEVE`, `BOOT`...): each row is a ring of the shape,
  height first, then radii. Bigger number, wider.
- **Animation timing**: `anims_combat.py` keys are `(time in seconds, pose)`. The cut's
  `SWEEP_HIT` is when the blade crosses his front; `character_animator.gd` has the same number
  (`SWEEP_HIT`) and the hit lands then, so change both together.
- **Run speed vs legs**: `STRIDE` in `anims_loco.py` and `character_animator.gd` (same numbers).
- **Wobble on characters**: `snap_scale` in `<name>_mat.tres` (1 = as wobbly as the walls, 2 = half).

## Making a new character (for the look scripts)
1. Copy `aeneas.py` to `<name>.py`. Keep the structure: `cb.Character("<name>", height=...)`, build
   into `ch.part("Body")` with the `body.*` / `base_body.*` helpers, paint each block of `ch.atlas`,
   add props with `ch.prop(mesh_name, bone, node_name)` (grip at the origin, length along +Y), then
   `ch.finish()`. Guards: put the coat in `ch.part("Coat")` (tinted from GuardData), name the eye
   prop `Visor` (on the `Head` bone), and keep a prop node called `Blade` on `Weapon_R`.
   Isabella: props `Brush` (Weapon_R) and `Bell` (Sheath). Kael: `Lamento`.
2. Run `.\tools\blender\rebuild.ps1 <name>`. `kael.tscn` etc. already use
   `scenes/characters/<name>_model.tscn`, so nothing else changes.
3. Bone names (fixed): Hips, Spine, Chest, Neck, Head, Shoulder/UpperArm/LowerArm/Hand _L/_R,
   UpperLeg/LowerLeg/Foot _L/_R, and the attach points Weapon_R (main hand grip), Weapon_L
   (off-hand reverse grip), Back (slung across the back), Sheath (left hip).
