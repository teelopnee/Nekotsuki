extends Node
## Asagiri Toru himself (docs/GDD.md 4.1 + 4.13). The origin picked on the NEW GAME screen (5 tag categories in
## data/toru.json, src/ui/toru_creator.gd), six stats (study, stamina, charm, courage, agility + transparency),
## quirks earned by how you live, one club and any number of part-time jobs (data/clubs.json). Clubs and jobs are
## places (`where`) open at their hours: a session is a menu, the clock jumps to its end, stats / money / closeness
## change. State in Game.flags["toru"] (saved with the game).

signal changed

const STATS := ["study", "stamina", "charm", "courage", "agility", "transparency"]
const DEFAULTS := {"origin": {}, "stats": {}, "club": "", "club_log": {}, "sessions": {}, "events": {}, "skips": 0,
	"jobs": {}, "worked": {}, "earned": 0, "pets": 0, "quirks": {}, "notes": [], "tokyo_week": -1, "debt_paid": 0}
const WEEKDAYS := ["Mon", "Tue", "Wed", "Thu", "Fri"]

var data := {}
var clubs := {}
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	data = _load("res://data/toru.json")
	clubs = _load("res://data/clubs.json")
	_rng.randomize()


func _load(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed if parsed is Dictionary else {}


func st() -> Dictionary:
	if not (Game.flags.get("toru") is Dictionary):
		Game.flags["toru"] = {}
	var s: Dictionary = Game.flags["toru"]
	for k in DEFAULTS:
		if not s.has(k):
			var d = DEFAULTS[k]
			s[k] = d.duplicate(true) if (d is Dictionary or d is Array) else d
	var stt: Dictionary = s["stats"]
	for k in STATS:
		if not stt.has(k):
			stt[k] = int(data.get("start", {}).get(k, 20))
	return s


# --- Origin (NEW GAME) ----------------------------------------------------------------------

func categories() -> Array:
	return data.get("categories", [])


func option(cat: String, id: String) -> Dictionary:
	for c in categories():
		if str(c.id) == cat:
			for o in c.get("options", []):
				if str(o.id) == id:
					return o
	return {}


func tag(cat: String) -> String:
	return str(st()["origin"].get(cat, ""))


func has_tag(id: String) -> bool:
	return (st()["origin"] as Dictionary).values().has(id)


func random_origin(rng: RandomNumberGenerator = null) -> Dictionary:
	var r := rng if rng else _rng
	var out := {}
	for c in categories():
		var opts: Array = c.get("options", [])
		if not opts.is_empty():
			out[str(c.id)] = str(opts[r.randi() % opts.size()].id)
	return out


## Apply the picked tags once, right after Game.new_game (Router.new_suzunari). Empty = canon Toru.
func apply_origin(tags: Dictionary) -> void:
	var s := st()
	s["origin"] = tags.duplicate()
	for cat in tags:
		var fx: Dictionary = option(str(cat), str(tags[cat])).get("fx", {})
		for k in fx.get("stats", {}):
			add(str(k), float(fx["stats"][k]), false)
		if fx.has("money_set"):
			Game.credits = int(fx["money_set"])
		if fx.has("money"):
			Game.credits += int(fx["money"])
		for f in fx.get("flags", []):
			Game.flags[str(f)] = true
		for k in fx.get("amane", {}):
			Amane.add(str(k), float(fx["amane"][k]))
		if fx.has("lore"):
			Amane.st()["lore"][str(fx["lore"])] = true
	check_quirks()
	changed.emit()


## Product of a multiplier dict over every picked tag: fx[key][sub] (or fx[key]["*"]).
func mult(key: String, sub: String) -> float:
	var v := 1.0
	for cat in st()["origin"]:
		var d = option(str(cat), str(st()["origin"][cat])).get("fx", {}).get(key)
		if d is Dictionary:
			v *= float(d.get(sub, 1.0)) * float(d.get("*", 1.0))
	return v


## A plain fx value of the first tag that has it (tears_mult, calm, ghosts_early, jumpy, sneeze...).
func fx_num(key: String, default: float = 0.0) -> float:
	for cat in st()["origin"]:
		var fx: Dictionary = option(str(cat), str(st()["origin"][cat])).get("fx", {})
		if fx.has(key):
			return float(fx[key])
	return default


func tears_mult() -> float:
	return maxf(fx_num("tears_mult", 1.0), 1.5 if quirk("soft_heart") else 1.0)


func tone_mult(tone: String) -> float:
	return mult("tones", tone)


func calm() -> float:
	return fx_num("calm", 1.0)


func jumpy() -> bool:
	return fx_num("jumpy", 0.0) > 0.0


func sneezes() -> bool:
	return fx_num("sneeze", 0.0) > 0.0


func cats_mult() -> float:
	return fx_num("cats_mult", 1.0)


## Minutes earlier the night spirits show themselves to you.
func ghosts_early() -> int:
	var early := int(fx_num("ghosts_early", 0.0)) + (60 if quirk("third_eye") and fx_num("ghosts_early", 0.0) <= 0.0 else 0)
	return maxi(early, 60) if Party.has("mio") else early  # Mio's curiosity


## Extra seconds before Ura-Suzunari's bell finds you (courage, quirks).
func bell_bonus() -> float:
	return stat("courage") * 0.6 + (30.0 if quirk("escapist") else 0.0) + (20.0 if quirk("third_eye") else 0.0)


## How fast people warm up to you (charm; being see-through slows it down).
func close_mult() -> float:
	return (1.0 + stat("charm") / 200.0) * (0.75 if quirk("see_through") else 1.0) * (1.25 if Party.has("hina") else 1.0)


func race_speed() -> float:
	return 1.0 + stat("agility") / 400.0


# --- Stats ------------------------------------------------------------------------------------

func stat(id: String) -> int:
	return int(st()["stats"].get(id, 0))


func stat_name(id: String) -> String:
	return str(data.get("stat_names", {}).get(id, id.capitalize()))


func gain(id: String) -> float:
	return mult("gain", id)


## Change a stat -> "> Courage +3 (41)" (or "" if nothing changed). Gains go through the origin's gain multipliers.
func add(id: String, v: float, use_gain: bool = true) -> String:
	if not id in STATS:
		return ""
	if use_gain and v > 0.0:
		v *= gain(id)
	var before := stat(id)
	var after := clampi(before + roundi(v), 0, 100)
	if after == before:
		return ""
	st()["stats"][id] = after
	changed.emit()
	return "> %s %+d (%d)" % [stat_name(id), after - before, after]


func add_stats(d: Dictionary, scale: float = 1.0) -> String:
	var out: Array[String] = []
	for k in d:
		var l := add(str(k), float(d[k]) * (scale if float(d[k]) > 0.0 else 1.0))
		if l != "":
			out.append(l)
	return "\n".join(out)


# --- Quirks (癖) ----------------------------------------------------------------------------

func quirk(id: String) -> bool:
	return st()["quirks"].has(id)


## Earn quirks from how you've lived (called every night and after the origin) -> lines for new ones.
func check_quirks() -> Array[String]:
	var s := st()
	var got: Array[String] = []
	var want := {
		"soft_heart": tag("personality") == "soft_hearted",
		"escapist": stat("agility") >= 60,
		"cat_servant": int(s["pets"]) >= 15,
		"see_through": stat("transparency") >= 80,
		"third_eye": (Amane.st()["lore"] as Dictionary).size() >= 12,
		"promise_breaker": (People.st()["broken"] as Dictionary).size() >= 3}
	for id in want:
		if want[id] and not quirk(id):
			s["quirks"][id] = Clock.day()
			var q: Dictionary = data.get("quirks", {}).get(id, {})
			got.append("> New quirk: %s - %s" % [str(q.get("name", id)), str(q.get("desc", ""))])
	return got


func on_pet() -> void:
	st()["pets"] = int(st()["pets"]) + 1


# --- Clubs -------------------------------------------------------------------------------------

func club() -> String:
	return str(st()["club"])


func club_data(id: String) -> Dictionary:
	return clubs.get("clubs", {}).get(id, {})


func meets_today(id: String) -> bool:
	return Clock.weekday() in club_data(id).get("days", []) and not bool(Week.day_data().get("holiday", false))


func club_open(id: String, minute: int = -1) -> bool:
	var m := Clock.minute() if minute < 0 else minute
	var c := club_data(id)
	return meets_today(id) and m >= int(c.get("open", 930)) and m < int(c.get("close", 1050))


func schedule_text(c: Dictionary) -> String:
	return "%s, %s-%s" % ["/".join(c.get("days", [])), Clock.time_text(int(c.get("open", 930))), Clock.time_text(int(c.get("close", 1050)))]


func join(id: String) -> String:
	var s := st()
	var c := club_data(id)
	var old := club()
	s["club"] = id
	s["skips"] = 0
	changed.emit()
	var out := "> You joined the %s (%s)." % [str(c.get("name", id)), schedule_text(c)]
	if old != "" and old != id:
		out = "> You left the %s.\n" % str(club_data(old).get("name", old)) + out
	return out


## Use a club's place: join it, or practise when it meets (one session a day).
func use_club(id: String, hud) -> void:
	if hud == null:
		return
	var c := club_data(id)
	var name := str(c.get("name", id))
	var s := st()
	if club() != id:
		var menu := [{"id": "join", "text": ("Leave the %s and join." % str(club_data(club()).get("name", ""))) if club() != "" else "Join the club."},
			{"id": "no", "text": "\"Maybe later.\""}]
		var pick: String = await hud.say(name, "%s\n\n(%s · %s)" % [Amane.fill(str(c.get("pitch", ""))), schedule_text(c),
			stat_name(str(c.get("stat", "")))], menu)
		if pick == "join":
			var out := join(id)
			if Amane.st()["met"] and str(c.get("amane", "")) != "":
				out += "\n\nLater, Amane: " + Amane.fill(str(c.get("amane", "")))
			await hud.say(name, out)
		return
	if s["club_log"].has(str(Clock.day())):
		await hud.say(name, "Practice is over for today. Next: %s." % schedule_text(c))
		return
	if not club_open(id):
		await hud.say(name, "No practice right now. The %s meets %s." % [name, schedule_text(c)])
		return
	await session(id, hud)


## One club session: the next event every 4th time, otherwise pick a style. The clock jumps to the club's close.
func session(id: String, hud) -> String:
	var s := st()
	var c := club_data(id)
	var name := str(c.get("name", id))
	var n := int(s["sessions"].get(id, 0))
	var events: Array = c.get("events", [])
	var ei := int(s["events"].get(id, 0))
	var out := ""
	if n % 4 == 3 and ei < events.size() and _needs_ok(events[ei].get("needs", {})):
		var ev: Dictionary = events[ei]
		Ledger.capture("%s: %s" % [name, str(ev.get("title", ""))])
		var choices: Array = []
		for ch in ev.get("choices", []):
			if not ch.has("when") or Amane.ok(ch["when"]):
				choices.append(ch)
		var menu := []
		for i in choices.size():
			menu.append({"id": str(i), "text": Amane.fill(str(choices[i].get("t", "...")))})
		var pick: String = await hud.say(name, "%s\n\n%s" % [str(ev.get("title", "")).to_upper(), Amane.fill(str(ev.get("text", "")))], menu)
		var ch: Dictionary = choices[int(pick)] if pick.is_valid_int() and int(pick) < choices.size() else choices[0]
		var lines := Town.apply_fx(ch.get("fx", {}))
		out = Amane.fill(str(ch.get("say", "...")))
		if lines != "":
			out += "\n" + lines
		s["events"][id] = ei + 1
	else:
		var styles: Array = clubs.get("styles", [])
		var menu := []
		for st_i in styles:
			menu.append({"id": str(st_i.id), "text": str(st_i.t)})
		var line := _pick(c.get("sessions", ["Practice."]))
		var pick: String = await hud.say(name, Amane.fill(line), menu)
		var style: Dictionary = styles[0]
		for st_i in styles:
			if str(st_i.id) == pick:
				style = st_i
		var m := float(style.get("mult", 1.0)) * mult("club_bonus", id)
		var notes: Array[String] = []
		var l := add(str(c.get("stat", "study")), float(clubs.get("base_gain", 4)) * m)
		if l != "":
			notes.append(l)
		if m >= 0.5:
			l = add_stats(c.get("also", {}))
			if l != "":
				notes.append(l)
		l = add_stats(style.get("stats", {}))
		if l != "":
			notes.append(l)
		for who in c.get("members", []):
			var before := int(Amane.st()["closeness"].get(str(who), 0))
			Amane.add_closeness(str(who), 2 + int(style.get("close", 0)))
			notes.append("> %s +%d" % [str(who), int(Amane.st()["closeness"].get(str(who), 0)) - before])
		out = str(style.get("say", "")) + ("\n" + "\n".join(notes) if not notes.is_empty() else "")
	s["sessions"][id] = n + 1
	s["club_log"][str(Clock.day())] = id
	s["skips"] = 0
	var close := int(c.get("close", 1050))
	if Clock.minute() < close:
		Clock.spend(close - Clock.minute())
	if Amane.st()["met"] and str(c.get("amane_day", "")) != "" and _rng.randf() < 0.35:
		out += "\n\n" + Amane.fill(str(c.get("amane_day", "")))
	changed.emit()
	await hud.say(name, out)
	return out


## The recruitment board (school 1F entrance): every club, its days and what it trains.
func use_board(hud) -> void:
	if hud == null:
		return
	var b: Dictionary = clubs.get("board", {})
	var menu := []
	for id in clubs.get("clubs", {}):
		var c := club_data(str(id))
		var mark := "  (your club)" if club() == str(id) else ""
		menu.append({"id": str(id), "text": "%s - %s · %s%s" % [str(c.name), "/".join(c.get("days", [])), stat_name(str(c.stat)), mark]})
	if club() != "":
		menu.append({"id": "_quit", "text": "Take your name off the %s sheet." % str(club_data(club()).get("name", ""))})
	menu.append({"id": "", "text": "Leave the board."})
	var text := str(b.get("text", ""))
	if club() != "":
		text += "\n\n" + str(b.get("current", "")).replace("{club}", str(club_data(club()).get("name", "")))
	var pick: String = await hud.say(str(b.get("name", "Club board")), text, menu)
	if pick == "_quit":
		var old := str(club_data(club()).get("name", ""))
		st()["club"] = ""
		changed.emit()
		await hud.say("", "> You left the %s. Nobody stops you. That's almost worse." % old)
	elif pick != "":
		await use_club(pick, hud)


# --- Part-time jobs ------------------------------------------------------------------------------

func job_data(id: String) -> Dictionary:
	return clubs.get("jobs", {}).get(id, {})


func hired(id: String) -> bool:
	return st()["jobs"].has(id)


## The shift window of a job that covers `minute` today (or, with `later`, still to come today) - {} if none.
func shift_now(id: String, minute: int = -1, later: bool = false) -> Dictionary:
	var m := Clock.minute() if minute < 0 else minute
	for sh in job_data(id).get("shifts", []):
		if not Clock.weekday() in sh.get("days", []):
			continue
		if (m >= int(sh.from) or later) and m < int(sh.to) - 30:
			return sh
	return {}


func shifts_text(j: Dictionary) -> String:
	var parts: Array[String] = []
	for sh in j.get("shifts", []):
		parts.append("%s %s-%s" % ["/".join(sh.days), Clock.time_text(int(sh.from)), Clock.time_text(int(sh.to))])
	return "; ".join(parts)


func _needs_ok(n: Dictionary) -> bool:
	for k in n.get("min_stat", {}):
		if stat(str(k)) < int(n["min_stat"][k]):
			return false
	if n.has("met") and bool(Amane.st()["met"]) != bool(n["met"]):
		return false
	if n.has("no_flag") and Game.flags.has(str(n["no_flag"])):
		return false
	return true


func hire(id: String) -> void:
	st()["jobs"][id] = {"since": Clock.day(), "shifts": 0}
	changed.emit()


## Use a job's place: interview, then work the shift that's on now.
func use_job(id: String, hud) -> void:
	if hud == null:
		return
	var j := job_data(id)
	var boss := str(j.get("boss", j.get("name", id)))
	if not hired(id):
		var pick: String = await hud.say(boss, "%s\n\n(%s · %s an hour)" % [Amane.fill(str(j.get("interview", ""))), shifts_text(j),
			DataDB.money(int(round(float(j.get("per_hour", 8.0)))))], [{"id": "yes", "text": "\"I'd like the job.\""}, {"id": "no", "text": "\"I'll think about it.\""}])
		if pick != "yes":
			return
		if not _needs_ok(j.get("needs", {})):
			await hud.say(boss, Amane.fill(str(j.get("turned_down", "\"Not yet.\""))))
			return
		hire(id)
		await hud.say(boss, Amane.fill(str(j.get("hired", "\"Welcome aboard.\""))) + "\n> Hired: %s (%s)" % [str(j.name), shifts_text(j)])
		return
	if st()["worked"].get(str(Clock.day()), "") == id:
		await hud.say(boss, "\"You've done your shift today. Go home, rest.\"")
		return
	if shift_now(id).is_empty():
		await hud.say(boss, "\"Not your shift. You're on %s.\"" % shifts_text(j))
		return
	await work(id, hud)


## Work a shift: style menu (or the next event every 3rd shift), pay by the hour, the clock jumps to the shift's end.
func work(id: String, hud) -> String:
	var s := st()
	var j := job_data(id)
	var sh := shift_now(id, -1, true)
	if sh.is_empty() or hud == null:
		return ""
	if Clock.minute() < int(sh.from):
		Clock.spend(int(sh.from) - Clock.minute())
	var hours := float(int(sh.to) - maxi(Clock.minute(), int(sh.from))) / 60.0
	var rec: Dictionary = s["jobs"][id]
	var n := int(rec.get("shifts", 0))
	var events: Array = j.get("events", [])
	var ei := int(rec.get("events", 0))
	var name := str(j.get("name", id))
	var pay_mult := 1.0
	var notes: Array[String] = []
	var out := ""
	if n % 3 == 2 and ei < events.size():
		var ev: Dictionary = events[ei]
		Ledger.capture("%s: %s" % [name, str(ev.get("title", ""))])
		var menu := []
		var choices: Array = ev.get("choices", [])
		for i in choices.size():
			menu.append({"id": str(i), "text": Amane.fill(str(choices[i].get("t", "...")))})
		var pick: String = await hud.say(name, "%s\n\n%s" % [str(ev.get("title", "")).to_upper(), Amane.fill(str(ev.get("text", "")))], menu)
		var ch: Dictionary = choices[int(pick)] if pick.is_valid_int() and int(pick) < choices.size() else choices[0]
		out = Amane.fill(str(ch.get("say", "...")))
		var lines := Town.apply_fx(ch.get("fx", {}))
		if lines != "":
			notes.append(lines)
		rec["events"] = ei + 1
	else:
		var styles: Array = clubs.get("job_styles", [])
		var menu := []
		for x in styles:
			menu.append({"id": str(x.id), "text": str(x.t)})
		var pick: String = await hud.say(name, Amane.fill(_pick(j.get("work", ["Work."]))), menu)
		var style: Dictionary = styles[0] if not styles.is_empty() else {}
		for x in styles:
			if str(x.id) == pick:
				style = x
		pay_mult = float(style.get("pay", 1.0))
		out = str(style.get("say", ""))
		var l := add_stats(style.get("stats", {}))
		if l != "":
			notes.append(l)
	var pay := maxi(1, roundi(float(j.get("per_hour", 8.0)) * hours * pay_mult * mult("job_bonus", id)))
	Game.credits += pay
	s["earned"] = int(s["earned"]) + pay
	notes.push_front("> Pay: %s (%.1f h)" % [DataDB.money(pay), hours])
	var l2 := add_stats(j.get("stats", {}))
	if l2 != "":
		notes.append(l2)
	if j.has("cats"):
		for cid in Cats.st():
			Cats.st()[cid]["attitude"] = mini(100, int(Cats.st()[cid]["attitude"]) + int(j["cats"]))
		notes.append("> Every cat in town smells the cafe on you (+%d)" % int(j["cats"]))
	if j.has("luck"):
		notes.append(Town.apply_fx({"luck": int(j["luck"])}))
	for k in j.get("amane", {}):
		Amane.add(str(k), float(j["amane"][k]))
	if not (j.get("amane", {}) as Dictionary).is_empty():
		notes.append("> Amane worked beside you the whole time")
	rec["shifts"] = n + 1
	s["worked"][str(Clock.day())] = id
	if Clock.minute() < int(sh.to):
		Clock.spend(int(sh.to) - Clock.minute())
	changed.emit()
	out += "\n" + "\n".join(notes)
	await hud.say(name, out)
	return out


## Weekend menu items (Aunt Haruka's "how will you spend the day?"): shifts still to come today.
func weekend_items() -> Array:
	var out := []
	for id in st()["jobs"]:
		var sh := shift_now(str(id), -1, true)
		if not sh.is_empty() and st()["worked"].get(str(Clock.day()), "") != str(id):
			out.append({"id": "job:" + str(id), "text": "Work at %s (%s-%s)." % [str(job_data(str(id)).get("name", id)),
				Clock.time_text(int(sh.from)), Clock.time_text(int(sh.to))]})
	return out


# --- Day loop ---------------------------------------------------------------------------------------

## Before the day ends (Week.before_day_end): club attendance, debt, Saki's Sunday call, new quirks.
func day_end(hud) -> void:
	var s := st()
	var notes: Array[String] = []
	if club() != "" and club() != "go_home" and meets_today(club()) and Clock.weekday() in WEEKDAYS and not s["club_log"].has(str(Clock.day())):
		s["skips"] = int(s["skips"]) + 1
		if int(s["skips"]) >= 3:
			s["skips"] = 0
			var c := club_data(club())
			s["notes"].append("%s caught you in the corridor: \"Three practices in a row, Asagiri. Are you in the %s or not?\"" % [
				str(c.get("captain", "The captain")), str(c.get("name", ""))])
	if Clock.weekday() == "Sun":
		var debt := int(fx_num("debt", 0.0))
		if debt > 0:
			var paid := mini(debt, Game.credits)
			Game.credits -= paid
			s["debt_paid"] = int(s["debt_paid"]) + paid
			notes.append("Sunday night. You transfer %s to the loan office in Tokyo.%s" % [DataDB.money(paid),
				"" if paid >= debt else " It isn't all of it. A letter will come."])
		if fx_num("tokyo", 0.0) > 0.0 and not Game.flags.has("saki_ended") and hud != null and int(s["tokyo_week"]) != Week.week_no():
			s["tokyo_week"] = Week.week_no()
			var call: Dictionary = data.get("tokyo_call", {})
			var menu := []
			for ch in call.get("choices", []):
				menu.append({"id": str(ch.id), "text": str(ch.t)})
			var pick: String = await hud.say("", str(call.get("text", "")), menu)
			for ch in call.get("choices", []):
				if str(ch.id) == pick:
					var lines := Town.apply_fx(ch.get("fx", {}))
					await hud.say("", str(ch.get("say", "")) + ("\n" + lines if lines != "" else ""))
	if stat("stamina") < 100:
		add("stamina", 2.0, false)  # a night's sleep
	notes.append_array(check_quirks())
	if hud != null and not notes.is_empty():
		await hud.say("", "\n".join(notes))


## Something for the wake-up note: a club captain's complaint, or a line from your past (now and then).
func morning_note() -> String:
	var s := st()
	var out: Array[String] = []
	for n in s["notes"]:
		out.append(str(n))
	s["notes"] = []
	if _rng.randf() < 0.3:
		var lines := []
		for cat in s["origin"]:
			lines.append_array(option(str(cat), str(s["origin"][cat])).get("mornings", []))
		if not lines.is_empty():
			out.append(str(lines[_rng.randi() % lines.size()]))
	return "\n\n".join(out)


## The goal's last line on the end card (data/toru.json goal epilogue, first match).
func goal_epilogue(ending_id: String = "") -> String:
	var o := option("goal", tag("goal"))
	for e in o.get("epilogue", []):
		var w: Dictionary = e.get("when", {})
		var ok := true
		for k in w.get("min_stat", {}):
			ok = ok and stat(str(k)) >= int(w["min_stat"][k])
		if w.has("min_money"):
			ok = ok and Game.credits >= int(w["min_money"])
		if w.has("ending"):
			ok = ok and ending_id in w["ending"]
		if w.has("flag"):
			ok = ok and Game.flags.has(str(w["flag"]))
		if w.has("route"):
			ok = ok and Amane.route() == str(w["route"])
		if w.has("min_lore"):
			ok = ok and (Amane.st()["lore"] as Dictionary).size() >= int(w["min_lore"])
		if ok:
			return str(e.get("text", ""))
	return ""


## Pause menu "Toru" page.
func status_text() -> String:
	var s := st()
	var lines: Array[String] = []
	var tags: Array[String] = []
	for c in categories():
		var o := option(str(c.id), tag(str(c.id)))
		if not o.is_empty():
			tags.append(str(o.name))
	lines.append("ASAGIRI %s  -  %s" % [Game.player_name.to_upper(), " · ".join(tags) if not tags.is_empty() else "(canon)"])
	for id in STATS:
		var v := stat(id)
		lines.append("%-13s %3d  %s" % [stat_name(id), v, "|".repeat(int(v / 5))])
	var c := club_data(club())
	lines.append("Club: %s" % (("%s (%s)" % [str(c.get("name", "")), schedule_text(c)]) if club() != "" else "none - see the board at the school entrance"))
	var jobs: Array[String] = []
	for id in s["jobs"]:
		jobs.append("%s (%s)" % [str(job_data(str(id)).get("name", id)), shifts_text(job_data(str(id)))])
	lines.append("Jobs: %s" % ("; ".join(jobs) if not jobs.is_empty() else "none"))
	lines.append("Earned: %s" % DataDB.money(int(s["earned"])))
	var qs: Array[String] = []
	for q in s["quirks"]:
		qs.append(str(data.get("quirks", {}).get(q, {}).get("name", q)))
	lines.append("Quirks: %s" % (", ".join(qs) if not qs.is_empty() else "none yet"))
	var goal := option("goal", tag("goal"))
	if not goal.is_empty():
		lines.append("Goal: %s" % str(goal.name))
	return "\n".join(lines)


func _pick(arr: Array) -> String:
	return str(arr[_rng.randi() % arr.size()]) if not arr.is_empty() else ""
