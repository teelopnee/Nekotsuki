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
