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
