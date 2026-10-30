# Characters (Blender scripts)

Every character is built by a Python script here, run by Blender with no window. Nothing is
modelled by hand, so to change a character you change a number in its script and rebuild.

## Rebuild a character
Close the Godot editor, then in PowerShell from the project folder:

```
.\tools\blender\rebuild.ps1 aeneas          # one character
.\tools\blender\rebuild.ps1 aeneas,kael    # several (commas between the names)
.\tools\blender\rebuild.ps1                 # all of them
```

That runs the character's script in Blender, imports the result into Godot, and rebuilds its
model scene. Open Godot again and press F5.

## What's where
| File | What it does |
| --- | --- |
| `aeneas.py` | Aeneas: colours (top of the file), his face (`FACE`), jacket / collar / sleeve / boot shapes, his sword Rocinante and its scabbard, knife and rifle; `PONCHO = True` builds the first arc's poncho |
| `aeneas_gear.py` | Aeneas's poncho (shape, hem, hood, sling, how it follows his arms), its painting, and the knife's sheath at the small of his back |
| `aeneas_hair.py` | Aeneas's haircut (after Jim Hawkins): the shell (buzzed sides, the long top standing proud above `LEDGE`), the clumps (`FRINGE` swept across his forehead, `SIDES`, `BACK`, `CROWN`: paths of angle, height, lift), the tied tail |
| `aeneas_anims.py` | Aeneas's own animations: the walks with the sword sheathed (`*_sheathed`, left hand on the scabbard), `iai` (the stance), `draw_cut` (the quick draw), `sheathe` |
| `agent.py` | The Agency agent: white long coat, black helmet with the visor slit, dark armour, dust at the hem, a knife across the small of his back; his own idle and patrol walk |
| `lieutenant.py` | The lieutenant: the agent's body bare-headed (his face `FACE`, cropped hair, the eyepiece); his GuardData file names `lieutenant_model.tscn` as his Model Scene |
| `anims_agency.py` | The agents' story poses: `captor_knife` / `captor_knife_low` (the knife at Aeneas's / Isabella's throat from behind), `drag_by_arm`, `heave_body` |
| `captain.py` | The Agency captain: taller, one arm (his left), dark uniform and breastplate, bare-headed (his face `FACE`: older, hard; grey hair slicked back; the eyepiece); no sword: he fights with his fist. His arm below the cut is its own mesh (`Severable`) over a hidden `Stump` |
| `captain_gear.py` | The captain's white coat draped round his shoulders (shape `CAPE`, folds, how it follows his chest, arm and thighs), its collar, the empty sleeves, epaulettes, and the pinned stump of his right arm |
| `captain_anims.py` | The captain fights left-handed: every animation mirrored, nothing keyed on the right arm, a run without the heel kick so his back foot stays under the coat |
| `captain_fists.py` | His blows: the jab (`telegraph` / `strike`), the hook (`telegraph_hook` / `strike_hook`), the overhand (`telegraph_heavy` / `strike_heavy`) |
| `captain_story.py` | His hall poses (`spear_hand`, `lift_throat`, `hold_throat`, `arm_severed`, `throw_one_arm`) and `split_arm()`: where the arm is cut (`CUT_T`) |
| `isabella.py`, `isabella_parts.py` | Isabella: robe, shawl, obi, hair and bun, her face (`FACE`), the brush and the bell |
| `isabella_anims.py` | Her hall poses: `break_free`, `lunge`, `stabbed`, `stagger_back`, `kneel_draw` (the circle on the floor), `collapse` |
| `kael.py`, `kael_gear.py` | Kael (long black coat, white hair, his face `FACE`) and Lamento (on his back, and a drawn copy in his hand, clean and bloody) |
| `kael_anims.py` | His walks with the right hand free, and `draw_lamento`, `sever_cut`, `behead_cut`, `bloody_stand` |
| `valentina.py` | Valentina: her face (`FACE`), blouse with a crossed collar, indigo corselet, marigold sash and kerchief, ochre skirt with a sashiko hem, braid |
| `villager_body.py` | A villager's body wrapped in a shroud and bound with rope (a prop: no animations) |
| `agency_heads.py` | The Agency's heads: the agents' helmet, and the officers' bare head (face, short hair `SLICKED` / `CROPPED`, the eyepiece over the left eye whose lens is their glowing `Visor`) |
| `agency_parts.py` | What the Agency share: shells and plates, the helmet and visor, the blade, and the weathering paint (`weather()`: dust at a hem; `chips()`: knocks in armour) |
| `grey_bodies.py` | Plain grey stand-ins for Kael, Isabella and the guards, until their own scripts exist |
| `rig.py` | The shared skeleton and its bone names |
| `anims_loco.py` | idle, walk, run, sprint, crouch_idle, crouch_walk, jump, fall |
| `anims_combat.py` | the fighting guard, block, dodge roll, hit, knife stab, death; the guards' telegraph, strike, stagger; Isabella's cast (her calligraphy slash) |
| `anims_story.py` | the story poses everyone has: `hostage`, `drop_to_knees`, `captive`, `dragged`, `limp`, `lifted_by_throat`, `held_by_throat` (and where a partner stands: `HOSTAGE_GAP`, `THROAT_GAP`, `DRAG_OFFSET`) |
| `anims_swings.py` | the sword swings (`windup_L/R`, `sweep_LR/RL`) as tables of keys: where the hand goes and where the blade points |
| `natural_arm.py` | keeps a sword arm human: for every frame of a swing it picks the elbow and the turn of the blade in the hand with the least strain (no bent-back wrists or wrung forearms) and the smoothest path |
| `face.py`, `face_paint.py` | Faces: the head mesh with its features (eye sockets, brow, nose, cheekbones, lips, chin, jaw; `relief()`), the ears, and the paint (eyes, brows, lips, shading, age lines, stubble). Each character passes a look (`face.look(face.MAN, ...)`) |
| `base_body.py`, `body.py`, `props.py` | shapes every character is made of (torso, limbs, head, hair locks, hands, boots, swords) |
| `mesh.py`, `paint.py`, `pose.py` | the machinery: tubes of polygons, the painted texture, posing and keying |
| `preview.py` | contact sheets of animations rendered in Blender (handy before going into Godot) |
| `make_wrapper.gd` | (Godot) builds `scenes/characters/<name>_model.tscn` from the export |

Outputs land in `models/characters/` (`<name>.glb` with every animation, `<name>_props.glb`,
`<name>.png` the texture, 512 px for those with a face, 256 for the rest, `<name>_mat.tres` the PS1 material) and
`scenes/characters/<name>_model.tscn`, which `player.tscn`, `kael.tscn`, `isabella.tscn`,
`valentina.tscn` and `guard.tscn` use as their **Model**. A scene plays a story pose by name through
the model's Animator (`story_pose("kneel_draw")`, `story_clear()`; `scripts/character_story.gd`).

## Tuning
- **Colours**: the `C = {...}` table at the top of `aeneas.py`.
- **Shapes**: the profile tables (`JACKET`, `SLEEVE`, `BOOT`...): each row is a ring of the shape,
  height first, then radii. Bigger number, wider.
- **Animation timing**: keys are `(time in seconds, pose)`. The cut's `SWEEP_HIT`
  (`anims_combat.py`) is when the blade crosses his front; `character_animator.gd` has the same
  number (`SWEEP_HIT`) and the hit lands then, so change both together. Isabella's slash:
  `CAST_HIT` (both files too) is when her stroke ends and the ink flies to the agent.
- **The swings**: the rows of `SWEEP_LR` / `SWEEP_RL` in `anims_swings.py` (the comment at the
  top says what each number is). The hit row's radius is how far his arm reaches; the last rows'
  height is how high the follow-through rises. You only say where the hand goes and where the
  blade points: `natural_arm.py` works out the elbow and wrist. How much strain it allows:
  `WRIST_FREE`, `FOREARM_FREE`... at its top.
- **Faces**: each character's `FACE = face.look(face.MAN / WOMAN / YOUNG_MAN, ...)` (the starting
  numbers are `BASE` in `face.py`). Shape: `nose` (how far it stands out), `nose_tip_z`, `socket` (how deep
  the eyes sit), `brow_ridge`, `cheek`, `hollow`, `lip_up` / `lip_lo`, `chin`, `jaw`; paint: `eye_w` /
  `eye_h` (eye size), `iris_r`, `eye_tilt`, `lash`, `wing`, the brows (`brow_z0` inner end, `brow_z1`
  outer, `brow_arch`, `brow_thick`), `smile` / `smirk`, `blush`, `age`, `stubble`. Rebuild to see it.
- **The anime eyes** (everyone at once): `BASE` in `face.py` scales every character's eye numbers
  (`face.eyes()`): `eye_size` (the whole opening), `eye_open` (taller still), `iris_size`, `iris_tall`
  (the iris an upright oval), `lash_size` (the upper lash line). The highlights are in `face_paint._eye`.
  The officers' eyepiece grows with `eye_size`. Rebuild all six faces after changing them:
  `.\tools\blender\rebuild.ps1 aeneas,isabella,valentina,kael,lieutenant,captain`.
- **The haircut**: `aeneas_hair.py`. `LEDGE` / `LEDGE_BACK` is where the buzzed sides stop,
  `volume()` how proud the long top stands, and each lock is a path you can push about.
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
  The captain's coat shape: `CAPE` rows in `captain_gear.py`; his height `HEIGHT` in `captain.py`; how far
  his blows reach: the fist rows in `captain_fists.py` (and `attack_range` in `data/enemies/agency_captain.tres`).
- **Story poses**: each is a few keys `(time, pose)`; the times a scene waits for are the constants at the
  top of each file (`BREAK_HITS`, `CIRCLE_START`, `SPEAR_HIT`, `THROW_RELEASE`, `HEAVE_RELEASE`,
  `LAMENTO_SWAP`, `SEVER_HIT`, `BEHEAD_HIT`). `LAMENTO_SWAP` and `HEAVE_RELEASE` are in
  `scripts/character_story.gd` too: change both together.
- **Wobble on characters**: `snap_scale` in `<name>_mat.tres` (1 = as wobbly as the walls, 2 = half).

## Making a new character (for the look scripts)
1. Copy `aeneas.py` to `<name>.py`. Keep the structure: `cb.Character("<name>", height=...)`, build
   into `ch.part("Body")` with the `body.*` / `base_body.*` helpers, paint each block of `ch.atlas`,
   add props with `ch.prop(mesh_name, bone, node_name)` (grip at the origin, length along +Y), then
   `ch.finish()`. Guards: put the coat in `ch.part("Coat")` (tinted with GuardData.coat_color) and
   any trim in `ch.part("Trim")` (GuardData.trim_color), paint both near-white, name the eye prop
   `Visor` (on the `Head` bone), and a swordsman keeps a prop node called `Blade` (on `Weapon_R`; the
   captain fights with his fist and has none). A guard kind with its own model names its
   `scenes/characters/<name>_model.tscn` as **Model Scene** in its GuardData file (data/enemies/).
   Isabella: props `Brush` (Weapon_R) and `Bell` (Sheath). Kael: `Lamento` (Back) and `LamentoDrawn`
   (Weapon_R: meshes `LamentoHand` and `LamentoBlood`). Agents: `Knife` (the Knife bone).
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
