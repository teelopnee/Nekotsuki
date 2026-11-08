# Toru's life: school, homes, creator, clubs, cat night, friends, exams

Inside Suzunari Gakuen, homes and walks (People), the NEW GAME creator and `Toru` stats / clubs / jobs, the cat spirit night, companions (Party) and exams.

Moved out of `CLAUDE.md` so sessions only read what they need. Keep it current when the system changes.

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
- NEW GAME = title -> content notice -> `src/ui/toru_creator.gd` (given name + one tag in each of 5 categories of
  `data/toru.json`: wound / personality / skill / secret / goal; every option shows what it does) ->
  `Router.new_suzunari(name, tags)` -> `Toru.apply_origin`. `Toru` autoload (`src/autoload/toru.gd`, state
  `Game.flags["toru"]`): six stats 0-100 (study, stamina, charm, courage, agility, transparency; `add()` goes through
  origin `gain` multipliers), origin effects read by other systems (`tears_mult` -> Amane cold replies shrink sooner,
  `tone_mult` -> Amane talk fx, `calm` -> tears fade, `jumpy`, `sneezes`/`cats_mult` -> Cats.pet, `ghosts_early` ->
  Town.present, `bell_bonus` (courage) -> Ura bell, `close_mult` (charm) -> Amane.add_closeness, `race_speed`
  (agility) -> player meta `speed_mult`), quirks earned every night (`check_quirks`: soft_heart, escapist, cat_servant,
  see_through, third_eye, promise_breaker), `morning_note()` (origin `mornings` lines), `day_end()` (club skips, Sunday
  debt + Saki's call), `goal_epilogue()` on the end card, `status_text()` = pause menu "Toru" page.
  Clubs + jobs: `data/clubs.json` (8 clubs, 5 jobs, styles, job_styles, board). Places: `where.level` suzunari ->
  `Suzunari._work_spots` (Interactables `Work_<id>` + floating name), school -> `School._club_spots` (+ recruitment board
  1F). `Toru.use_club` (pitch/join, one session a day while it meets, every 4th = next `events` entry, clock jumps to
  `close`), `use_board`, `use_job` (interview with `needs`, shifts, every 3rd = event, pay x hours x bonuses),
  `weekend_items()` (Aunt Haruka's weekend menu offers today's shifts). Town fx `stats` / `study` also train stats.
- Cat spirit night (`data/cat_night.json`, GDD 4.11): `Amane.cat_night_due()` (week 2+, a running plan, jealousy >= 20
  or tears >= 3, self < 55, not guarded, once a week) is checked in Suzunari/School `end_day` after `before_day_end` ->
  `Game.flags.cat_night` -> Suzunari in cat mode (`cat_night`, `_build_cat_night`): clock frozen at night, townsfolk
  hidden, other Interactables off, player = black two-tailed cat (`kasha` sheet, meta `cat_mode` = no combat,
  `speed_mult`), spots (group `cat_spot`): rival's window (People door or `rival_homes`; plan / resist / watch),
  Senpai's window (ends the night gently), secrets (lore), knocks (`Ledger.deed`, Ura board), dawn timer.
  Roofs: `JPKit.gable` adds the roof slabs as colliders on `LevelBuilder.LAYER_ROOF` (512, only the cat's mask has it);
  ROLL = LEAP (`Suzunari.cat_leap`: rays down 1.5-7 m ahead -> up onto a roof/wall top, across a gap, or down to the
  street; `_cat_hop_to` arc). The navmesh includes rooftops - don't use `nearest_walkable` for "down". Player meta
  `standing_on` stops CameraRig fading the house under the cat. GUARD = SNEAK (meta `sneaking`: x0.45 speed, half
  sight range). Night watch: `src/actors/night_watcher.gd` (group `night_watch`, data `watchers`: patrol with torch,
  drunk, stone dogs; suspicion "?" -> "!" = `spotted` -> `_cat_spotted`: hop away, dawn +25 s, Ura board post,
  deed "seen"; 3 = the night ends as "dawn"; a patrol that half-saw the cat walks to `last_seen`, sweeps its torch, then
  returns to its round). Touch buttons become LEAP / SNEAK (HUD `_update_context_buttons`).
  `Suzunari.nearest_walkable` never answers a street query with a rooftop (the baked navmesh covers flat house tops).
- Companions (`Party` autoload, `data/party.json`, GDD 4.13): People menu `p:hang:<id>` (closeness >= 30, after 15:20
  or weekend 10:00, max 2, until `curfew`) -> `PartyNPC` (`src/actors/party_npc.gd`, extends CompanionNPC with
  `follow_offset`, group `party`), spawned by Suzunari/School (`Party.spawn_in`); `People.hides` hides their usual
  body. Every 30 min closeness +2 (Amane notices if near); banter + pair lines. Gifts: Hayate (cats don't report:
  Cats), Hina (`Toru.close_mult` x1.25; ask = a schedule or the rival plan), Mio (`Toru.ghosts_early` 60; ask = lore),
  Reiji (`Party.excused()` while with him; ask = a council pass token `Week.st().passes`). Members reset each day.
- Exams (GDD 4.13): grade = min(4, lessons/8) + Study/12 + choice. `Week.days_to_exam()`, `exam_hint()` on the
  objective; `Week.cram(hud, library|home)` (School 2F `LibraryCram`, Suzunari `HomeDesk`; 1 h, Study +3, 3 a day);
  `Week.tutor(id)` via People menu `p:tutor:<id>` (Reiji/Hina/Mio teach you, you drill Hayate -> flag
  `taught_hayate`); exam choice `copy` (catch chance from agility/courage, see-through ~0; `Week.copy_roll` for
  tests) -> F + Makabe -8 + Ura post; `_exam_results` after the last exam day = ranking board (`st().ranks`).
  Grades in `Game.flags["exam_d<day>_<am|pm>"]` + `st().grades`. Test: `tools/friends_test.gd`.
- Cat night readability (2026-11-08): the cat's sprite tint is brightened (`base_modulate` 1.35/1.3/1.55 = moonlit
  fur), the halo is stronger and sits in front of the cat, the camera is closer and steeper (`configure(40, 12, fov)`),
  facade windows drop to `JPKit.window_scale` 0.15 and the notice board is hidden. Talk close-up also hides bystanders' speech bubbles (`CameraRig._talk_labels`).
