extends Node
## School days with a cost, and the first week with an end (docs/REVIEW.md "hard review" priorities 1-2).
## - Lessons are one event, not a wait: when a class block starts while you're in the school, pick how you
##   spend it and the clock jumps to the end of the block (data/lessons.json). After 8:30 you're late; in town
##   15+ minutes into a block you're absent (Makabe notices, the Ura board notices, Amane notices). Three lates
##   or two absences reach Aunt Haruka at night.
## - The 13 weeks of episode 0 (data/weeks/weekNN.json, 8 April -> Tanabata 7 July): an objective and authored beats
##   per day (where / when / near / needs), dreams on Friday nights ("when": "night", played as the day ends), exam
##   days, a week-close summary + hook at the end of every 7th day, and the last night on the steps -> an ending
##   (data/endings.json, Week.ending()).
## State: Game.flags["week"].

const AM := [510, 750]   ## homeroom 8:30 -> lunch 12:30
const PM := [800, 920]   ## 13:20 -> clubs 15:20
const TRUANT_AFTER := 15
const DEFAULTS := {"done": {}, "late": 0, "truant": 0, "study": 0, "today": {}, "closed": [], "told": {}}
const HOUSES := {"Inukai Hayate": "the Inukai house", "Hayase Hina": "the flower shop", "Kuroe Mio": "the Kuroe house",
	"Shirasagi Reiji": "the Shirasagi residence"}

var lessons: Dictionary = {}
var weeks: Dictionary = {}  ## week number -> data/weeks/weekNN.json
var endings: Dictionary = {}
var ura: Dictionary = {}      ## data/ura.json - the other side
var weekend: Dictionary = {}  ## data/weekend.json - free days
const LAST_WEEK := 13
var _busy := false
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	lessons = _load("res://data/lessons.json")
	for n in range(1, LAST_WEEK + 1):
		var w := _load("res://data/weeks/week%02d.json" % n)
		if not w.is_empty():
			weeks[n] = w
	endings = _load("res://data/endings.json")
	ura = _load("res://data/ura.json")
	weekend = _load("res://data/weekend.json")
	Clock.minute_passed.connect(_on_minute)
	Clock.day_started.connect(func(_d): st()["today"] = {})


func _load(path: String) -> Dictionary:
	if FileAccess.file_exists(path):
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
		if parsed is Dictionary:
			return parsed
	return {}


func st() -> Dictionary:
	if not Game.flags.has("week") or not (Game.flags["week"] is Dictionary):
		Game.flags["week"] = DEFAULTS.duplicate(true)
	var s: Dictionary = Game.flags["week"]
	for k in DEFAULTS:
		if not s.has(k):
			s[k] = DEFAULTS[k].duplicate(true) if DEFAULTS[k] is Dictionary or DEFAULTS[k] is Array else DEFAULTS[k]
	return s


func today() -> Dictionary:
	return st()["today"]


func _level() -> Node:
	return get_tree().get_first_node_in_group("level") if get_tree() else null


func _hud() -> Node:
	var l := _level()
	return l.get("hud") if l else null


func _free(hud: Node) -> bool:
	return hud != null and not _busy and not hud._dialogue_open


## The level calls this once it's built (and every minute runs it too).
func level_ready() -> void:
	_on_minute(Clock.minute())


func _on_minute(m: int) -> void:
	if _busy or not Game.location_id in ["suzunari", "school"] or bool(Game.flags.get("in_ura", false)):
		return
	_check_lessons(m)
	if not _busy:
		_check_beats(m)


## Suzunari's own music (tools/gen_music_suzunari.py): morning, Omagatoki, and night - or whenever Amane cries.
func music_now() -> String:
	var m := Clock.minute()
	if m >= Clock.NIGHT or Amane.tears_level() >= 3:
		return "suzunari_rain_night"
	if m >= Clock.DUSK - 20:
		return "suzunari_dusk"
	return "suzunari_morning"


# --- Lessons, lateness, truancy ------------------------------------------------------------------

func block(m: int = -1) -> String:
	var t := Clock.minute() if m < 0 else m
	if Clock.is_weekend() or bool(day_data().get("holiday", false)):
		return ""
	if t >= AM[0] and t < AM[1]:
		return "am"
	if t >= PM[0] and t < PM[1]:
		return "pm"
	return ""


func _check_lessons(m: int) -> void:
	var b := block(m)
	if b == "" or today().has("lesson_" + b):
		return
	var start: int = AM[0] if b == "am" else PM[0]
	if Game.location_id == "school":
		var hud := _hud()
		if _free(hud):
			_lesson(b, m - start)
	elif m - start >= TRUANT_AFTER and not today().has("truant_" + b):
		_truant(b)


func _subject(b: String) -> String:
	var pair: Array = lessons.get("subjects", {}).get(Clock.weekday(), ["Homeroom", "Self-study"])
	return str(pair[0 if b == "am" else 1])


func _pick(arr) -> String:
	if not arr is Array or (arr as Array).is_empty():
		return ""
	return Amane.fill(str(arr[_rng.randi() % arr.size()]))


func _lesson(b: String, late: int) -> void:
	var hud := _hud()
	_busy = true
	today()["lesson_" + b] = true
	var s := st()
	var block_name := "Morning lessons" if b == "am" else "Afternoon lessons"
	var text := _pick(lessons.get("open", [])).replace("{block}", block_name).replace("{subject}", _subject(b))
	var notes: Array[String] = []
	if late > 2:
		s["late"] = int(s["late"]) + 1
		today()["late"] = true
		text = _pick(lessons.get("late", [])).replace("{late}", str(late)) + "\n\n" + text
		notes.append("> Late mark (%d this week)" % int(s["late"]))
		Amane.add_closeness("Makabe-sensei", -1)
	if bool(day_data().get("exam", false)):
		await _exam(b, text, notes)
		return
	var menu := []
	for c in lessons.get("choices", []):
		menu.append({"id": str(c.id), "text": str(c.t)})
	var picked: String = await hud.say("", text, menu)
	var res := _pick(lessons.get("results", {}).get(picked, lessons.get("results", {}).get("attend", []))).replace("{subject}", _subject(b))
	match picked:
		"attend":
			s["study"] = int(s["study"]) + 1
			Amane.add_closeness("Makabe-sensei", 1)
			notes.append("> Studied (%d)" % int(s["study"]))
		"doze":
			Game.hp = minf(Game.hp + 15.0, Game.max_hp())
			notes.append("> Rested")
		"window":
			if Amane.st()["met"] and res.contains("hood"):
				Amane.add("bond_now", 1.0)
		"note":
			Amane.add_closeness(Amane.FRIEND, 3)
			notes.append("> Hayate +3")
			if res.contains("caught") or res.contains("reads it aloud"):
				Amane.add_closeness("Makabe-sensei", -2)
	var end_at: int = AM[1] if b == "am" else PM[1]
	var jump: int = maxi(0, end_at - Clock.minute())
	notes.append("> The lessons pass. %s - %s." % [Clock.time_text(end_at), "lunch" if b == "am" else "school's out"])
	Clock.advance(jump)
	await hud.say("", res + "\n" + "\n".join(notes))
	_busy = false


## Exam days (midterms week 5, finals week 10): what you studied (lessons attended) decides the grade.
func _exam(b: String, late_text: String, notes: Array[String]) -> void:
	var hud := _hud()
	var s := st()
	var ex: Dictionary = lessons.get("exam", {})
	var menu := []
	for c in ex.get("choices", []):
		menu.append({"id": str(c.id), "text": str(c.t)})
	var text := _pick(ex.get("open", [])).replace("{subject}", _subject(b))
	if late_text.contains("late") or late_text.contains("Late"):
		text = late_text.split("\n\n")[0] + "\n\n" + text
	var picked: String = await hud.say("", text, menu)
	var score: int = int(s["study"]) + int({"careful": 2, "guess": 0, "help": -1, "clock": 1}.get(picked, 0))
	var grade := "A" if score >= 9 else ("B" if score >= 6 else ("C" if score >= 3 else "D"))
	if picked == "help":
		Amane.add_closeness(Amane.FRIEND, 6)
		notes.append("> Hayate +6")
	Game.flags["exam_w%d_%s" % [week_no(), b]] = grade
	var res := str(ex.get("results", {}).get(picked, "")) + "\n" + str(ex.get("grades", {}).get(grade, ""))
	notes.append("> Grade: %s (studied %d)" % [grade, int(s["study"])])
	var end_at: int = AM[1] if b == "am" else PM[1]
	Clock.advance(maxi(0, end_at - Clock.minute()))
	await hud.say("", res + "\n" + "\n".join(notes))
	_busy = false


func _truant(b: String) -> void:
	var s := st()
	today()["truant_" + b] = true
	s["truant"] = int(s["truant"]) + 1
	Amane.add_closeness("Makabe-sensei", -3)
	Amane.post("truant")
	if Amane.st()["met"] and Amane.route() != "ignore":
		Amane.add("tears", 0.4)
	var hud := _hud()
	if hud and hud.has_method("toast"):
		var t := _pick(lessons.get("truant", [])).replace("{block}", "Morning lessons" if b == "am" else "Afternoon lessons")
		hud.toast("%s  (absent %d)" % [t, int(s["truant"])], Color(1.0, 0.72, 0.6))


# --- Week 1 beats --------------------------------------------------------------------------------

func week_no(d: int = -1) -> int:
	return int(((Clock.day() if d < 0 else d) - 1) / 7) + 1


func day_in_week(d: int = -1) -> int:
	return ((Clock.day() if d < 0 else d) - 1) % 7 + 1


func day_data(d: int = -1) -> Dictionary:
	var day := Clock.day() if d < 0 else d
	return weeks.get(week_no(day), {}).get("days", {}).get(str(day_in_week(day)), {})


var marker_hint := ""  ## " (NE 120 m)" - set by the Suzunari level from marker()


func objective() -> String:
	if bool(Game.flags.get("in_ura", false)):
		var g: Dictionary = ura.get("goals", {}).get(str(st().get("ura_goal", "free")), {})
		return str(g.get("objective", ura.get("goals", {}).get("free", {}).get("objective", "")))
	var dd := day_data()
	if dd.is_empty():
		return ""
	for bt in dd.get("beats", []):
		if not st()["done"].has(str(bt.id)) and _needs_ok(bt):
			return str(dd.get("objective", "")) + marker_hint
	return ""


func morning_note() -> String:
	var dd := day_data()
	var key := "morning_%d" % Clock.day()
	if dd.get("morning", "") == "" or st()["told"].has(key):
		return ""
	st()["told"][key] = true
	return Amane.fill(str(dd.morning))


func _check_beats(m: int) -> void:
	var hud := _hud()
	if not _free(hud) or People.escorting():
		return
	for bt in _candidates():
		if _beat_ready(bt, m):
			play_beat(bt)
			return
	if free_day() and Game.location_id == "suzunari" and m < 720 and not today().has("weekend") and _near_home():
		weekend_menu()


## Today's beats, then yesterday's that were missed (they carry over one day unless "carry": false).
func _candidates() -> Array:
	var out := []
	for d in [Clock.day(), Clock.day() - 1]:
		if d < 1:
			continue
		for bt in day_data(d).get("beats", []):
			if st()["done"].has(str(bt.id)) or str(bt.get("when", "")) == "night":
				continue
			if d != Clock.day() and not bool(bt.get("carry", true)):
				continue
			out.append(bt)
	return out


func free_day() -> bool:
	return Clock.is_weekend() or bool(day_data().get("holiday", false))


func _near_home() -> bool:
	var lvl := _level()
	var p := lvl.get("player") as Node3D if lvl else null
	return p != null and lvl.get("builder") != null and p.global_position.distance_to(lvl.builder.center(27, 48)) < 12.0


## The next story place to go to: [tile, label] of the first pending beat today (or yesterday's) that has a place,
## or [] - Suzunari puts a lantern there and the HUD shows the way.
func marker() -> Array:
	var m := Clock.minute()
	for bt in _candidates():
		if not bt.has("near") or not _needs_ok(bt):
			continue
		if m < int(bt.get("after", 0)) - 90:
			continue
		if bt.has("before") and m >= int(bt["before"]) and not bool(bt.get("fallback", false)):
			continue
		var n: Array = bt["near"]
		return [Vector2i(int(n[0]), int(n[1])), str(bt.get("speaker", ""))]
	return []


func _needs_ok(bt: Dictionary) -> bool:
	if str(bt.get("speaker", "")).begins_with("Amane") and not Amane.st()["met"]:
		return false
	return not bt.has("needs") or Amane.ok(bt["needs"])


func _beat_ready(bt: Dictionary, m: int) -> bool:
	if not _needs_ok(bt):
		return false
	if m < int(bt.get("after", 0)):
		return false
	var late: bool = bt.has("before") and m >= int(bt["before"])
	if late:
		return bool(bt.get("fallback", false))
	var where := str(bt.get("where", "any"))
	if where != "any" and where != str(Game.location_id):
		return false
	if bt.has("near") and Game.location_id == "suzunari":
		var lvl := _level()
		var p := lvl.get("player") as Node3D if lvl else null
		var n: Array = bt["near"]
		if p == null or lvl.get("builder") == null:
			return false
		if p.global_position.distance_to(lvl.builder.center(int(n[0]), int(n[1]))) > float(n[2]) * LevelBuilder.TILE:
			return false
	return true


func play_beat(bt: Dictionary) -> void:
	var hud := _hud()
	if hud == null:
		return
	_busy = true
	st()["done"][str(bt.id)] = Clock.day()
	var choices: Array = bt.get("choices", [])
	var pick: String = await Town.scene(str(bt.get("speaker", "")), fill(str(bt.get("text", ""))), choices, "wk_" + str(bt.id))
	if pick.is_valid_int() and int(pick) < choices.size():
		var fx: Dictionary = choices[int(pick)].get("fx", {})
		if fx.has("final"):
			await ending(str(fx["final"]))
		elif fx.has("enter_ura"):
			_busy = false
			enter_ura(str(fx["enter_ura"]))
			return
	_busy = false


## {rival}, {rival_short}, {player} in story text.
func fill(t: String) -> String:
	var r := Amane.rival()
	if r == "":
		r = str(Amane.st()["rival"]) if str(Amane.st()["rival"]) != "" else Amane.FRIEND
	return Amane.fill(t).replace("{rival_short}", r.split(" ")[-1] if r.contains(" ") else r).replace("{rival}", r)


# --- Night: consequences and the week close -----------------------------------------------------

## Suzunari / School call this before the day ends (awaitable).
func before_day_end(hud: Node) -> void:
	if hud == null:
		return
	var s := st()
	var cons: Dictionary = lessons.get("consequence", {})
	if int(s["late"]) >= 3 and not s["told"].has("late_3"):
		s["told"]["late_3"] = true
		await hud.say("Asagiri Haruka", Amane.fill(str(cons.get("late_3", ""))))
	if int(s["truant"]) >= 2 and not s["told"].has("truant_2"):
		s["told"]["truant_2"] = true
		Town.st()["luck"] = clampi(int(Town.st()["luck"]) - 1, -5, 5)
		await hud.say("", Amane.fill(str(cons.get("truant_2", ""))) + "\n> Asagiri-do's luck falls")
	for bt in day_data().get("beats", []):  # dreams and other night scenes
		if str(bt.get("when", "")) == "night" and not s["done"].has(str(bt.id)) and _needs_ok(bt):
			await play_beat(bt)
	if Game.flags.has("ending"):
		return
	if week_no() >= 13 and day_in_week() == 7:
		# Tanabata can't be slept through: if you end the night early, you go up the steps anyway.
		for bt in day_data().get("beats", []):
			if str(bt.id) == "w13_tanabata":
				await hud.say("", "You lie down. You can't sleep. Nobody in Suzunari can sleep tonight. You get up, and you go to the steps.")
				st()["done"].erase("w13_tanabata")
				await play_beat(bt)
				return
	if day_in_week() == 7 and not (s["closed"] as Array).has(week_no()):
		await close_week(hud, week_no())


func summary() -> Array[String]:
	var s := st()
	var a := Amane.st()
	var lines: Array[String] = []
	lines.append("School: studied %d · late %d · absent %d" % [int(s["study"]), int(s["late"]), int(s["truant"])])
	lines.append("Amane: %s · bond %d · %s" % [Amane.ROUTE_NAMES.get(Amane.route(), "-"), int(float(a["bond_now"])),
		Amane.TEAR_NAMES[Amane.tears_level()]])
	var close: Array = []
	for who in a["closeness"]:
		close.append([int(a["closeness"][who]), str(who)])
	close.sort_custom(func(x, y): return x[0] > y[0])
	var names: Array[String] = []
	for c in close.slice(0, 3):
		names.append("%s %d" % [c[1], c[0]])
	lines.append("Closest: %s" % (", ".join(names) if not names.is_empty() else "nobody yet"))
	var ps := People.st()
	var pick := 0
	var walk := 0
	for k in ps["pickups"]:
		pick += int(ps["pickups"][k])
	for k in ps["walks"]:
		walk += int(ps["walks"][k])
	lines.append("Mornings: picked someone up %d · walked someone home %d" % [pick, walk])
	lines.append("Promises: %s" % (", ".join(PackedStringArray(a["promises"])).replace("_", " ") if not (a["promises"] as Array).is_empty() else "none"))
	lines.append("Remembered %d things · Hyakki Zukan %d pages" % [(a["lore"] as Dictionary).size(), (Town.st()["zukan"] as Dictionary).size()])
	return lines


func close_week(hud: Node, n: int = 1) -> void:
	var s := st()
	(s["closed"] as Array).append(n)
	var c: Dictionary = weeks.get(n, {}).get("close", {})
	var text := "%s\n\n%s\n\n%s" % [str(c.get("title", "WEEK %d" % n)), "\n".join(summary()),
		fill(str(c.get("route", {}).get(Amane.route(), "")))]
	await hud.say("", text)
	var rival := Amane.rival()
	if rival == "":
		rival = Amane.FRIEND
	var house: String = HOUSES.get(rival, "a house on the river street")
	var hook: Array[String] = []
	for h in c.get("hook", []):
		hook.append(fill(str(h)).replace("{rival_house}", house))
	await hud.say("", "\n\n".join(hook) + "\n\n" + str(c.get("next", "")))


# --- The last night (week 13): an ending -------------------------------------------------------------

## The final choice on the 999 steps -> which ending (data/endings.json, docs/GDD.md section 6).
func ending_id(choice: String) -> String:
	var a := Amane.st()
	var bond := float(a["bond_now"])
	var self_v := float(a["self"])
	var f := Game.flags
	var rivals_gone := 0
	for who in ["Inukai Hayate", "Hayase Hina", "Kuroe Mio", "Shirasagi Reiji"]:
		if Amane.fate(who) in ["injured", "hidden"]:
			rivals_gone += 1
	if rivals_gone >= 3 and choice != "return_god":
		return "two_of_us"
	match choice:
		"tadaima":
			if bool(f.get("memory_2016", false)) and bond >= 45.0:
				return "okaeri"
			return "right_distance" if Amane.route() in ["boundary", "friend"] and self_v >= 45.0 else "cat_who_waits"
		"bell":
			return "red_thread" if Amane.route() == "romance" and bond >= 50.0 else "this_life_stranger"
		"remove_bell":
			return "this_life_love" if bond >= 50.0 else "this_life_stranger"
		"walk_beside":
			return "right_distance" if self_v >= 45.0 else "cat_who_waits"
		"leave":
			return "cat_who_waits"
		"ura":
			if bool(f.get("makabe_letter_sent", false)):
				return "unsent_letter"
			if bool(f.get("sayo_found", false)) and bool(f.get("letter_101", false)):
				return "homecoming"
			return "endless_festival" if bond >= 40.0 else "hidden"
		"seal":
			return "dog_and_cat"
		"return_god":
			return "god_returned"
	return "cat_who_waits"


func ending(choice: String) -> void:
	var hud := _hud()
	var id := ending_id(choice)
	var e: Dictionary = endings.get("endings", {}).get(id, {})
	Game.flags["ending"] = id
	Game.flags["ending_choice"] = choice
	if hud:
		for page in e.get("pages", []):
			await hud.say("", fill(str(page)))
		var epi := ""
		if bool(Game.flags.get("makoto_apologised", false)) and not id in ["god_returned", "two_of_us", "hidden"]:
			epi = "\n\n" + fill(str(endings.get("family_epilogue", "")))
		await hud.say("", "%s\n\n%s%s\n\n%s" % [str(e.get("title", id)).to_upper(), "\n".join(summary()), epi,
			str(endings.get("end_card", "EPISODE 0 - END"))])
	remember_ending(id)
	Ledger.write()
	Game.save_game()
	Clock.running = false
	Router.goto(Router.TITLE)


const SEEN_PATH := "user://endings_seen.json"


## Every ending ever reached on this device (the title screen shows them).
func endings_seen() -> Dictionary:
	if FileAccess.file_exists(SEEN_PATH):
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(SEEN_PATH))
		if parsed is Dictionary:
			return parsed
	return {}


func remember_ending(id: String) -> void:
	var seen := endings_seen()
	seen[id] = {"title": str(endings.get("endings", {}).get(id, {}).get("title", id)), "date": Time.get_date_string_from_system()}
	seen["_last"] = id
	var f := FileAccess.open(SEEN_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(seen))
		f.close()


# --- Free days -----------------------------------------------------------------------------------------

## Weekends and holidays: Aunt Haruka asks how you'll spend the day (data/weekend.json). Costs hours.
func weekend_menu() -> void:
	var hud := _hud()
	if not _free(hud):
		return
	_busy = true
	today()["weekend"] = true
	var who := _closest()
	var menu := []
	for a in weekend.get("activities", []):
		if str(a.id) == "friend" and who == "":
			continue
		menu.append({"id": str(a.id), "text": str(a.t).replace("{who}", who.split(" ")[-1] if who != "" else "")})
	menu.append({"id": "", "text": "\"I'll decide as I go.\""})
	var picked: String = await hud.say("Asagiri Haruka", Amane.fill(_pick(weekend.get("ask", []))), menu)
	for a in weekend.get("activities", []):
		if str(a.id) != picked or picked == "":
			continue
		var fx: Dictionary = (a.get("fx", {}) as Dictionary).duplicate()
		var extra := ""
		if fx.has("friend"):
			Amane.add_closeness(who, int(fx["friend"]))
			extra = "> %s +%d" % [who, int(fx["friend"])]
			fx.erase("friend")
		var lines := Town.apply_fx(fx)
		Clock.advance(int(a.get("minutes", 180)))
		var line := _pick(a.get("lines", [])).replace("{who}", who.split(" ")[-1] if who != "" else "a friend")
		var notes: Array[String] = []
		for x in [lines, extra, "> %d hours pass" % int(int(a.get("minutes", 180)) / 60)]:
			if str(x) != "":
				notes.append(str(x))
		await hud.say("", line + "\n" + "\n".join(notes))
	_busy = false


func _closest() -> String:
	var best := ""
	var best_v := 9
	var c: Dictionary = Amane.st()["closeness"]
	for who in c:
		if int(c[who]) > best_v and not str(who).ends_with("-sensei") and str(who) != "Sato Yui":
			best_v = int(c[who])
			best = str(who)
	return best


# --- Ura-Suzunari ----------------------------------------------------------------------------------------

## Step onto the thousandth stair: the town level reloads as Ura-Suzunari (Suzunari._setup reads Router.params).
func enter_ura(goal: String) -> void:
	st()["ura_goal"] = goal
	Game.flags["ura_visits"] = int(Game.flags.get("ura_visits", 0)) + 1
	Game.flags["in_ura"] = true
	Clock.running = false
	Router.goto(Router.SUZUNARI, {"ura": true, "goal": goal})


## Walk back down: ordinary Suzunari, a little later than you left (Omagatoki is over).
func leave_ura(thrown_out: bool = false) -> void:
	Game.flags.erase("in_ura")
	Game.location_id = "suzunari"
	if thrown_out:
		var lore: Dictionary = Amane.st()["lore"]
		if not lore.is_empty():
			lore.erase(lore.keys()[_rng.randi() % lore.size()])
		Clock.next_day()
		Clock.st()["minute"] = Clock.START_MIN
		Router.goto(Router.SUZUNARI, {"spawn_tile": [4, 21]})
		return
	Clock.advance(maxi(0, Clock.NIGHT + 10 - Clock.minute()))
	Router.goto(Router.SUZUNARI, {"spawn_tile": [4, 21]})
