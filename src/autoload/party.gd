extends Node
## Companions (docs/GDD.md 4.13, data/party.json): up to two friends hang out with you after school or on a weekend
## until their curfew. Ask through their People menu ("p:hang:<id>"); they follow you through town and into the
## school (PartyNPC), banter, grow closer every 30 minutes (Amane notices), and each brings a gift: Hayate =
## loyalty (cats don't report you), Hina = truth (people warm up faster; she tells you something true), Mio =
## curiosity (night spirits show early; she tells you a story), Reiji = rules (cutting class isn't marked; a
## council pass). State in Game.flags["party"] (members are dropped at a new day).

const IDS := ["hayate", "hina", "mio", "reiji"]

var data := {}
var _rng := RandomNumberGenerator.new()
var _chat_t := 30.0
var _last_tick := -1


func _ready() -> void:
	if FileAccess.file_exists("res://data/party.json"):
		var parsed = JSON.parse_string(FileAccess.get_file_as_string("res://data/party.json"))
		data = parsed if parsed is Dictionary else {}
	_rng.randomize()
	Clock.minute_passed.connect(_on_minute)


func st() -> Dictionary:
	if not (Game.flags.get("party") is Dictionary):
		Game.flags["party"] = {}
	var s: Dictionary = Game.flags["party"]
	if int(s.get("day", -1)) != Clock.day():
		s["day"] = Clock.day()
		s["members"] = []
		s["asked"] = {}
	if not s.has("hung"):
		s["hung"] = {}
	return s


func members() -> Array:
	return st()["members"]


func has(id: String) -> bool:
	return members().has(id)


func member(id: String) -> Dictionary:
	return data.get("members", {}).get(id, {})


## Can you ask `id` to hang out right now? "" = yes, else the reason.
func can_join(id: String) -> String:
	if not id in IDS or has(id):
		return "no"
	if members().size() >= int(data.get("max", 2)):
		return "full"
	if People.escorting(id):
		return "busy"
	var m := Clock.minute()
	var start := 600 if Clock.is_weekend() else 920
	if m < start or m >= curfew(id) - 20:
		return "time"
	if bool(Week.day_data().get("holiday", false)) and m < 600:
		return "time"
	return ""


func curfew(id: String) -> int:
	return mini(int(data.get("curfew", 1230)), maxi(int(People.profile(id).get("home_leave", 1080)) + 120, 1170))


func menu_items(id: String) -> Array:
	if not id in IDS or Game.flags.has("cat_night"):
		return []
	if has(id):
		return [{"id": "p:part:" + id, "text": "\"I'll head off on my own now.\""}]
	if can_join(id) == "":
		return [{"id": "p:hang:" + id, "text": "\"Want to hang out for a bit?\""}]
	return []


func run_item(what: String, id: String, hud: Node) -> void:
	var m := member(id)
	var who := People.short(id)
	match what:
		"hang":
			if People.close(id) < int(data.get("need", 30)):
				await hud.say(who, str(m.get("no", "")) + "\n> Not close enough yet (%d / %d)." % [People.close(id), int(data.get("need", 30))])
				return
			if can_join(id) != "":
				return
			join(id)
			await hud.say(who, str(m.get("yes", "")) + "\n> %s is hanging out with you until %s. Gift: %s - %s" % [who,
				Clock.time_text(curfew(id)), str(m.get("gift", "")), str(m.get("passive", ""))])
		"part":
			leave(id, "part")
			await hud.say(who, str(m.get("part", "")))


func join(id: String) -> void:
	var s := st()
	if has(id):
		return
	(s["members"] as Array).append(id)
	s["hung"][id] = int(s["hung"].get(id, 0)) + 1
	_last_tick = Clock.minute()
	var lvl := _level()
	if lvl:
		spawn_one(lvl, id, (s["members"] as Array).size() - 1)


## Someone goes home: "part" (you split up), "curfew" (time to go), "day" (a new day).
func leave(id: String, why: String = "part") -> void:
	var s := st()
	(s["members"] as Array).erase(id)
	for n in get_tree().get_nodes_in_group("party"):
		if str(n.get("person")) == id and n.has_method("leave"):
			var p := get_tree().get_first_node_in_group("player") as Node3D
			n.leave(n.global_position - (p.global_position if p else n.global_position))
	if why == "curfew":
		var hud := _hud()
		if hud and hud.has_method("toast"):
			hud.toast("%s: %s" % [People.short(id), str(member(id).get("bye", ""))], Color(1.0, 0.9, 0.75))


## Each level calls this after it is built: today's companions appear beside you.
func spawn_in(lvl: Node) -> void:
	if Game.flags.has("cat_night") or Game.flags.has("in_ura"):
		return
	var i := 0
	for id in members():
		spawn_one(lvl, str(id), i)
		i += 1


func spawn_one(lvl: Node, id: String, slot: int) -> Node:
	var actors = lvl.get("actors")
	var p := get_tree().get_first_node_in_group("player") as Node3D
	if actors == null or p == null:
		return null
	for n in get_tree().get_nodes_in_group("party"):
		if str(n.get("person")) == id and not n.get("leaving"):
			return n
	var c = load("res://scenes/actors/npc.tscn").instantiate()
	c.set_script(load("res://src/actors/party_npc.gd"))
	c.person = id
	c.follow_offset = Vector3(-1.1, 0, 0.9) if slot == 1 else Vector3(1.0, 0, 0.6)
	actors.add_child(c)
	var at: Vector3 = p.global_position + c.follow_offset * 1.6
	if lvl.has_method("nearest_walkable"):
		at = lvl.nearest_walkable(at)
	c.global_position = at + Vector3(0, 0.05, 0)
	return c


# --- Time: closeness, Amane, curfew, chatter -----------------------------------------------------

func _on_minute(m: int) -> void:
	if members().is_empty() or Game.flags.has("cat_night"):
		return
	for id in members().duplicate():
		if m >= curfew(str(id)):
			leave(str(id), "curfew")
	if _last_tick < 0 or m < _last_tick:
		_last_tick = m
	if m - _last_tick >= 30:
		_last_tick = m
		for id in members():
			Amane.add_closeness(People.full_name(str(id)), 2)
		var a := get_tree().get_first_node_in_group("amane") as Node3D
		var p := get_tree().get_first_node_in_group("player") as Node3D
		if a and p and a.visible and Amane.st()["met"] and a.global_position.distance_to(p.global_position) < 14.0 and not members().is_empty():
			Amane.notice_rival(People.full_name(str(members()[0])), a)


func _process(delta: float) -> void:
	if members().is_empty() or not Clock.running:
		return
	_chat_t -= delta
	if _chat_t > 0.0:
		return
	_chat_t = _rng.randf_range(16.0, 28.0)
	var bodies := get_tree().get_nodes_in_group("party")
	if bodies.is_empty():
		return
	if bodies.size() >= 2 and _rng.randf() < 0.35:
		var a: Node = bodies[0]
		var b: Node = bodies[1]
		var key := "%s+%s" % [a.get("person"), b.get("person")]
		var lines: Array = data.get("pairs", {}).get(key, data.get("pairs", {}).get("%s+%s" % [b.get("person"), a.get("person")], []))
		if not lines.is_empty():
			var parts := str(lines[_rng.randi() % lines.size()]).split(" -- ")
			for i in parts.size():
				var who: Node = a if parts[i].begins_with(People.short(str(a.get("person")))) else b
				var t := parts[i].substr(parts[i].find(":") + 1).strip_edges()
				get_tree().create_timer(2.4 * i).timeout.connect(func(): if is_instance_valid(who): who.say(t, 2.3))
			return
	var n: Node = bodies[_rng.randi() % bodies.size()]
	var banter: Array = member(str(n.get("person"))).get("banter", [])
	if not banter.is_empty():
		n.say(Amane.fill(str(banter[_rng.randi() % banter.size()])), 3.0)


# --- Gifts ---------------------------------------------------------------------------------------

## The once-a-day ask: Hayate (loyalty), Hina (truth), Mio (curiosity), Reiji (rules).
func ask_gift(id: String) -> String:
	var s := st()
	if s["asked"].has(id):
		var again: Array = member(id).get("ask", [])
		return Amane.fill(str(again[0])) if not again.is_empty() else "\"Ask me again tomorrow.\""
	s["asked"][id] = true
	match id:
		"hina":
			var tr: Dictionary = data.get("truth", {})
			if Amane.rival() != "" and Amane.st()["met"]:
				return str(tr.get("rival", "")).replace("{rival}", Amane.rival().split(" ")[-1]) + "\n> Amane's plan: step %d of 6" % int(Amane.st()["plan"]["stage"])
			for who in People.IDS:
				if not People.knows(str(who)) and str(who) != "hina":
					var line := People.learn(str(who), "hina")
					return str(tr.get("schedule", "")).replace("{who}", People.short(str(who))).replace("{time}", Clock.time_text(People.leave_min(str(who)))) + "\n" + line
			return str(tr.get("none", ""))
		"mio":
			var cu: Dictionary = data.get("curious", {})
			for k in cu.get("lore", []):
				if not Town.knows(str(k)):
					return str(cu.get("say", "")) + "\n" + Town.remember(str(k))
			return str(cu.get("none", ""))
		"reiji":
			Week.st()["passes"] = int(Week.st().get("passes", 0)) + 1
			return str(data.get("rules", {}).get("say", "")) + "\n> A council pass: one late mark or cut class, excused."
		_:
			var lines: Array = member(id).get("ask", [])
			return Amane.fill(str(lines[_rng.randi() % lines.size()])) if not lines.is_empty() else "..."


## While Reiji is with you (or one of his council passes is in your pocket), a cut class or a late mark isn't
## counted. Using a pass spends it.
func excused() -> bool:
	if has("reiji"):
		return true
	if int(Week.st().get("passes", 0)) > 0:
		Week.st()["passes"] = int(Week.st()["passes"]) - 1
		return true
	return false


func _level() -> Node:
	return get_tree().get_first_node_in_group("level") if is_inside_tree() else null


func _hud() -> Node:
	var l := _level()
	return l.get("hud") if l else null
