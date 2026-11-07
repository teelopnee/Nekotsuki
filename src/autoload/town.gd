extends Node
## Suzunari's lore in the world (data/town.json, docs/LORE.md is the source of truth).
## - examine(kind, idx): LevelBuilder landmarks (torii, halls, guardians, the six Jizo = save points, ema, basin)
## - lore points: readable signs placed at map tiles (spawn_in)
## - spirits: cast members and yokai at their spot during their hours, each a short scene with exact words
##   to pick; effects fill the Notes codex, the Hyakki Zukan (yokai met), Easter eggs, luck, money, hp,
##   Amane's lore flags / promises (shared with data/amane_talk.json requirements).
## State: Game.flags["town"]; known lore lives in Amane.st()["lore"] so his talks can react to it.

signal codex_changed

const DEFAULTS := {"seen": {}, "zukan": {}, "eggs": {}, "picked": {}, "today": [], "luck": 0}
const ZUKAN := {"kappa": "Kappa", "tanuki": "Bake-danuki", "tsukumogami": "Tsukumogami", "rokurokubi": "Rokurokubi",
	"nopperabo": "Nopperabo", "kuchisake": "Kuchisake-onna", "zashiki_warashi": "Zashiki-warashi",
	"hanako": "Hanako-san", "okuri_inu": "Okuri-inu", "ikiryo": "Ikiryo", "nekomata": "Nekomata"}

var data := {}
var _picks := {}


func st() -> Dictionary:
	if not Game.flags.has("town") or not (Game.flags["town"] is Dictionary):
		Game.flags["town"] = DEFAULTS.duplicate(true)
	var s: Dictionary = Game.flags["town"]
	for k in DEFAULTS:
		if not s.has(k):
			s[k] = (DEFAULTS[k] as Variant).duplicate(true) if DEFAULTS[k] is Dictionary or DEFAULTS[k] is Array else DEFAULTS[k]
	return s


func _ready() -> void:
	var path := "res://data/town.json"
	if FileAccess.file_exists(path):
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
		if parsed is Dictionary:
			data = parsed
	# School eggs live with the school's data but count in the same codex.
	var sp := "res://data/school.json"
	if FileAccess.file_exists(sp):
		var sd = JSON.parse_string(FileAccess.get_file_as_string(sp))
		if sd is Dictionary and data.has("eggs"):
			data["eggs"].merge(sd.get("eggs", {}))
	Clock.day_started.connect(func(_d): st()["today"] = [])


func lore_title(id: String) -> String:
	return str(data.get("lore_titles", {}).get(id, id.capitalize()))


func knows(id: String) -> bool:
	return Amane.st()["lore"].has(id)


## Learn a piece of lore. Returns the "> Remembered" line (empty if already known).
func remember(id: String) -> String:
	if id == "" or knows(id):
		return ""
	Amane.st()["lore"][id] = true
	codex_changed.emit()
	return "> Remembered: %s" % lore_title(id)


func level() -> Node:
	return get_tree().get_first_node_in_group("level") if is_inside_tree() else null


func _hud() -> Node:
	var l := level()
	return l.get("hud") if l else null


# --- Landmarks --------------------------------------------------------------------------------

func landmark(kind: String, idx: int = 0) -> Dictionary:
	var e = data.get("landmarks", {}).get(kind, {})
	if e is Array:
		e = (e as Array)[clampi(idx, 0, (e as Array).size() - 1)] if not (e as Array).is_empty() else {}
	return e if e is Dictionary else {}


func landmark_text(kind: String, idx: int = 0) -> String:
	var t := str(landmark(kind, idx).get("text", ""))
	while t.contains("#ema#"):
		t = t.replace("#ema#", "- \"%s\"" % _pick_new("ema", data.get("ema_wishes", ["..."])))
	return Amane.fill(t)


## Examine a LevelBuilder landmark. Jizo also save the game (they keep the way).
func examine(kind: String, idx: int = 0) -> void:
	var e := landmark(kind, idx)
	if e.is_empty():
		return
	var key := "lm_%s_%d" % [kind, idx] if kind == "jizo" else "lm_" + kind
	var first: bool = not st()["seen"].has(key)
	st()["seen"][key] = true
	if first:
		codex_changed.emit()
	var text := landmark_text(kind, idx)
	if kind == "jizo":
		Game.save_game()
		var all := true
		for i in 6:
			all = all and st()["seen"].has("lm_jizo_%d" % i)
		if all and not st()["eggs"].has("six_jizo"):
			text += "\n" + egg("six_jizo")
	var h := _hud()
	if h == null:
		return
	if e.has("choices"):
		await scene(str(e.get("name", "")), text, e["choices"], key)
	else:
		await h.say(str(e.get("name", "")), text)


# --- Lore signs -------------------------------------------------------------------------------

func read_point(id: String) -> void:
	for lp in data.get("lore_points", []):
		if str(lp.id) != id:
			continue
		var first: bool = not st()["seen"].has("lp_" + id)
		st()["seen"]["lp_" + id] = true
		if first:
			codex_changed.emit()
		var text := Amane.fill(str(lp.text))
		if lp.has("lore"):
			var r := remember(str(lp.lore))
			if r != "":
				text += "\n" + r
		if lp.has("egg") and not st()["eggs"].has(str(lp.egg)):
			text += "\n" + egg(str(lp.egg))
		var h := _hud()
		if h:
			await h.say(str(lp.name), text)
		return


# --- Spirits & townsfolk with their own scenes --------------------------------------------------

func spirit(id: String) -> Dictionary:
	for sp in data.get("spirits", []):
		if str(sp.id) == id:
			return sp
	return {}


func present(sp: Dictionary, minute: int = -1) -> bool:
	var m := Clock.minute() if minute < 0 else minute
	if People.hides(str(sp.get("id", "")), m):
		return false  # at home, on the road, or walking with you (People autoload)
	for w in sp.get("hours", []):
		if m >= int(w[0]) and m < int(w[1]):
			if sp.has("needs") and not Amane.ok(sp["needs"]):
				return false
			return true
	return false


## Talk to a spirit/cast member: opener -> exact words -> their answer + what changed.
func meet(id: String, actor: Node = null) -> void:
	var sp := spirit(id)
	var h := _hud()
	if sp.is_empty() or h == null:
		return
	var s := st()
	if await People.maybe_offer_home(id, h):
		return  # a close friend offers to walk you home (their own words)
	var extras: Array = People.menu_items(id)
	if (s["today"] as Array).has(id):
		var again := Amane.fill(_pick(sp.get("again", ["(They nod. Another day, maybe.)"])))
		if extras.is_empty():
			await h.say(str(sp.name), again)
		else:
			extras.append({"id": "bye", "text": "\"See you.\""})
			await scene(str(sp.name), again, [], "sp_" + id, extras)
		return
	(s["today"] as Array).append(id)
	var met_key := "sp_" + id
	if not s["seen"].has(met_key):
		s["seen"][met_key] = true
		codex_changed.emit()
	if actor and actor.has_method("face_player"):
		actor.face_player()
	await scene(str(sp.name), Amane.fill(_pick(sp.get("open", ["..."]))), sp.get("choices", []), met_key, extras)


## A one-choice scene: shows `text` with `choices` [{t, say, fx}], answers and applies effects.
## Choices already picked before show their answer again but don't re-apply one-off effects.
func scene(speaker: String, text: String, choices: Array, key: String, extras: Array = []) -> String:
	var h := _hud()
	if h == null or (choices.is_empty() and extras.is_empty()):
		return ""
	var picked: Array = st()["picked"].get(key, [])
	var menu := []
	for i in choices.size():
		var c: Dictionary = choices[i]
		if c.has("when") and not Amane.ok(c["when"]):
			continue
		var item := {"id": str(i), "text": Amane.fill(str(c.get("t", "...")))}
		if picked.has(i):
			item["text"] = item["text"] + "  (asked)"
			item["scale"] = 0.92
		menu.append(item)
	menu.append_array(extras)
	var pick: String = await h.say(speaker, text, menu)
	if pick.begins_with("p:"):
		await People.run_item(pick, h)  # schedules, walking home, Yui's rumours (People autoload)
		return pick
	if not pick.is_valid_int():
		return ""
	var i := int(pick)
	var c: Dictionary = choices[i]
	var again := picked.has(i)
	if not again:
		picked.append(i)
		st()["picked"][key] = picked
	var out := Amane.fill(str(c.get("say", "...")))
	var lines := apply_fx(c.get("fx", {}), again)
	if lines != "":
		out += "\n" + lines
	await h.say(speaker, out)
	return pick


## Effects of a scene choice -> "> what changed" lines. `again` = only repeatable effects.
func apply_fx(fx: Dictionary, again: bool = false) -> String:
	var lines: Array[String] = []
	var s := st()
	for k in fx:
		var v = fx[k]
		match k:
			"zukan":
				if not s["zukan"].has(str(v)):
					s["zukan"][str(v)] = Clock.day()
					lines.append("> Hyakki Zukan: new page - %s" % ZUKAN.get(str(v), str(v).capitalize()))
					codex_changed.emit()
			"egg":
				if not s["eggs"].has(str(v)):
					lines.append(egg(str(v)))
			"lore":
				var r := remember(str(v))
				if r != "":
					lines.append(r)
			"flag":
				Game.flags[str(v)] = true
			"promise":
				var pr: Array = Amane.st()["promises"]
				if not pr.has(str(v)):
					pr.append(str(v))
					lines.append("> A promise was made. Enma's Ledger wrote it down.")
			"luck":
				if not again:
					s["luck"] = clampi(int(s["luck"]) + int(v), -5, 5)
					lines.append("> Asagiri-do's luck %s" % ("rises" if int(v) > 0 else "falls"))
			"money":
				Game.credits = maxi(0, Game.credits + int(v))
				lines.append("> %s %s" % ["Spent" if int(v) < 0 else "Got", DataDB.money(absi(int(v)))])
			"hp":
				Game.hp = clampf(Game.hp + float(v), 1.0, Game.max_hp())
				lines.append("> %s" % ("Feeling better" if float(v) > 0 else "Ouch"))
			"amane_self":
				if not again:
					Amane.add("self", float(v))
			"closeness":
				if not again:
					Amane.add_closeness(str(fx.get("who", "Hina")), int(v))
			"minutes":
				Clock.advance(int(v))
				lines.append("> %d minutes pass" % int(v))
			"tears":
				Amane.add("tears", float(v))
			"bond":
				if not again:
					Amane.add("bond_now", float(v))
					lines.append("> Amane %s" % ("is happy" if float(v) > 0 else "is hurt"))
	return "\n".join(lines)


## Mark an Easter egg found -> its line (data/town.json eggs, docs/EASTER_EGGS.md).
func egg(id: String) -> String:
	st()["eggs"][id] = Clock.day()
	codex_changed.emit()
	return "> ??? %s" % str(data.get("eggs", {}).get(id, "Something in Suzunari remembers you."))


func luck() -> int:
	return int(st()["luck"])


# --- Spawning ---------------------------------------------------------------------------------

## Lore signs (wooden boards) and spirits at their tiles. Called by the Suzunari level after build.
func spawn_in(lvl: Node) -> Array:
	var out := []
	var b = lvl.get("builder")
	if b == null:
		return out
	for lp in data.get("lore_points", []):
		var p: Vector3 = b.center(int(lp.tile[0]), int(lp.tile[1]))
		out.append(_sign(lvl, p, str(lp.id), str(lp.name)))
	for sp in data.get("spirits", []):
		if sp.has("indoor"):
			continue  # placed by the School level
		var n = load("res://scenes/actors/npc.tscn").instantiate()
		n.set_script(load("res://src/actors/spirit_npc.gd"))
		n.set("spirit_id", str(sp.id))
		lvl.get("actors").add_child(n)
		n.global_position = b.center(int(sp.tile[0]), int(sp.tile[1])) + Vector3(0, 0.1, 0)
		n.call("set_home", n.global_position)
		out.append(n)
	return out


func _sign(lvl: Node, p: Vector3, id: String, title: String) -> Node3D:
	var root := Node3D.new()
	root.name = "Lore_" + id
	lvl.add_child(root)
	root.global_position = p + Vector3(0.7, 0, -0.7)
	var wood := StandardMaterial3D.new()
	wood.albedo_color = Color(0.42, 0.3, 0.2)
	var board := StandardMaterial3D.new()
	board.albedo_color = Color(0.88, 0.82, 0.68)
	var post := MeshInstance3D.new()
	var pm := BoxMesh.new()
	pm.size = Vector3(0.12, 1.3, 0.12)
	post.mesh = pm
	post.material_override = wood
	post.position = Vector3(0, 0.65, 0)
	root.add_child(post)
	var plate := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.9, 0.55, 0.06)
	plate.mesh = bm
	plate.material_override = board
	plate.position = Vector3(0, 1.15, 0.08)
	root.add_child(plate)
	var roof := MeshInstance3D.new()
	var rm := PrismMesh.new()
	rm.size = Vector3(1.05, 0.22, 0.2)
	roof.mesh = rm
	roof.material_override = wood
	roof.position = Vector3(0, 1.52, 0.06)
	root.add_child(roof)
	var it := Interactable.new()
	it.prompt = "Read: " + title
	it.radius = 1.6
	it.position = Vector3(0, 0.8, 0.6)
	root.add_child(it)
	it.interacted.connect(func(_p): read_point(id))
	return root


# --- Codex (phone Notes) ----------------------------------------------------------------------

## Lines for the phone's Notes tab: lore remembered, places read, yokai met, eggs found.
func codex() -> Dictionary:
	var s := st()
	var lore := []
	for id in Amane.st()["lore"]:
		lore.append(lore_title(str(id)))
	var places := []
	for lp in data.get("lore_points", []):
		if s["seen"].has("lp_" + str(lp.id)):
			places.append(str(lp.name))
	for kind in data.get("landmarks", {}):
		var e = data["landmarks"][kind]
		if e is Array:
			for i in (e as Array).size():
				if s["seen"].has("lm_%s_%d" % [kind, i]):
					places.append(str(e[i].get("name", kind)))
		elif s["seen"].has("lm_" + str(kind)):
			places.append(str((e as Dictionary).get("name", kind)))
	var zukan := []
	for id in ZUKAN:
		zukan.append(ZUKAN[id] if s["zukan"].has(id) else "???")
	var people := []
	for sp in data.get("spirits", []):
		if s["seen"].has("sp_" + str(sp.id)):
			people.append("%s (%s)" % [str(sp.name), str(sp.get("label", ""))])
	return {"lore": lore, "places": places, "zukan": zukan, "people": people, "eggs": s["eggs"].size(),
		"eggs_total": data.get("eggs", {}).size(), "promises": Amane.st()["promises"].duplicate()}


func _pick(a) -> String:
	if a is Array and not (a as Array).is_empty():
		return str((a as Array).pick_random())
	return str(a)


## Pick without repeating the last few (ema wishes).
func _pick_new(key: String, arr: Array) -> String:
	var used: Array = _picks.get(key, [])
	var pool := []
	for a in arr:
		if not used.has(a):
			pool.append(a)
	if pool.is_empty():
		used.clear()
		pool = arr.duplicate()
	var v = pool.pick_random()
	used.append(v)
	_picks[key] = used
	return str(v)
