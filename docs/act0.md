# Act 0 — rough cut (built overnight, 2026-10-22/23)

Three walkable levels after the Empty Town, so the story can be walked start to finish.
**Decided** = the author's call (from chat or Notion). **Proposed** = Claude's call, made to keep
building; change any of them.

Play: F5 opens the title screen. New Game starts at 0.1, Chapters starts at any place, and the act
walks through from the town to the end of the station.

## One world (2026-10-25)
- **Decided (the author):** the levels blend into one big level, with walkways between them, except
  the memory (the Massacre stays its own scene). It is `scenes/world/world.tscn`; each level is still
  its own scene and plays alone with F6. How it is built: `docs/customizing.md`, "The big world".
- **Proposed:** Black Sand lies north of the town and 50 m below it, so its town wall is the town's
  foundation. The walkway down is a service stair: a door at the back of the hall's stage (right of
  the cube), three flights down inside the foundation, a door high on the drifted sand in the town
  wall (a cool lamp over it), and a grating gangway down the drift. In the world the town wall has a
  slot for that door (windows west of it as before, a new pattern east of it); Black Sand on its own
  (F6) is unchanged.
- **Proposed:** the door stays shut (a shutter) until the story reaches Black Sand, so the town can't
  be skipped. After the hall the town is empty when you walk back up: its agents, figures and story
  scenes are gone.
- **Proposed:** Black Sand's descent corridor runs on as a 40 m road tunnel (two strip lights still
  glow) straight into the station's entry corridor. The `down` scene fades out and back in (its title
  card was removed with the act-divider screens), then you walk the tunnel; there is no load.
- **Proposed:** Kael follows from Black Sand into the station (the station's own Kael is not used in
  the world). The flashlight comes with the station, as before, and stays with you after it.
- **Proposed:** Continue returns to your last save. The game saves by itself at checkpoints, at the
  end of story scenes, when a story fight is won and when you walk into the next place (at its
  start). After the end of Act 0, Continue lands in the training room just before `end_of_act`.
  New checkpoints: Black Sand past the road, and the middle of the station's hall.

## 0.2 The Massacre (a memory) — `scenes/levels/massacre.tscn`
- **Decided:** plays as the blackout dream after the Empty Town; you are four years old.
- **Decided:** the Third Eye Tribe village is an enclosed hall inside the megastructure: walled
  compounds laid out like Japanese estates with Spanish white walls, each with a courtyard; a great
  estate at the end where the scene takes place; grass, lit by grow-lamp panels in the ceiling.
- **Proposed:** it's the festival night, so most grow lamps are dimmed and the courtyards are strung
  with lanterns. (A daytime version would turn every panel on.)
- **Proposed:** six small estates along one lane, the Great Estate at the north end, the only
  corridor in at the south. The ceremony is only hinted at: a crowd, a dais, a fire basin. Per the
  Notion rule, no tithe, no horse, no faces, no father's death.
- **Decided (2026-10-23):** Isabella only follows Aeneas in the Empty Town, until she dies. In the
  memory she is narration only ("a hand closes on his arm"); no follower.
- **Proposed:** the way out is a drain under the north wall behind the Great Estate. (Notion leaves the extraction
  unassigned; "Anchises holds the lane" is only implied by a figure labelled Father at the gate.)
- **Proposed:** the raiders are stand-in figures and fires that appear when "the men" scene plays.
  No chase AI yet; it's a memory, and the fragment is short.
- Child Aeneas: smaller, slower, lower camera, no knife or rifle. The whiteout at the drain leads
  into Black Sand.
- Beats: `memory` (courtyard), `the_men` (the Great Estate gate), `the_drain`, `whiteout`.
- **Dressed (overnight 2026-10-26), detail like the town's; no new story beats.** All of it is
  **Proposed**: change, move or delete anything. The props are in `scripts/props_massacre/`.
  - The houses: dark stone footings, timber posts and beam bands on the white plaster, terracotta
    gable roofs laid with round tiles (in the style of the family house in Black Sand), a raised plank
    veranda along each courtyard front under the eave, lattice paper windows lit warm from inside, a
    sliding door left a hand open, a noren curtain, red paper lanterns on the veranda posts. The Great
    Estate's hall has a gabled entrance porch over its door.
  - Each estate gate is a small roofed gate with its two plank doors swung open against the wall.
  - The courtyards: a tree (pine, maple, persimmon; a pink blossom tree in the Great Estate), the
    basin made a stone water trough with a bamboo spout dripping into it, stepping stones from the
    gate, a vegetable bed, a washing line, a stone lantern, a well or a woodpile, hens, a cat on
    the veranda, potted geraniums and a bonsai, persimmons drying under the eave, birds and pots on
    the wall tops. The Great Estate's courtyard has festival banners, two drums by the dais, barrels
    and sacks, low tables and a red parasol.
  - The lane is packed earth, with paths to every gate; lantern posts down both sides and strings of
    paper lanterns across it.
  - **Proposed landmark: the market** by the way in: seven stalls (fruit and greens, cloth, pottery,
    lanterns, a food stall with a steaming pot), parasols, benches, banners.
  - **Proposed landmark: the village shrine** at the foot of the pillar behind the Great Estate, on
    the way to the drain: a vermilion torii, two stone lanterns, a small shrine with candles and rice
    cakes, a row of jizo with red bibs.
  - Fields under the lamps: rice paddies, vegetable beds, low grow-lamp frames, irrigation channels
    with plank bridges (one runs along the back to a sump by the drain), field sheds, drying racks,
    a persimmon orchard, bamboo along the hall walls.
  - The megastructure: pilasters and two ledges on the hall walls, concrete beams across the
    ceiling, ten free-standing pillars with conduits, big pipes along the walls, tiny lit windows far
    up the walls. The grow-lamp panels now hang 4 m below the ceiling on steel rigs with cable trays.
  - The haze is warmer and paler (the fog is a dim amber, not black). Lantern lights breathe like
    candles; birds peck, cats look round or breathe, chimes sway; running water by the channels and
    the fire basin crackles.
  - Look-at spots (draft lines in `data/inspect/massacre.txt`): the drum, the shrine, the food
    stall, a paddy.
  - Fixed: the two roof fires that show when the men come hung in the courtyards' air; they now sit
    on the roofs of the first two houses. The wall copings and the corridor mouth no longer flicker.

## 0.3 Black Sand — `scenes/levels/black_sand.tscn`
- **Decided 2026-10-25 (the author):** dark and foggy (Blame! is an inspiration). The family home is a giant steel module repurposed into a shed with two beds ("No one was going to build that house for them"); Isabella's body lies inside. Sand drifts up the steel side walls; the south side is the town as a solid black block with windows starting high up.
- **Superseded 2026-10-25 by the author's sacrifice rule:** a sacrifice only counts if the body is burned or given to the cube. Isabella gives her life in the hall, but her body stays (the cube doesn't take it), and Kael and Aeneas carry her back to the family house in Black Sand, hidden in the fog under the Kowloon town ("her giving her life was overkill anyways"). The old cairn-with-her-bell idea (below) is out of date. Kael's "her body is special"
  line is deferred to a later arc.
- **Decided:** artificial dawn: the ceiling panels switch on far-to-near over ~22 s, the "sun" rises
  with them, the fog lightens. This is the morning the Agency starts hunting them.
- **Proposed:** the dune field is a hall 180 m across with the stacked town on the south horizon
  (six tower silhouettes and the bridge stub, in fog).
- **Proposed:** the route: wake on a dune → the grave (west crest) → Kael's camp in the lee of a
  half-buried pipe (east), where he shows the cube and the symbol scratched into the pipe → the
  watched road (a lit Precursor causeway, two patrolling agents, crates for cover, a checkpoint
  before it) → the buried arch (north) → a ramp down into the station.
- **Proposed:** Kael joins as a follower after the camp scene (the static Kael is swapped for the
  companion).
- Beats: `waking`, `the_grave`, `the_cube`, `the_road`, `the_arch`, `down`.
- **Proposed (overnight 2026-10-26, dressed like the town; still dark and foggy):**
  - The family's yard in front of the shed: a hand-made fence of pipe offcuts, wire and an old door;
    a raised garden of carried soil with pale sprouts under a lamp whose bulb is going; a windbreak
    of stakes and tarp; water drums under a downpipe off the roof (it drips); a tool rack and a
    barrow on the east wall; salvage sorted in stacks; a drag sled; a cold fire pit with its pot; a
    second washing line; boards laid from the door to where the guide lamps lead in; worn sand.
  - The dunes: the megastructure's bones coming out of the sand: girders (some bent, one lying),
    two girder frames, big pipes that rise and dive back in, masts with a blinking red lamp,
    modules like theirs sinking on their sides (one burst open on a dark inside), dead machines
    with one lamp still blinking, tanks. A few sit right beside the walk so the route passes them.
  - Cables hang from the ceiling far up, some to the sand where they lie coiled, some ending in
    the air. Wind-blown sand drifts across the dunes; a wind loop (`audio/black_sand_wind.wav`,
    a placeholder like the other sounds) plays from the walls and the yard.
  - Under the town: balconies, air conditioners, bags and rubble that came down from it, pipes out
    of the block's foot (two broken ones high up drip), cables from the lit storeys to the sand.
  - Trail stakes with rags from the camp to the road, and from the road to the arch.
  - Ten things to look at (E / D-pad up), lines in `data/inspect/black_sand.txt` (DRAFT): the
    garden, the drums, the tools, the fire pit, the washing, the fence, the dead machine, the
    fallen balcony, the sunk module, the town's cables.
  - New pieces: `sand_relic.gd` (girder, frame, pipe bend, mast, wall conduits), `sand_hulk.gd`
    (module, machine, tank, fallen balcony), `sand_yard.gd` and `sand_salvage.gd` (the family's
    things), `sand_scatter.gd` (small clutter as one MultiMesh per patch). Each has a Kind,
    Variant and Length in the Inspector; Drift heaps sand against a piece's foot.

## 0.4 The Vacuum Station — `scenes/levels/vacuum_station.tscn`
- From Notion: a dead Precursor vacuum-tube station, a house-sized capsule, neither can work the
  panel, a hologram AI offers the one destination left (ETA one month), Kael begins training.
- **Proposed:** a dark brutalist hall (80 x 110 m) with dead departure boards, fallen panels, a dead
  maintenance drone, three tube mouths on the north wall; the capsule docked in the middle one,
  jutting onto a raised boarding deck. The AI is a flickering cyan hologram at a pedestal by the door.
- **Proposed:** the capsule interior is the "house": bunks, a galley, a table with the ciphered
  book; a partition; the training room at the far end (mat, wooden dummy, rack). Boarding plays
  the launch (fade, "ONE MONTH LATER") and puts you in the training room.
- **Proposed:** the AI's voice is labelled STATION in the dialogue file.
- **Decided 2026-10-25 (the author):** the station is in massive disrepair, the building half collapsed
  in on itself. The three tubes stay round: the closed one is caved in, the right one is empty ("maybe
  I can hide a secret in there"), and the middle one holds the train, which is the house and fits the
  tube. The train is a trapezoid seen from the side. Far fewer lights, so a flashlight; the lights
  that are left point the way.
- **Proposed (round 6):** the collapsed half is the west side (left, coming in): west of the x = -14
  columns the roof is gone, slabs hang from the torn edge or lie on rubble heaps, beams and the catwalk
  end in buckled stubs, the west wall is 16 m tall with its top slumped inward, a column lies where it
  fell. Through the hole, far off, the megastructure's dark wall with a few tiny lights, and a cold
  glow on the ruin. The route down the middle and the east ramp is untouched.
- **Proposed:** the caved-in tube is the left one (it is next to the collapse); the right one's blast
  door is gone and a walkway runs 26 m in, through the north wall, to a cave-in. The secret's spot is
  marked by `Tubes2/SecretSpot` (a Marker3D) beside a hazard sign near the end.
- **Proposed:** the train's ends stand upright for the buffer band, then lean back 2.2 m to a shorter
  roof with chamfered corners, a dark windscreen on the front's slant. The side door moved back 1.1 m
  (the leaning front would have cut it); the east bunk moved with it.
- **Proposed:** the lights that point the way: the lit door into the hall, three lamps down the east
  side, a lamp over the east ramp, cyan arrows on the floor, the hologram, the lit train door. The
  inside of the train stays warmly lit (inhabited places are cleaner, and brighter).
- **Proposed (overnight 2, dressed like the town):** the station is filled out in its own
  character: ages of dust, rust and roots, and what the last travellers left behind. Nothing new
  lights the way; most of it shows under the few lamps or in the flashlight.
  - The concourse: two ticket booths beside the gates, windows to the aisle (one pane cracked
    out, a sign in the old script on each roof); cases, a trunk and a heap of luggage dropped at
    the gates, a trail of cases out across the hall to the platform; crowd barriers knocked flat;
    old tickets and paper everywhere; faded posters (a tube mouth with a capsule leaving it, a
    network map half torn away) and stencilled words in the old script on the walls and columns.
  - Signs in the old script: one hangs on long chains from the roof beams over the aisle, its twin
    lies broken on the floor below; two hang under the catwalk (one by a single chain), two from
    the conduit high on the north wall, small ones from the wall pipes on the east side.
  - The east side: a waiting area nobody waits in (two rows of benches, one rotted through, the
    luggage), a third booth, a dead hologram emitter (the platform's live one has a dead twin on
    the west deck too), ceiling lamps fallen from under the gallery, water dripping from the
    gallery into rusty puddles, roots and moss coming through the wall.
  - The collapse: grit, broken floor tiles and moss round every heap, puddles where the roof is
    open, roots on the walls, dead cables hanging from the torn roof edge, dust drifting in the
    cold light through the hole (and under the working lamps). A wind sound through the hole.
  - The platform: benches, luggage, roots and posters on both decks. The east tube and its
    walkway are left bare for the secret.
  - The train: a locker on the training room's partition, a stack of mats, a water drum, chalk
    tally marks on the wall; a network map pinned up over the galley.
  - Look-at spots (E / D-pad up): the booth, the luggage, a poster, the fallen sign, the dead
    emitter, the roots, the old capsule, the chalk marks. Their lines are DRAFT, in
    `data/inspect/vacuum_station.txt`: rewrite them in your voice.
  - New pieces you can drag in from `scenes/prefabs/props/`: `station_relic.tscn` (Kind: suitcase,
    trunk, luggage heap, ticket booth, broken bench, dead emitter, hanging sign, fallen sign,
    roots, fallen lamp, train locker, mat stack, water drum), `station_scatter.tscn` (a patch of
    grit, tile shards, paper, rust flakes or moss: set its size and how many) and
    `dust_motes.tscn` (dust in the air, seen only in light).
- Beats: `arrival`, `the_ai`, `launch`, `training`, `end_of_act` (back to the menu).

## Shared pieces added
- **Location menu** (`scenes/location_menu.tscn`); the title screen is the main scene now.
- **Dialogue commands:** `[fade out|in|white]`, `[title TEXT / LINE 2]`, `[teleport MarkerName]`,
  `[level res://...]` (goes to another level; inside the one world it lets you walk on).
- **Kael** as a companion (`scenes/kael.tscn`): same following code as Isabella.
- **Flashlight** (`scenes/flashlight.tscn`, `scripts/flashlight.gd`): drag it into any level and
  Aeneas has a torch there (L / D-pad down; off at the start unless Start On is ticked). A level
  without it has none. The Vacuum Station has one.
- **Artificial dawn** (`scripts/artificial_dawn.gd`) and **hologram** flicker (`scripts/hologram.gd`).
- Materials: grass, black sand, white plaster, terracotta, Precursor panels and lights, lanterns,
  grow lamps, hologram, wood, brass, fire.

## Known gaps (not bugs, just not built)
- No chase or fight in the Massacre; the raiders are set dressing.
- The Black Sand road agents use the Empty Town's stealth rules; nothing special for the dawn.
- No sword training mechanics in the capsule; the room is there for them.
- Companions sometimes stand between the camera and Aeneas when the camera is low (child Aeneas).
- All lines are DRAFT narration-heavy placeholders in `data/dialogue/*.txt`.
