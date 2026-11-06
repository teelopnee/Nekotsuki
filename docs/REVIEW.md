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
