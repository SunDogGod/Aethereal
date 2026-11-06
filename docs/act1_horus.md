# Act 1, arc 1-1 Horus (Temek) — the rough cut (2026-11-05)

One walkable level for the whole route, so the arc can be walked end to end: the train's end,
the water pipe, three days of desert, the farmer's shack, the Barrier Obelisk, and Temek seen
from its edge. Beats are told through dialogue scenes drafted from the Notion canon
(`data/dialogue/horus.txt`, every line marked DRAFT). Detail comes later, after you walk it.

**Decided** = your call (chat 2026-11-05, or Notion canon). **Proposed** = my call, made to keep
building; change any of them.

## The place
- **Decided (canon):** Temek is Kemet backwards: Egypt × Tenochtitlan, a dieselpunk oil city on a
  dying lake, black Voidstone pyramids under permanent amber smog, derricks against pyramids. One
  Construct pipe feeds the lake. Life underground by day, the surface at night.
- **Decided (you, 2026-11-05):** the desert is inside the megastructure, under a ceiling far above,
  lost in amber haze (like Black Sand, warmer). Derrick flames and the Obelisk light the dunes.
- **Decided (you):** rough out the whole route first, Temek included.
- **Proposed:** the level is `scenes/levels/horus_road.tscn`, about 700 m long, south to north:
  the capsule's tunnel mouth at the south end, Temek's lake at the north. Its own fog (amber,
  thick) hides the ceiling and the far ends. Not part of the Act 0 world: Act 1 starts a new world.

## The route (south → north)
1. **The platform (Proposed):** the capsule stops in a concrete tunnel mouth at the desert's edge
   (the same house-sized capsule as the station). The train's AI speaks once, then the doors
   stay open. A ramp climbs out of the cutting onto the sand. Scene `arrival`.
2. **The pipe (Decided, canon):** a 4 m Construct pipe on pylons runs north across the dunes to
   the lake, with a pump house where it leaves the rock. The centipede wrecks it. **Proposed:** the
   attack is a cutscene (the ground heaves, the pipe tears, water sprays and dies, Rocinante
   breaks) with no creature model yet: a trench of churned sand and the torn pipe are what you
   see. Aeneas keeps a sword in play for now (the two daggers come when you say). Scene `the_pipe`.
3. **Three days (Decided, canon):** the long walk. **Proposed:** the dunes rise and fall with old
   infrastructure half buried (the same relics as Black Sand, rusted warmer), a dead derrick, and
   mirages: a sheet of "water" on the horizon that fades as you near it, three times. Narration
   marks the days with fades (no act cards). Scenes `day_two`, `day_three`.
4. **The farmer's shack (Decided, canon):** a real shack, half dug into a dune, moisture farmed
   on condenser frames (cloth stretched on metal) and plants grown underground. **Proposed:** the
   farmer is a figure at his frames; he shows them pulling water from the air (a look, a glow at
   his hand, a line). Scene `the_farmer`. A bed inside heals (RestBed, scene `rest`).
5. **The Barrier Obelisk (Decided, canon):** a black monolith on the last ridge, 40 m tall,
   Sievert sealed inside it (unseen). **Proposed:** a faint wall of light stands across the ridge
   either side of it; the way through is the Obelisk's foot, and it lets them pass. Scene
   `the_obelisk`.
6. **Temek's edge (Decided, canon):** from the ridge, the lake city: a black lake, causeways, the
   pyramids, derricks burning, the smog. **Proposed:** the rough cut ends at the first causeway
   gate, where beggars crowd them and the nobleman's man meets them. Scene `the_gate`, then the
   title screen until the city itself is built.

## What it needs that doesn't exist yet
- A desert terrain builder (dunes from noise, flat where the road runs): `scripts/props_horus/`.
- Props: pipe on pylons (broken variant), pump house, derrick (lit, dead), condenser frame, the
  shack, the Obelisk, the barrier light, pyramids, the lake, the causeway and gate.
- Materials: warm sand, Voidstone, oiled iron, the lake.
- Life: derrick flames, drifting smog, heat shimmer, drifting lights (the Mantid/Grey foreshadowing).

## Open for you
- What the centipede looks like and how the fight plays (none of it is built).
- Whether Rocinante breaks here in play (then the two daggers), or stays whole until the smith.
- Temek's streets: nothing past the gate is designed. We design the city together.
