# Customizing Aethereal

How to build and change levels in the Godot editor without writing code. Each part is short:
read the one you need. The **Aethereal** dock does most of the work.

## The Aethereal dock

It's a tab called **Aethereal** on the right, next to the **Inspector**. If you don't see it:
**Project > Project Settings > Plugins**, tick **Enable** next to **Aethereal Tools**.

How placing works:

1. Open a level (double-click it in `scenes/levels/` in the FileSystem panel).
2. In the 3D view, look at the spot you want. The **centre of the view** is what counts.
   (Hold the right mouse button and use WASD to fly; Q and E go down and up.)
3. Press a button. The new thing lands on the floor there, turned the way you're looking, and is
   **selected**, so you can move it straight away: **W** = move, **E** = rotate, **R** = scale.
   **Page Down** drops a selected thing onto the floor under it.
4. Changed your mind? **Ctrl+Z** takes it out again.
5. **Ctrl+S** saves the level.

New things go into tidy group nodes: `Guards`, `Checkpoints`, `StoryTriggers`, `Inspect`, `Life`,
`Dressing`, `Shots`. If the level doesn't have that group yet, the dock makes it.

**Place: At the selected node** puts the next thing on top of the selected Block, or on the floor
under any other selected node, instead of where you look.

What the buttons make:

| Button | What you get |
| --- | --- |
| Story trigger | A zone that plays a dialogue scene when Aeneas walks in |
| Look-at spot | Something Aeneas can look at ("E / Up: Look") |
| Camera shot | A story camera, exactly where your 3D view is looking |
| Checkpoint | A restart spot (spotted, slain, fell) that also saves the game |
| Agency guard | An agent with a two-point patrol |
| Patrol point | One more point on the selected guard's walk |
| Fight | A story fight with one agent in it |
| Flicker light, Steam vent, Drip, TV window | The small signs of life |
| Block, Building | A box to build with, and a box with building fronts |
| Props | Every prop script in `scripts/props/` (and each level's own props folder) |
| Bake navigation | Updates where fighters can walk |
| New level... | A new level from the template |
| Open the guide | This page |

Hover over any button for a reminder of what it does.

**Prefabs.** The same things are also ready-made scenes in `scenes/prefabs/`: drag one from the
FileSystem panel into the 3D view. The difference: a dragged prefab stays linked to its file (open
`scenes/prefabs/checkpoint.tscn`, change it, and every dragged copy changes too), while a button
makes a separate copy you can change freely. When unsure, use the buttons.

## Make a new level

1. In the dock, press **New level...**, type its name (for example `The Old Mill`) and press OK.
   It makes `scenes/levels/the_old_mill.tscn` and `data/dialogue/the_old_mill.txt`, and opens the level.
2. The new level already has: a 40 m floor and one building (under `Layout`), a sun and fog
   (`WorldEnvironment`, `Sun`), the **Player**, the **StealthDirector** (restarts after being
   spotted, slain or falling), an opening camera (`Shots/OpeningShot`), a trigger that plays the
   `arrival` scene at the start (`StoryTriggers/Arrival`), empty `Guards`, `Checkpoints`,
   `Inspect`, `Life` and `Dressing` groups, and a `Navigation` node.
3. Build it with Blocks (see "Blocks and buildings" below). Move the Player to where the level starts.
4. **Put it in the chapter list** so the title screen offers it. Open `scripts/ui/chapters.gd`
   (double-click it) and add a line to the list, in story order:

   ```
   ["0.5", "The Old Mill", "res://scenes/levels/the_old_mill.tscn"],
   ```

   Keep the comma at the end. An empty number (`""`) marks a test space, which is never saved.
5. **Lead into it from the level before.** At the end of that level's last dialogue scene, add
   `[level res://scenes/levels/the_old_mill.tscn]`.
6. Play it: **F6** plays the open level; **F5** starts from the title screen.

Without the button: in the FileSystem panel, right-click `scenes/prefabs/level_template.tscn` >
**Duplicate...**, give it a new name in `scenes/levels/`, and make its dialogue file by hand.

To make the new level part of the big world (walk into it instead of loading it), see below.

## The big world (one connected level)

The Empty Town, Black Sand and the Vacuum Station are one place you can walk through:
`scenes/world/world.tscn`. The Massacre stays its own scene (it is a memory). F5 and the chapter
list play the world; each level scene is still its own file, and **F6** on it still plays it alone,
so you keep editing the levels exactly as before. Open `world.tscn` to see them all in place.

How it is put together (the Scene panel of `world.tscn`):
- **Zones**: one **WorldZone** per place (`Town`, `BlackSand`, `Station`), holding that level as an
  instance and a **Start** marker (where a chapter starts). Move the zone node to move the level.
  In the Inspector: **Order** (the chapter's number after the dot), **Box** (the zone's space; its
  bottom is where falling restarts you), and the lists the world uses instead of editing the level:
  **Remove In World** (the level's own Player and StealthDirector), **Followers** (who joins Aeneas
  once the story gets here: Isabella in the town, Kael in Black Sand, the station's flashlight),
  **Gone After** / **Hidden After** / **Shown After** (what changes once the story has moved past
  this zone: the town's agents, figures, story triggers and checkpoints are gone after the hall; Kael's figure
  in Black Sand is hidden and the following Kael shown).
- **Links**: the walkways. `Descent` (`scenes/world/descent.tscn`) is the service stair: a door at
  the back of the hall's stage (shut until the story reaches Black Sand), three flights down inside
  the town's foundation, out through a door in the town wall high on the drifted sand, and a
  gangway down the drift. `RoadTunnel` (`scenes/world/road_tunnel.tscn`) runs from the bottom of
  Black Sand's arch ramp to the station's entry corridor. A link lists the pieces of each level it
  replaces (**Replaces In A/B**: the hall's back wall, Black Sand's town wall and barrier, the two
  end walls of the tunnel) and brings its own; its **InA** / **InB** pieces move into that level
  when the game starts, so they show and hide with it. If you change one of the replaced pieces in
  its level, change the link's copy too (the world uses the link's).
- One **Player**, one **StealthDirector** (every level's checkpoints and agents), a **Carry** node
  for whoever follows Aeneas, and one **WorldEnvironment** that the world fills in itself.

While you play, only the zone Aeneas is in is shown and running (both zones while he walks a link),
so playing costs about what one level costs; loading still builds all three (see "Loading" below).
Each zone keeps its own fog, light and sky: set them
on that level's `WorldEnvironment` as before; on a link they fade from one into the other, and the
music crossfades to the next level's track.

The story: `[level ...]` and the chapter list still name the level file. If that level is in the
world, the world loads with Aeneas at that zone's Start; if he is already in the world, the line just
lets him walk on (Black Sand's `down` scene fades out and back in, and he walks the tunnel into
the station). Use `[teleport MarkerName]` after a fade when the story skips time. Walking into
the next zone saves the game at that zone's `Start` (see "Saving"). A scene finds cameras, markers and characters in
its own level first (a `black_sand.txt` scene uses Black Sand's `TownShot`, not the town's).

To add a zone:
1. Build the level as usual (its own Player, sun and fog), and add it to `scripts/ui/chapters.gd`.
2. In `world.tscn`, select `Zones`, add a child Node3D, give it the script
   `scripts/world/world_zone.gd`, and drag the level scene onto it (it must be the zone's first
   child). Add a Marker3D called `Start` where Aeneas begins. Move the zone so the level sits where
   it belongs, clear of the other levels.
3. Set **Order** and **Box** (cover where he can walk; boxes must not overlap), and fill in the
   lists (at least `Player`, and `StealthDirector` if the level has one, under **Remove In World**).
4. Add the level's path to `LEVELS` at the top of `scripts/world/world.gd`.
5. Build a link: a scene whose top node has `scripts/world/world_link.gd`, with **Zone A** and
   **Zone B** set, a **Box** covering the walkway, two markers `Blend/A` and `Blend/B` (the fade runs
   from A to B), the walkway's Blocks, and **Replaces In A/B** for the end walls in the way. Instance
   it under `Links`. (The two links were built by the scratch script `world/build_links.gd`, and the
   world by `world/build_world.gd`; after the first build, edit them in the editor.)
6. Walk it: the walkway must have no steps (ramps), like any level.

## Loading

Nothing to do here; this is how it works, so nothing surprises you.

- **Changing scenes** (New Game, Continue, a chapter, a `[level ...]` line) goes through Story: the
  screen fades to black, the next scene loads on a background thread and is built a little each
  frame, so the window never freezes. If it takes more than a moment, a small **LOADING** line with
  a bar shows in the bottom-right corner. Its look is in `scripts/scene_loader.gd` (`attach`).
- **The title screen starts loading the world** as soon as it shows, and after every change the
  scenes its dialogue can lead to (`[level]` lines) start loading too, so the next change is quick.
  A level's music is loaded the same way.
- **Blocks and props build their mesh once**, when they are in a scene. In the editor that is the
  moment you open the scene or change a setting, exactly as before. While the game runs, identical
  plain Blocks share one mesh. Nothing is baked into files, so there is nothing to rebuild after
  editing a level.
- Writing a new prop script? Copy the pattern from any script in `scripts/props/`: the setters call
  `_rebuild()`, which is just `MeshBuild.request(self)`, and the building goes in `_rebuild_now()`
  (`scripts/mesh_build.gd` explains why). Build its shapes with `PropMesh`.
- **Renderer**: on Windows the game (and the editor) draws through Vulkan
  (**Project Settings > Rendering > Rendering Device > Driver** for Windows). On the Iris Xe laptop
  it gave the town a steadier frame rate and used a quarter of the video memory of D3D12, with the
  same picture. If Vulkan ever fails to start, Godot falls back to D3D12 by itself; to choose D3D12
  for good, set that driver back to `d3d12`.

## Saving

The game saves by itself: there is no save menu, and there is one save. **Continue** on the title
screen puts Aeneas back at the last save, with the place as he left it.

**When it saves**
- At a **checkpoint** that moves the restart point on. Continue puts him on the checkpoint.
- At the **end of a story scene**, where he stands. A scene that starts a fight (`[fight X]`) saves
  the start of that fight, so Continue starts the fight again.
- When a **story fight is won**, where he stands.
- When he **walks into the next zone** of the big world, at that zone's `Start`.
- At the **start of every level** (New Game, a chapter, a `[level ...]` line). Continue then starts
  that level the normal way, opening scene and all. This is the only save in the Massacre until its
  first scene ends.

It never saves during a fight, a scene, a restart or a fall; a save that comes up then waits for a
quiet moment. Nothing is saved when you pause or quit, and a level played on its own (F6) never
saves. When the file is written, a small diamond and the word **saved** fade in and out in the
bottom-right corner (`scripts/ui/hud_saved.gd`; set `SHOW` to false there to hide it).

**What it remembers**: the zone and how far the story has come, where he stands and which way he
and the camera face, the restart point, the story scenes finished (in order), the checkpoints
reached, the fights won, the agents down for good (where they lie, knifed or bound), look-at spots
that can only be read once, and the flashlight. Health is not saved: Continue starts at full health,
like every restart. Companions come back from the story: whoever has joined Aeneas by then follows
him, shown or hidden as the scenes left them.

**How Continue puts it back**: the level loads with Aeneas already at the saved spot, so no trigger
sees him at the start. The triggers of finished scenes are marked done, and those scenes are run
again without playing: only the commands that change the level for good (`[hide]`, `[show]`,
`[collapse]`, `[kill]`, `[empower]`, `[erupt]`, and where `[place]`, `[stand]`, `[move]`, `[pose]`
and `[ink]` leave people). A fight the save was in starts again a moment after
the screen fades in. Then the agents lie down where they fell, won fights stay won (the capture door
stays open), the checkpoints already reached count as passed, and the flashlight is as it was.

**The file** is `savegame.json` in the game's user folder (on Windows
`%APPDATA%\Godot\app_userdata\Aethereal 3D\`). It is plain text you can open. Each save is written to
`savegame.tmp.json` first and then replaces the old file, which stays as `savegame.bak.json`: a crash
in the middle of saving can't spoil the save, and a broken file falls back to the spare. A file from
a newer version of the game is never overwritten (it is kept as `savegame.v2.json`, or whichever
number). The old `save.cfg` from before saving still works (Continue starts that level) until the
first new save, which keeps it as `save.cfg.old`. To start over, choose New Game, or delete
`savegame.json` and `savegame.bak.json`.

**New Game and Chapters ask first** ("This replaces your saved game (0.3 Black Sand).", No has the
focus) whenever they would replace a save. With no save, or a save of the very start of that same
level, they go straight in.

**When you change the game**
- Saves name things by their node path and scene name. If you rename a dialogue scene, a trigger, a
  fight or an agent, older saves lose that part (the scene plays again, the agent stands up). Harmless,
  but expect it while testing.
- A new dialogue command that changes the level for good must also be handled in
  `scripts/story_replay.gd`, or Continue will forget what it did.
- Something new that changes for good (a door that opens, a lever) needs a line in
  `scripts/save_state.gd` (what goes in the file) and `scripts/save_restore.gd` (putting it back).
- The pieces: `scripts/autosave.gd` (when to save), `scripts/save_state.gd` (what),
  `scripts/ui/save_game.gd` (the file), `scripts/save_restore.gd` and `scripts/story_replay.gd`
  (Continue).

## Write dialogue scenes

Each level's scenes live in one plain-text file: `data/dialogue/<level>.txt`. Open it in any text
editor (or double-click it in Godot). Changes show up the next time you press F5 or F6.

```
=== kael_meeting ===
[camera KaelShot]
KAEL: Hello. My name is Kael.
Aeneas looks him over.
[camera]
```

- `=== name ===` starts a scene. Triggers and fights play it by this name.
- `NAME: words` is a spoken line (the name in capitals, then a colon).
- A line with no name is narration.
- Lines starting with `#` are notes to yourself; the game skips them.

Commands, one per line, in square brackets:

| Command | What it does |
| --- | --- |
| `[camera ShotName]` | Cut to a camera under the level's `Shots` node |
| `[camera]` | Back to the normal camera behind Aeneas |
| `[frame Name]` | Cut to a side-on shot of Aeneas and that character, wherever they are standing (mid-fight) |
| `[wait 1.5]` | Pause for 1.5 seconds |
| `[hide Name]` / `[show Name]` | Hide or show something in the level, by its node name |
| `[fade out]` / `[fade white]` / `[fade in]` | Fade to black, fade to white, fade back |
| `[fade dim]` | Darken the screen part way (his sight going); `[fade in]` brings it back |
| `[title ACT 0 / BLACK SAND]` | A title card (` / ` starts a new line) |
| `[teleport MarkName]` | Move Aeneas to a Marker3D; restarts happen there from now on |
| `[fight FightName]` | Start a Fight: its agents attack once the scene ends |
| `[erupt on]` / `[erupt off]` | Aeneas's gravity power, on or off |
| `[empower GuardName]` | That agent can't be beaten (hits land but don't count) |
| `[kill GuardName]` | That agent drops (sacrificed), no blood |
| `[heal]` | Aeneas back to full health |
| `[place Name MarkName]` | That character stands on a Marker3D (the town's are under `StoryMarks`), facing its way |
| `[move Name MarkName 2.5]` | That character walks to the marker in 2.5 seconds; the scene carries on meanwhile |
| `[stand Name Other 0.62]` | Stands 0.62 m in front of Other, face to face. A minus number: that far *behind* Other, facing the same way (a hostage taker). `Player` is Aeneas |
| `[face Name Other]` | Turns to look at Other |
| `[pose Name anim]` / `[pose Name]` | Plays a story pose (`hostage`, `kneel_draw`, `hold_throat`...; the list is in `scripts/character_story.gd`) / back to standing |
| `[ink Name Agent 0.33]` | Name's brush (Isabella) binds that agent: the stroke lands 0.33 s from now and he drops for good |
| `[call Name action values]` | Runs a node's own action, e.g. `[call Bonfire throw_in ValentinaHall]`, `[call Kael set_lamento true true]`. Continue doesn't replay it: add a `[hide]` or `[place]` after it if the result has to last |
| `[level res://scenes/levels/name.tscn]` | Fade out and go to that level (in the big world: walk on to it, see "The big world") |

Names are looked up anywhere in the level (in the big world, the scene's own level first), so give things unique names. The full, current list of
commands is in `scripts/dialogue_file.gd` (if a new one appears there, it works here too).

## Story triggers and camera shots

**Story trigger**

1. Look at the floor where the scene should start and press **Story trigger**.
2. In the Inspector, type the scene's name in **Scene** (the name between the `===` marks).
   **Dialogue File** is already your level's file.
3. Make the zone fit: click the trigger's **Zone** child and drag the orange dots, or change
   **Shape > Size**.
4. **Once** on = plays the first time only. Off = every time he walks in.

A trigger can wait switched off: untick **Monitoring**, and a Fight's **Unlock On Win** can switch
it on when that fight is won. A trigger whose scene has already played some other way (a fight's
Won Scene) stays quiet. The town's `StoryTriggers/FirstPair` has no zone: it plays its scene the
first time Aeneas is offered a takedown with Isabella binding the other agent.

**Camera shot**

1. Fly the 3D view until it shows the shot you want.
2. Press **Camera shot**. The camera is placed exactly there.
3. Rename it (select it, press **F2**), for example `MillShot`.
4. To look through it, select it and tick **Preview** at the top-left of the 3D view.
5. Use it in a scene: `[camera MillShot]`. Change **Fov** in the Inspector to zoom.

## Guards and patrols

1. Look at the floor and press **Agency guard**. He faces away from you and walks between two
   points, `Route/A` (where he stands) and `Route/B` (4 m ahead).
2. Select a point under his `Route` and move it. With the guard or a point selected, an **amber
   line** in the 3D view shows his whole walk.
3. More points: select the guard (or one of his points), look where the next point goes, press
   **Patrol point**. He walks them top to bottom as listed in the Scene panel, then back to the
   first. Drag points in the Scene panel to change the order.
4. No `Route` at all = he stands his post, looking the way he's turned (rotate him with **E**).

In the guard's Inspector:

- **Data**: what kind of agent he is (`data/enemies/agency_agent.tres`, `agency_lieutenant.tres`,
  `agency_captain.tres`).
- **Fights**: on = being seen starts a sword fight instead of a restart.
- **Dormant**: on = he ignores Aeneas until a scene starts his fight.

Keep patrol points out of walls and off ledges. A level needs a **StealthDirector** for restarts
after being spotted (new levels have one).

## Fights

1. Look at the floor and press **Fight**. You get a `Fight` node with one agent in it (Fights and
   Dormant already on).
2. More agents: select the Fight and press **Agency guard**; each one joins that fight.
3. Rename the Fight (F2), for example `MillFight`, and start it from a scene: `[fight MillFight]`.
4. In the Fight's Inspector:
   - **Won Scene**: plays when every agent is down.
   - **Death Scene**: plays if Aeneas dies. Empty = back to the last checkpoint, fight again.
   - **Boss** and **Boss Half Scene**: a scene the first time the boss drops under half health.
   - **Unlock On Win**: a switched-off trigger that switches on when the fight is won.
   - **Choreography File**: optional, see below.


The scene that starts a fight saves the game first (Continue starts the fight again), and winning
it saves too (see "Saving").

Fighters walk on the navigation mesh, so press **Bake navigation** after moving walls or ramps
where a fight happens.

### Choreographed fights (the captain)

A fight wrapped in cutscenes can follow a script instead of the agents fighting freely. The
captain's is `data/fights/captain.txt` (the CaptainFight's **Choreography File**). Open it in any
text editor; the list of beats and what each one does is at the top. In short:

```
=== phase 1 ===
approach 2.6         walk up to 2.6 m from Aeneas
guard 0.8            stand on guard for 0.8 s (a pause)
feint 0.5            draw the fist back, don't hit
swing 0.75           a hook with a 0.75 s wind-up (block, parry or dodge it)
scene captain_measure   play that scene from the level's dialogue file (camera cuts, lines)
loop                 after the last beat, start again from here
combo 0.75 0.4 0.4   three blows in a row (jabs and hooks)
heavy 1.1            an overhand blow that can't be blocked (his coat flashes red): dodge it
```

- `=== phase 1 ===` is the Fight's **Boss** until the Boss Half Scene; `=== phase 2 ===` is the
  boss afterwards (once that scene has empowered him). `=== Name phase 1 ===` gives another
  guard in the same fight his own beats, by node name. The lieutenant has his own short fight,
  `data/fights/lieutenant.txt` (LieutenantFight), slow and easy on purpose. Guards with no section fight freely.
- The fight is still real: Aeneas's hits land, and a parry staggers the captain (his next beat
  starts when he recovers). Hitting him doesn't interrupt his beat.
- `scene` beats play once each (even after a restart). Write them in the dialogue file like any
  scene; `[frame Captain]` cuts to a side-on shot of Aeneas and the captain wherever they stand.
  The fight pauses while a scene plays.
- Damage and reach come from the guard's data file (`data/enemies/agency_captain.tres`).
- Changes show up the next time the fight starts (F5 or F6). To try a new fight's choreography,
  copy `captain.txt`, change it, and pick the copy as that Fight's **Choreography File**.

## Checkpoints

1. Look at the floor where Aeneas should come back and press **Checkpoint**. The node's centre is
   where he reappears; the box around it is the zone he walks into.
2. **Hide When Reached** (optional): something to hide once he gets there.

Don't put one where he only passes while falling: checkpoints wait until he lands safely.

Checkpoints only move forward. Their order is the order of the `Checkpoints` list in the Scene
panel, top to bottom: walking back through one higher up the list keeps the restart where it is. So
keep the list in the order he reaches them (drag a new one into place). In the big world, a zone's
checkpoints go once the story is past it (`Checkpoints` in the zone's **Gone After**), and walking
into a new zone moves the restart to its `Start`.

A checkpoint that moves the restart point on also **saves the game** (Continue puts him back on
it). During a story fight checkpoints do nothing: the fight restarts where it started.

## Look-at spots

1. Look at the thing (a poster, a door) and press **Look-at spot**. It stands on the floor in front
   of it.
2. **Label**: what the prompt says after "E / Up: " (for example `Look at the poster`).
3. **Text**: what Aeneas notices. Separate lines with `|`. It starts with placeholder words.
4. Or keep the words in the level's inspect file: empty **Text**, set **File** to
   `data/inspect/<level>.txt`, and add a line there: `NodeName|first line|second line`.
5. **Reach**: how close he has to be. **Once**: can only be read one time.

Prompts aren't offered during fights.

## Blocks and buildings

Every wall, floor and ramp is a **Block**: a box you can see and stand on.

- **Size**: change it in the Inspector; the collision follows.
- **Material**: drag a file from `materials/` onto the Material field (`concrete`, `pavement`,
  `metal_plates`, `dev_grid`, the glowing `neon_*`...).
- **Grime**: how dark the foot of the walls gets. **Trim**: for rails, pipes and cables.
- **Ctrl+D** duplicates the selected Block. With a Block selected, the dock's **Block** button
  puts the new one next to it.
- **No steps.** Aeneas can't climb even a 30 cm ledge: use ramps (a Block turned with E) and keep
  floors level with each other.

**Buildings** are Blocks with **Style = Building** and a `building` material: a ground floor with
doors and shopfronts, 3 m window bays, a parapet and a plain roof. A face under 5 m wide or 4 m
tall stays blank. Turn **Ground Floor** off for a block that doesn't stand on a street.

**Props** (the Props part of the dock) come from the scripts in `scripts/props/` (plants, bins,
bicycles, pipes, cables, rooftop tanks...) and each level's own `scripts/props_<level>/` folder.
Pick what it is with **Kind** and **Variant** in the Inspector. Most props have no collision, so
they never block the way. **Refresh list** picks up new prop scripts.

**Balconies and big pipes** dress the outside of a building. In the town they are under
`Facades` (`Balconies` and `BigPipes`); copy one (Ctrl+D) and move it, or drag
`scenes/prefabs/props/balcony.tscn` / `big_pipe.tscn` in, or use the dock's **Balcony** and
**Pipe Run** props.

- **Balcony** (`scripts/props/balcony.gd`): its origin goes on the wall at the balcony's floor,
  the red arrow (X) along the wall, the blue one (Z) pointing out of it. One window bay is 3 m wide,
  so put it on a slab line under a window. **Railing**: steel bars or a solid concrete lip.
  **Clutter**: nothing, laundry, crates, plants, an AC unit, or a bit of everything. **Variant**
  changes colours. **Width** and **Depth** in metres. **Solid** turns on collision: leave it off
  for balconies out of reach (keep those at least 6 m above any floor, so neither Aeneas nor the
  camera gets near), turn it on for one he can walk onto or under.
- **Pipe Run** (`scripts/props/pipe_run.gd`), the big ones: **Radius** 0.25-0.45, **Square** for
  a box duct. **Points** are corners in the pipe's own space: start and end a run a few
  centimetres inside the wall (Z -0.05) and it reads as coming out of the wall and going back in.
  **Wall Side** = where the wall is (0, 0, -1 when the pipe's blue arrow points out of the wall):
  every bracket then gets an arm and a plate back to it, **Wall Gap** metres behind the pipe.
  **Solid** turns on collision for a pipe Aeneas can walk into; keep pipes without it at least
  3.6 m above the floor. Put them on the plain corner piers so they don't cross windows.
- Windows don't notice balconies or pipes (they aren't Blocks), so a balcony can sit in front of
  a window, which is what you want.

**The camera** pulls in when a wall gets between it and Aeneas, then waits a moment and eases back
out. It ignores small things (anything under about 2.6 m every way, and thin rails, pipes and
signs), so it no longer jumps in front of him at vending machines and crates. To make one body
block the camera anyway, or to let the camera through a big one, give it the metadata
`camera_blocks` (true or false). The timings are on the Player's `CameraPivot` (Walls group).

**Signs of life** go under `Life`:

- **Flicker light**: **Personality** (steady, failing tube, dying bulb), light **Color**,
  **Energy** and **Range**. **Emissive Block** makes a sign plate dim with it.
- **Steam vent**: point at a wall for a wall grille, at the floor for a grate. **Direction**,
  **Amount**, **Speed**, **Tint**.
- **Drip**: hangs under the ceiling and drips to the floor below.
- **TV window**: point at a building wall. **Brightness**.

## Light, fog and mood

- **WorldEnvironment** (top of the level): click it, then its **Environment** in the Inspector.
  - **Background > Color**: the sky.
  - **Ambient Light > Color** and **Energy**: how bright the shadows are.
  - **Fog**: **Light Color** (usually the sky colour), **Depth Begin** and **Depth End** (where it
    starts and where everything disappears).
- **Sun** (DirectionalLight3D): **Color**, **Energy**, and its angle (rotate it with E).
- **Lamps** (OmniLight3D): **Color**, **Energy**, **Range**. There are no real-time shadows, on
  purpose (the PS1 look).
- The vertex wobble for the whole game: **Project > Project Settings > Shader Globals >
  ps1_snap_resolution** (bigger numbers = less wobble).
- Every surface uses a material from `materials/` (they all use the PS1 shader). Don't use Godot's
  StandardMaterial3D on level geometry.

## Navigation (where fighters can walk)

Fighters find their way around on a navigation mesh (the blue floor you see when the `Navigation`
node is selected).

- After moving walls, ramps or columns where fights happen, press **Bake navigation** in the dock.
  **Ctrl+Z** brings the old mesh back.
- Its settings are on the `Navigation` node: click it, then its **NavigationMesh**. **Agent >
  Radius** keeps fighters off walls; **Filters > Baking AABB** limits the area (the Empty Town only
  bakes its courtyard and hall).
- A level without a `Navigation` node: copy the one from `scenes/prefabs/level_template.tscn`
  (right-click it in that scene > Copy, then Paste in your level), and add your level's top node
  to the group `navmesh_source` (Node panel > Groups). Then bake.

## Where the tuning knobs are

- **Guards**: `data/enemies/*.tres`. Double-click one: sight range and angle, how fast they notice
  Aeneas, walking speed, waits at each point, health, damage, wind-up. For a new kind, duplicate a
  file (right-click > Duplicate), change its numbers, and pick it as a guard's **Data**.
- **Aeneas**: open `scenes/player.tscn` and click **Player**: Running, Jumping, Crouching and
  Falling speeds and heights. Click **Combat** for health, stamina, damage and sword reach.
  **CameraPivot** holds the camera's mouse speed and how far up and down it can look.
- **Isabella and Kael**: click them in a level: follow distance, speed, side offset, bind reach.
- **Player settings** (volume, mouse speed, invert, fullscreen) are in the game's Settings menu.
  Their starting values are at the top of `scripts/ui/game_settings.gd`.
- **Colours and the pixel look**: `scenes/ps1_screen.tscn` (colour levels, dither).
- **Sounds**: the WAV files in `audio/`. Replace one with a file of the same name.
- **Music**: `audio/music/`, and the track list at the top of `scripts/music.gd`.

## Characters (Blender)

Aeneas, Kael, Isabella, Valentina, the agents and the captain (and the wrapped villagers' bodies)
are built by Python scripts that Blender runs, in `tools/blender/`. To change a character you change a
number in its script and rebuild it. `tools/blender/README.md` explains how (colours, shapes,
animation timing, making a new character).

Story poses (the knife at the throat, Isabella's circle, the captain lifting Aeneas, Kael's cuts...)
are animations too, played by name from a scene. The list of names, and what each one does with
props (the knife, Lamento, the captain's arm), is at the top of `scripts/character_story.gd`.

## The dock's own files

- `addons/aethereal_tools/`: the dock. `builders.gd` says how each thing is made (sizes,
  materials, layers); `placer.gd` says where it goes.
- `scenes/prefabs/`: the prefabs and `level_template.tscn`. After changing `builders.gd` or adding
  a prop script, rebuild them (with Godot closed), from the project folder:
  `godot --headless --path . -s res://addons/aethereal_tools/tools/make_prefabs.gd`
