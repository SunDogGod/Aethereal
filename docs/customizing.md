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
| Checkpoint | A save spot for restarts |
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

   Keep the comma at the end. An empty number (`""`) marks a test space that Continue never remembers.
5. **Lead into it from the level before.** At the end of that level's last dialogue scene, add
   `[level res://scenes/levels/the_old_mill.tscn]`.
6. Play it: **F6** plays the open level; **F5** starts from the title screen.

Without the button: in the FileSystem panel, right-click `scenes/prefabs/level_template.tscn` >
**Duplicate...**, give it a new name in `scenes/levels/`, and make its dialogue file by hand.

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
| `[wait 1.5]` | Pause for 1.5 seconds |
| `[hide Name]` / `[show Name]` | Hide or show something in the level, by its node name |
| `[fade out]` / `[fade white]` / `[fade in]` | Fade to black, fade to white, fade back |
| `[title ACT 0 / BLACK SAND]` | A title card (` / ` starts a new line) |
| `[teleport MarkName]` | Move Aeneas to a Marker3D; restarts happen there from now on |
| `[fight FightName]` | Start a Fight: its agents attack once the scene ends |
| `[erupt on]` / `[erupt off]` | Aeneas's gravity power, on or off |
| `[empower GuardName]` | That agent can't be beaten (hits land but don't count) |
| `[kill GuardName]` | That agent drops (sacrificed), no blood |
| `[heal]` | Aeneas back to full health |
| `[level res://scenes/levels/name.tscn]` | Fade out and go to that level |

Names are looked up anywhere in the level, so give things unique names. The full, current list of
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
it on when that fight is won.

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

Fighters walk on the navigation mesh, so press **Bake navigation** after moving walls or ramps
where a fight happens.

## Checkpoints

1. Look at the floor where Aeneas should come back and press **Checkpoint**. The node's centre is
   where he reappears; the box around it is the zone he walks into.
2. **Hide When Reached** (optional): something to hide once he gets there.

Don't put one where he only passes while falling: checkpoints wait until he lands safely.

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

Aeneas, Kael, Isabella and the agents are built by Python scripts that Blender runs, in
`tools/blender/`. To change a character you change a number in its script and rebuild it.
`tools/blender/README.md` explains how (colours, shapes, animation timing, making a new character).

## The dock's own files

- `addons/aethereal_tools/`: the dock. `builders.gd` says how each thing is made (sizes,
  materials, layers); `placer.gd` says where it goes.
- `scenes/prefabs/`: the prefabs and `level_template.tscn`. After changing `builders.gd` or adding
  a prop script, rebuild them (with Godot closed), from the project folder:
  `godot --headless --path . -s res://addons/aethereal_tools/tools/make_prefabs.gd`
