# In-game edits

Build Mode (F2 in the running game, or F1 > Build mode) saves what you change in a level here,
one file per scene: `empty_town.json`, `black_sand.json`... The game puts these changes back every
time that scene loads, so they work at once (and ship in an exported game).

To make them part of the scene for good, open the editor and press **Bake in-game edits** in the
Aethereal dock (Level section). The scene file is changed and saved, and the edits file is renamed
to `<name>.json.bak` (a spare copy you can delete).

How to use Build Mode: `docs/customizing.md`, "Build Mode: change a level from inside the game".
