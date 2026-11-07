extends Node
## School days with a cost, and the first week with an end (docs/REVIEW.md "hard review" priorities 1-2).
## - Lessons are one event, not a wait: when a class block starts while you're in the school, pick how you
##   spend it and the clock jumps to the end of the block (data/lessons.json). After 8:30 you're late; in town
##   15+ minutes into a block you're absent (Makabe notices, the Ura board notices, Amane notices). Three lates
##   or two absences reach Aunt Haruka at night.
## - Week 1 (data/week1.json): an objective and authored beats per day (where / when / near), the first route
##   choice on Sunday at Omagatoki, and a week-close summary + hook for week 2 when day 7 ends.
## State: Game.flags["week"].

const AM := [510, 750]   ## homeroom 8:30 -> lunch 12:30
const PM := [800, 920]   ## 13:20 -> clubs 15:20
const TRUANT_AFTER := 15
const DEFAULTS := {"done": {}, "late": 0, "truant": 0, "study": 0, "today": {}, "closed": [], "told": {}}
const HOUSES := {"Inukai Hayate": "the Inukai house", "Hayase Hina": "the flower shop", "Kuroe Mio": "the Kuroe house",
	"Shirasagi Reiji": "the Shirasagi residence"}

var lessons: Dictionary = {}
var week1: Dictionary = {}
var _busy := false
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	lessons = _load("res://data/lessons.json")
	week1 = _load("res://data/week1.json")
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
	if _busy or not Game.location_id in ["suzunari", "school"]:
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
	if Clock.is_weekend():
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

func day_data(d: int = -1) -> Dictionary:
	return week1.get("days", {}).get(str(Clock.day() if d < 0 else d), {})


func objective() -> String:
	var dd := day_data()
	if dd.is_empty():
		return ""
	for bt in dd.get("beats", []):
		if not st()["done"].has(str(bt.id)):
			return str(dd.get("objective", ""))
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
	for bt in day_data().get("beats", []):
		if st()["done"].has(str(bt.id)):
			continue
		if _beat_ready(bt, m):
			play_beat(bt)
			return


func _beat_ready(bt: Dictionary, m: int) -> bool:
	if str(bt.get("speaker", "")).begins_with("Amane") and not Amane.st()["met"]:
		return false
	if bt.has("needs") and not Amane.ok(bt["needs"]):
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
	await Town.scene(str(bt.get("speaker", "")), Amane.fill(str(bt.get("text", ""))), bt.get("choices", []), "wk_" + str(bt.id))
	_busy = false


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
	if Clock.day() >= 7 and not (s["closed"] as Array).has(1):
		await close_week(hud)


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


func close_week(hud: Node) -> void:
	var s := st()
	(s["closed"] as Array).append(1)
	var c: Dictionary = week1.get("close", {})
	var text := "%s\n\n%s\n\n%s" % [str(c.get("title", "WEEK 1")), "\n".join(summary()),
		str(c.get("route", {}).get(Amane.route(), ""))]
	await hud.say("", text)
	var rival := Amane.rival()
	if rival == "":
		rival = Amane.FRIEND
	var house: String = HOUSES.get(rival, "a house on the river street")
	var hook: Array[String] = []
	for h in c.get("hook", []):
		hook.append(Amane.fill(str(h)).replace("{rival_house}", house).replace("{rival}", rival))
	await hud.say("", "\n\n".join(hook) + "\n\n" + str(c.get("next", "")))
