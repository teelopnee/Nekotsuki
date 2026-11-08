# NEKOTSUKI — notes for AI coding sessions

Japanese-school yandere life sim with action (HD-2D world, chibi sprites) in **Godot 4.7, GDScript, Mobile renderer**,
built on the ODD-SPACE engine (copied in M0 and being re-themed system by system). The owner develops on a
**Samsung Galaxy Tab S12 Ultra** with the Godot Android editor and syncs through GitHub (`main`), so:

- Commit + push finished work to `main`. Always `git pull --rebase origin main` first (the tablet pushes too).
- Talk to the owner in **Thai**. In-game text, code and comments are **English**; the setting is Japan, so keep
  honorifics (Senpai, -kun, -san, -sensei). Design docs are in Thai.
- The owner cares about token cost: read only what you need (grep, line ranges), never re-read big files, keep replies short.
- Source of truth: `docs/LORE.md` (world; never contradict it), `docs/CAST.md` (every character, past lives, ledger hooks),
  `docs/GDD.md` (systems, story, milestones, Odd-Space migration table), `docs/EASTER_EGGS.md`. Update them when the design changes.
- Every character has a backstory and ledger hooks; every Easter egg must have an effect; real Japanese beliefs are tagged [จริง].
- Visuals are chibi sprites only (no bust portraits): expressive poses, face layers, manga emote FX (GDD section 8).
- Content limits: no sexual content (the cast are high-schoolers; romance = confession, hand-holding, festival dates);
  Amane never self-harms or threatens to; no gore.
- Cross-episode memory is Enma's Ledger (`user://ledger.json`, LORE section 9): anything a character should remember
  in a later episode goes through it.
- Keep everything editable on a tablet: data in `data/*.json`, ASCII level layouts, small scripts. Touch controls must keep working.
- Original IP only: never copy another game's characters, art, music or names (Easter eggs may reference the owner's own games).

## Where things are (read only the file you need)
This file is the index. Each system is documented in one file under `docs/dev/`; grep there before reading code.
When you add or change a system, update its `docs/dev/` file, not this one (keep CLAUDE.md short: every session pays for it).

| File | What is in it |
|---|---|
| `docs/dev/town.md` | Suzunari theme (`tools/suzunari_theme.py`, `data/suzunari/`), map + landmarks (`data/maps/suzunari.txt`, `Town`, spirits), Amane talk data, `JPKit` buildings, HD-2D lens, shadows, materials/textures, ambience |
| `docs/dev/story.md` | NEW GAME entry, `Clock`, `Amane`, `Cats` / rival / living spirit / `Ledger`, `Week` (13 weeks, lessons, lates, exams' story side, endings), Ura-Suzunari, races, story markers, kamikakushi rescue, Enma's Ledger page |
| `docs/dev/life.md` | School interior (`School`, `JPSchool`, `data/school.json`), homes + walks (`People`, `HomeVisits`), creator + `Toru` stats/quirks/clubs/jobs, cat spirit night, companions (`Party`), exams |
| `docs/dev/engine.md` | Inherited ODD-SPACE engine: autoload order, LevelBuilder, NPC life/voices/impact/counters, shop keepers, combat, enemies, weapons, tips/settings, Saga bookends |
| `docs/dev/pipeline.md` | Art pipeline (`sprite_forge.py`, textures, FX, audio) and the Android APK |
| `docs/REVIEW.md` | Critique log: score, open issues, fix log. Add an entry every pass. |
| `docs/GDD.md`, `LORE.md`, `CAST.md`, `EASTER_EGGS.md` | Design (Thai). Source of truth for content. |

Tests (`godot --headless --path . --script res://tools/<name>.gd`, exit code = failures): `check_project`, `smoke_test`
(still the old sci-fi flow), `day_test`, `week_test` (plays every story choice), `talk_test`, `m3_test`, `school_test`,
`people_test`, `ura_test`, `life_test`, `friends_test`, `emote_test`; inherited `impact_test`, `interact_back_test`,
`keeper_test`, `combat_test`, `story_test`, `voice_test`, `pad_test`. Text: `python3 tools/leak_check.py` (every themed
line, sci-fi words + "the police" grammar; exit code = leaks). Screenshots (not headless): `tools/shot_suzunari.gd`,
`shot_school.gd`, `shot_ura.gd`, `shot_life.gd`, `shot_ending.gd` -- `<dir> [names]`. Play-through bot:
`tools/playbot.gd -- <out.txt> [days] [seed] [random|kind|cold]` plays the real day flow and writes a transcript.

Screenshot command (software Vulkan, needs `apt-get update && apt-get install -y mesa-vulkan-drivers`):
  `VK_ICD_FILENAMES=/usr/share/vulkan/icd.d/lvp_icd.json xvfb-run -a -s "-screen 0 1280x800x24" godot --path . --resolution 1280x800 --script res://tools/shot_suzunari.gd -- <dir>`

## Validate before every push
Download Godot once (Linux x86_64) into your scratchpad:
`https://github.com/godotengine/godot-builds/releases/download/4.7.2-stable/Godot_v4.7.2-stable_linux.x86_64.zip`
```bash
godot --headless --path . --import                                  # (re)generate .godot cache, *.uid, *.import
godot --headless --path . --script res://tools/check_project.gd     # compiles all scripts + scenes, exit code = failures
godot --headless --path . --script res://tools/smoke_test.gd        # station -> ship -> planets -> saga -> 6 random lives to endings
```
`grep "SCRIPT ERROR"` on the smoke-test output must be empty. `tools/count_endings.gd` prints the ending space;
`tools/print_world.gd -- <biome|all> <seed>` prints generated maps.
Screenshots (software Vulkan): `apt-get install mesa-vulkan-drivers xvfb`, then
`VK_ICD_FILENAMES=/usr/share/vulkan/icd.d/lvp_icd.json xvfb-run -a -s "-screen 0 1280x800x24" godot --path . --resolution 1280x800 --script res://tools/capture_screens.gd -- <out_dir>`
(options: `--quick`, `--biome=<env>`, `--street` = also walk to the nearest shop front, `--creator`; ~10 min per biome on lavapipe).
`--street --probe` also works with `--headless` (no images): prints the ASCII map around the hero plus every mesh/collider
on the camera sight line - the fastest way to find out what is blocking or darkening a shot.

Commit the generated `*.uid` / `*.import` files; never commit `.godot/`.


## Gotchas learned the hard way (Godot 4.7)
- Outdoor camera (pitch 30, fov 32, distance 16) only sees ground ~8-32 m ahead and things below ~5 m:
  sky, rooftop props and anything taller never appear in frame. Put "wow" at street level; keep holograms ~2.4-3x.
- Thin particles (rain < ~0.05 m wide) turn into screen noise; prefer fewer, larger streaks.
- Outdoor low walls (southern map rim, river banks) are built as `_street_edge` (pale kerb + slim barrier/rail): the camera
  looks down on their 2 m-deep top face, which read as a black band in front of the hero when it was a dark wall box.
- Occluder cut-away (`CameraRig._update_occluders`) sweeps a 5 m box along the sight line (layer 128), so a whole
  row of buildings across a narrow street fades together; a single ray left a dark band over the hero.
- Never run `--import` while `tools/sprite_forge.py` is still writing sheets: a half-written PNG gets imported as
  `valid=false`. Fix: delete that `.png.import` and re-import.
- `VirtualJoystick` is a **native class** in 4.7 → ours is `TouchStick`. Check `ClassDB.class_exists()` before naming classes.
- No `match` inside a multi-line lambda passed as a call argument (parser error). Use a named method.
- `var x := <Variant expression>` fails ("cannot infer type") → write `var x: bool = ...`.
- `%g` is not a GDScript format specifier.
- Controls created at runtime inside the tree: use `set_anchors_and_offsets_preset(PRESET_FULL_RECT)`,
  not `set_anchors_preset` (that keeps the old zero-size rect).
- Don't pass `--rendering-driver vulkan` on the CLI: it silently switches the renderer to Forward+.
- `tools/*.gd` run with `--script`: autoloads only exist from the first `_process` frame, and
  referencing game `class_name`s at compile time poisons the script cache — compare by `get_global_name()`.
- Depth-based DOF (`CameraAttributesPractical`) blurred everything on lavapipe; default is the
  screen-space HD-2D lens (`assets/shaders/hd2d_post.gdshader`, tilt-shift etc.), selectable in Settings.
- Mobile renderer: max 8 omni lights per mesh → floors are built in 6x6-tile chunks.
- CPU budget: `tools/perf_probe.gd` (times player/NPC/enemy physics + sprite frame work per planet; keep < 2.5 ms on a
  desktop core). Don't trust `Performance.TIME_PHYSICS_PROCESS` (per-second MAX) or headless frame time (headless sleeps
  ~6.9 ms per frame). Crowd LOD: `ViewLod.off_screen()` (camera view box, focus set by CameraRig) -> idle NPCs / foes tick
  4x less often, sprites skip frame work. Walkers on the ground use velocity.y = 0 (a downward push collided with
  floor-chunk seams on every step: 2+ slide iterations); owners at their post never run move_and_slide.
- Particle quads with billboard materials ignore particle scale unless `billboard_keep_scale = true`.
- Godot's GUI focus + `ui_*` actions give gamepad menu navigation; always `grab_focus()` the first button of
  every screen/modal. BUT Godot 4.7's built-in `ui_accept`/`ui_cancel` have NO joypad buttons (and a joypad
  event added to `ui_accept` in project.godot is dropped on load) -> `Router.ensure_gamepad_ui()` binds
  A = confirm, B = back at runtime. Verify with `tools/pad_test.gd` (sends real joypad events headless).
  `Router.input_device` tracks touch/keyboard/gamepad for prompts.
- HUD dialogue pauses the tree; cutscenes use `await hud.say(...)` (SceneTreeTimers keep running).

