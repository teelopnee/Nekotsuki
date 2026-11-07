extends Node
## In-game clock for NEKOTSUKI: one real second = `rate` game minutes while a Suzunari level runs.
## Day 1 = Wednesday 8 April 2026 (start of term). State lives in Game.flags["clock"] (saved).

signal minute_passed(minute: int)
signal period_changed(period: String)
signal day_started(day: int)

const START_MIN := 7 * 60 + 30
const END_MIN := 22 * 60
const DUSK := 18 * 60
const NIGHT := 18 * 60 + 30
## [start minute, name]
const PERIODS := [[0, "Morning"], [510, "Homeroom"], [530, "Class"], [750, "Lunch"], [800, "Class"],
	[920, "Clubs"], [1050, "Evening"], [DUSK, "Omagatoki"], [NIGHT, "Night"]]
const WEEKDAYS := ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
const MONTHS := [["Apr", 30], ["May", 31], ["Jun", 30], ["Jul", 31], ["Aug", 31]]
## Light keyframes: [minute, sun colour, sun energy, ambient colour, ambient energy]
const LIGHT := [[450, "#ffe2b8", 1.3, "#b8c0dc", 1.3], [720, "#fff4e0", 1.5, "#c8d0ec", 1.4],
	[990, "#ffd8a0", 1.3, "#c0b4d0", 1.3], [DUSK, "#ff8a50", 1.0, "#c07070", 1.05],
	[NIGHT, "#ff4a40", 0.6, "#8a2a3a", 0.75], [1170, "#7a8ad0", 0.3, "#2a3060", 0.7], [END_MIN, "#6a7ac0", 0.25, "#1e2448", 0.65]]

var running := false
var rate := 1.0
var _acc := 0.0
var _period := ""


func st() -> Dictionary:
	if not Game.flags.has("clock") or not Game.flags["clock"] is Dictionary:
		Game.flags["clock"] = {"day": 1, "minute": START_MIN}
	return Game.flags["clock"]


func minute() -> int:
	return int(st().get("minute", START_MIN))


func day() -> int:
	return int(st().get("day", 1))


func weekday() -> String:
	return WEEKDAYS[(day() + 1) % 7]


func is_weekend() -> bool:
	return weekday() in ["Sat", "Sun"]


func date_text() -> String:
	var d := 7 + day()
	for m in MONTHS:
		if d <= int(m[1]):
			return "%s %d %s" % [weekday(), d, m[0]]
		d -= int(m[1])
	return "%s day %d" % [weekday(), day()]


func clock_text() -> String:
	return "%02d:%02d" % [minute() / 60, minute() % 60]


func time_text(m: int) -> String:
	return "%d:%02d" % [m / 60, m % 60]


func period() -> String:
	var p := "Morning"
	for e in PERIODS:
		if minute() >= int(e[0]):
			p = str(e[1])
	if is_weekend() and p in ["Homeroom", "Class", "Lunch", "Clubs"]:
		return "Day off"
	return p


func is_dusk() -> bool:
	return minute() >= DUSK and minute() < NIGHT


func _process(delta: float) -> void:
	if not running:
		return
	_acc += delta * rate
	while _acc >= 1.0:
		_acc -= 1.0
		advance(1)


func advance(m: int) -> void:
	var s := st()
	s["minute"] = mini(minute() + m, END_MIN)
	minute_passed.emit(minute())
	var p := period()
	if p != _period:
		_period = p
		period_changed.emit(p)


## Something worth doing costs time (a talk, a scene). Only while the clock runs, and never far enough to end the
## day by itself.
func spend(m: int) -> int:
	if not running:
		return 0
	var n := mini(m, maxi(0, END_MIN - 30 - minute()))
	if n > 0:
		advance(n)
	return n


func next_day() -> void:
	var s := st()
	s["day"] = day() + 1
	s["minute"] = START_MIN
	_period = ""
	day_started.emit(day())


## Sun / ambient for the current minute (interpolated between LIGHT keyframes).
func light() -> Dictionary:
	var m := float(minute())
	var a: Array = LIGHT[0]
	var b: Array = LIGHT[LIGHT.size() - 1]
	for i in LIGHT.size() - 1:
		if m >= float(LIGHT[i][0]) and m <= float(LIGHT[i + 1][0]):
			a = LIGHT[i]
			b = LIGHT[i + 1]
			break
	var t := 0.0 if b[0] == a[0] else clampf((m - float(a[0])) / (float(b[0]) - float(a[0])), 0.0, 1.0)
	return {"sun": Color.from_string(str(a[1]), Color.WHITE).lerp(Color.from_string(str(b[1]), Color.WHITE), t),
		"sun_energy": lerpf(float(a[2]), float(b[2]), t),
		"ambient": Color.from_string(str(a[3]), Color.GRAY).lerp(Color.from_string(str(b[3]), Color.GRAY), t),
		"ambient_energy": lerpf(float(a[4]), float(b[4]), t)}
