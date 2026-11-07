# Review log

## M0 (2026-11-06)
- Copied the ODD-SPACE engine (code, data, assets, tools, CI) and renamed the project, package id
  (`com.teelopnee.nekotsuki`) and exports.
- `check_project.gd`: 56 scripts, 9 scenes, 0 failures. `smoke_test.gd`: exit 0, no SCRIPT ERROR.
- Open: all game content is still ODD-SPACE sci-fi; replace per GDD section 10, starting with M1 (expressive chibi sprites).

## M1 (2026-11-06): expressive chibi
- sprite_forge: school outfits, 5 hair styles, cat ears/ahoge/choker and other accessories, 9 cast + 10 student variants,
  25 emotion animations with their own faces (eyes x12, brows x5, mouths x12, blush, tears).
- gen_fx: 20 manga emotes. Runtime: `Emotion.express`, `BillboardSprite.emote`, `FX.emote`, NPC reactions show emotions.
- Open: Amane's ears read small at 64 px; skirts are simple cones; emotions are not yet triggered by the story
  (comes with M2/M3); generic sci-fi variants have no emotion animations (they fall back to idle + emote icon).

## M2 (2026-11-06): first day in Suzunari
- New game starts in Suzunari: school (classrooms, pillared corridor, courtyard), shopping street, river, home.
- Clock with periods and lighting (gold morning -> red Omagatoki -> night), day end saves and starts the next morning.
- Amane: meets you at the school gate, trails you, freezes and peeks when you look at him, walks up to talk;
  four choices (kind / flirt / boundary / reject), the reject button shrinks as he cries; tears -> rain + gloom;
  jealousy when he sees you with someone; Rinrin phone (reply / read / mute / block -> doorstep morning).
- Tests: day_test + all inherited tests pass. Screenshots: docs/preview/suzunari_day1.png.
- Open: shop interiors, keeper greetings, NPC small talk and barks are still sci-fi text (M3/M4); combat key hints
  still on screen; buildings are the generic facade kit (no Japanese roofs yet); no real school timetable for NPCs.

## Theme pass (2026-11-06): no more ODD-SPACE in Suzunari
- `tools/suzunari_theme.py`: auto-rewrites ~4,600 inherited strings (510 changed, 265 sci-fi lines dropped) into
  `data/suzunari/*.json` + `data/copy_suzunari_auto.json`; hand-written town text in `data/suzunari/_manual/`
  (barks, shop names and greetings, verb names, jobs, tips, vocabulary, Japanese names).
- Runtime theme switch (DataDB / Copy / CharacterLook / LevelBuilder / Interactions / NPCVoice / HUD / pause menu /
  witness label / title slogans). Money shows as yen (1 credit = 100 yen).
- Shop fronts: tiled eaves, noren curtains, red paper lanterns, romaji blade signs; no neon tubes or wanted posters.
- day_test now fails on sci-fi words in townsfolk talk (0/40 leaks) and off-theme verbs.
- Open: shop option texts are auto-converted (readable but plain); 25 lines kept with sci-fi words where a list had
  nothing else; music is still the synthwave set; title backdrop is still the synthwave sunset.

## M3 first pass (2026-11-06): the town's brain
- Cats (8, named, remembered) spy for Amane; petting wins them over. Weekly rival (Hayate by default) and the nightly
  living-spirit plan with six stages, morning news, clues on the Ura board; warn the rival, watch the rooftops at night
  (chase / call it "Amane" / let it go) or help Amane grow (self >= 55) to stop it. Hayate walks you home.
  Enma's Ledger v1 written every night. Tests: m3_test (19 checks) + all others pass.
- Open: the night watch is a dialogue, not yet a playable cat-spirit level (M5); rumours come from Amane's events,
  not yet from every witnessed act; spirited-away rivals cannot be rescued yet (Dusk Side, M5); music still synthwave.

## M4 first pass (2026-11-06): words and world
- Amane talks by topic with exact words: 17 topics x 5 replies (85 lines you can say), each with its own answer, a
  crying variant for cold words, lore and promises; up to 3 topics per talk, urgent topics first (rival, black cat,
  rain, promise, dreams). The HUD still shrinks cold words as he cries.
- New 56x56 Suzunari with a shrine plaza, the 999 steps, the dog shrine, six Jizo (save points), temple ruins, station,
  sealed tunnel, harbour memorial and beach. Every Japanese landmark can be examined (lore + choices: five-yen prayers,
  ema wishes, purification, guardian cats). 18 lore signs.
- 11 people and yokai with hours and exact-choice scenes (43 choices): Chiyo, Makabe-sensei, Mio, Hina, Hanako-san,
  the kappa Gataro, the tanuki antique dealer, a rokurokubi konbini clerk, a nopperabo at the last bus, the
  kuchisake-onna at the station, Kiku the zashiki-warashi. New yokai sprites (faceless nopperabo, kappa dish).
- Phone Notes tab: remembered lore, promises, people, Hyakki Zukan, places, Easter eggs (13). Ledger stores them.
- Tests: talk_test (60+ checks: every reply and choice plays, no sci-fi leaks, ids defined) + all earlier suites.
- Open: Hayate still has the old 4-choice menu; townsfolk small talk is still the generic Copy grammar; CAST.md says
  Chiyo is Amane's grandmother but calls Sayo her granddaughter (check); interiors (3rd-floor toilet, old building)
  are not walkable yet so Hanako and Mio stand outside; kuchisake chase minigame not built; music still synthwave.

## Visual pass (2026-11-06): a Suzunari that looks alive
- Ground: 20 Poly Haven CC0 photo textures pixelized to 128 px (32 texels/m, quantized palettes) by
  `tools/jp_textures.py`; each town zone has its own ground (white shrine gravel + sando slabs, stone steps, shopping
  paving with a stone centre strip, cracked asphalt with white lines and gutters, grass embankment, sandy schoolyard,
  beach, classroom floorboards, the wooden bridge and pier).
- Buildings: every 'b' block becomes a row of narrow Japanese units (machiya, modern shops, houses, the station, the old
  wooden schoolhouse, the Nekomori house) with kawara gable roofs in five tints, pixel facades (lattice, shop windows,
  shutters, shoji, aluminium sashes, house doors) that light up at dusk, hisashi eaves, balconies with futons and laundry,
  potted plants, noren, red lanterns, nobori banners.
- Shrines: a real haiden (stone base, vermilion pillars, copper-green roof with chigi and katsuogi, shimenawa + shide,
  lanterns) and sculpted guardian cats/dogs; the hill is a cedar/camphor/bamboo forest on a stone wall.
- Nature and life: sakura with fluffy textured crowns (riverside row, courtyard, shrine), fallen petals, drifting petals,
  grass tufts and flowers along every wall, planters, sparrows that scatter, butterflies, kei cars and vans (left-hand
  traffic), fishing boats, utility poles with sagging wires, lantern garlands, classroom desks and blackboards.
- Light: the sun moves (long golden shadows in the morning, red at Omagatoki), haze and colour grade follow the sky,
  windows/lanterns/street lamps come on at dusk; softer lens (less aberration and grain), no litter (Japanese streets).
- Cost: ~3,000 mesh instances + ~200 multimeshes for the whole town, frustum-culled; lights hidden by day.
- Open: interiors are still diorama cut-aways; the station has no railway yet; no birdsong/ambience; foreground sakura
  south of the player can fill the bottom of the frame; check frame time on the tablet (Settings > graphics).

## Octopath pass (2026-11-06): the HD-2D lens
- Research (HD-2D articles, an HD-2D pipeline write-up): the look = depth of field that grows with distance from a sharp
  band, ambient occlusion, soft bloom, vignette, sprites lit by the scene's lights, god rays and floating particles.
- New depth lens (`hd2d_depth.gdshader`): real depth of field around the hero (foreground sakura becomes bokeh, distant
  rooftops melt) + SSAO contact shadows (wall feet, eaves, under cars and characters). Old saves switch to it once.
- Light: stronger key light and darker cool fill (no more flat grey daylight), more contrast and saturation, god rays
  through alleys / shrine trees / the steps / the riverside sakura at dawn and Omagatoki, dust motes in the beams,
  ground mist in the morning.
- Cost: one full-screen pass (12 blur + 11 depth taps per pixel); off on graphics "low". Check on the tablet.
- Open: the lens is skipped by transparent effects on purpose (labels, rain, shafts stay crisp); water has no reflections.
- Known flaky (pre-existing, also on the previous commit): `interact_back_test` "an NPC walked up and started a
  conversation" fails ~1 run in 3 - the approaching NPC sometimes stops at ~1.8 m and returns to idle without opening the
  talk (`NPC` "approach" state, distance threshold vs. stop distance). A longer wait made it fail every time.

## Shadow pass (2026-11-06)
- Why no shadows were visible: the sun shone from behind the camera (shadows fell behind every object), and the
  character cards faced the camera, so from a side sun they cast a thin line.
- Fix: sprites billboard in the vertex shader (they turn to the light in the shadow pass -> full silhouettes), half-Lambert
  wrap lighting; a shadow sun behind the town + a shadowless key light in front; drifting cloud shadows; lamp shadows at
  night; 4096 shadow map; less ground mist; exposure 0.98.
- Open: the shopping street is in building shade most of the day (sunlit only at alley gaps) - intended, but check that
  it does not feel too dark on the tablet.

## Texture pass (2026-11-07): one weathered town, not primitives
- Owner: buildings and shrines looked like plain 3D placed on the ground. Cause: dozens of flat-coloured props
  (torii, pillars, lanterns, statues, poles, awnings, noren, rails) next to photo-textured ground.
- 7 more Poly Haven CC0 textures pixelized (weathered red paint for vermilion, copper patina, chipped paint, granite,
  indigo cloth, sheet metal, dark lacquer); every prop key maps to one; flat colours become tinted chipped paint; one shared
  grime layer (soft dirt + rain streaks) on walls, roofs and props; fascia, gutters and downpipes on roofs; leafy cedars.
- Open: shrine gravel still reads a little flat in strong morning light.

## Detail pass (2026-11-07): "it still looks the same"
- Why the texture pass barely showed: the depth lens blurred everything above the shop fronts, the photo textures went
  muddy when shrunk, and the streets were big empty floors with boxes on them.
- Fixes: gentler background blur; textures re-baked as pixel art (bevel light + cavity outlines from normal maps);
  timber frames, storey slabs, window frames; dense street-level clutter in front of every house and shop; shrine
  lanterns rows, omikuji rack, sake barrels, tamagaki, banners; tactile paving, drain grates, kerbs, asphalt patches,
  manholes; roof trims now hide with the house when it is cut away (they floated as a bar across the frame).
- Open: morning light on the shrine gravel is still bright; consider per-time exposure.

## Enter buildings: Suzunari Gakuen (2026-11-07)
- Researched room types (Japanese school facility guides; Yandere Simulator only as a list of room kinds). The layout,
  names and contents are our own and tied to our lore (seven mysteries, Makabe's letters, Tanabata, past lives).
- Four floors, 24 rooms with name plates and fluorescent light pools, 24 room features (60+ exact-word choices), staff
  and cast at work (Makabe, Fujimura-sensei, Tomi-san, Reiji, Hanako), students in classrooms, Amane follows you in.
  New textures: linoleum, terrazzo, toilet tiles, wall tiles, tatami, planks (Poly Haven CC0) + pixel blackboard, cork,
  lockers, shoe cubbies, bookshelves and window views.
- Open: rooms are one floor per load (a short fade on stairs); no gym, pool or old-building interior yet; students do
  not follow a timetable between rooms yet; the classroom seat does not run a real lesson minigame.
- Life pass (owner: "it looks bland"): students fill rooms by period and sit at desks/tables by themselves; posters,
  class motto, clock, timetable, paper cranes, bags and books on desks; window sun beams with dust; waxed floors; a lower
  indoor camera so the back wall is part of the picture. Open: some light-haired sprites bloom under room lights; the
  roof at lunch could use more groups; students still don't change rooms on their own between periods.
- Fixes: light-haired sprites no longer bloom indoors (glow threshold); the roof at lunch is full (picnic sheets, seats
  filled near you); the bell moves students between rooms along door/corridor routes and brings new ones up the stairs.
  Open: students walk straight between waypoints and can brush through each other; a stuck walker is nudged after 3 s.

## Homes, pick-ups and walking people home (2026-11-07)
- Five houses (one new: Inukai house behind the dog shrine, one new: Kuroe house by the old temple stones, the
  Shirasagi residence as its own building with a roofed gate and a cracked giant maneki-neko); door, nameplate, bell.
- Schedules are learned, not shown: ask when close (35), buy from Sato Yui (new, 2-B, runs the Ura board in secret),
  or trade Mio ghost stories. Ring or wait; parents answer with their own voices (Inukai Takeshi, Hayase Natsuko / Ken,
  Kuroe Setsu, Sawada-san / Shirasagi Kyoko, Nekomori Chiyo). Walk to school, walk them home, they walk you home, they
  pick you up. Amane reacts by route. 287 lines each for Hayate/Hina/Mio/Reiji, 400 for Amane (incl. jealousy).
- Hayate no longer trails you after school by default: he walks over and asks (closeness >= 20), as his nature says.
- Tests: people_test 77 checks; all suites pass. Open: companions steer straight (they pop behind you if stuck); the
  houses are not enterable inside yet (doorstep scenes only); no weekend visits beyond the parents' lines.

## Hard review (2026-11-07, at fc015f8): "is it a game yet?"
Owner asked for a harsh review against interviews and reviews of similar games (Persona, Majora's Mask, Shenmue,
Yandere Simulator, Octopath Traveler / HD-2D, Boyfriend Dungeon, DDLC, Spirittea). Checked: GDD, this log, code and data
samples, 6 test suites (check_project 75 scripts 0 failures, day/people/talk/m3/school tests pass, no SCRIPT ERROR) and
the latest screenshots in docs/preview.
- Score (playable game today): **4/10**. Potential of the idea: ~8.
  Concept/world 8.5 · Amane's writing 7 · daily-life systems 5 · visuals 6 · UI 3 · sound 2 · can be finished 0-1.
- 1. No game to finish: M5-M7 not started (13-week story, endings, cat-spirit night, Ura-Suzunari); `saga.gd` and the
  smoke test are still the sci-fi flow. 20+ systems in 17 commits over two days while the GDD already plans episode 8.
  Same trap as Yandere Simulator (Vice: a "debug sandbox"); Majora's Mask cut 7 days to 3 to ship in a year.
- 2. Time has no cost: 1 real s = 1 game min (a day is ~14.5 real min), a lesson is 50 s with nothing to do, you can
  wander mid-class with no consequence (no lateness/truancy logic). Persona's calendar is built to create pressure.
- 3. Dialogue gives itself away by position: the cold reply is last in 17/17 topics, flirt is 3rd in 15/17, and button
  size follows the tone, so players pick by slot, not words. Topics reset daily (`topics_today`): 17 topics with 1-2
  answers each repeat from day 3 of a 91-day game.
- 4. The shrinking reject button / locked boundary while he cries is the strongest mechanic, but there is no content
  warning anywhere in src/ or data/ (Boyfriend Dungeon had to apologise and rewrite its stalking warning).
- 5. Five visual passes in a row on backgrounds while characters stay unreadable: tiny in frame, Toru always seen from
  behind, the 25 emote faces (M1 pillar) invisible at play distance, foreground sakura still covers ~1/3 of the town shot,
  name labels overlap ("Tanaka Mei Suzuki Mei <FRIENDLY><FRIENDLY>"). HD-2D's hard part is the sprites, not the sets.
- 6. UI and sound are still ODD-SPACE: terminal font, magenta ticker, HP 120/120, "SPACE dodge"/ROLL in a town with no
  enemies, <FRIENDLY> tags on strangers; Suzunari music is `crystal_lull` (synthwave), flagged 4 times above, never fixed.
- 7. Sci-fi leaks in `data/suzunari/barks.json` ("Uploading your face to the ad network", "Low gravity, high rent",
  "SCANNING... COLLATERAL DETECTED"; the `combat` key is still read by `npc.gd`); the leak check samples only 40 lines.
  Townsfolk are grammar filler (+ pickpocket/threaten/insult verbs) next to five people with real schedules.
- 8. Engine debt: 24k lines of GDScript, the biggest files inherited (level_builder, npc, saga); no pass in this log had
  a score until now; Open items pile up.
- Best parts: rain = tears (weather as a character's feelings, seen by the whole town); learned schedules where people
  come out of their door on their minute (Majora's notebook / Shenmue DNA); the boundary route with its own good ending;
  Amane's voice.
- Priority: (1) no new systems or visual passes until week 1 can be played to an end (7 days + week close + hook);
  (2) give time a cost (skip lessons with one event, limited after-school slots, lateness/truancy consequences);
  (3) shuffle replies, hide tone, once-only topic beats, "you asked yesterday" lines; (4) talk close-up camera, Toru's
  face, fade foreground sakura; (5) three music tracks (morning / Omagatoki / rainy night), a Suzunari HUD, a content
  warning; (6) purge sci-fi data and check every line; (7) time the first 10 minutes on the tablet and note where it drags.

## Fix pass for the hard review (2026-11-07)
Worked through the priority list in order; no new world systems or visual passes on the sets.
- (1) Week 1 can be played to an end: `Week` autoload + `data/week1.json` - an objective and authored beats every day
  (Haruka's table, the pillow-turner, Amane's bento, Chiyo's "don't leave that child", Saturday at the dog shrine, Sunday
  at Omagatoki "What am I to you?" = the first route choice (finds you anyway if you miss it), Makabe's staff room, the
  day-7 midnight message), then a week-close summary (school, Amane, closest people, mornings, promises, lore) and the
  week-2 hook (the two-tailed cat on the rival's roof, the first Ura thread).
- (2) Time has a cost: a lesson block is one event (attend / doze / window / pass Hayate a note) and the clock jumps to
  lunch or 15:20; after 8:30 you're late; in town 15 minutes into a block you're absent (Makabe, the Ura board and Amane
  notice); three lates / two absences reach Haruka at night. Talks cost time (Town 10 min, Amane 5 per topic, Hayate 10).
- (3) Dialogue no longer gives itself away: reply order is shuffled per day, only cold words shrink and only while he
  cries; nine story topics are asked once per life, everyday ones rest 3 days and he notices ("You asked me that
  yesterday").
- (4) Readable characters: talk close-up (lens moves in on the pair, lower pitch, name tags hidden), Toru turns to the
  person he talks to and never shows his back in a conversation; foreground sakura/pines between the lens and the hero
  fade; townsfolk names only within reach, no <FRIENDLY> tags on strangers. Content notice before NEW GAME.
- (5) Three original tracks (`tools/gen_music_suzunari.py`: morning yo-scale koto, Omagatoki miyako-bushi shakuhachi +
  temple bell, rainy-night piano lullaby) chosen by time of day and by Amane's tears; title music too. UI theme
  `washi_theme.tres` (indigo + gold, sans font) replaces the cyan/magenta terminal look; no HP / OVERCLOCK / ROLL /
  MELEE / FIRE in town; ticker is a dark-wood notice board; hints without "dodge".
- (6) Sci-fi purge: theme script drops whole ODD-SPACE bark families (taunts, planets, crew, station) and rewrites the
  last 57 leaks; `python3 tools/leak_check.py` checks EVERY line of 19 data files (0 leaks).
- Tests: week_test (28 checks) + all suites pass.
- Open: (7) time the first 10 minutes on the tablet (owner); weeks 2-13 are not authored yet; townsfolk are still grammar
  filler with pickpocket/threaten verbs; Toru still walks with his back to the lens (that's the camera, by design);
  engine debt unchanged. Score now (my estimate): 5/10 as a playable game - week 1 has a start, a middle and an end.

## Story pass: weeks 2-13 and the endings (2026-11-07)
- Episode 0 now runs from 8 April to Tanabata (91 days): 13 week files, 96 beats, 277 exact-word choices, 12 Friday
  dreams with Grandpa Genzo (his last on week 11) plus Rin's dream on week 13, Golden Week holidays, midterms and finals
  graded by attendance, a summary + hook at the end of every week, and the last night on the 999 steps with 8 choices
  (some gated by route / flags) -> 13 written endings + the "family" epilogue, recorded in Enma's Ledger.
- Follows LORE/CAST: 1868 promise, the hundred letters and Letter 101, Tabaruzaka, 1890 "tadaima", Sayo on the riverbed
  since 2011, Makoto and the cat in 2001, Makabe's unsent letters, Kyoko's 13th-night ritual and "return the god to the
  shrine", the Inukai seal, Mio's six Jizo, Hina's 2016 photo, Reiji's father.
- Tests: week_test 40 checks (plays every non-final choice of every week; maps every final choice to a written ending;
  plays one ending through to the end card). leak_check 0 over 32 files.
- Open: beats are scenes (no Ura-Suzunari level, no fights - the relay and the hill are text); a few beats need the
  player at the right place and time with no map marker; weekend days can feel empty without a beat; nothing yet for
  people you never befriended (some beats only appear with closeness); the endings don't yet change the title screen.

## Fixing the story pass's open items (2026-11-07)
- Ura-Suzunari is a place now, not a paragraph: red endless dusk, rain falling up, shadow townsfolk, five echoes of
  1868/1890/1945/2011/2016, wild kasha to fight (umbrella / salt), Rin as a floating bell, Sayo on the riverbed with a
  Kasha Matriarch, the two-bell rule (stay too long and a day is gone, with one memory), free entry at dusk after you've
  met Rin. Weeks 6 and 11 walk you in.
- Places have markers: a paper lantern over the next story place and "(NE 85 m)" on the objective line.
- Weekends and holidays are never empty: Aunt Haruka's day menu (5 activities, each costs hours).
- Missed beats carry over one day; seven fallback beats for days that used to need closeness with someone; Tanabata
  can't be slept through; the title screen lists endings reached on this device.
- Fixes found on the way: weapon names are Japanese in Suzunari (Umbrella, Salt Throw...), the O2/bounty line no longer
  shows in town, kasha have no sci-fi shield pips.
- Tests: ura_test 28 checks, week_test still plays every choice.
- Open: the relay and the hill on the 13th are still scenes; kasha use the cat sprite (no attack/hurt frames yet);
  Ura has no unique map of its own (it is Suzunari re-lit); no Ura-only music.

## Finishing the open items (2026-11-07)
- The relay (week 7) and the hill on the 13th (week 10) are now runs: catch the two-tailed cat before it reaches the
  rival, reach the lantern on the hill before the third nail. Fail and the other outcome plays.
- Kasha have their own sprite: a big two-tailed cat with flame-tipped tails, pounce / charge / hurt / down frames.
- Ura-Suzunari looks like the other side: dry riverbed with children's stone towers, festival stalls, red lanterns in
  the air, torii across the road, the station sign reads KISARAGI, and its own music (slow taiko, a slightly flat flute,
  bells played backwards).
- Enemy shield pips / "??" readouts hidden in Suzunari.
- Tests: ura_test 30 checks (incl. both race outcomes).
- Open: Ura still uses the Suzunari map underneath (lore says it IS the same town); the race cat is a sprite, not an
  enemy you can hit; no gamepad rumble or sound cue for the countdown.

## Countdown feel (2026-11-07)
- Races now sound and feel like a countdown: a taiko hit + clap at the start, a hyoshigi (wooden clapper) tick every
  second, a faster double clap with a stronger pulse in the last three, a temple bell (win) or a low drum (loss).
  Gamepads rumble with each tick; on the tablet with no pad the device itself buzzes. Ura's bells ring and rumble too.
- New setting: Vibration on/off (old saves keep vibrating). ura_test 34 checks (cue order, sounds, setting).

## Toru's life (2026-11-07): the four missing GDD systems
- NEW GAME creator (GDD 4.1): given name + 28 tags in 5 categories (`data/toru.json`), each one says what it does and
  really does it (money, debt, stats, Amane's tears/words, cats, ghosts, Saki's Sunday call, club/job bonuses, goal
  epilogue on the end card). Gamepad/touch friendly, RANDOM button.
- Stats + quirks + clubs + jobs (GDD 4.13): `Toru` autoload, 6 stats with real effects (exams, closeness speed, Ura
  bell, race speed, fish-market interview, teachers forgetting you), 6 quirks earned at night, 8 clubs at their own
  places (school rooms, schoolyard, budokan, gate) + recruitment board, 5 jobs with interviews, shifts, pay and events;
  weekend menu offers shifts. 23 club/job events written.
- Cat spirit night (GDD 4.11): play Amane's two-tailed cat on jealous nights - the sleeping town, the rival's window
  (plan / resist), Senpai's window, four secrets, four things to knock over, roof leaps, dawn; outcomes drive
  `Amane.plan` and the next morning.
- Enma's Ledger page (GDD 4.14): Dosho and Domyo brush in up to ~15 entries, argue each one and stamp it; the Johari
  mirror shows real frames captured at key moments; totals; `ledger.json` now also stores origin, stats, club, jobs,
  quirks, deeds and cat nights.
- Tests: new `life_test.gd` (60+ checks); all suites pass. Screenshots: docs/preview/life_*.png.
- Open: the cat leaps between fixed rooftop points rather than walking freely on roofs/walls, and there's no sneaking;
  companions (2 friends who follow you around) and exam cramming/cheating are not in yet; the scribes' "handwriting"
  is the UI font slanted, not a brush font.
