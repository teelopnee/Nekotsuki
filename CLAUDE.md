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

## NEKOTSUKI systems (episode 0)
- NEW GAME = `Router.new_suzunari()` (Toru, cast look) -> `scenes/world/suzunari.tscn` (`src/world/suzunari.gd`, map
  `data/maps/suzunari.txt`, LevelBuilder legend below). Continue routes there when `Game.location_id == "suzunari"`.
  The old sci-fi flow (creator, station, planets, saga) still exists for the smoke test until it is replaced.
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
- `Clock` autoload: 1 real s = `rate` game minutes, periods, Omagatoki 18:00-18:30, day ends 22:00 (`level.end_day()` saves
  and reloads), `light()` drives the sun. State in `Game.flags["clock"]`.
- `Amane` autoload (state in `Game.flags["amane"]`, lines `data/amane.json`): tears 0-5 -> `rain` (level particles + gloom),
  route none/friend/romance/boundary/ignore, `choices()` (reject button shrinks via HUD choice `scale`), `choose()`
  returns text + `> impact` block + feeling, `converse()`, phone (`send`, `phone_reply`), jealousy from
  `EventBus.interaction_done` near him, `morning_event()` (blocked -> doorstep). `AmaneNPC` (`src/actors/amane_npc.gd`)
  follows at `follow_distance()`, peeks when looked at, slips behind you when far/stuck, walks up to talk.
  `src/ui/neko_overlay.gd`: date/time/forecast + Rinrin phone. HUD objective line = `Amane.objective_text()` in Suzunari.
- M3 town brain: `Cats` autoload + `CatNPC` (8 cats, `Game.flags["cats"]`, sprites `cat_a/b/c` from `build_cat` /
  `CAT_ANIMS`): a cat within 12 m that doesn't like you (attitude < 40) runs to Amane after you talk to someone
  (`EventBus.interaction_done`); petting raises attitude / cancels the report. `Amane`: `closeness` per NPC, weekly
  `pick_rival()` (Monday; Hayate +25 by default), `_ikiryo_night()` each night = next stage of the living-spirit plan
  (`data/amane.json stages` 1-6: nightmare, shoes, cats, ties cut, injured, spirited away -> `fates`), blocked by
  `warn()` (Hayate dialogue), the phone "Watch the rooftops" `night_choice()` (chase / name / let_go) or self >= 55;
  Friday night jumps a step. `post()` = Ura board (phone tab). `HayateNPC` (`src/actors/hayate_npc.gd`,
  `data/hayate.json`): courtyard from 8:10 (home before that), after 15:20 walks over and offers to walk you home (People). `Ledger` autoload writes `user://ledger.json`
  every night (`snapshot()`, `read()`). Test: `tools/m3_test.gd`.
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
- Enter buildings - Suzunari Gakuen (`src/world/school.gd`, `scenes/world/school.tscn`, `Router.SCHOOL`,
  `Game.location_id = "school"`): one floor per load (`Router.params {floor, at}`, `Game.flags.school_floor`), maps
  `data/maps/school_{1f,2f,3f,roof}.txt` built by `JPSchool` (`src/world/jp_school.gd`; legend in its header: floors
  `. _ , : ; =`, furniture `k n d t a l g s b x v p e m c y f o r w u h z j i q Y`, links `S` up / `D` down / `K` roof /
  `X` exit - R and E are LevelBuilder.ACTOR_CHARS). Stairs: `S`/`K` on floor n and `D` on floor n+1 share a tile;
  you arrive one tile south. `data/school.json`: `rooms` (name plate at `door`, fluorescent light over `rect`),
  `features` (interactable at `tile`, Town.scene with `choices` or `variants` picked by `when`: Amane.ok keys +
  `after`/`before` minutes + `chance`), `doors` (exterior tiles; Suzunari `_school_doors` -> `enter_school`,
  `Game.flags.school_door`, `Router.params.spawn_tile` on the way out), `eggs` (merged into Town). Staff and cast
  indoors = Town spirits with `indoor` + `itile` (Makabe, Fujimura-sensei, Tomi-san, Reiji, Hanako). Town fx also
  take `minutes`, `tears`, `bond`. Exterior: the school block is one 'b' building, JPKit style `school_main`.
  Test: `tools/school_test.gd`; shots: `tools/shot_school.gd -- <dir> [names]`.
  Life inside: `School._crowd()` spawns students by `Clock.period()` (classrooms full in lessons, store/entrance at
  lunch and mornings, club rooms after school, roof at lunch); desks and tables are `life_spot` "sit" seats, so they sit
  down by themselves. `JPSchool` dresses back walls (posters `jp_f_poster0-7`, motto banner, clock, PA speaker,
  timetable), window sun beams + floor patches (`jp.shaft_mats`, driven by `set_sun`), glossy floors, desk clutter
  (bags, books, pencil cases - coloured MultiMeshes), senbazuru by the windows, dust motes. Indoor camera: pitch 27,
  distance 13.5 so the back wall is in frame.
  Between periods (`Clock.period_changed` -> `School._bell`): the chime (`assets/audio/sfx/chime.wav`,
  `tools/gen_chime.py`, Westminster Quarters), then surplus students walk to rooms that want people via `route()`
  (room door -> corridor -> door -> seat; NPCs steer straight, so routes go through door tiles) or leave by the
  stairs (`NPC.walk_path(points, "free")`); rooms still short get students arriving from the stairs. `NPC.path` /
  `walk_path` / meta `area` (Rect2: seats are only picked inside the NPC's room). Roof at lunch: picnic sheets ('+',
  4 seats each), students start by the seats nearest the player. Indoor glow threshold 1.35 (roof 1.8) so light hair
  doesn't bloom.
- Homes & walks (`People` autoload, state `Game.flags["people"]`; `HomeVisits` node = Suzunari `home`, `src/world/home_visits.gd`;
  `CompanionNPC`): five houses with a door, nameplate and bell (`data/people/<id>.json` profile: `door`, `leave`/`arrive`/
  `home_leave` minutes, parent, `answer` odds, `fx` per personality: rush / wait / broken promise / pickup / walk, `rumour`
  (Sato Yui sells it, ¥500), `mio_says` (Mio trades it for 3+2n known lore)). Hayate 7:50 Inukai house (53,22), Hina 7:55
  above the florist (12,38), Mio 8:12 Kuroe house (52,38), Reiji 7:40 Shirasagi residence (51,50, JPKit style `mansion`),
  Amane 7:52 Nekomori house (34,4). Morning door: ring (parent or friend answers by tier) / wait (5 min, or to their
  minute if known) -> `_come_out` -> "walk to school together" -> escort `school` (ends in the schoolyard tiles z20-30
  x<=39 or at the school door: arrive line + closeness + "same time tomorrow?" promise; broken = toast + fx.broken +
  "sorry" menu item). Standing near the door at their minute = they come out on their own. After 15:20: "walk you home"
  (`their_home`, needs closeness 25) or they offer (`my_home`, `NEED_OFFER` 45, Hayate 20 and he walks over himself);
  close friends then offer to pick you up tomorrow (`pickup_me` -> `at_your_door` on the next morning, `HomeVisits.resume`).
  Lines: ~30 keys x 5 people (tiered keys `_low/_mid/_high`, `{who, t}` entries = another speaker, `morning_day` by
  weekday) + Amane's `jealous` section (cut_in / follow / sulk / text / text_boundary / cut_in_reply / join).
  Amane while you walk with someone: romance = cuts in (answers kind / honest / boundary / take his hand), friend/none =
  trails + barks + sulks at the gate, ignore = sad texts, boundary = brave text. `People.hides(id, m)` hides the usual
  body (Hayate before 8:10, spirits via `Town.present`, AmaneNPC before 7:52) while they're home / on the road / with you.
  `People.menu_items(id)` + `run_item` add "p:" choices to Town.meet / HayateNPC (ask schedule, walk home, buy, trade, sorry).
  Closeness = Amane `closeness` (Amane: bond_now), so pick-ups feed the weekly rival. Test: `tools/people_test.gd`;
  shots: `tools/shot_suzunari.gd -- <dir> house_inukai,house_shirasagi,house_kuroe,house_hayase,house_nekomori,pickup_hina`.
- Tests: `tools/day_test.gd` (day loop, routes, rain, phone, doorstep, next day). Screenshots:
  `VK_ICD_FILENAMES=/usr/share/vulkan/icd.d/lvp_icd.json xvfb-run -a -s "-screen 0 1280x800x24" godot --path . --resolution 1280x800 --script res://tools/shot_suzunari.gd -- <dir>`
  (needs `apt-get install mesa-vulkan-drivers`; `apt-get update` first).

## Engine notes (inherited from ODD-SPACE)
Everything below still describes the inherited code, which keeps its sci-fi names (planets, Consortium, Paragon, crew...).
Rename and rewrite these notes as systems are replaced (GDD section 10). `docs/REVIEW.md` is this repo's critique log.

### Layout
- `src/autoload/` singletons (order matters, see `project.godot`): `EventBus`, `DataDB`, `Game`,
  `Factions`, `Causality`, `Origin`, `Crew`, `FlawPerk`, `Encounters`, `Saga`, `Stories`, `Interactions`, `ShipAI`, `Audio`, `Router`.
  `Origin` = 6 tag categories (class incl. 5 Consortium heirs .. beggar, age + exact years, background, personality,
  motivation, secret; `data/tags.json`). `Saga` = branching procedural main story (`data/saga.json`: approaches per beat,
  surrender choices, twist, 15+ finales, composed endings, early motivation endings). `Stories` = per-planet local arcs
  + street events (`data/stories.json`). `Interactions` = character-dependent verbs on NPCs (`data/interactions.json`).
  Story/interaction choices share one requirement grammar (flag/any_flag/tag/age/min_wealth/... see the `_doc` keys).
  Systems communicate via `EventBus` signals. Persistent systems implement `reset()/to_save()/from_save()`
  and are registered in `Game._systems()` + `Game.save_game()/load_game()`.
- `src/actors/` Player / Enemy (data-driven subsystems) / NPC (witness, dialogue) / Projectile.
- `src/world/` `LevelBuilder` (ASCII → 3D: normal-mapped kit, wall dressing, windows, shafts, foliage,
  horizons, water `~`, cliffs `^`, street props k q j g w i v o Y, facades, low lantern cables, landing-bay paint),
  `WorldGen` (per-biome dense map generators + connectivity fix; preview with `tools/print_world.gd`),
  `Level` base (lighting/bloom, weather, navmesh bake, spawning, HUD, `refresh_quests()` for Saga),
  `station_prologue.gd` (intro cutscene), `planet_surface.gd` (WorldGen + per-seed palette variation +
  landing sequence), `CameraRig` (HD-2D lens post shader, punch/shake/look-ahead, occluder fade),
  `Critter` (ambient life: bot, drone, flyby, sky-traffic car, street traffic that brakes for people),
  `Hologram` (giant additive character ads, `holo_sprite.gdshader`), `Flicker` (failing neon).
  Outdoor builds also add road paint/crosswalks/manholes, litter + stains (MultiMesh), wet-street neon
  reflections (`_glow_spots`), neon facade tubes, low lantern cables, biome extras (mist, lily pads, dust devils),
  shop-front venues (`data/venues.json` via `Interactions.open_venue`), wanted posters and news billboards.
- NPC life: `life_spot` markers (bench seats, stall queues, hologram dance floors) -> `NPC._pick_activity`
  (sit / phone / queue / dance), waving at friends, cheering on `story_event`; reactive barks (`data/barks.json`).
- `src/core/character_look.gd` random looks (variant + palette colours); sprites are palette-indexed.
- `src/core/copy.gd` procedural copywriter over `data/copy.json` (Tracery-style `#symbol#` grammar): billboards,
  hologram slogans, shop/stall/street names, HUD news ticker, wall flyers + graffiti, menus, PA announcements,
  NPC small talk + replies, NPC/robot/merchant names, drone pitches, venue greetings (`<venue>_scene/_keeper`).
  Preview: `tools/print_copy.gd -- [symbol] [count]`. Add variety by adding alternatives there.
  Grammar also works inside `barks.json`, `venues.json` greet lines and `interactions.json` lines (`Interactions.fill`).
  Modifiers: `.cap` `.upper` `.lower` `.a`; vars `{planet}`/`{PLANET}`, `{player}`, barks also `{name}`.
- Barks: `pair` lines `"A -- B -- C"` alternate between two NPCs (`NPC._converse`); enemies talk via
  `Enemy.bark()` from `<taunt|hurt|yield|standdown>:<enemy_type>` keys (throttled across the fight).
- NPC eyes & memory + voices: `src/core/npc_voice.gd` (`NPCVoice`). Acts in an NPC's line of sight (`NPC.witness_act`,
  fed by `interaction_done`, `action_recorded`, `enemy_killed`, `perfect_dodge`, `player_parried`, `EventBus.player_act`
  for dance/hurt) map to an act KIND and a STANCE per NPC voice (`data/reactions.json`), shift attitude, are remembered
  (`NPC.memories`) and gossiped planet-wide (`Game.flags["street_<planet>"]`, saved). Talking opens with a memory, gossip
  or a remark about who you are (`pc_class_/pc_age_/pc_bg_/pc_pers_/pc_goal_/pc_secret_<tag>`, wounds, money, bounty,
  fame, crew, saga, planet) voiced by mood (`open_<mood>`) + voice (`close_<voice>`) + the NPC's own `tic`. Grammar:
  `data/copy_people.json`, `data/copy_reactions.json` (merged into Copy). Memory-driven verbs use the requirement keys
  `npc_saw` / `npc_heard` / `npc_mood` and effects `forget`, `street_rep`. Test: `tools/voice_test.gd -- <class> <age> <bg>`;
  size of the line space: `python3 tools/count_copy.py`.
- Impact layer (NPC "Impact" section + `Interactions.resolve`): every verb result ends with a `>` block saying what changed
  (relationship before -> after, call cut / sped up, who saw it and how they took it, who is still calling Paragon).
  `relation_label()` tags over heads (FRIENDLY, OWES YOU ONE, DEVOTED, DISLIKES YOU, FURIOUS, SCARED OF YOU, REPOSSESSED,
  KEEPS QUIET) change behaviour: favours come back as gifts, grudges become `complaint` reports (stoppable calls),
  scared NPCs back off, furious ones heckle, attitude >= 45 or loyal = they won't report you, attitude scales call speed.
  Verb effect `"react": grateful|scared|bow|leave|repossessed|grudge|smitten` triggers these. New strangers on a planet
  start biased by its street memory (`NPCVoice.street_bias/street_feared`). Only `Causality.PHONE_VERBS` get phoned in;
  other witnessed acts become public at once. `WitnessComponent.can_see` (memory) vs `can_witness` (will report).
  A silenced witness MUST go back to normal life (`on_report_finished`) - it used to stay "reporting" forever.
  Test: `tools/impact_test.gd` (exit code = failures).
- NPCs always answer back: after every verb `Interactions.present_counter` shows a counter-move from `data/counters.json`
  (`counters.<kind>_<ok|fail>`, `served` after the family lawyer) with choices (reply / effects / chance / cost / verb).
  Outcomes with no `react` get `reactions.json` `default_react[kind]` (talk->warm/cold, charity->grateful, threat->scared/grudge,
  theft->robbed (they notice later and may accuse you), show->fan/heckler, beg->pity, deal->partner, weird->intrigued/spooked).
  NPCs also come to YOU (`NPC._schedule_approach` -> state "approach" -> `counters.approach.<kind>`: thanks, pity, partner,
  fan, confront (before a grudge becomes a complaint), smitten); "follow" state for crushes / curious people. One approach
  per 25 s, never in combat or over an open dialogue. `Interactions.force_outcome` forces rolls for tests.
  Test: `tools/interact_back_test.gd` (every verb x outcome answers back + changes something; every counter choice played).
- Shop owners: `LevelBuilder.venue_spots` (venue doors) -> `Level.spawn_keeper` puts an NPC with role "keeper" beside every
  door (stands at `post_pos`, skips physics while idle; Talk disabled - the door is the way in, except mid-call). Same person
  every visit: state saved in `Game.flags["keepers_<planet>"][<venue>|<sign>|<x>,<z>]` (one key per DOOR, also on the door as
  meta `keeper_key` - chain stores share a brand sign) (`persist_keeper` on change + `_exit_tree`;
  `{"dead": true}` -> the shop stays dark with its own scene). `Interactions.open_venue(..., door)` greets by memory /
  mood / regular / fan / partner, shows personal prices (`price_mult`: attitude, regular, fear), adds 3 owner verbs, turns
  away banned customers (`counters.venue.keeper_banned`). Every shop option maps to an act kind
  (`reactions.json venue_option_kind`) -> `_keeper_reacts`: mood + reaction (`reactions.json keeper`: regular, grateful,
  banned, robbed, fan, heckler, scared, grudge...) + afterword + counter `counters.venue.keeper_<kind>_<ok|fail>` (falls back
  to the person counters). Test: `tools/keeper_test.gd` (all 14 shop types x outcomes, bans, death, return visit).
- Combat pacing: `Enemy._take_token()` = attack tokens (max 2 attackers, 1 shooter at a time; saga bosses exempt);
  ranged foes kite rarely + slowly and stand still 0.9 s after each burst ("recover"); enemy bolts x0.78 speed;
  allies join within 8 m with a staggered delay; `WorldGen._scatter_enemy` spreads foes as patrols of 1-2 (swarms of 3).
  Player `DASH` state: MELEE with a hostile 3-9 m away dashes in (i-frames) and starts the combo on arrival.
- Enemies (`data/enemies.json`, map chars in `LevelBuilder` legend): G officer, E repo drone, B grub, H debt brute,
  R pirate, U riot unit (`guard`: blocks frontal shots/melee; flank, parry, charge, explode, katana or harpoon it),
  F gutter punk (`flank`), Q ad-bomb bot (`explode`, chain reactions), J ad-swarm drone (threes), Z vat golem (`slam`).
  `drops: {item: chance}`, `scale`, barks `<kind>:<type>`.
- Weapons: `src/core/arsenal.gd` + `data/weapons.json` (BLADE: pipe, baton, chain, katana, hammer; GUN: sidearm,
  scatter, arc, harpoon, grenade). Owned/equipped in `Game.flags.weapons/equip`; `weapon_<id>` items unlock on pickup
  (`Game.add_item`), sold by street traders / pawn / corp stores, dropped by enemies, start kit by background.
  Swap: `swap_melee` (1 / L3 / BLADE) and `swap_ranged` (2 / R3 / GUN). `Grenade` node, Projectile `pull/stun/push_force`.
  Test: `tools/combat_test.gd` (every enemy, tokens, every weapon, dash, riot guard, boom chain, unlocks).
- Player-facing polish: `src/core/tips.gd` + `data/tips.json` (one-time just-in-time tips, banner in HUD, seen list in
  device settings); `Interactions.should_counter` (big moments always, else Settings "followups"); `_impact_block` caps
  at 3 lines; HUD `_update_context_buttons` (touch buttons only when useful); Settings: difficulty (`Enemy.dmg_mult`,
  token limits), graphics (`Level.apply_quality/quality_mult`), ui_scale (root content_scale_factor), tips, followups.
  HUD `_update_calm` tucks the status panel when calm (Settings hud_fade). `Router._notification`: Android Back = close/open menu, app pause/focus-out = pause menu + autosave.
  Title "CREDITS & LICENSES" (Godot + third-party licence texts - required for distribution). PC: Windows/Linux presets,
  mouse (LMB melee, RMB fire; touch-emulated mouse ignored), F11 fullscreen. Critique log: `docs/REVIEW.md` - update it
  every pass (score, open issues, fix log).
- Authored act bookends: `data/bookends.json` -> `Saga.play_bookend(open|close, act)` (once per life, flag
  `bookend_<kind>_<act>`): openings by motivation + wealth band, closings by `Saga.dominant_axis()` + crew. Act numbers in
  saga beats are floats ("1.0") - normalise with int(). Authored meetings `bookends.json meet.<scene>` ->
  `Saga.play_meet` (flag `meet_<scene>`): ally on first contact, lieutenant + antagonist face-off when the elite first
  enters "chase" (`Enemy._set_state` -> `Saga.on_boss_sighted`), the antagonist's call on reaching the MacGuffin beat;
  parts picked by personality / persona trait / wealth band or `feud` / lieutenant_fate / ally_fate / axis.
  `idle.<role>.<beat>` = saga people talked to outside their beat (points you at the next goal).
  Side quests: `saga.json side.<type>.offer/done` lists (index `q.line`), `manner.<trait>`, `waiting`, `turn_in` (take /
  free / double -> `Saga._complete_side`). `Saga.fill`: `{faction}` = display name (world.faction is the id). Legacy titles are scored (`legacy_strength`),
  not first-match. Test: `tools/story_test.gd`.
- `src/core/first_day.gd`: 4-step onboarding checklist for a new life (talk / shop / fight / change), shown as the first
  objective line; steps fire from NPC talk, open_venue, enemy kills, relation changes. UI review shots: `tools/ui_review.gd`.
- `src/ui/` HUD (code-built), touch controls, pause menu, title, character creation, star map.
- `docs/ARCHITECTURE.md` explains the systems; `docs/GDD.md` the design.

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

## Art pipeline (all original, generated by code; replaceable 1:1 by hand-made art)
- `python3 tools/sprite_forge.py [variant...] [--preview]` - chibi characters: 3D SDF rig ->
  ray-marched **palette-indexed** pixel art (R = slot*16+8, G = band*40+20; 16 slots x 6 bands),
  sel-out outlines, eye decals. 64x64 frames, 19 anims (incl. sit, phone, dance, cheer, wave, surrender) x 5 directions (S, SE, E, NE, N; W mirrored
  in-engine) -> `<variant>.png/.json` + `variants.json`. Variants h00-h33 (humans), r00/r01 (robots),
  drone, drone_quad, grub; ~60 min for all on 4 cores. Colours are applied at runtime by
  `indexed_sprite.gdshader` from `CharacterLook` palettes - never bake colours into sheets.
- NEKOTSUKI additions to `sprite_forge.py`: school outfits (`blazer`, `teacher`, `track`, `miko`, `apron`, `skirt` short/long),
  hair `messy/neat/bob/hime/fluffy`, acc `catears/ahoge/choker/headphones/glasses/camera/armband`, cast variants `c_<id>`
  (`CAST`) and students `s00-s09` (`STUDENTS`). Variants with cfg `school` also get 25 `EMOTE_ANIMS` (cry, wail, pout,
  fluster, shock, angry, sulk, peek, tug, bow, dogeza, laugh, think, facepalm, shrug, sneeze, yandere, loaf, pat_get,
  pat_give, offer, pinky, faint, happy, sad), each with its own face (`p.eyes/brows/mouth/cheek/tears/ears`; styles in
  `_eye/_brow/_mouth/_cheek`). The flash slot's bands 1-4 are face FX colours (blush, tears) - `CharacterLook.FACE_FX`.
  Check poses fast without forging: `python3 tools/cast_preview.py out.png --cast amane --anims cry,wail --cols 6`.
  Cast colours: `data/cast_looks.json` (`CharacterLook.cast_look(id)`). Runtime: `Emotion.express(actor, feeling)` =
  `BillboardSprite.emote(anim, s)` (held over idle/talk) + `FX.emote(actor, kind)` (`data/emotions.json`); manga emote
  glyphs are ASCII in `gen_fx.py GLYPHS`. Test: `tools/emote_test.gd`.
- `python3 tools/gen_textures.py` - 64px pixel textures + normal maps (`*_n.png`, incl. asphalt, planks),
  space backdrop, horizon silhouettes, foliage atlas, light-shaft gradient.
- `python3 tools/gen_fx.py` - pixel VFX sheets (slashes, sparks, explosion, dust, break, telegraph) + fx.json.
- `python3 tools/gen_audio.py` - SFX, synthwave + Karplus-Strong music (one track per biome), ambience loops, thunder.
- Texture import defaults are lossless (pixel art!); `assets/textures/*.import` have mipmaps on.

## Android APK
- `export_presets.cfg` preset "Android" (arm64, Mobile renderer). Needs export templates + Android SDK
  build-tools + JDK; set `export/android/android_sdk_path` / `java_sdk_path` in the editor settings.
- Release signing via env: `GODOT_ANDROID_KEYSTORE_RELEASE_PATH/_USER(oddspace)/_PASSWORD`.
  The keystore is NOT in the repo (public). CI (`.github/workflows/android.yml`) reads it from the
  secrets `ANDROID_KEYSTORE_BASE64` / `ANDROID_KEYSTORE_PASSWORD` (the owner must add them; writing
  secrets from an agent session is blocked). APKs signed with a different key can't update in place.
- Publish: `gh release create vX.Y.Z build/odd-space.apk ...` (build/ is git-ignored).
