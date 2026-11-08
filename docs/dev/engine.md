# Engine notes (inherited from ODD-SPACE)

Moved out of `CLAUDE.md`. Everything below still describes the inherited code, which keeps its sci-fi names (planets, Consortium, Paragon, crew...).
Rename and rewrite these notes as systems are replaced (GDD section 10). `docs/REVIEW.md` is this repo's critique log.

### Layout
- `src/autoload/` singletons (order matters, see `project.godot`): `EventBus`, `DataDB`, `Game`,
  `Factions`, `Causality`, `Origin`, `Crew`, `FlawPerk`, `Encounters`, `Saga`, `Stories`, `Interactions`, `ShipAI`, `Audio`, `Router`
  (NEKOTSUKI adds `Clock`, `Amane`, `Cats`, `Ledger`, `Town`, `People`, `Week`, `Toru`, `Party` before `ShipAI`).
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

- Flaws & perks are ODD-SPACE only: `FlawPerkSystem.report_mishap` returns at once in Suzunari (no "MISHAP PATTERN
  DETECTED / the universe offers you a deal" modal; the pause menu has no Perks tab there). `interact_back_test` closes
  unrelated modals while it waits for the walk-over and polls on the NPC's own timer (it was flaky ~1 in 6: the flaw
  offer after the theft verbs paused the tree).
