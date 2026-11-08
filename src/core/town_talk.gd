class_name TownTalk
extends RefCounted
## What Suzunari's townsfolk say (data/town_talk.json), in the style of Valve's dynamic dialogue (Elan Ruskin, GDC 2012,
## "AI-driven Dynamic Dialog through Fuzzy Pattern Matching"): every rule is a set of criteria over facts about the
## world, the speaker and Toru; of the rules that match, the one with MOST criteria wins (specific beats general),
## ties are random; a line that was said is remembered (Game.flags.town_talk) and rests for `cool` days (`once` =
## never again), so the town stops repeating itself. Generic rules with no criteria are the fallback.
## Concepts: open, recall (what this person saw you do: fact kind), gossip (what the street says: kind), accuse
## (a known crime), remark, rumour, mutter (a speech bubble as you pass), farewell, headline (news ticker: verb).
## Criteria keys (all must hold): period, weekday, weekend, week_min, week_max, days_left_max, rain, place, job, temper,
## mood, kind, club, has_club, has_job, late_min, truant_min, study_min, route, flag, no_flag, rival, rival_fate,
## tag, met, lore_min, deed, amane_seen, verb. Lists mean "any of". Text: {npc} {player} {rival} {rival_short}
## {club} {days_left} {weekday} {place} {target} {location}.

const PATH := "res://data/town_talk.json"
const TEMPERS := ["chatty", "grumpy", "gentle", "nosy"]
static var _data: Dictionary = {}
static var _rng := RandomNumberGenerator.new()


static func data() -> Dictionary:
	if _data.is_empty() and FileAccess.file_exists(PATH):
		var d = JSON.parse_string(FileAccess.get_file_as_string(PATH))
		if d is Dictionary:
			_data = d
			_rng.randomize()
	return _data


static func active() -> bool:
	return DataDB.theme == "suzunari" and not data().is_empty()


static func mem() -> Dictionary:
	if not Game.flags.has("town_talk"):
		Game.flags["town_talk"] = {"said": {}, "met": {}}
	return Game.flags["town_talk"]


## Facts about the moment, the speaker and Toru. Cheap: built once per line.
static func facts(npc: Node = null, extra: Dictionary = {}) -> Dictionary:
	var f := {}
	f["period"] = Clock.period()
	f["weekday"] = Clock.weekday()
	f["weekend"] = Clock.is_weekend() or bool(Week.day_data().get("holiday", false))
	f["week"] = Week.week_no()
	f["days_left"] = maxi(0, 91 - Clock.day())
	var tl := Amane.tears_level()
	f["rain"] = "storm" if tl >= 4 else ("rain" if tl >= 2 else "dry")
	f["route"] = Amane.route()
	var rv := Amane.rival()
	f["rival"] = rv != ""
	f["rival_name"] = rv
	f["rival_fate"] = Amane.fate(rv) if rv != "" else ""
	f["club"] = Toru.club()
	f["has_club"] = Toru.club() != ""
	f["has_job"] = not (Toru.st().get("jobs", {}) as Dictionary).is_empty()
	var ws: Dictionary = Week.st()
	f["late"] = int(ws.get("late", 0))
	f["truant"] = int(ws.get("truant", 0))
	f["study"] = int(ws.get("study", 0))
	f["lore"] = (Amane.st()["lore"] as Dictionary).size()
	f["tags"] = (Toru.st().get("origin", {}) as Dictionary).values()
	var deeds := {}
	for d in Game.flags.get("deeds", []):
		deeds[str(d.get("kind", ""))] = true
	f["deeds"] = deeds
	f["amane_seen"] = bool(Amane.st()["met"]) and float(Amane.st()["bond_now"]) >= 15.0  # the town has seen him follow you
	f["place"] = _place()
	var a := Amane.st()
	f["tears"] = Amane.tears_level()
	f["bond"] = float(a["bond_now"])
	f["self"] = float(a["self"])
	var jmax := 0
	for who in a["jealousy"]:
		jmax = maxi(jmax, int(a["jealousy"][who]))
	f["jealousy"] = jmax
	f["cat_nights"] = (Game.flags.get("cat_night_log", []) as Array).size()
	f["promise_steps"] = (a["promises"] as Array).has("tanabata_steps")
	if npc != null:
		var nm := str(npc.get("npc_name"))
		f["npc"] = nm
		f["job"] = _job(str(npc.get("job")), nm)
		f["temper"] = TEMPERS[absi(hash(nm)) % TEMPERS.size()]
		var att := int(npc.get("attitude")) if npc.get("attitude") != null else 0
		f["mood"] = "warm" if att >= 15 else ("cold" if att <= -15 else "neutral")
		f["met"] = int(mem()["met"].get(nm, 0)) > 0
	f.merge(extra, true)
	return f


static func _job(job: String, nm: String) -> String:
	var j := (job + " " + nm).to_lower()
	for pair in [["student", "student"], ["teacher", "teacher"], ["sensei", "teacher"], ["fish", "fisher"], ["boat", "fisher"],
			["granny", "elder"], ["old man", "elder"], ["grandpa", "elder"], ["retired", "elder"], ["owner", "shop"],
			["master", "shop"], ["clerk", "shop"], ["shop", "shop"], ["cook", "shop"], ["baker", "shop"], ["monk", "shrine"],
			["priest", "shrine"], ["miko", "shrine"], ["driver", "worker"], ["office", "worker"], ["salary", "worker"]]:
		if j.contains(pair[0]):
			return pair[1]
	return "local"


static func _place() -> String:
	var tree := Engine.get_main_loop() as SceneTree
	var lvl: Node = tree.get_first_node_in_group("level") if tree else null
	if lvl == null or str(Game.location_id) == "school":
		return "school"
	var p = lvl.get("player")
	var b = lvl.get("builder")
	if p == null or b == null:
		return "town"
	var x := int(p.global_position.x / LevelBuilder.TILE)
	var z := int(p.global_position.z / LevelBuilder.TILE)
	if z <= 10:
		return "shrine"
	if z <= 31:
		return "school"
	if z >= 50:
		return "beach"
	if z >= 43:
		return "river"
	if x <= 12 and z >= 34 and z <= 40:
		return "station"
	return "street"


static func _ok(when: Dictionary, f: Dictionary) -> bool:
	for k in when:
		var v = when[k]
		match k:
			"week_min":
				if int(f.week) < int(v): return false
			"week_max":
				if int(f.week) > int(v): return false
			"days_left_max":
				if int(f.days_left) > int(v): return false
			"late_min":
				if int(f.late) < int(v): return false
			"truant_min":
				if int(f.truant) < int(v): return false
			"study_min":
				if int(f.study) < int(v): return false
			"lore_min":
				if int(f.lore) < int(v): return false
			"flag":
				for fl in (v if v is Array else [v]):
					if not bool(Game.flags.get(str(fl), false)): return false
			"no_flag":
				for fl in (v if v is Array else [v]):
					if bool(Game.flags.get(str(fl), false)): return false
			"tag":
				var any := false
				for t in (v if v is Array else [v]):
					if (f.tags as Array).has(str(t)): any = true
				if not any: return false
			"deed":
				if not (f.deeds as Dictionary).has(str(v)): return false
			"rival_fate":
				if not (v if v is Array else [v]).has(str(f.rival_fate)): return false
			_:
				if (k.ends_with("_min") or k.ends_with("_max")) and f.has(k.substr(0, k.length() - 4)):
					var num := float(f[k.substr(0, k.length() - 4)])
					if k.ends_with("_min") and num < float(v): return false
					if k.ends_with("_max") and num > float(v): return false
					continue
				if not f.has(k):
					return false
				var have = f[k]
				if v is Array:
					if not (v as Array).has(have): return false
				elif typeof(v) == TYPE_BOOL or typeof(have) == TYPE_BOOL:
					if bool(have) != bool(v): return false
				elif str(have) != str(v):
					return false
	return true


## Same matcher over another rule list (Amane's openers, data/amane_openers.json): concept "" = every rule.
static func line_in(rules: Array, concept: String, npc: Node = null, extra: Dictionary = {}) -> String:
	var keep := _data
	_data = {"rules": rules}
	var f := facts(npc, extra)
	var pick := _choose(concept, f, true)
	if pick == "":
		pick = _choose(concept, f, false)
	_data = keep
	if pick == "":
		return ""
	mem()["said"][str(hash(pick))] = Clock.day()
	return fill(pick, f)


## The best line for a concept, or "" (callers fall back to their old source). When every matching line is resting,
## the one said longest ago comes back rather than nothing (the old ODD-SPACE pools must never answer in Suzunari).
static func line(concept: String, npc: Node = null, extra: Dictionary = {}) -> String:
	if not active():
		return ""
	var f := facts(npc, extra)
	var pick := _choose(concept, f, true)
	if pick == "":
		pick = _choose(concept, f, false)
	if pick == "":
		return ""
	mem()["said"][str(hash(pick))] = Clock.day()
	if npc != null:
		var nm := str(npc.get("npc_name"))
		mem()["met"][nm] = int(mem()["met"].get(nm, 0)) + 1
	return fill(pick, f)


static func _choose(concept: String, f: Dictionary, rested: bool) -> String:
	var day := Clock.day()
	var said: Dictionary = mem()["said"]
	var best := -1
	var pool: Array = []
	for r in data().get("rules", []):
		if concept != "" and str(r.get("c", "")) != concept:
			continue
		var when: Dictionary = r.get("when", {})
		if not _ok(when, f):
			continue
		var free: Array = []
		for t in r.get("t", []):
			var key := str(hash(str(t)))
			if said.has(key):
				if bool(r.get("once", false)):
					continue
				if rested and day - int(said[key]) < int(r.get("cool", 4)):
					continue
			free.append(t)
		if free.is_empty():
			continue
		var score := when.size() if rested else 0  # second pass: any matching line, oldest first
		if score > best:
			best = score
			pool = []
		if score == best:
			for t in free:
				pool.append(t)
	if pool.is_empty():
		return ""
	if not rested:  # everything is resting: the line said longest ago
		pool.sort_custom(func(a, b): return int(said.get(str(hash(str(a))), -999)) < int(said.get(str(hash(str(b))), -999)))
		return str(pool[0])
	return str(pool[_rng.randi() % pool.size()])


static func fill(t: String, f: Dictionary) -> String:
	var rv := str(f.get("rival_name", ""))
	var club_name := str(Toru.club_data(str(f.get("club", ""))).get("name", "a club")) if str(f.get("club", "")) != "" else "no club"
	var out := t.replace("{player}", Game.player_name).replace("{npc}", str(f.get("npc", "")))
	out = out.replace("{rival}", rv if rv != "" else "that boy").replace("{rival_short}", rv.split(" ")[-1] if rv != "" else "him")
	out = out.replace("{club}", club_name).replace("{days_left}", str(f.get("days_left", 0))).replace("{weekday}", str(f.get("weekday", "")))
	out = out.replace("{place}", str(f.get("place", ""))).replace("{target}", str(f.get("target", "someone")))
	out = out.replace("{location}", "Suzunari")
	return out


## The first thing a townsperson says: what they saw you do, what they heard, or a greeting that fits the moment.
static func open(npc: Node) -> String:
	var mems: Array = npc.get("memories") if npc.get("memories") != null else []
	if not mems.is_empty():
		var l := line("recall", npc, {"kind": str(mems[0].get("kind", ""))})
		if l != "":
			return l
	var street := NPCVoice.street_memory()
	if not street.is_empty() and _rng.randf() < 0.35:
		var kinds := street.keys()
		var l2 := line("gossip", npc, {"kind": str(kinds[_rng.randi() % kinds.size()])})
		if l2 != "":
			return l2
	return line("open", npc)
