extends Node
## Enma's Ledger (閻魔帳, docs/LORE.md 9): what every episode remembers. Written at the end of each day and
## read by later episodes (user://ledger.json). Dōmyō writes the good, Dōshō the bad - here it is just JSON.

const PATH := "user://ledger.json"
const MIRROR_DIR := "user://mirror"
const MIRROR_MAX := 14

var scribes := {}  ## data/ledger_scribes.json: the end-of-episode page


func _ready() -> void:
	if FileAccess.file_exists("res://data/ledger_scribes.json"):
		var parsed = JSON.parse_string(FileAccess.get_file_as_string("res://data/ledger_scribes.json"))
		scribes = parsed if parsed is Dictionary else {}


func snapshot() -> Dictionary:
	var a := Amane.st()
	var chars := {"amane": {"route": Amane.route(), "bond_now": a["bond_now"], "bond_past": a["bond_past"],
		"self": a["self"], "trust": a["trust"], "ikiryo_named": a["ikiryo_named"], "cat_reports": a["cat_reports"]}}
	for who in a["closeness"]:
		chars[str(who)] = {"closeness": a["closeness"][who], "fate": Amane.fate(str(who))}
	for who in a["fates"]:
		if not chars.has(str(who)):
			chars[str(who)] = {"closeness": 0, "fate": a["fates"][who]}
	var cats := {}
	for id in Cats.st():
		cats[id] = {"name": Cats.st()[id]["name"], "attitude": Cats.st()[id]["attitude"]}
	return {"version": 1, "episode": 0, "player": Game.player_name, "day": Clock.day(), "date": Clock.date_text(),
		"rival": Amane.rival(), "stage": int(a["plan"]["stage"]), "characters": chars, "cats": cats,
		"promises": (a["promises"] as Array).duplicate(), "lore": (a["lore"] as Dictionary).keys(),
		"ending": str(Game.flags.get("ending", "")), "ending_choice": str(Game.flags.get("ending_choice", "")),
		"week": Week.st().duplicate(true),
		"mornings": {"pickups": People.st()["pickups"].duplicate(), "walks": People.st()["walks"].duplicate(),
			"broken": People.st()["broken"].keys(), "known": People.st()["known"].duplicate()},
		"toru": {"origin": Toru.st()["origin"].duplicate(), "stats": Toru.st()["stats"].duplicate(), "club": Toru.club(),
			"jobs": Toru.st()["jobs"].keys(), "quirks": Toru.st()["quirks"].keys()},
		"deeds": (Game.flags.get("deeds", []) as Array).duplicate(true),
		"cat_nights": (Game.flags.get("cat_night_log", []) as Array).duplicate(true),
		"town": {"zukan": Town.st()["zukan"].duplicate(), "eggs": Town.st()["eggs"].duplicate(), "luck": Town.luck(),
			"met": Town.st()["picked"].keys()}}


## A deed for the scribes (the end-of-episode page): eavesdropping, knocking things over, the cat night...
func deed(kind: String, id: String) -> void:
	var d: Array = Game.flags.get("deeds", [])
	d.append({"day": Clock.day(), "kind": kind, "id": id})
	Game.flags["deeds"] = d


func write() -> bool:
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(JSON.stringify(snapshot(), "\t"))
	f.close()
	return true


func read() -> Dictionary:
	if not FileAccess.file_exists(PATH):
		return {}
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	return parsed if parsed is Dictionary else {}


# --- The Johari mirror: real frames of the moments that mattered ---------------------------------

## Keep this moment for the mirror on the ledger page: the last rendered frame (scaled down) + a caption.
## Headless runs (tests) keep the caption only.
func capture(caption: String) -> void:
	var list: Array = Game.flags.get("mirror", [])
	if list.size() >= MIRROR_MAX:
		list.remove_at(1)  # always keep the first meeting
	var rec := {"day": Clock.day(), "caption": caption, "path": ""}
	if DisplayServer.get_name() != "headless" and is_inside_tree():
		var tex := get_viewport().get_texture()
		var img: Image = tex.get_image() if tex else null
		if img and not img.is_empty():
			img.resize(400, maxi(1, int(400.0 * img.get_height() / img.get_width())), Image.INTERPOLATE_BILINEAR)
			DirAccess.make_dir_recursive_absolute(MIRROR_DIR)
			var path := "%s/%d_%d.png" % [MIRROR_DIR, Clock.day(), Time.get_ticks_msec()]
			if img.save_png(path) == OK:
				rec["path"] = path
	list.append(rec)
	Game.flags["mirror"] = list


## NEW GAME: an empty mirror.
func clear_mirror() -> void:
	Game.flags.erase("mirror")
	var d := DirAccess.open(MIRROR_DIR)
	if d:
		for f in d.get_files():
			d.remove(f)


# --- The page Domyo and Dosho write (docs/GDD.md 4.14) ----------------------------------------------

func _fill(t: String, vars: Dictionary) -> String:
	for k in vars:
		t = t.replace("{%s}" % k, str(vars[k]))
	return t


func _entry(type: String, vars: Dictionary = {}) -> Dictionary:
	var e: Dictionary = scribes.get("entries", {}).get(type, {})
	if e.is_empty():
		return {}
	var dm: Array = e.get("domyo", ["..."])
	var ds: Array = e.get("dosho", ["..."])
	var i := absi(hash(type + str(vars))) 
	return {"type": type, "text": _fill(str(e.get("text", "")), vars), "domyo": _fill(str(dm[i % dm.size()]), vars),
		"dosho": _fill(str(ds[i % ds.size()]), vars), "verdict": str(e.get("verdict", "argued")),
		"mirror": _fill(str(e.get("mirror", "")), vars)}


## Every entry that applies to this life, in the order the scribes read them.
func entries() -> Array:
	var out := []
	var a := Amane.st()
	out.append(_entry("route_" + Amane.route()))
	for who in a["fates"]:
		var f := str(a["fates"][who])
		if f in ["injured", "hidden", "cut", "rescued"]:
			out.append(_entry("fate_" + f, {"who": who}))
	var cats := {}
	for c in Game.flags.get("cat_night_log", []):
		var k := "plan" if str(c.get("outcome", "")) == "dawn" else str(c.get("outcome", ""))
		cats[k] = int(cats.get(k, 0)) + 1
	for k in ["plan", "resist", "window", "skip"]:
		if cats.has(k):
			out.append(_entry("cat_" + k, {"n": cats[k]}))
	var deeds := {}
	for d in Game.flags.get("deeds", []):
		deeds[str(d.get("kind", ""))] = int(deeds.get(str(d.get("kind", "")), 0)) + 1
	for k in ["eavesdrop", "knock", "seen", "cheat", "cheat_caught", "ura_food_broken", "ura_food", "ura_food_refused"]:
		if deeds.has(k):
			out.append(_entry(k, {"n": deeds[k]}))
	for d in Game.flags.get("deeds", []):
		if str(d.get("kind", "")) == "exam":
			var parts := str(d.get("id", "")).split(":")
			if parts.size() == 2:
				out.append(_entry("exam_good" if int(parts[1]) <= 60 else "exam", {"name": parts[0], "n": parts[1]}))
	var broken: Array = People.st()["broken"].keys()
	for i in mini(3, broken.size()):
		out.append(_entry("promise_broken", {"who": People.short(str(broken[i]))}))
	var open: Array = []
	for p in a["promises"]:
		open.append(str(p).replace("_", " "))
	if not open.is_empty():
		out.append(_entry("promise_open", {"name": ", ".join(open.slice(0, 4))}))
	var picks: Dictionary = People.st()["pickups"]
	var total := 0
	var best := ""
	for id in picks:
		total += int(picks[id])
		if best == "" or int(picks[id]) > int(picks[best]):
			best = str(id)
	if total > 0:
		out.append(_entry("pickups", {"n": total, "who": People.short(best)}))
	if int(Week.st()["truant"]) >= 2:
		out.append(_entry("truant", {"n": int(Week.st()["truant"])}))
	if Toru.club() != "":
		var n := int(Toru.st()["sessions"].get(Toru.club(), 0))
		if n > 0:
			out.append(_entry("club", {"name": str(Toru.club_data(Toru.club()).get("name", "")), "n": n}))
	var jobs: Dictionary = Toru.st()["jobs"]
	for id in jobs:
		var n := int(jobs[id].get("shifts", 0))
		if n > 0:
			out.append(_entry("job", {"name": str(Toru.job_data(str(id)).get("name", id)), "n": n, "money": DataDB.money(int(Toru.st()["earned"]))}))
	var eggs := (Town.st()["eggs"] as Dictionary).size()
	if eggs > 0:
		out.append(_entry("eggs", {"n": eggs}))
	var zukan := (Town.st()["zukan"] as Dictionary).size()
	if zukan >= 3:
		out.append(_entry("zukan", {"n": zukan}))
	var goal := Toru.option("goal", Toru.tag("goal"))
	if not goal.is_empty():
		out.append(_entry("goal", {"name": str(goal.get("name", "")), "title": Toru.goal_epilogue(str(Game.flags.get("ending", "")))}))
	var end_id := str(Game.flags.get("ending", ""))
	if end_id != "":
		out.append(_entry("ending", {"title": str(Week.endings.get("endings", {}).get(end_id, {}).get("title", end_id))}))
	var clean := []
	for e in out:
		if not (e as Dictionary).is_empty():
			clean.append(e)
	return clean


## The ledger page at the end of the episode (src/ui/ledger_page.gd). Returns when the player closes it.
func show_page(parent: Node) -> void:
	if parent == null:
		return
	var page: Control = load("res://src/ui/ledger_page.gd").new()
	var layer := CanvasLayer.new()
	layer.layer = 60
	layer.process_mode = Node.PROCESS_MODE_ALWAYS
	parent.add_child(layer)
	layer.add_child(page)
	await page.closed
	layer.queue_free()
