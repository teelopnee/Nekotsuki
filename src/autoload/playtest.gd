extends Node
## Playtest log (docs/REVIEW.md: "time the first 10 minutes on the tablet"). Counts REAL seconds per in-game day,
## split into walk / talk (dialogue or scene open) / menu (paused: phone, pause menu) / idle (standing, no dialogue),
## and keeps a timeline of the first scenes of a new life. Shown on the pause menu "Playtest" page (debug builds only).
## Device-local: `user://playtest.json`, not part of the save; a NEW GAME starts a fresh log.

const PATH := "user://playtest.json"
const TIMELINE_MAX := 80

var book := {}
var _write_t := 0.0
var _mode := ""


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS  # menus pause the tree; menu time still counts
	if FileAccess.file_exists(PATH):
		var f := FileAccess.open(PATH, FileAccess.READ)
		var d = JSON.parse_string(f.get_as_text()) if f else null
		if d is Dictionary:
			book = d


func shown() -> bool:
	return OS.is_debug_build()


func new_life() -> void:
	book = {"started": Time.get_datetime_string_from_system(), "real": 0.0, "days": {}, "timeline": []}
	mark("NEW GAME")
	save()


func mark(text: String) -> void:
	if book.is_empty():
		return
	var tl: Array = book["timeline"]
	if tl.size() < TIMELINE_MAX:
		tl.append([snappedf(float(book["real"]), 0.1), _clock_text(), text])


func _clock_text() -> String:
	var m := int(Clock.minute())
	return "D%d %02d:%02d" % [int(Clock.day()), m / 60, m % 60]


func _process(delta: float) -> void:
	if book.is_empty() or DataDB.theme != "suzunari" or not Game.location_id in ["suzunari", "school"]:
		return
	var lvl := get_tree().get_first_node_in_group("level")
	if lvl == null:
		return
	var hud = lvl.get("hud")
	var mode := "idle"
	if hud != null and bool(hud.get("_dialogue_open")):
		mode = "talk"
	elif get_tree().paused:
		mode = "menu"
	else:
		var p := get_tree().get_first_node_in_group("player") as CharacterBody3D
		if p and Vector2(p.velocity.x, p.velocity.z).length() > 0.3:
			mode = "walk"
	_mode = mode
	book["real"] = float(book["real"]) + delta
	var key := str(Clock.day())
	var days: Dictionary = book["days"]
	if not days.has(key):
		days[key] = {"real": 0.0, "walk": 0.0, "talk": 0.0, "menu": 0.0, "idle": 0.0, "scenes": 0}
	var d: Dictionary = days[key]
	d["real"] = float(d["real"]) + delta
	d[mode] = float(d.get(mode, 0.0)) + delta
	_write_t += delta
	if _write_t > 30.0:
		_write_t = 0.0
		save()


## One scene or talk opened (Town.scene, Amane talks): counted for the day and put on the timeline.
func scene(text: String) -> void:
	if book.is_empty():
		return
	var d: Dictionary = book["days"].get(str(Clock.day()), {})
	if not d.is_empty():
		d["scenes"] = int(d.get("scenes", 0)) + 1
	mark(text)


func save() -> void:
	if book.is_empty():
		return
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(book, " "))


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_APPLICATION_PAUSED:
		save()


static func mmss(s: float) -> String:
	return "%d:%02d" % [int(s) / 60, int(s) % 60]


## The pause-menu page: per day (real time and where it went), then the first scenes with their real time.
func report() -> String:
	if book.is_empty():
		return "No log yet. Start a NEW GAME and play; this page fills in by itself."
	var lines: Array[String] = ["Started %s · played %s (real time)" % [str(book.get("started", "?")), mmss(float(book["real"]))], ""]
	var days: Dictionary = book["days"]
	var keys := days.keys()
	keys.sort_custom(func(a, b): return int(a) < int(b))
	for k in keys:
		var d: Dictionary = days[k]
		var r := maxf(1.0, float(d["real"]))
		lines.append("Day %s  %s  ·  walk %d%%  talk %d%%  menu %d%%  idle %d%%  ·  %d scenes" % [k, mmss(r),
			int(100.0 * float(d["walk"]) / r), int(100.0 * float(d["talk"]) / r), int(100.0 * float(d["menu"]) / r),
			int(100.0 * float(d["idle"]) / r), int(d.get("scenes", 0))])
	lines.append("")
	lines.append("First scenes (real time · game time):")
	for e in book["timeline"]:
		lines.append("%s  ·  %s  ·  %s" % [mmss(float(e[0])), str(e[1]), str(e[2])])
	lines.append("")
	lines.append("Where did it drag? Note the real time from this page (e.g. \"Day 2, 4:30, nothing to do\").")
	return "\n".join(lines)
