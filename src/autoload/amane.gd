extends Node
## Amane's mind (docs/GDD.md 4.3): tears 0-5, this-life vs past-life bond, trust, self, jealousy,
## the route the player is on, his phone messages. Tears drive the town's rain (Suzunari level).
## State lives in Game.flags["amane"] so it is saved with the game. Lines: data/amane.json.

signal changed
signal tears_changed(level: int)
signal message_received(text: String)

const DEFAULTS := {"met": false, "route": "none", "bond_now": 0.0, "bond_past": 100.0, "tears": 0.0,
	"trust": 10.0, "self": 10.0, "jealousy": {}, "rival": "", "blocked": false, "muted": false,
	"unread": 0, "messages": [], "talks": 0, "rain": 0.0, "pending": "", "last_msg": 0,
	"closeness": {}, "plan": {"target": "", "stage": 0, "guarded": false, "warned": false}, "fates": {}, "news": [],
	"ura": [], "cat_reports": 0, "ikiryo_named": false, "woke_crying": false, "lore": {}, "promises": [],
	"topics_today": [], "topics_seen": {}}
const FRIEND := "Inukai Hayate"  ## the week-2 rival unless you got closer to someone else
const TEAR_NAMES := ["calm", "pouting", "teary", "crying", "wailing", "storm"]
const FORECAST := ["Clear", "Clear", "Clouds", "Drizzle", "Rain", "Storm"]
const RAIN := [0.0, 0.0, 0.18, 0.45, 0.78, 1.0]
const ROUTE_NAMES := {"none": "-", "friend": "Friend", "romance": "Romance", "ignore": "Ignore", "boundary": "Boundaries"}

var data: Dictionary = {}
var talk: Dictionary = {}  ## data/amane_talk.json - topics and exact replies
var _rng := RandomNumberGenerator.new()
## What each tone of reply does unless the reply overrides it (fx).
const TONE_FX := {"kind": {"bond_now": 3.0, "tears": -0.6, "trust": 1.0}, "flirt": {"bond_now": 6.0, "tears": -1.0},
	"tease": {"bond_now": 2.0, "tears": 0.3}, "curious": {"trust": 2.0}, "honest": {"trust": 3.0, "bond_now": 1.0},
	"boundary": {"self": 5.0, "tears": 0.4}, "cold": {"bond_now": -3.0, "tears": 1.0, "trust": -2.0},
	"lie": {"trust": -2.0, "bond_now": 1.0}}


func _ready() -> void:
	_rng.randomize()
	var path := "res://data/amane.json"
	if FileAccess.file_exists(path):
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
		if parsed is Dictionary:
			data = parsed
	if FileAccess.file_exists("res://data/amane_talk.json"):
		var t = JSON.parse_string(FileAccess.get_file_as_string("res://data/amane_talk.json"))
		if t is Dictionary:
			talk = t
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
	# Context first (data/amane_openers.json, TownTalk matcher: most specific wins, said lines rest for days).
	if _ctx_openers.is_empty() and FileAccess.file_exists("res://data/amane_openers.json"):
		var d = JSON.parse_string(FileAccess.get_file_as_string("res://data/amane_openers.json"))
		_ctx_openers = d.get("rules", []) if d is Dictionary else []
	if not _ctx_openers.is_empty() and DataDB.theme == "suzunari":
		var l := TownTalk.line_in(_ctx_openers, "")
		if l != "":
			return l
	if lv <= 1 and Clock.is_dusk() and _rng.randf() < 0.6:
		return _pick(data.get("dusk", []))
	if lv <= 1 and data.get("openers_route", {}).has(route()) and _rng.randf() < 0.6:
		return _pick(data["openers_route"][route()])
	return _pick(data.get("openers", {}).get(str(lv), []))


## Choices for HUD.say. The more he cries, the smaller and fainter "reject" gets - and the bigger "kind".
var _ctx_openers: Array = []


func choices() -> Array:
	var lv := tears_level()
	var c: Dictionary = data.get("choices", {})
	var rej: Array = c.get("reject", ["Leave me alone."])
	return [
		{"id": "kind", "text": str(c.get("kind", "Be nice."))},
		{"id": "flirt", "text": str(c.get("flirt", "Flirt."))},
		{"id": "boundary", "text": str(c.get("boundary" if lv <= 1 else "boundary_locked", "Set a boundary.")), "disabled": lv > 1},
		{"id": "reject", "text": str(rej[mini(lv, rej.size() - 1)]), "scale": 1.0 - 0.12 * lv},
	]


## Apply a conversation choice. Returns {"text", "feeling"} for the reply and his body language.
func choose(id: String, decisive: bool = false) -> Dictionary:
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
			nudge_route("friend", 2.0, decisive and route() in ["none", "ignore"])
			text = _pick(resp.get("kind", []))
			feeling = "content" if before.tears >= 3 else "happy"
		"flirt":
			add("tears", -2.0)
			add("bond_now", 9.0)
			nudge_route("romance", 3.0, decisive)
			text = _pick(resp.get("flirt", []))
			feeling = "love"
		"boundary":
			add("tears", 0.7)
			add("self", 8.0)
			add("bond_now", 2.0)
			nudge_route("boundary", 3.0, decisive and route() in ["none", "ignore", "friend"])
			text = _pick(resp.get("boundary", []))
			feeling = "pout"
		"reject":
			add("tears", 1.3)
			add("bond_now", -4.0)
			add("trust", -3.0)
			nudge_route("ignore", 3.0, decisive)
			var lv := tears_level()
			text = _pick(resp.get("reject_wail" if lv >= 4 else ("reject_cry" if lv >= 2 else "reject_soft"), []))
			feeling = "wail" if lv >= 4 else ("cry" if lv >= 2 else "sulk")
	s["talks"] = int(s["talks"]) + 1
	return {"text": text + "\n" + impact(before), "feeling": feeling}


## Route with hysteresis (third review #3: one line used to flip Friend -> Ignore -> Romance). Every choice adds points to
## a route; points fade 15% a night; the route only changes when another one has ROUTE_SET points and leads the
## current one by ROUTE_MARGIN. `decisive` (the story's own questions, e.g. Sunday's "What am I to you?") sets it outright.
const ROUTE_SET := 6.0
const ROUTE_MARGIN := 3.0


func nudge_route(to: String, pts: float, decisive: bool = false) -> void:
	var s := st()
	if not s.has("tone_pts") or not (s["tone_pts"] is Dictionary):
		s["tone_pts"] = {}
	var tp: Dictionary = s["tone_pts"]
	tp[to] = float(tp.get(to, 0.0)) + pts
	if decisive:
		tp[to] = maxf(float(tp[to]), ROUTE_SET + ROUTE_MARGIN)
		s["route"] = to
		return
	var cur := route()
	var cur_pts := float(tp.get(cur, 0.0)) if cur != "none" else 0.0
	var best := cur
	var best_pts := cur_pts
	for k in tp:
		if float(tp[k]) > best_pts:
			best = str(k)
			best_pts = float(tp[k])
	if best != cur and best_pts >= ROUTE_SET and best_pts - cur_pts >= ROUTE_MARGIN:
		s["route"] = best


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
## Opener -> pick a topic -> his line -> pick your exact words -> his answer. Up to 3 topics per talk.
func converse(actor: Node3D, hud: Node) -> void:
	var s := st()
	if hud == null:
		return
	Playtest.scene("Talk: Amane")
	if not s["met"]:
		s["met"] = true
		Ledger.capture("The boy at the gate")  # for the Johari mirror
		for l in data.get("first_meeting", []):
			await hud.say(fill(str(l[0])), fill(str(l[1])))
		set_tears(2.2)
		Emotion.express(actor, "cry", 3.0)
		return
	var text := opener()
	var feel := ""
	var shown := false  # has `text` already been on screen (with a menu under it)?
	for round in 3:
		var menu := topic_choices()
		if menu.is_empty():
			break
		menu.append({"id": "bye", "text": _pick(talk.get("bye", ["\"Bye.\""]))})
		var topic: String = await hud.say("Amane", text, menu)
		shown = true
		if topic == "bye" or topic == "" or not talk.get("topics", {}).has(topic):
			break
		(s["topics_today"] as Array).append(topic)
		var t: Dictionary = talk["topics"][topic]
		var again := asked_before(topic)
		s["topics_seen"][topic] = Clock.day()
		var reply: String = await hud.say("Amane", (again + "\n" if again != "" else "") + fill(_pick(t.get("a", ["..."]))), reply_choices(topic))
		var r := answer(topic, int(reply) if reply.is_valid_int() else 0)
		Clock.spend(5)
		text = str(r.text)
		feel = str(r.feel)
		shown = false
	var fw: Dictionary = talk.get("farewell", {})
	var lv := tears_level()
	var bye := _pick(fw.get("4" if lv >= 4 else ("2" if lv >= 2 else "0"), ["..."]))
	await hud.say("Amane", bye if shown else text + "\n\n" + bye)  # "Later." used to repeat his last answer
	if feel != "":
		Emotion.express(actor, feel, 3.2)


## Requirement check for topics and replies (see data/amane_talk.json _doc).
func ok(when: Dictionary) -> bool:
	var s := st()
	for k in when:
		var v = when[k]
		if k == "min_bond" and float(s["bond_now"]) < float(v):
			return false
		elif k == "min_trust" and float(s["trust"]) < float(v):
			return false
		elif k == "min_self" and float(s["self"]) < float(v):
			return false
		elif k == "min_day" and Clock.day() < int(v):
			return false
		elif k == "min_tears" and tears_level() < int(v):
			return false
		elif k == "max_tears" and tears_level() > int(v):
			return false
		elif k == "route" and route() != str(v):
			return false
		elif k == "not_route" and route() == str(v):
			return false
		elif k == "rival" and (str(s["rival"]) != "") != bool(v):
			return false
		elif k == "stage_min" and int(s["plan"]["stage"]) < int(v):
			return false
		elif k == "lore" and not s["lore"].has(str(v)):
			return false
		elif k == "no_lore" and s["lore"].has(str(v)):
			return false
		elif k == "period" and not (v as Array).has(Clock.period()):
			return false
		elif k == "dusk" and Clock.is_dusk() != bool(v):
			return false
		elif k == "flag" and not bool(Game.flags.get(str(v), false)):
			return false
		elif k == "no_flag" and bool(Game.flags.get(str(v), false)):
			return false
		elif k == "routes" and not (v as Array).has(route()):
			return false
		elif k == "max_bond" and float(s["bond_now"]) > float(v):
			return false
		elif k == "min_lore_count" and (s["lore"] as Dictionary).size() < int(v):
			return false
		elif k == "max_close":
			for who in v:
				if int(s["closeness"].get(str(who), 0)) > int(v[who]):
					return false
		elif k == "min_close":
			for who in v:
				if int(s["closeness"].get(str(who), 0)) < int(v[who]):
					return false
	return true


## Up to 4 topics for today: urgent ones first (jealousy, the black cat, rain), then a shuffle of the rest.
## Topics he can be asked now. Story beats are asked once per life (ONCE); everyday topics come back after
## COOLDOWN days (and he notices: "you asked me that yesterday"); situational ones (rain, rival...) every day.
const ONCE := ["mother", "promise", "dreams", "steps", "festival", "bell", "grandma", "hoodie", "senpai"]
const DAILY := ["rain", "rival", "blackcat", "bento"]
const COOLDOWN := 3


func topic_choices() -> Array:
	var s := st()
	var seen: Dictionary = s["topics_seen"]
	var urgent := []
	var rest := []
	for id in talk.get("topics", {}):
		if (s["topics_today"] as Array).has(id):
			continue
		if seen.has(id):
			if id in ONCE:
				continue
			if not id in DAILY and Clock.day() - int(seen[id]) < COOLDOWN:
				continue
		var t: Dictionary = talk["topics"][id]
		if not ok(t.get("when", {})):
			continue
		var c := {"id": id, "text": fill(str(t.get("menu", id)))}
		if id in ["rival", "blackcat", "rain", "promise", "dreams"]:
			urgent.append(c)
		else:
			rest.append(c)
	rest.shuffle()
	var out := urgent + rest
	return out.slice(0, 4)


## Asked before (cooldown topics): his "you asked me that ..." line, "" the first time.
func asked_before(topic: String) -> String:
	var seen: Dictionary = st()["topics_seen"]
	if not seen.has(topic) or topic in DAILY:
		return ""
	var ago := Clock.day() - int(seen[topic])
	var when := "yesterday" if ago <= 1 else ("the other day" if ago <= 4 else "last week")
	return _pick(talk.get("again", [])).replace("{when}", when)


## The exact words you can say, in an order that changes every day (so the slot gives nothing away).
## While he cries, cold words shrink and fade - the only size difference.
func reply_choices(topic: String) -> Array:
	var out := []
	var lv := tears_level()
	var replies: Array = talk.get("topics", {}).get(topic, {}).get("replies", [])
	for i in replies.size():
		var r: Dictionary = replies[i]
		if not ok(r.get("when", {})):
			continue
		var c := {"id": str(i), "text": fill(str(r.get("t", "...")))}
		var tm := Toru.tears_mult()  # soft-hearted: his tears hit you x1.5
		var k := float(lv - 1) * tm if lv >= 2 else (0.6 if tm > 1.2 and lv >= 1 else 0.0)
		if str(r.get("tone", "")) == "cold" and k > 0.0:
			c["scale"] = maxf(0.45, 1.0 - 0.14 * k)
		out.append(c)
	var order := RandomNumberGenerator.new()
	order.seed = hash("%s:%d:%d" % [topic, Clock.day(), int(st()["talks"])])
	for i in range(out.size() - 1, 0, -1):
		var j := order.randi_range(0, i)
		var tmp = out[i]
		out[i] = out[j]
		out[j] = tmp
	return out


## His answer to reply #idx of a topic: effects, route, lore, promises -> {"text", "feel"}.
func answer(topic: String, idx: int) -> Dictionary:
	var s := st()
	var replies: Array = talk.get("topics", {}).get(topic, {}).get("replies", [])
	if idx < 0 or idx >= replies.size():
		return {"text": "...", "feel": ""}
	var r: Dictionary = replies[idx]
	var tone := str(r.get("tone", "kind"))
	var before := {"tears": tears_level(), "bond": int(s["bond_now"]), "route": route()}
	var fx: Dictionary = (TONE_FX.get(tone, {}) as Dictionary).duplicate()
	fx.merge(r.get("fx", {}), true)
	for k in fx:
		if k == "jealousy":
			var j: Dictionary = s["jealousy"]
			var who := str(s["rival"])
			if who != "":
				j[who] = maxi(0, int(j.get(who, 0)) + int(fx[k]))
		elif k == "hp":
			Game.hp = minf(Game.max_hp(), Game.hp + float(fx[k]))
		elif s.has(k):
			add(k, float(fx[k]) * Toru.tone_mult(tone))  # personality: kind / sharp / indifferent words land differently
	match tone:
		"flirt":
			nudge_route("romance", 2.0)
		"tease":
			nudge_route("romance", 0.5)
		"kind":
			nudge_route("friend", 1.5)
		"curious", "honest":
			nudge_route("friend", 0.5)
		"boundary":
			nudge_route("boundary", 2.0)
		"cold":
			nudge_route("ignore", 2.0)
	var extra := ""
	if r.has("lore") and not s["lore"].has(str(r.lore)):
		s["lore"][str(r.lore)] = true
		extra = "\n> Remembered: %s" % Town.lore_title(str(r.lore))
	if r.has("promise") and not (s["promises"] as Array).has(str(r.promise)):
		(s["promises"] as Array).append(str(r.promise))
		extra += "\n> A promise was made. Enma's Ledger wrote it down."
	var says: Array = r.get("say", ["..."])
	if tone == "cold" and tears_level() >= 3 and r.has("say_crying"):
		says = r["say_crying"]
	s["talks"] = int(s["talks"]) + 1
	changed.emit()
	return {"text": fill(_pick(says)) + "\n" + impact(before) + extra, "feel": str(r.get("feel", ""))}


# --- Phone (Rinrin) ----------------------------------------------------------------------

func send(mood: String) -> void:
	var s := st()
	send_text(_pick(data.get("phone", {}).get(mood, [])))


## Push one message from Amane to the Rinrin phone.
func send_text(t: String) -> void:
	var s := st()
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
		set_tears(float(s["tears"]) - 0.02 * Toru.calm())
	s["rain"] = move_toward(float(s["rain"]), rain_target(), 0.03)
	if s["met"] and not s["blocked"] and m - int(s["last_msg"]) >= 45 and _rng.randf() < 0.25:
		var mood := "sad" if tears_level() >= 2 else ("jealous" if str(s["rival"]) != "" and _rng.randf() < 0.4 else "clingy")
		send(mood)


func _new_day(_d: int) -> void:
	var s := st()
	if s.get("tone_pts") is Dictionary:
		for k in s["tone_pts"]:
			s["tone_pts"][k] = float(s["tone_pts"][k]) * 0.85  # old feelings fade; the route itself stays
	_ikiryo_night()
	if Clock.weekday() == "Mon":
		pick_rival()
	if s["woke_crying"]:
		s["woke_crying"] = false
		s["tears"] = float(s["tears"]) + 2.0
	set_tears(float(s["tears"]) * 0.5 + (1.0 if s["muted"] and int(s["unread"]) > 2 else 0.0))
	s["rain"] = rain_target()
	s["talks"] = 0
	s["topics_today"] = []
	s["jealousy"] = {}
	s["rival"] = ""
	if s["blocked"]:
		s["blocked"] = false


## The world calls this every morning: returns a scene note (e.g. the doorstep visit) or "".
func morning_event() -> String:
	var s := st()
	var notes: Array[String] = []
	if str(s["pending"]) == "doorstep":
		s["pending"] = ""
		set_tears(3.0)
		notes.append(str(data.get("doorstep", "")))
	for n in s["news"]:
		notes.append(str(n))
	s["news"] = []
	return "\n\n".join(notes)


## Bystander verbs (Interactions): if Amane can see you get close to someone else, he notices.
func _on_interaction(_verb: String, success: bool, npc: Node) -> void:
	if not success or npc == null or npc.is_in_group("amane"):
		return
	add_closeness(str(npc.get("npc_name")), 4)
	if not st()["met"]:
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
	if _rng.randf() < 0.3:
		post("rival", who)
	if actor != null:
		Emotion.express(actor, "pout" if int(j[who]) < 30 else "yandere", 2.8)
		if actor.has_method("say"):
			actor.say(_pick(data.get("jealous_bark", ["..."])), 2.2)


## Objective line for the HUD while in Suzunari.
func objective_text() -> String:
	if Game.flags.has("cat_night"):
		var lvl := get_tree().get_first_node_in_group("level")
		if lvl and lvl.has_method("cat_objective"):
			return lvl.cat_objective()
	var w := Week.objective()
	var base := _objective_base()
	return base if w == "" else w + "\n" + base


func _objective_base() -> String:
	var s := st()
	if not s["met"]:
		return "Go to school. (Someone is waiting at the gate.)"
	if Clock.minute() >= Clock.NIGHT:
		return "Go home before it gets late. (Phone: end the day)"
	var r: String = ROUTE_NAMES.get(route(), "-")
	var rt := "" if r == "-" else " · Route: " + r
	return "%s · %s%s · Forecast: %s" % [Clock.period(), "Amane is " + TEAR_NAMES[tears_level()], rt, FORECAST[tears_level()]]


# --- Rivals and the living spirit (生霊) --------------------------------------------------
## Each Monday Amane fixes on whoever got closest to Senpai. Every night his jealousy walks out of
## his body as a black cat with two tails and takes the next step (docs/GDD.md 4.3) - unless the rival
## was warned, Senpai watched the rooftops, or Amane is secure enough in himself (self >= 55).

func add_closeness(who: String, v: int) -> void:
	if who == "" or who == "Amane":
		return
	var c: Dictionary = st()["closeness"]
	if v > 0:
		v = maxi(1, roundi(v * Toru.close_mult()))  # charm warms people faster; being see-through slows it
	c[who] = int(c.get(who, 0)) + v


func rival() -> String:
	return str(st()["plan"]["target"])


func fate(who: String) -> String:
	return str(st()["fates"].get(who, ""))


func pick_rival() -> String:
	var s := st()
	var best := FRIEND if fate(FRIEND) == "" else ""
	var best_v := 25 + int(s["closeness"].get(FRIEND, 0)) if best != "" else -1
	for who in s["closeness"]:
		if fate(str(who)) in ["injured", "hidden"]:
			continue
		var v := int(s["closeness"][who])
		if v > best_v:
			best = str(who)
			best_v = v
	s["plan"] = {"target": best, "stage": 0, "guarded": false, "warned": false}
	if best != "":
		s["rival"] = best
	return best


func _ikiryo_night() -> void:
	var s := st()
	var p: Dictionary = s["plan"]
	if p.get("cat_decided", false):
		p.erase("cat_decided")  # Senpai walked as the cat tonight and decided (cat_outcome)
		return
	var who := str(p.get("target", ""))
	if who == "" or fate(who) in ["injured", "hidden"]:
		return
	if float(s["self"]) >= 55.0:
		s["news"].append(str(data.get("calm_night", "")))
		return
	if p.get("guarded", false):
		p["guarded"] = false
		s["news"].append(fill(str(data.get("guarded_night", ""))).replace("{rival}", who))
		add("self", 3.0)
		return
	var step := 1
	if route() == "romance" and _rng.randf() < 0.4:
		step += 1
	if Clock.weekday() == "Sat" and int(p["stage"]) >= 2:
		step += 1  # Friday night is the deadline
	p["stage"] = mini(6, int(p["stage"]) + step)
	apply_stage(who, int(p["stage"]))


func apply_stage(who: String, stage: int) -> void:
	var s := st()
	s["news"].append(str(data.get("stages", {}).get(str(stage), "")).replace("{rival}", who))
	post("stage", who)
	match stage:
		4:
			s["fates"][who] = "cut"
			s["closeness"][who] = 0
		5:
			s["fates"][who] = "injured"
		6:
			s["fates"][who] = "hidden"
			s["news"].append(str(Week.ura.get("hidden", {}).get("hint", "")))


## A cat spirit night tonight (docs/GDD.md 4.11)? High jealousy (or tears), a plan still running, Amane not yet
## secure, the rival not warned or watched, week 2 on, once a week.
func cat_night_due() -> bool:
	var s := st()
	var p: Dictionary = s["plan"]
	var who := rival()
	if not s["met"] or who == "" or fate(who) in ["injured", "hidden"] or int(p["stage"]) >= 6:
		return false
	if float(s["self"]) >= 55.0 or p.get("guarded", false) or Week.week_no() < 2 or Game.flags.has("in_ura"):
		return false
	if (s.get("cat_weeks", []) as Array).has(Week.week_no()):
		return false
	return int(s["jealousy"].get(who, 0)) >= 20 or tears_level() >= 3


## What Senpai decided as the cat: plan (the next stage now; jealousy and tears ease, his self falls) | dawn | skip
## (same, the cat went on alone) | resist (no stage; self +8, he wakes up crying) | window (no stage; a gentler night).
func cat_outcome(kind: String, morning: String = "") -> void:
	var s := st()
	var p: Dictionary = s["plan"]
	var weeks: Array = s.get("cat_weeks", [])
	weeks.append(Week.week_no())
	s["cat_weeks"] = weeks
	p["cat_decided"] = true
	var who := rival()
	match kind:
		"resist":
			add("self", 8.0)
			s["woke_crying"] = true
			s["lore"]["ikiryo"] = true
		"window":
			add("self", 3.0)
			add("bond_past", 2.0)
			set_tears(maxf(0.0, float(s["tears"]) - 1.0))
		_:
			p["stage"] = mini(6, int(p["stage"]) + 1)
			apply_stage(who, int(p["stage"]))
			s["jealousy"] = {}
			set_tears(float(s["tears"]) * 0.5)
			add("self", -3.0)
	if morning != "":
		s["news"].append(morning)
	var log: Array = Game.flags.get("cat_night_log", [])
	log.append({"day": Clock.day(), "rival": who, "outcome": kind, "stage": int(p["stage"])})
	Game.flags["cat_night_log"] = log
	changed.emit()


## Senpai walked someone the cat hid back down the thousandth step (Ura-Suzunari): they're home ("rescued"),
## closer to you, and the plan against them is over. Amane cried - and was relieved.
func rescue(who: String, news: String = "") -> void:
	var s := st()
	s["fates"][who] = "rescued"
	add_closeness(who, 10)
	if rival() == who:
		s["plan"] = {"target": "", "stage": 0, "guarded": false, "warned": false}
	add("self", 6.0)
	add("tears", 1.0)
	s["lore"]["dusk_side"] = true
	if news != "":
		s["news"].append(news)
	Ledger.deed("rescue", who)
	changed.emit()


## Senpai warned the rival (Hayate's "be careful around cats"): tonight the cat turns back at the window.
func warn(who: String) -> bool:
	var p: Dictionary = st()["plan"]
	if str(p.get("target", "")) != who:
		return false
	p["guarded"] = true
	var first: bool = not p.get("warned", false)
	p["warned"] = true
	return first


## Night watch from the phone (after 21:00): chase | name | let_go.
func night_choice(id: String) -> String:
	var s := st()
	var p: Dictionary = s["plan"]
	var w: Dictionary = data.get("night_watch", {})
	match id:
		"chase":
			p["guarded"] = true
			s["woke_crying"] = true
		"name":
			p["guarded"] = true
			s["ikiryo_named"] = true
			add("self", 10.0)
		"let_go":
			var j: Dictionary = s["jealousy"]
			j[rival()] = maxi(0, int(j.get(rival(), 0)) - 10)
	return fill(str(w.get(id, "")))


# --- The school's anonymous board (裏サイト) ------------------------------------------------

func post(kind: String, who: String = "", place: String = "") -> void:
	var s := st()
	var t := _pick(data.get("ura", {}).get(kind, []))
	if t == "":
		return
	t = t.replace("{rival}", who if who != "" else str(s["rival"])).replace("{place}", place if place != "" else "corridor")
	var u: Array = s["ura"]
	u.append({"day": Clock.date_text(), "time": Clock.clock_text(), "text": t})
	while u.size() > 40:
		u.pop_front()
	changed.emit()
