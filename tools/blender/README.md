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
| `aeneas.py` | Aeneas: colours (top of the file), jacket / collar / sleeve / boot shapes, hair locks, face paint, his sword Rocinante and its scabbard, knife and rifle; `PONCHO = True` builds the first arc's poncho |
| `aeneas_gear.py` | Aeneas's poncho (shape, hem, hood, sling, how it follows his arms), its painting, and the knife's sheath at the small of his back |
| `aeneas_anims.py` | Aeneas's own animations: the walks with the sword sheathed (`*_sheathed`, left hand on the scabbard), `iai` (the stance), `draw_cut` (the quick draw), `sheathe` |
| `agent.py` | The Agency agent (and the lieutenant, in his GuardData colours): white long coat, black helmet with the visor slit, dark armour, dust at the hem; his own idle and patrol walk |
| `captain.py` | The Agency captain: taller, one arm (his left), dark uniform and breastplate, crimson-crested helmet, longer blade in his left hand |
| `captain_gear.py` | The captain's white coat draped round his shoulders (shape `CAPE`, folds, how it follows his chest, arm and thighs), its collar, the empty sleeves, epaulettes, and the pinned stump of his right arm |
| `captain_anims.py` | The captain fights left-handed: every animation mirrored, nothing keyed on the right arm, a run without the heel kick so his back foot stays under the coat |
| `agency_parts.py` | What the Agency share: shells and plates, the helmet and visor, the blade, and the weathering paint (`weather()`: dust at a hem; `chips()`: knocks in armour) |
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
- **The quick draw**: `DRAW_HIT` in `aeneas_anims.py` is when the drawn blade crosses his front
  (`DRAW_HIT` in `character_animator.gd` too); `SHEATHE_HOME` is when the sheathed blade is home
  (`SHEATHE_HOME` in `character_anim_layers.gd` too). Where the sword hangs: `SCABBARD_THROAT` and
  `SCABBARD_DIR` in `rig.py`; where his left hand holds it: `HOLD_T` in `aeneas_anims.py`.
- **The poncho**: colours `poncho*` in `aeneas.py`; shape `PROFILE` and `hem_z()` in `aeneas_gear.py`.
  To hide it in the game without rebuilding: select the Player's **Model** and untick **Poncho**
  (`scripts/aeneas_outfit.gd`); in `scenes/player.tscn` for every level, or on one level's Player.
- **Run speed vs legs**: `STRIDE` in `anims_loco.py` and `character_animator.gd` (same numbers).
- **The Agency**: coat, trim and visor colours are in `data/enemies/*.tres` (no rebuild); the dust at the hem
  is `ap.weather(...)` in `agent.py` / `captain.py` paint() (`top` = how high it climbs, `strength`).
  The captain's coat shape: `CAPE` rows in `captain_gear.py`; his height `HEIGHT` and blade `BLADE_LENGTH`
  in `captain.py`.
- **Wobble on characters**: `snap_scale` in `<name>_mat.tres` (1 = as wobbly as the walls, 2 = half).

## Making a new character (for the look scripts)
1. Copy `aeneas.py` to `<name>.py`. Keep the structure: `cb.Character("<name>", height=...)`, build
   into `ch.part("Body")` with the `body.*` / `base_body.*` helpers, paint each block of `ch.atlas`,
   add props with `ch.prop(mesh_name, bone, node_name)` (grip at the origin, length along +Y), then
   `ch.finish()`. Guards: put the coat in `ch.part("Coat")` (tinted with GuardData.coat_color) and
   any trim in `ch.part("Trim")` (GuardData.trim_color), paint both near-white, name the eye prop
   `Visor` (on the `Head` bone), and keep a prop node called `Blade` (on `Weapon_R`, or `Weapon_L`
   for a left-handed fighter like the captain). A guard kind with its own model names its
   `scenes/characters/<name>_model.tscn` as **Model Scene** in its GuardData file (data/enemies/).
   Isabella: props `Brush` (Weapon_R) and `Bell` (Sheath). Kael: `Lamento`.
2. Run `.\tools\blender\rebuild.ps1 <name>`. `kael.tscn` etc. already use
   `scenes/characters/<name>_model.tscn`, so nothing else changes.
3. Bone names (fixed): Hips, Spine, Chest, Neck, Head, Shoulder/UpperArm/LowerArm/Hand _L/_R,
   UpperLeg/LowerLeg/Foot _L/_R, and the attach points Weapon_R (main hand grip), Weapon_L
   (off-hand reverse grip), Back (slung across the back), Sheath (left hip), Scabbard (a sword
   worn at the left hip: its head is where the sheathed sword's grip sits) and Knife (across the
   small of the back). A character with `*_sheathed` animations, a `Sword` prop node and a
   `Scabbard` prop node carries its sword sheathed (the game moves `Sword` between Weapon_R and
   Scabbard); pose an arm on an attach bone with `{"hold": ("Scabbard", t, roll)}` (pose.py).
4. A script for the model's root (like Aeneas's outfit switches): set `ch.root_script` before
   `finish()`; make_wrapper.gd puts it on.
