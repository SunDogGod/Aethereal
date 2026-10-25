# Act 0 — rough cut (built overnight, 2026-10-22/23)

Three walkable levels after the Empty Town, so the story can be walked start to finish.
**Decided** = the author's call (from chat or Notion). **Proposed** = Claude's call, made to keep
building; change any of them.

Play: F5 opens the **location menu**. Pick a place, or start at 0.1 and walk the whole act
(the Empty Town skips from the Valentina scene straight to the blackout, since the hall isn't built).

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
- Beats: `arrival`, `the_ai`, `launch`, `training`, `end_of_act` (back to the menu).

## Shared pieces added
- **Location menu** (`scenes/location_menu.tscn`), now the main scene.
- **Dialogue commands:** `[fade out|in|white]`, `[title TEXT / LINE 2]`, `[teleport MarkerName]`,
  `[level res://...]` (goes to another level).
- **Kael** as a companion (`scenes/kael.tscn`): same following code as Isabella.
- **Artificial dawn** (`scripts/artificial_dawn.gd`) and **hologram** flicker (`scripts/hologram.gd`).
- Materials: grass, black sand, white plaster, terracotta, Precursor panels and lights, lanterns,
  grow lamps, hologram, wood, brass, fire.

## Known gaps (not bugs, just not built)
- No chase or fight in the Massacre; the raiders are set dressing.
- The Black Sand road agents use the Empty Town's stealth rules; nothing special for the dawn.
- No sword training mechanics in the capsule; the room is there for them.
- Companions sometimes stand between the camera and Aeneas when the camera is low (child Aeneas).
- All lines are DRAFT narration-heavy placeholders in `data/dialogue/*.txt`.
