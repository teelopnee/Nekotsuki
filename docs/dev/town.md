# Suzunari: theme, map, look and light

The town itself: the sci-fi -> Suzunari text theme, the 56x56 map and its landmarks, Town spirits and Amane's talk data, JPKit buildings, the HD-2D lens, shadows, materials, ambience.

Moved out of `CLAUDE.md` so sessions only read what they need. Keep it current when the system changes.

- Suzunari theme (the inherited sci-fi text and dressing, re-skinned):
  `python3 tools/suzunari_theme.py` turns the base data into `data/suzunari/*.json` (barks, venues, interactions,
  counters, items, tips) and `data/copy_suzunari_auto.json` (Copy symbols `suzunari_<symbol>`): REPLACE rules
  (credits -> yen, Paragon -> the police, paste -> instant noodles...), BAD lines dropped from line lists, then the
  hand-written overrides in `data/suzunari/_manual/*.json` merged on top. Edit the manual files (or the base data) and
  re-run the script; never edit the generated files. Runtime: `DataDB.apply_theme("suzunari")` (themed venues /
  interactions / counters / items; `DataDB.themed_path()` for barks and tips; `DataDB.money(n)` = n x 100 yen),
  `Copy.theme` (also nested #symbols#), `CharacterLook.theme` (no robots / sci-fi accessories / neon hair),
  `palette.theme` (LevelBuilder: tiled eaves, noren, red lanterns, Japanese shop types and blade signs, no wanted
  posters or neon tubes), `Interactions.SUZUNARI_VERBS` (town verbs only), `NPCVoice` (`pc_new` remarks instead of
  sci-fi biography), HUD hints / pause "Town" tab / witness "CALLING THE POLICE". day_test checks for sci-fi leaks.
- M4 words & world: map `data/maps/suzunari.txt` is 56x56 (shrine plaza + 999 steps north, school z20-31 with the gate at
  x21-24 z31, Inukai dog shrine x41-54, road z32-33, Rokujizo crossroads, station, shopping street, river + bridge, home,
  beach). LevelBuilder `_jp_cell` builds Japanese landmarks (A torii, Y hall, T offering box, C komaneko/komainu
  (east of x=40 = dog), h stone lantern, o jizo x6 = save points, m ema, X basin, q bike, n pole, c bamboo, u hydrangea,
  l stone steps); each one is an Interactable -> `Town.examine(kind, idx)`.
  `Town` autoload (`data/town.json`, state `Game.flags["town"]`): landmark texts (+ optional choices), 18 lore signs
  (`lore_points`, tiles), 11 `spirits` (cast + yokai, `hours` in minutes, `SpiritNPC` at a tile, `Town.meet`), scene
  choices `{t, say, fx}` with fx `lore / egg / zukan / promise / flag / luck / money / hp / amane_self / closeness`.
  Known lore lives in `Amane.st()["lore"]` (shared with talk requirements); titles in `lore_titles`; Notes tab =
  `Town.codex()`. Amane talks: `data/amane_talk.json` topics (`when` requirements, `menu`, `a` = his line, 5 `replies`
  with exact words `t`, `tone` kind/curious/flirt/tease/honest/boundary/cold -> `Amane.TONE_FX`, `say`, `say_crying`,
  `fx`, `lore`, `promise`, `feel`). `Amane.converse`: up to 3 topics per talk, cold words shrink as he cries.
  Yokai sprites `y_*` (`sprite_forge.py YOKAI`, eyes/mouth "none" = nopperabo). Test: `tools/talk_test.gd`.
  Townsfolk verbs show exact words: `verbs.<id>.say` lists in `data/suzunari/_manual/interactions.json` (menu =
  `"line"  (verb)`). Suzunari '^' = wooded hill (`_jp_hill`: mossy bank, stone wall, cedars; trees only near paths).
- Suzunari look (`src/world/jp_kit.gd`, `JPKit`, created by LevelBuilder when palette theme = "suzunari"): ground kind
  per town zone (`floor_kind`: gravel, sando slabs, stone path, paving, asphalt, grass, schoolyard, beach, classroom wood,
  bridge), Japanese buildings (`building` splits a 'b' block into 4-8 m units: machiya, modern shop, house, keeper's
  house, old school, station; kawara gable roofs, pixel facade quads with night emission, hisashi, balconies with futons
  and laundry, potted plants, nobori flags, noren, lanterns, shop venues), sakura ('g' + every 3rd embankment tile,
  textured fluffy crowns + fallen-petal carpets) and shrine pines, utility-pole wires, road paint + gutters, classroom
  desks + blackboards, lantern garlands over the shopping street, planters, fishing boats, sea/forest margin.
  `set_night(t)` drives `night_mats` / `night_lights` (from `Suzunari._apply_light`, which also moves the sun, sets the
  haze colour and the HD-2D colour grade). Shrine hall `_jp_hall`, guardians `_jp_guardian`, street lamps 'L' in
  LevelBuilder. Ambient life: `TownLife` (sparrows that scatter, butterflies), petals (GPUParticles following the player),
  kei cars (`Critter.style = "kei"`). Textures: `python3 tools/jp_textures.py <cache>` (Poly Haven CC0 -> pixelized
  128 px, credited on the title screen) and `python3 tools/jp_facades.py` (facade panels + blossom); commit the PNGs.
- HD-2D depth lens (Octopath look, default `dof_mode` "depth"; Settings cycles depth / tilt_shift / physical / off;
  off on graphics "low"): `assets/shaders/hd2d_depth.gdshader` on a full-screen quad under the camera (`CameraRig.lens_quad`,
  render_priority -128 = first in the transparent pass, so it sees the opaque frame + depth and labels/rain stay crisp):
  depth-of-field by real distance (`focus_dist` = camera->hero each frame, `focus_range`/`far_range`, golden-spiral blur
  with bokeh weighting) + normal-oriented SSAO (contact shadows). The canvas post (`hd2d_post`) still does vignette,
  grain and toning. Suzunari light: strong sun x1.25, ambient x0.62, contrast 1.14 / saturation 1.16; god rays
  (`JPKit._shafts` + `set_sun`, morning + Omagatoki), dust motes (`Suzunari._build_motes`), morning ground mist (fog height).
- Shadows (they used to fall behind everything): `indexed_sprite.gdshader` billboards in `vertex()` toward whoever
  looks - the camera when drawing, the LIGHT in the shadow pass - so characters cast full-silhouette shadows from any sun
  angle; `light()` = half-Lambert `wrap` so backlit sprites stay readable. Suzunari uses two suns: `sun` (casts shadows)
  swings BEHIND the town (yaw 115 -> 245 deg), so shadows stretch toward the camera; `_key` (no shadows) lights facades
  from the camera side. Cloud shadows: `_clouds`, a shadows-only quad at 24 m with `jp_f_clouds.png`, drifting.
  Street lamps 'L' cast shadows at night. Directional shadow map 4096. Debug tip: test shadows with ambient + key at 0.
- No flat colours in Suzunari: `LevelBuilder._jp_mat(key)` -> `JPKit.prop_mat` (`PROP_TEX`: lacquer = weathered
  vermilion, darkwood, hinoki, granite, kawara, indigo cloth, paint, sheet metal) and `_flat(c)` -> `JPKit.painted(c)`
  (chipped-paint texture tinted by the colour). Every `jp_*` material except floors (`JPKit.FLOOR_TEX`) gets the shared
  grime detail layer (`jp_f_grime.png`, `JPKit.weather`). Gable roofs add fascia, gutter and downpipe; Suzune hall roof =
  copper patina. Add a prop texture: entry in `tools/jp_textures.py TEX` + key in `PROP_TEX`.
  `jp_textures.py pixelize` bakes a top-left bevel light + cavity darkening from each normal map (crisp gaps between
  stones/tiles/planks). Buildings: timber frames (`_timber`), storey slabs + plinth (`_storeys`), window sills/lintels/
  jambs (`_window_frame`). Street-level clutter per unit (`_clutter`: bikes, crates, pots, umbrella stands, A-frame
  signs, AC units, vending machines, mailboxes, display stands at shops), `_shrine_dressing` (lantern rows, omikuji
  rack, sake barrels, tamagaki, shrine nobori), `_ground_details` (tactile paving, drain grates, kerbs, patches,
  manholes). Anything added to a house that is not drawn with its wall/roof materials must go into `deco` (fade_hide),
  or it floats in mid-air when the camera cuts the house away (gable() takes `deco` for ridge/fascia/gutter/downpipe).
  Depth lens is gentle on the background now (`far_range` 11 m, `max_radius` 4.5) so facades stay readable.
- Ambience: `python3 tools/gen_ambience_suzunari.py` -> `assets/audio/music/amb_suzunari_{day,dusk,night}.ogg`;
  `Suzunari.update_ambience()` (every minute: rain -> amb_rain, night/cat night, Omagatoki, day; Ura none);
  `Audio.play_ambience` loops OGG too. Title and indoor levels stop it. `finish_cat_night(kind)` -> `Amane.cat_outcome` (sets `plan.cat_decided` so `_ikiryo_night` skips) ->
  next day. Log `Game.flags.cat_night_log`.
- Theme script extras (2026-11-08): `fix_police` turns "the police says / has / doesn't" into plural verbs and capitalises
  "the police" at the start of a sentence (the bare `#faction#` symbol stays lowercase); `{planet}` / `{PLANET}` become
  Suzunari (the old `planet -> town` rule had left a broken `{town}` placeholder); ODD-SPACE ad-dystopia lines
  (`ads`, `ad-*`, ad blockers, scanners) are dropped from line lists, single strings get hand rewrites in `REPLACE`;
  bark family `crisis:*` is dropped. `tools/leak_check.py` checks the same words + the "the police" grammar.
- Night windows: `JPKit.set_night` scales each night material by its meta `night_mult` (school ribbon windows 0.3) and,
  for facade windows (meta `window`), by `JPKit.window_scale` (1.0; the cat night sets 0.15 = a sleeping town).
  The school's "SUZUNARI GAKUEN" Label3D is shaded (it glowed at night) and in `deco` (hides with the cut-away building).
- Vending machines in Suzunari: white-lit panel (energy 0.75, light 0.55 / 3 m), not ODD-SPACE's cyan AIR-O-MAT.
- No ODD-SPACE chrome in Suzunari (2026-11-08): `ShipAI.say` is silent (no Q.U.A.C.K. comm panel); the death screen uses
  `suzunari_death_title` / `suzunari_death_line` from `data/suzunari/_manual/copy.json` + "Enma's Ledger keeps everything
  ..."; the pause menu has no Perks or Crew tab and the Causality tab is "Rumours" ("WHAT SUZUNARI SAW").
- Townsfolk voice (2026-11-08, `src/core/town_talk.gd` `TownTalk`, `data/town_talk.json`): Valve-style dynamic dialogue
  (Ruskin, GDC 2012): rules `{c, when, t, cool, once}`; of the rules whose criteria all hold, the one with the MOST
  criteria wins (specific beats general), ties are random; said lines rest `cool` days (`Game.flags.town_talk`), and
  when everything matching is resting the line said longest ago comes back - the ODD-SPACE pools never answer in
  Suzunari. Concepts: open, recall (what they saw: kind), gossip (street memory: kind), accuse (a known crime),
  remark, rumour, mutter (bubbles), headline (news ticker: verb). Facts: period, weekday, weekend, week, days_left,
  rain (Amane's tears), place (shrine / school / river / beach / station / street), job category, temper (stable per
  name), mood, met, route, rival + fate, club, job, late / truant / study, lore count, deeds, tags, story flags, Amane's
  tears / bond / self / jealousy / cat nights; any number takes `<fact>_min` / `<fact>_max`. Hooked into
  `NPC._opening_line` / `_talk_civilian` (accuse), `NPCVoice.remark / recall / aside / gossip`, `Interactions.rumor /
  greeting`, `CausalityGraph` headlines and the HUD ticker. Town verb results and townsfolk needs are hand-written in
  `data/suzunari/_manual/interactions.json`; the theme script also drops the billing-dystopia jokes (`BAD`), fixes
  "on Suzunari", "a the police" and "I'm {job}" (-> `{job_a}`, `Interactions.job_a`). `Copy._tidy` fixes "the the"
  and lower-case sentence starts inside composed lines. Money in effect lines shows as yen; nobody calls Paragon.
- `tools/town_voice_test.gd` makes 30 townspeople talk through every runtime generator (2,300 lines) and fails on
  sci-fi words, generated planet / faction / saga names, non-Japanese names, placeholders, broken grammar or too much
  billing satire (was 111 leaks + 18 tone lines, now 0). `-- <file> all` also dumps every distinct line for reading.
