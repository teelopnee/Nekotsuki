extends Node
## Amane's mind (docs/GDD.md 4.3): tears 0-5, this-life vs past-life bond, trust, self, jealousy,
## the route the player is on, his phone messages. Tears drive the town's rain (Suzunari level).
## State lives in Game.flags["amane"] so it is saved with the game. Lines: data/amane.json.

signal changed
signal tears_changed(level: int)
signal message_received(text: String)

const DEFAULTS := {"met": false, "route": "none", "bond_now": 0.0, "bond_past": 100.0, "tears": 0.0,
	"trust": 10.0, "self": 10.0, "jealousy": {}, "rival": "", "blocked": false, "muted": false,
	"unread": 0, "messages": [], "talks": 0, "rain": 0.0, "pending": "", "last_msg": 0}
const TEAR_NAMES := ["calm", "pouting", "teary", "crying", "wailing", "storm"]
const FORECAST := ["Clear", "Clear", "Clouds", "Drizzle", "Rain", "Storm"]
const RAIN := [0.0, 0.0, 0.18, 0.45, 0.78, 1.0]
const ROUTE_NAMES := {"none": "-", "friend": "Friend", "romance": "Romance", "ignore": "Ignore", "boundary": "Boundaries"}

var data: Dictionary = {}
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	var path := "res://data/amane.json"
	if FileAccess.file_exists(path):
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
		if parsed is Dictionary:
			data = parsed
	Clock.minute_passed.connect(_tick)
	Clock.day_started.connect(_new_day)
	EventBus.interaction_done.connect(_on_interaction)


func st() -> Dictionary:
	if not Game.flags.has("amane") or not Game.flags["amane"] is Dictionary:
		Game.flags["amane"] = DEFAULTS.duplicate(true)
	var s: Dictionary = Game.flags["amane"]
	for k in DEFAULTS:
		if not s.has(k):
			s[k] = DEFAULTS[k].duplicate(true) if DEFAULTS[k] is Dictionary or DEFAULTS[k] is Array else DEFAULTS[k]
	return s


func tears_level() -> int:
	return clampi(int(floor(float(st()["tears"]) + 0.001)), 0, 5)


func rain_target() -> float:
	return RAIN[tears_level()]


func route() -> String:
	return str(st()["route"])


## How far behind Senpai he trails.
func follow_distance() -> float:
	return {"romance": 2.6, "friend": 4.0, "boundary": 6.5, "ignore": 8.0}.get(route(), 5.0)


func add(key: String, v: float, lo: float = 0.0, hi: float = 100.0) -> void:
	var s := st()
	if key == "tears":
		set_tears(float(s["tears"]) + v)
		return
	s[key] = clampf(float(s[key]) + v, lo, hi)
	changed.emit()


func set_tears(v: float) -> void:
	var s := st()
	var before := tears_level()
	s["tears"] = clampf(v, 0.0, 5.4)
	if tears_level() != before:
		tears_changed.emit(tears_level())
	changed.emit()


func _pick(arr) -> String:
	if not arr is Array or (arr as Array).is_empty():
		return ""
	return fill(str(arr[_rng.randi() % arr.size()]))


func fill(t: String) -> String:
	return t.replace("{player}", Game.player_name).replace("{rival}", str(st()["rival"]) if str(st()["rival"]) != "" else "someone")


# --- Conversation --------------------------------------------------------------------------

func opener() -> String:
	var lv := tears_level()
	if lv <= 1 and Clock.is_dusk() and _rng.randf() < 0.6:
		return _pick(data.get("dusk", []))
	if lv <= 1 and data.get("openers_route", {}).has(route()) and _rng.randf() < 0.6:
		return _pick(data["openers_route"][route()])
	return _pick(data.get("openers", {}).get(str(lv), []))


## Choices for HUD.say. The more he cries, the smaller and fainter "reject" gets - and the bigger "kind".
func choices() -> Array:
	var lv := tears_level()
	var c: Dictionary = data.get("choices", {})
	var rej: Array = c.get("reject", ["Leave me alone."])
	return [
		{"id": "kind", "text": str(c.get("kind", "Be nice.")), "scale": 1.0 + 0.07 * lv},
		{"id": "flirt", "text": str(c.get("flirt", "Flirt."))},
		{"id": "boundary", "text": str(c.get("boundary" if lv <= 1 else "boundary_locked", "Set a boundary.")), "disabled": lv > 1},
		{"id": "reject", "text": str(rej[mini(lv, rej.size() - 1)]), "scale": 1.0 - 0.12 * lv},
	]


## Apply a conversation choice. Returns {"text", "feeling"} for the reply and his body language.
func choose(id: String) -> Dictionary:
	var s := st()
	var before := {"tears": tears_level(), "bond": int(s["bond_now"]), "route": route()}
	var resp: Dictionary = data.get("responses", {})
	var text := ""
	var feeling := ""
	match id:
		"kind":
			add("tears", -1.5)
			add("bond_now", 5.0)
			add("trust", 3.0)
			if route() in ["none", "ignore"]:
				s["route"] = "friend"
			text = _pick(resp.get("kind", []))
			feeling = "content" if before.tears >= 3 else "happy"
		"flirt":
			add("tears", -2.0)
			add("bond_now", 9.0)
			s["route"] = "romance"
			text = _pick(resp.get("flirt", []))
			feeling = "love"
		"boundary":
			add("tears", 0.7)
			add("self", 8.0)
			add("bond_now", 2.0)
			if route() in ["none", "ignore", "friend"]:
				s["route"] = "boundary"
			text = _pick(resp.get("boundary", []))
			feeling = "pout"
		"reject":
			add("tears", 1.3)
			add("bond_now", -4.0)
			add("trust", -3.0)
			s["route"] = "ignore"
			var lv := tears_level()
			text = _pick(resp.get("reject_wail" if lv >= 4 else ("reject_cry" if lv >= 2 else "reject_soft"), []))
			feeling = "wail" if lv >= 4 else ("cry" if lv >= 2 else "sulk")
	s["talks"] = int(s["talks"]) + 1
	return {"text": text + "\n" + impact(before), "feeling": feeling}


## Odd-Space style "> what changed" block.
func impact(before: Dictionary) -> String:
	var s := st()
	var lines: Array[String] = []
	var lv := tears_level()
	lines.append("> Tears: %s (%s)" % ["*".repeat(lv) + "-".repeat(5 - lv), TEAR_NAMES[lv]])
	lines.append("> Bond (this life) %d -> %d" % [int(before.bond), int(s["bond_now"])])
	if route() != str(before.route):
		lines.append("> Route: %s" % ROUTE_NAMES.get(route(), route()))
	if lv != int(before.tears):
		lines.append("> Weather: %s" % ("the rain eases" if lv < int(before.tears) else "the sky darkens over Suzunari"))
	return "\n".join(lines)


## Full conversation with the actor in the world. `hud` is the level HUD (await-able say()).
func converse(actor: Node3D, hud: Node) -> void:
	var s := st()
	if hud == null:
		return
	if not s["met"]:
		s["met"] = true
		for l in data.get("first_meeting", []):
			await hud.say(fill(str(l[0])), fill(str(l[1])))
		set_tears(2.2)
		Emotion.express(actor, "cry", 3.0)
		return
	var picked: String = await hud.say("Amane", opener(), choices())
	var r := choose(picked)
	await hud.say("Amane", str(r.text))
	Emotion.express(actor, str(r.feeling), 3.2)


# --- Phone (Rinrin) ----------------------------------------------------------------------

func send(mood: String) -> void:
	var s := st()
	var t := _pick(data.get("phone", {}).get(mood, []))
	if t == "":
		return
	var msgs: Array = s["messages"]
	msgs.append({"time": Clock.clock_text(), "text": t, "from": "amane"})
	while msgs.size() > 30:
		msgs.pop_front()
	s["unread"] = int(s["unread"]) + 1
	s["last_msg"] = Clock.minute()
	message_received.emit(t)
	changed.emit()


## Reply from the phone panel: reply | read | mute | block. Returns the consequence line.
func phone_reply(kind: String) -> String:
	var s := st()
	var unread := int(s["unread"])
	s["unread"] = 0
	match kind:
		"reply":
			(s["messages"] as Array).append({"time": Clock.clock_text(), "text": "Go to sleep, Amane.", "from": "me"})
			add("bond_now", 3.0)
			add("tears", -0.6)
			s["muted"] = false
			send("happy")
			s["unread"] = 0
			return "He answers in four seconds. Bond +3. Tomorrow there will be a bento in your shoe locker."
		"read":
			if unread > 0:
				add("tears", 0.8)
			return "\"Read\" appears under his messages. Tears +1. He will notice. He always notices."
		"mute":
			s["muted"] = true
			return "Notifications off. You get some peace. He doesn't know yet. (This time.)"
		"block":
			s["blocked"] = true
			add("trust", -8.0)
			s["pending"] = "doorstep"
			return "Blocked. Tomorrow morning he will be waiting outside the sweet shop."
	return ""


# --- Time ---------------------------------------------------------------------------------

func _tick(m: int) -> void:
	var s := st()
	if float(s["tears"]) > 0.0:
		set_tears(float(s["tears"]) - 0.02)
	s["rain"] = move_toward(float(s["rain"]), rain_target(), 0.03)
	if s["met"] and not s["blocked"] and m - int(s["last_msg"]) >= 45 and _rng.randf() < 0.25:
		var mood := "sad" if tears_level() >= 2 else ("jealous" if str(s["rival"]) != "" and _rng.randf() < 0.4 else "clingy")
		send(mood)


func _new_day(_d: int) -> void:
	var s := st()
	set_tears(float(s["tears"]) * 0.5 + (1.0 if s["muted"] and int(s["unread"]) > 2 else 0.0))
	s["rain"] = rain_target()
	s["talks"] = 0
	s["jealousy"] = {}
	s["rival"] = ""
	if s["blocked"]:
		s["blocked"] = false


## The world calls this every morning: returns a scene note (e.g. the doorstep visit) or "".
func morning_event() -> String:
	var s := st()
	if str(s["pending"]) == "doorstep":
		s["pending"] = ""
		set_tears(3.0)
		return str(data.get("doorstep", ""))
	return ""


## Bystander verbs (Interactions): if Amane can see you get close to someone else, he notices.
func _on_interaction(_verb: String, success: bool, npc: Node) -> void:
	if not success or npc == null or not st()["met"] or npc.is_in_group("amane"):
		return
	var a := get_tree().get_first_node_in_group("amane") as Node3D
	var p := get_tree().get_first_node_in_group("player") as Node3D
	if a == null or p == null or a.global_position.distance_to(p.global_position) > 14.0:
		return
	notice_rival(str(npc.get("npc_name")), a)


func notice_rival(who: String, actor: Node3D = null) -> void:
	var s := st()
	var j: Dictionary = s["jealousy"]
	j[who] = int(j.get(who, 0)) + (16 if route() == "romance" else 10)
	s["rival"] = who
	add("tears", 0.4)
	if actor != null:
		Emotion.express(actor, "pout" if int(j[who]) < 30 else "yandere", 2.8)
		if actor.has_method("say"):
			actor.say(_pick(data.get("jealous_bark", ["..."])), 2.2)


## Objective line for the HUD while in Suzunari.
func objective_text() -> String:
	var s := st()
	if not s["met"]:
		return "Go to school. (Someone is waiting at the gate.)"
	if Clock.minute() >= Clock.NIGHT:
		return "Go home before it gets late. (Phone: end the day)"
	return "%s · %s · Route: %s · Forecast: %s" % [Clock.period(), "Amane is " + TEAR_NAMES[tears_level()],
		ROUTE_NAMES.get(route(), "-"), FORECAST[tears_level()]]
