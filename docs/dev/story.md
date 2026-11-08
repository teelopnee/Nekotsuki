# Story: clock, Amane, the 13 weeks, Ura-Suzunari, endings

NEW GAME entry, Clock, Amane's brain, the town's brain (cats, rival, living spirit), the Week story with school days, Ura-Suzunari, races, story flow, the kamikakushi rescue and the Enma's Ledger page.

Moved out of `CLAUDE.md` so sessions only read what they need. Keep it current when the system changes.

- NEW GAME = `Router.new_suzunari()` (Toru, cast look) -> `scenes/world/suzunari.tscn` (`src/world/suzunari.gd`, map
  `data/maps/suzunari.txt`, LevelBuilder legend below). Continue routes there when `Game.location_id == "suzunari"`.
  The old sci-fi flow (creator, station, planets, saga) still exists for the smoke test until it is replaced.
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
- Story, 13 weeks (`Week` autoload, `data/weeks/week01..13.json`, `data/endings.json`): days are keyed 1-7 inside each
  week (day 1 = Wed 8 Apr; `week_no()`, `day_in_week()`; 91 days to Tanabata 7 July). Day keys: `objective`, `morning`,
  `holiday` (no lessons), `exam` (lessons become exams graded by `study`), `beats`. Beat keys as below plus `"when":
  "night"` (played in `before_day_end`: Grandpa Genzo's Friday dreams, midnight messages). Text placeholders `{rival}`,
  `{rival_short}`, `{player}` (`Week.fill`). `needs` / choice `when` use `Amane.ok` (now also `flag`, `no_flag`, `routes`,
  `min_close {name: n}`, `min_lore_count`, `max_bond`). Scene fx also: `study`, `trust`, `warn_rival`, `name_ikiryo`,
  `flag` as a list, `final` (week 13 only) -> `Week.ending(choice)` -> `ending_id()` (route, bond, self, flags
  memory_2016 / sayo_found / letter_101 / makabe_letter_sent / seal_known / kyoko_offer, rival fates) -> pages + end card
  + `Game.flags.ending` + Ledger + back to the title. Validate all story data: `tools/week_test.gd` (plays every choice).
- School days & week 1 (`Week` autoload, `data/weeks/week01.json`, `data/lessons.json`, state `Game.flags["week"]`): lesson
  blocks AM 510-750 / PM 800-920 are ONE event when you're in the school (4 choices, clock jumps to the block end);
  late = > 2 min into a block; absent = in town 15+ min into a block (toast, Makabe -3, Ura post "truant", Amane tears);
  `before_day_end(hud)` (Suzunari/School `end_day`, awaited): Haruka hears about 3 lates / 2 absences, day 7 closes week 1
  (`close_week`: summary + hook). Daily beats: `days.<n>.beats` {where, after, before, near [x,z,r], needs, fallback,
  speaker, text, choices} played via `Town.scene` (fx incl. `amane_choose`); `objective()` prefixes the HUD line,
  `morning_note()` at wake-up. `Clock.spend(m)` = time cost of a talk (never past 21:30). `Week.music_now()` picks
  `suzunari_morning` / `suzunari_dusk` / `suzunari_rain_night` (`tools/gen_music_suzunari.py`, OGG). Amane talk: topics in
  `Amane.ONCE` once per life, others rest `COOLDOWN` days (`topics_seen`, `talk.again` lines), replies shuffled per day.
  CameraRig talk close-up (`_talk`, `_talk_partner`, `_face_each_other`, `_talk_labels`) and foreground fade of group
  `foliage_fg`. UI theme `assets/ui/washi_theme.tres` (project default). `python3 tools/leak_check.py` = every themed
  line checked for sci-fi words (exit code = leaks). Content notice before NEW GAME (`title_screen._content_notice`).
  Test: `tools/week_test.gd`.
- Story flow: `Week.marker()` = place of the next pending beat (lantern `StoryMarker` + `marker_hint` "(NE 85 m)" on
  the objective line); missed beats carry over one day (`_candidates`, `"carry": false` to stop it); weekends and
  holidays open Aunt Haruka's menu at home before noon (`data/weekend.json`, `weekend_menu`: shop / fishing / study /
  a day with your closest friend / sleep, each costs hours); `max_close` need + fallback beats where a day depended on
  closeness; Tanabata can't be slept through (`before_day_end` plays w13_tanabata); endings reached are kept in
  `user://endings_seen.json` and shown on the title screen.
- Ura-Suzunari (`data/ura.json`, `Week.enter_ura(goal)` / `leave_ura(thrown_out)`, flag `in_ura`): the Suzunari level in
  ura mode (`Router.params.ura`, `Suzunari.ura`): clock stopped at the entry minute, red light (`_ura_light`), rain
  falling up, townsfolk turned to shadows, five `EchoNPC`s (`src/actors/echo_npc.gd`: 1868 / 1890 / 1945 / 2011 / 2016,
  Town.scene), the goal (Rin = floating bell `_spawn_rin`; riverbed = solid echo Sayo + elite "Kasha Matriarch"), wild
  kasha (`data/enemies.json` "kasha", cat sprite, look in ura.json) and the exit Interactable at the steps. Two-bell rule:
  `bell_seconds` -> toast; x2 -> thrown out, `Clock.next_day()`, one lore entry forgotten. Story beats enter with fx
  `enter_ura: rin|riverbed`; after meeting Rin (flag `met_rin`) the "ThousandthStep" Interactable at the top of the 999
  (4,10) lets you go over on your own at Omagatoki (goal `free`). Weapons show Suzunari names (`weapons.json
  suzunari_name`: Umbrella, Salt Throw...). `_ura_dressing`: the river runs dry (stone bed + MultiMesh of children's
  stone towers), festival stalls on the shopping street, floating red lanterns over the roads, torii across the road
  (x 8/26/46), the station sign reads KISARAGI. Music `ura_festival` (gen_music_suzunari.py). Kasha sprite = variant
  `kasha` (`sprite_forge.py kasha`: two flame-tipped tails, `KASHA_ANIMS` pounce/charge/hurt/dead). Enemy shield pips
  and "??" readouts are hidden in the Suzunari theme. Test: `tools/ura_test.gd`; shots: `tools/shot_ura.gd -- <dir>`.
- Races (`Week.race(spec)`, fx `race`; `Suzunari.start_race`): a scene you have to run - kind `cat` (the two-tailed
  cat runs off along open street, catch it within 2.4 m) or `lantern` (reach a lantern at `to`); `seconds` (at least
  distance/4.5 + 6 unless `exact`), countdown on the objective line, then `ok` / `fail` {say, fx}. Used by the relay
  (week 7) and the hill on the 13th (week 10). Feel: `FX.countdown(start|tick|urgent|win|lose)` = hyoshigi / taiko /
  bell SFX (`tools/gen_race_sfx.py` -> `assets/audio/sfx/race_*.wav`) + `FX.rumble(..., handheld)` on every gamepad,
  or the tablet itself (`Input.vibrate_handheld`) when no pad is connected; last 3 s = double clap + stronger pulse.
  Ura's bells also ring + rumble. Settings "Vibration" (`Game.settings.rumble` "on"/"off", `FX.rumble_on()`).
- Kamikakushi rescue (`data/ura.json hidden`): everyone with fate "hidden" waits in Ura-Suzunari (`_spawn_hidden`,
  `src/actors/lost_npc.gd`, group `lost`); take their hand -> `Game.flags.ura_rescue` -> they follow; `Week.leave_ura`
  down the steps -> `Amane.rescue(who)` (fate "rescued", closeness +10, plan cleared, self +6, deed "rescue"); thrown
  out by the second bell = the hand slips. Hidden people are gone from town (`People.hides`, doorstep line).
- Enma's Ledger page (GDD 4.14): `Week.ending` -> end card (+ goal epilogue) -> `Ledger.show_page()` ->
  `src/ui/ledger_page.gd`: Dosho (left, slanted ink) and Domyo (right) brush in each `Ledger.entries()` entry
  (`data/ledger_scribes.json`: route, fates, cat nights, deeds, promises, pickups, truancy, club, jobs, eggs, zukan,
  goal, ending), argue, stamp GOOD / BAD / UNDECIDED; then the Johari mirror shows `Ledger.capture(caption)` frames
  (`user://mirror/*.png`, taken at first meeting, races, Rin, club/job events, cat windows, the ending; headless keeps
  captions only), then totals. Scribe sprites: `python3 tools/gen_scribes.py`. Test: `tools/life_test.gd` (creator,
  origin effects, clubs, jobs, weekend, Sunday, cat night, ledger page).
- Ledger page fonts: `assets/fonts/yuji_syuku_ledger.woff2` (Domyo, subset Latin + 善悪閻魔帳) and
  `caveat_brush.woff2` (Dosho), SIL OFL (texts `assets/fonts/OFL_*.txt`, shown in CREDITS, exported by include_filter).
- Ura light (2026-11-08): red key light over cold violet ambient (`_ura_light`: ambient (0.36, 0.28, 0.56) x0.85,
  saturation 1.08, facade windows at `window_scale` 0.45), so the riverbed reads in two tones instead of one red wash. The HUD notice board is hidden in Ura
  (`HUD.set_ticker_shown(false)` in `_build_ura`). The objective line omits "Route:" until a route exists.
- Yomotsuhegui stall (2026-11-08, `data/ura.json food`, `Suzunari._ura_food_stall/_ura_food`): one dango stall on
  the Ura shopping street (stall_x 17) offers a skewer once per visit (eat / refuse / ask, all give lore
  `yomotsuhegui`). Eat = one bite, then Rin knocks it away (as in 2016, LORE 1.1 says a full meal keeps you there):
  flag `ate_in_ura` -> `bell_seconds()` x `bell_mult` 0.7 and being thrown out forgets 2 lore instead of 1; if Genzo's
  week-6 promise `dont_eat_ura` was made it is removed and `broke_genzo_promise` set. Refuse/ask = `refused_ura_food`.
  Deeds `ura_food_broken` / `ura_food` / `ura_food_refused` reach the Ledger page; the same night `Week._genzo_food`
  plays Grandpa's dream (`genzo_broken` / `genzo_ate` / `genzo_refused`). `kasa_friend` (week 6, you took the old
  umbrella home) adds `kasa_bonus` 20 s to the bells, with a toast on arrival.
- What Suzunari remembers (`data/endings.json remembers`, `Week.remembered(id)`): after the ending pages, up to 4 lines
  about story choices (every flag that week choices set has one; one line per entry for tablet editing). Line keys:
  `flags` (all), `none`, `not_endings`, `who` (a rival's full name: skipped when hidden or in two_of_us), `p` (3 first).
  week_test checks every line's flags are set by some choice.
- Playtest log (`src/autoload/playtest.gd`, debug builds only): real seconds per game day split into walk / talk /
  menu / idle, scene count, and a timeline of the first 80 scenes, lessons, Ura visits, races, cat nights and day ends
  (`Playtest.scene/mark`, hooked in `Town.scene`, `Amane.converse`, `Week._lesson/enter_ura/race/before_day_end`,
  `Suzunari._build_cat_night`). `user://playtest.json`, reset by NEW GAME; pause menu page "Playtest".
