# Level 1 — The Empty Town (arc 0.1)

> **The story was retold by the author on 2026-10-26: see `docs/empty_town_story.md`, which supersedes the beats below where they disagree. It is built: see "The retold story, built (2026-10-26)" at the end. Beats 5-12 below, the "I sacrifice" line, the lieutenant fed to the cube and Valentina killed as a shield are the OLD version.**

Designed with the author, 2026-10-22. **Decided** = the author's call. **Proposed** = Claude's suggestion,
waiting for the author's OK.

## The place
- **Decided:** a brutalist village stacked on itself like Kowloon Walled City or Japanese apartment blocks,
  with an 80s Japanese sci-fi / cyberpunk feel: neon, CRT screens, vending machines, pipes, AC units, laundry.
- **Decided:** it sits inside the megastructure from the first shot. No sun and no time of day:
  artificial light and fog everywhere. The fog hides how big the space really is.
- **Decided:** the only way in is a bridge from another part of the megastructure. This is the
  "one entrance corridor" from the Notion notes.
- Notion detail to keep: wrong details the villagers treat as normal (a shop with no door, a well that's
  just a pipe junction, identical streets).
- **Proposed:** the main hall is at the bottom of a light well in the middle of the block. You come in
  at the bridge, partway up, and sneak *down* through the stack to reach it.

## Who's here
- **Aeneas:** carries a knife and a rifle. **Decided:** the knife does the work (takedowns, fights).
  **Proposed:** the rifle stays slung on his back as a story prop (they were coming back from a hunt);
  firing it is a loud last resort that alerts the whole block.
- **Isabella (his mother):** **Decided:** ink power. She draws sigils that bind people, follows Aeneas
  and hides with him, and takes guards down at the same moment he does.
- **Kael:** passing through. Meets them at the start, splits off, and comes back at the end to save Aeneas.
- **Valentina:** the girl Aeneas likes ("Valentina" is still a working name). Dies in the hall.
- **The Agency squad:** the captain, his lieutenant, and agents. **Proposed:** they're calm and orderly,
  rounding people up rather than looting. Per Notion, the Agency is still "controlled, strategic, subtle"
  until Ouros takes over.

## The beats
1. **The bridge.** Aeneas and Isabella walk back toward the block. Something's wrong right away: too
   quiet, lights on, nobody around. Teaches movement.
2. **Kael.** Near the end of the bridge they meet Kael, who's passing through and asks if anyone lives
   here. They tell him yes.
3. **The round-up.** From a balcony over the light well they see agents leading villagers across the
   catwalk and down toward the hall: the same route the player takes next. Kael splits off.
   (Changed while gray-boxing: the well is too deep and narrow to see the courtyard floor from the
   rim, so the captives cross the catwalk where you can see them.)
4. **Sneaking down through the stack.** Stairwells, walkways, rooftops and alleys, past patrols.
   Paired takedowns: Isabella binds one guard with ink while Aeneas takes another with the knife.
5. **Breaking cover.** Near the hall, Aeneas sees Valentina being dragged off. The player breaks cover
   and frees her from one agent, then more arrive and they're all caught.
6. **The hall.** Villagers are being sacrificed through a Black Cube to the captain.
7. **The perfect sacrifice** (cutscene). Isabella draws ink circles and symbols to strengthen it, rings
   her bell, says "I sacrifice," and is gone. (Old version: now "Sacrificio", see the end.) This is the first sacrifice anyone sees, and it's flawless.
8. **The eruption** (playable). Aeneas's raw gravity tears the hall apart. He can barely steer it.
   The Agency starts losing.
9. **The captain cheats** (Proposed). He feeds his own lieutenant to the Cube for power. It's a rushed,
   hijacked sacrifice right after Isabella's perfect one, so the player sees the difference.
10. **Boss fight, meant to lose.** The powered-up captain turns the fight around.
11. **Valentina** (Proposed). The captain grabs her as a shield. Aeneas pulls his power back so he
    won't crush her; the captain kills her anyway and knocks Aeneas down. He held back because he loved
    her, and it didn't save her.
12. **Kael steps in.** Blackout.
13. (Next: escape in the dark; the Agency hunts them.)

## Why these proposals
- **The captain's sacrifice:** Notion says every botched or hijacked sacrifice is measured against
  Isabella's. Putting one right after hers shows that on screen.
- **Valentina:** her death isn't Aeneas's fault; the captain kills her. That keeps "his fault" for Sera
  later. It still plants the theme: he loses someone because he loved her.
- **Isabella:** her sacrifice stays a calm, deliberate choice rather than being stabbed first, so it
  reads as "perfect".

## The gray-box (built 2026-10-22): `scenes/levels/empty_town.tscn`
The block surrounds a central light well, 18 x 18 m. Its decks step down around the well, and the
route spirals down. Checker floors mark the route.
| Where | Height | What happens |
| --- | --- | --- |
| Start ledge + bridge (66 m) | 24 m | Beat 1. Kael waits near the far end (beat 2). |
| South deck: gate alley, rim, overlook balcony | 24 m | Beat 3: watch the round-up on the catwalk. |
| Ramp down to the East deck | 24 → 16 m | Beat 4: sneaking starts. |
| Catwalk across the well | 16 → 8 m | Exposed: anyone in the courtyard can see you. |
| West deck alleys (a loop: west, south, east) | 8 m | Patrols and takedowns go here. |
| Ramp down into the courtyard | 8 → 0 m | The pipe-junction "well" is in the middle. |
| Courtyard near the hall door | 0 m | Beat 5: Valentina. |
| The hall (stage, Black Cube) | 0 m | Beats 6–12. |

Running straight through takes about 40 seconds. Capsules are stand-ins (black = Agency,
beige = villagers); floating yellow text marks each beat. Fall off an edge and you're put back on
the last ground you stood on.

## Build order (small slices, play each one)
1. ~~Gray-box the town (bridge → stack → light well → hall). Walk it start to finish, no enemies.~~ Done.
2. ~~Isabella follows and hides with you.~~ Done: she follows your exact path, a little to the side,
   and copies your crouch. Her ink takedowns come with slice 3.
3. ~~Crouching, guard patrols, getting spotted, knife takedowns, paired ink takedowns.~~ Done.
   Four agents: one patrolling the East deck past the foot of the ramp; a pair at the end of the
   catwalk who watch each other (a paired takedown); one patrolling the alley's east leg.
   **Decided:** Aeneas's knife takedowns kill (a blood pool spreads under the body). Isabella's
   ink binds drop them with no blood; whether a bind kills is still open.
4. ~~Dialogue and simple cutscenes.~~ Done (2026-10-22): arrival, Kael, the round-up and a
   Valentina stub play from `data/dialogue/empty_town.txt` with fixed camera shots. The lines are
   drafts for the author to rewrite.
5. ~~The hall: sacrifice cutscene, eruption, captain fight, ending.~~ Built 2026-10-24 (beats 5–12):
   - **Valentina (tutorial fight):** three agents in the courtyard; Souls-style sword combat
     (see README). Dying restarts at the courtyard checkpoint with the same fight.
   - **The capture:** reinforcements arrive (set dressing), fade to the hall. **Decided:** Isabella's
     follower ends here; she is a stand-in on the stage for the sacrifice.
   - **The sacrifice:** villagers vanish into the cube; Isabella draws the ink circle, rings the
     bell, "Sacrificio" (was "I sacrifice"), gone. Replaced 2026-10-26, see the end.
   - **The eruption (playable):** Aeneas can't be hurt; each press slams everything within 7 m.
     Four agents attack; when they're down the captain steps in.
   - **Captain phase 1:** a fair fight (260 hp, hard hits, parryable). **Decided 2026-10-25 (the
     author):** "completely choreographed because the cutscenes". The captain plays a fixed list of
     beats (step in, feint, swing, combo, a pause, a heavy cut you must dodge, short camera cuts)
     from `data/fights/captain.txt`; the lieutenant keeps to his shoulder and cuts in now and then.
     Hits land and parries stagger him, but hitting him never breaks his rhythm.
   - **Lieutenant:** at half health the captain feeds him to the cube. The captain is then
     invulnerable and unblockable, and switches to his phase 2 beats, which end with a finishing blow.
   - **The loss:** Aeneas's death plays the Valentina scene, Kael, the blackout, then the Massacre.
   - **Proposed:** the lines are drafts; the captain's "Sacrificio" uses the trigger word from the
     massacre notes on purpose (same cult, same word).

## Detail pass (2026-10-24): buildings, life signs, inspect spots, sound
Built from the author's list ("life signs, inspect prompts, sound, more detail, breaks in the
city textures, doors that don't open").
- **Buildings:** every tower and skyline block is a Block in **Building** style: a ground floor of
  doors and shuttered shopfronts, 3 m window bays with blank corners, slab lines, a parapet, a plain
  roof. No windows on edges, roofs or undersides; ledges and extrusions stay blank. The tiles are
  `textures/building_atlas.png`. **Proposed:** the doorless shop sits on the gate alley's west
  wall at z 16..19, framing (and hiding) one of Tower2's painted doors; lit windows are picked per building from its position, so each run looks the same.
- **Life signs** (node `Life`): six TV windows (gate, east deck, alleys) that cut between blues and
  whites and go black now and then; four steam vents (gate, deck, alley, courtyard) with a grille
  each; three drips (catwalk, alley, hall door); four flickering lights with a **personality**
  (0 steady, 1 buzzing, 2 dying) on the gate light, the pink alley light, the hall front and the gate
  sign's glow. **Proposed:** the personalities as set; the author can change them in the Inspector.
- **Inspect spots** (node `Inspect`, prompt "E / Up: ..."): the well (a pipe junction), the doorless
  shop, a dropped basket in the alley, a running tap in the courtyard (z -7.2), the Agency poster on
  Tower7's west face, a lit vending machine, the laundry line, the hall door. The lines in
  `data/inspect/empty_town.txt` are DRAFT placeholders for the author to rewrite.
- **Sound:** footsteps on plates (bridge, catwalk), pavement (streets) and concrete (everything
  else), spaced by stride (1.6 m run, 1.1 m crouched, **proposed** 1.9 m sprint); the neon hum at
  seven signs; the vending hum at three machines; the cube's drone in the hall; swing whoosh, hit thud,
  parry clang, takedown stab. All synthesized placeholders; levels set blind, to be judged by ear.
- **Open:** the Laundry prompt can hide behind the takedown prompt near the west agent pair; the
  steam may read as a bright knot and the drips are tiny (judge in the editor). The menu highlight
  and each dialogue advance play `ui_blip`.

## Fix pass (2026-10-25): the author's "so many things are wrong" list, plus a six-reviewer audit
- **Stuck agents**: the stair agent stood inside the hall wall; the captain and lieutenant sat in the
  stage top. Moved. Fighters now path around the stage, columns and rails (navigation mesh over the
  courtyard and hall), keep apart instead of merging, can't hit through a ramp from below, and wait
  untouchable until their fight starts.
- **Footsteps**: remade from noise (the plates rang four tuned notes: the xylophone) and about 14 dB
  quieter; volume on the Player's Footsteps node. **Warping**: texture warping is off.
- **Story flow**: the round-up now plays on the rim outside the gate alley (it only played from the
  balcony). The Valentina fight starts as you step off the ramp or anywhere in the courtyard, on the
  floor (it used to start on the ramp, where the agents piled against its side). After the fight the
  capture waits at the hall door, so the well, the tap and the hall door can be looked at first.
  Dying to the captain before half restarts in the hall with the earlier agents still down.
  **Decided by the audit, not the author (Proposed):** jumping into the light well is a fall (FELL).
- **Sound**: hum loops no longer tick at the seam; each hum is a little off-pitch from the others;
  the alley sign is quieter; the running tap, the well's pipe and the courtyard machines now sound;
  the knife is a thud, not a note.
- **Props**: about 30 placements fixed: AC units floating, sunk or mounted backwards, signs inside
  walls and ducts, the alley vending machine facing the wall, the phone booth inside Tower4, the deck
  barrels inside Tower6, ducts at head height in the alley, a vent blowing into a tower, rails and
  pipes z-fighting. The doorless shop now frames one of Tower2's painted doors.
- **Shots**: the Valentina and hall cameras were blocked by a pipe and a column; reframed. The ink
  circle's rings stand upright in front of Isabella. TV windows sit inside painted windows.
- **Open**: the Laundry prompt still yields to the takedown prompt while the west pair stands (by
  design). guard.gd and player_combat.gd are over the 300-line rule from before this pass, and
  player.gd is back at ~330 lines; splitting them is a separate job.

## Round 5 (2026-10-25): the author's list (lit cracked windows, cracked vending machines, cleaner streets, the well)
- **Windows:** more of the lit windows are cracked now (crisp one-pixel cracks round a small hole,
  the light still on behind them), and the atlas has three more window columns (13-15), so the
  fronts repeat less. Boarded and broken-dark windows stay.
- **Vending machines:** some lit, some dark, some cracked. New fronts: lit and cracked, switched
  off (one red standby lamp), off and smashed (`materials/empty_town_vending_*.tres`). The gate's
  second machine and the deck machine are cracked; the deck machine's light is failing and takes
  its glow with it (on, off, on). New machines: a lit and a dead pair in the courtyard (they
  replace the two flat neon boxes), a cracked lit and a dark one on the rim, a smashed one in the
  alley's back corner, and on the start ledge a smashed one and a cracked one that flickers.
  The inspected machine at the gate (DeadVending) is still the lit, humming one.
- **Lived-in streets cleaner, the rest dirtier:** the gate alley, rim, deck, alleys and courtyard
  are swept (loose debris, rubble and grime stains off the floors; the buildings keep their
  wear), with plants by doors and stalls, a broom, and a doormat at every door. The start
  ledge is full of trash: two skips heaped with bags, bags along the rails, rubble, debris,
  crates, dead cables, grime. Trash too in the tunnel mouth, on the bridge, the overlook and the
  back corners (the alley's north end, the deck's north-east corner).
- **Where they came from:** the black panel in the megastructure wall is now a real opening, a
  steel frame with hazard stripes and a lamp over it, and a tunnel behind with ceiling lights
  that fade into the dark (one failing). It shows in the opening shot behind Isabella and Aeneas.
  It's walkable for 34 m and ends in the dark.
- **Windows and doors where real buildings have them** (`scripts/building_faces.gd` with the new
  `scripts/building_context.gd`, every level): a door or shopfront only with floor right at its
  foot and room in front (never facing a drop, never over a roof or under a slab; onto a roof
  or a small ledge a door, not a shop); a face with nothing to step onto gets no ground floor,
  windows start at the bottom (the towers' outer faces over the drop); a courtyard or deck running
  along a foundation wall puts the ground floor at that height (the courtyard walls now have
  doors and shopfronts at the courtyard floor); no window with something solid within 1.5 m in
  front (a neighbour pressed against it, a slab or walkway across it, a ramp against it).
  Rails, pipes, signs and panels don't count. Set a Block's metadata `faces_context` to false
  to turn this off for that block. In the editor a building rebuilds when it moves, not when its
  neighbour moves: nudge it (or reopen the scene) to refresh its doors and windows.
- **The concrete extension blocks** on the outer south face (Bay1-7) and Tower3's overhang are
  gone. In their place 28 AC units (`scripts/props/empty_town_ac.gd`): a unit under a window,
  its two refrigerant lines out of the side and into the wall through a cover plate, a drain down
  from its tray; a rust streak under most. **Proposed:** the well's two smaller ledges (Tower7's
  and the north one) stay as broken balconies with their rebar; Tower3's rebar now sticks out of
  the wall where its slab broke away.
- **Short pipes with a reason:** downpipes off the roof edges of the five rooftop blocks (a
  hopper on the parapet, the pipe down, a shoe over the roof below), and a feed from Tower3Top's
  wall into the water tank beside it.
- **The well:** round pipes, properly joined: the riser comes up out of a worn concrete collar,
  a cross fitting at 2.9 m, the east main runs to the courtyard wall and along it into the hall's
  frame duct, the west main drops into the ground. Flanges at every joint and end, a valve wheel
  on top where the overhead cables tie on, a rope wound round it (`empty_town_well.gd`, Wellhead).
  **The tap** moved here: a tap cut into the west main's standpipe, blue water falling into a
  round concrete basin (Tap basin), with its look-at prompt, its sound and a drip. The bucket
  that lay by the old tap lies by the basin. Both are solid, so the navigation mesh was rebaked.
- **For the author:** the well's and the tap's look-at lines are yours and unchanged, but the well
  line says there's no water in it, and the tap line has the water hitting the plates; with the
  tap now at the well, over a basin, you may want to rewrite both.

## Round 8 (2026-10-25): Blame!-scale skyline, a prerendered city behind the town, the tap
- **The far city** is now a prerendered backdrop: a city of about 550 megastructure blocks
  (70-800 m wide, kilometres tall, 0.7-7.5 km away, bridges between them, a ceiling far overhead)
  rendered once into `textures/backdrop_city.png` and shown as the level's sky. Tiny sparse lights
  (a few pixels at most, some in dotted walkway lines), layers fading into the fog. Being a sky it
  never clips, so it fills the back of the town in the second opening shot, and it looks the same
  from the bridge, the streets and every shot. Its haze is the fog colour: change the fog, re-render it.
- **The skyline towers** around the town are taller (300-470 m) megastructure shafts with the new
  tiny-window faces all the way up; the glowing crowns on top are gone.
- **The apartment towers** switch to the same tiny-window bays above 42 m (`faces_dense_above` on
  each tower): the street fronts keep their big windows, the tops read as one vast structure.
  Four AC units on the south faces (and their streaks) moved down one storey to stay under real windows.
- **The tap** sounds like a sink or a hose now: a thin hiss and a trickle of small bubbles, half
  as loud, heard within about 8 m (it carried 14).
- **Proposed:** the 42 m line, the backdrop's density and brightness, and the slit-window tile are
  first passes; say if the tops should go further down (or stay big-windowed) or the city be darker.

## Round 8 (2026-10-25): the town as part of one world
- **Decided (the author):** the levels blend into one big level with walkways between them. The town
  is the first zone of `scenes/world/world.tscn`; this scene is untouched and still plays alone (F6).
- **Proposed:** the way down to Black Sand is a service door at the back of the hall's stage, right of
  the cube, behind a shutter that stays shut until the story reaches Black Sand (so the captain fight
  and the loss play exactly as before). Behind it, a stair inside the town's foundation comes out high
  on the sand drift against Black Sand's town wall. In the world, the hall's back wall is the walkway's
  own copy with the doorway cut in (`scenes/world/descent.tscn`).
- **Proposed:** once the story has passed the hall, the town you walk back into is empty: no agents,
  no figures, no story scenes.

## The retold story, built (2026-10-26)
Built from the author's telling in `docs/empty_town_story.md`. Scenes in `data/dialogue/empty_town.txt`
(new lines marked DRAFT), fights in `data/fights/captain.txt` and `data/fights/lieutenant.txt`.
| Beat | Scene / fight | What plays |
| --- | --- | --- |
| 1 | `arrival`, `kael_meeting`, `round_up` | The author's lines; the round-up adds a DRAFT line for the ransacked town. |
| 2 | `first_pair` (trigger `StoryTriggers/FirstPair`) | The first time the paired-takedown prompt shows (the catwalk pair): a side-on shot of Aeneas and Isabella, "You get the first one, I'll get the second." Her ink takes the second agent when you press. |
| 3 | `valentina` -> **ValentinaFight** | Valentina (her real model) is dragged across the courtyard by an agent (`HallFight/Dragger`), who then holds her at knife point by the hall wall. Three agents attack; he stays out of it. |
| 4 | `captured` (ValentinaFight's Won Scene) | Aeneas corners him; the lieutenant's knife at his throat; another agent (`Figures/IsabellaCaptor`) has Isabella. Fade to the hall, all three captive. No walk to the door any more. |
| 5 | `captured`, continued | The bonfire, a body thrown on, the cube's aura. The lieutenant reports; the captain walks over. Isabella's ink: her captor and two guards (`Figures/HallGuard1`, `HallGuard2`) drop. She goes for the captain, his hand goes into her chest (cut away to Aeneas). Her last words, the circle painted round her (`InkCircle`, `scripts/ink_circle.gd`), "Sacrificio", her soul rises into the cube (surge); her body stays in the circle. |
| 6 | `captured` end -> **HallFight** | The seal breaks: a burst and a white flash, then the playable eruption kills the hall agents and Valentina's holder. The captain and lieutenant are spared. |
| 7 | `eruption_end` -> **LieutenantFight** | The power drains; the lieutenant comes at him: a slow, easy choreographed fight. |
| 8 | `valentina_fire` (LieutenantFight's Won Scene) | The captain lifts Valentina by the throat, "Sacrificio", throws her on the fire; the cube surges. |
| 9 | **CaptainFight** (fists) | Phase 1 is fair; past half health `captain_turn` empowers him and phase 2 can't be won. Dying before half restarts in the hall. |
| 10-11 | `captain_throat` (Death Scene) | He holds Aeneas up by the throat; the arm speech (DRAFT); the screen dims; a blade takes his arm; both drop to their knees; Kael with a bloody sword; the beheading is a cut to the fire; "Sacrificio" over black; the Massacre memory. |

**Proposed (taste calls made while building; the author decides):**
- The paired-takedown line plays as a short cutscene the first time the prompt appears, in a side-on shot.
- Valentina's holder holds her at knife point during the fight, against the hall's front wall.
- The eruption's start: a ring along the floor, the fire leaping and a white flash.
- After the eruption Aeneas fights the lieutenant with his sword (the power has drained); the fight is slow and easy.
- The captain turns at half health with "Good. Now I stop playing." (DRAFT) and becomes unbeatable;
  Valentina's sacrifice is his boost before the fight.
- The bodies of the agents Isabella kills are moved clear of her circle during the cut-away.
- Who says the last "Sacrificio" is left open: narration, "Far away, someone says...".
- The captain's arm is not shown falling; the cut is a flash in the dim, then he kneels with the stump.

**Saves:** scene names kept: arrival, kael_meeting, round_up, valentina, captured. New scenes:
first_pair, eruption_end, valentina_fire, captain_turn, captain_throat (old captain_phase, lieutenant
and valentina_death are gone). Moved nodes: ValentinaFight/Dragger is now HallFight/Dragger, and
CaptainFight/Lieutenant is now LieutenantFight/Lieutenant. A save made in the hall before today
(old story) can come back odd (those two agents standing where they started); a save before the
courtyard is fine. Figures/HallVillagers, Figures/Reinforcements and the old upright InkCircle are gone.
