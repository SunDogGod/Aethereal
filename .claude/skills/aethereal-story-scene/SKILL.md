---
name: aethereal-story-scene
description: Write or change Aethereal cutscenes and dialogue - the plain-text scene files, camera shots, story commands, fights. Use when the author changes the story, a cutscene, its pacing or its lines.
---

# Story scenes

- Scenes are plain text in `data/dialogue/<level>.txt`; the command list is in the comment header of
  `data/dialogue/empty_town.txt` ([camera], [wait], [pose], [place], [move], [fade], [fight], [level], [call] ...).
  Played by the Story autoload (`scripts/story.gd`, stage commands in `scripts/story_stage.gd`).
- Each scene needs its nodes in the level: a StoryTrigger, the camera Shots it names, the characters.
  Fights: `fight.gd` nodes with won/death scenes; choreography text in `data/fights/*.txt`.
- The author writes the story. Keep their lines verbatim; your new lines get `# DRAFT`. Canon beats for
  Act 0's town: `docs/empty_town_story.md` (update it when the author changes the story).
- Rules: no floating text, tutorials or act cards. Wordless beats need real time (1.5-3 s holds).
  Violence cuts away or stays in silhouette. "Sacrificio" is the sacrifice word; a sacrifice only counts
  if the body is burned or given to the cube.
- Skipping (hold Tab / Back) and Continue both rely on `scripts/story_replay.gd` `apply()` knowing each
  command's end state: add a case there for any new state-changing command.
- Check: tests/test_story.gd, tests/batch9/sound-skip/test_skip.gd, the hall tests if the hall changed;
  film the scene windowed and look at the beats.
