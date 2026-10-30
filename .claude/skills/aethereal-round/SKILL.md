---
name: aethereal-round
description: How to run a round of changes from the author's feedback list on Aethereal - split the list, build, test, commit, report. Use whenever the author pastes a list of changes or asks for an overnight or background batch.
---

# A round of changes

1. **Godot closed.** Ask the author to close it (without saving) before editing; tell them to reopen
   after. An open editor can overwrite scene files.
2. **Split the list by files, not by topic.** Two builders must never edit the same file at the same
   time (`scenes/levels/<level>.tscn` is the usual clash: chain those builders one after another).
   Typical owners: sound/UI/story.gd; characters (tools/blender, rebuild); one level's .tscn; shared
   scripts. Small or mechanical items: do them inline, no builder.
3. **Brief each builder** with: the author's words verbatim, the files it owns, "touch nothing else,
   no git commit", test only what it touches, windowed screenshots to a scratch folder, plain report.
4. **Keep it lean.** No reviewer agents unless asked; skip a final-check agent and run the battery
   yourself (skill: aethereal-test-battery). Mechanical builders (dressing from a clear brief, moving
   files, test fixes) can run on a cheaper model (`model: "sonnet"`) and lower effort; keep the top model
   for design-heavy work (characters, cutscene staging, new systems).
5. **Tie off loose ends** the builders flag (docs, README controls table, CLAUDE.md, the author's
   story docs: their words are drafts, update them and say so).
6. **Battery, look at the screenshots, commit** (`git add -A`, one commit per verified round).
7. **Report in plain words**: what plays now, what's a draft or proposal for them to judge, what you
   couldn't see/hear/feel. No internal code rules (line limits etc.). Send 2-3 key screenshots.
