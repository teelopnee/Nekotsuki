extends Node
## Home visits, morning pick-ups and walking people home (data/people/<id>.json, docs/GDD.md 4.6).
## Every named friend has a house, a parent who answers the bell, a morning schedule (leave home -> arrive at
## school) you only learn by asking once you're close, or by buying it from Sato Yui (or trading Mio a ghost
## story), and 200+ lines of their own. Closeness is Amane's `closeness` table (bond_now for Amane himself), so
## pick-ups feed the weekly rival pick. The level node HomeVisits (src/world/home_visits.gd) runs the doors and
## the escorts; this autoload keeps the state (Game.flags["people"]) and the words.

signal changed

const IDS := ["hayate", "hina", "mio", "reiji", "amane"]
const DEFAULTS := {"known": {}, "pickups": {}, "walks": {}, "today": {}, "promise": {}, "broken": {},
	"pickup_me": {}, "escort": {}, "trades": 0}
## Closeness needed to ask for a schedule, to walk someone home, for them to offer to walk you / pick you up.
const NEED_ASK := 35
const NEED_WALK := 25
const NEED_OFFER := 45
const NEED_PICKUP_OFFER := 55
const BROKER_PRICE := 5  ## x 100 yen

var data: Dictionary = {}
var _recent: Dictionary = {}
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	for id in IDS:
		var path := "res://data/people/%s.json" % id
		if FileAccess.file_exists(path):
			var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
			if parsed is Dictionary:
				data[id] = parsed
	Clock.day_started.connect(_new_day)


func st() -> Dictionary:
	if not Game.flags.has("people") or not (Game.flags["people"] is Dictionary):
		Game.flags["people"] = DEFAULTS.duplicate(true)
	var s: Dictionary = Game.flags["people"]
	for k in DEFAULTS:
		if not s.has(k):
			s[k] = DEFAULTS[k].duplicate(true) if DEFAULTS[k] is Dictionary else DEFAULTS[k]
	return s


func _new_day(d: int) -> void:
	var s := st()
	s["today"] = {}
	s["escort"] = {}
	var pm: Dictionary = s["pickup_me"]
	if not pm.is_empty() and int(pm.get("day", 0)) < d:
		s["pickup_me"] = {}


# --- Who and how close ------------------------------------------------------------------------

func profile(id: String) -> Dictionary:
	return data.get(id, {}).get("profile", {})


func full_name(id: String) -> String:
	return str(profile(id).get("name", id.capitalize()))


func short(id: String) -> String:
	return str(profile(id).get("short", id.capitalize()))


## npc_name -> id ("Inukai Hayate" -> "hayate"), "" for anyone without a house.
func id_of(npc_name: String) -> String:
	for id in data:
		if full_name(id) == npc_name or short(id) == npc_name:
			return id
	return ""


func close(id: String) -> int:
	if id == "amane":
		return int(float(Amane.st()["bond_now"]))
	return int(Amane.st()["closeness"].get(full_name(id), 0))


func add_close(id: String, v: int) -> void:
	if v == 0:
		return
	if id == "amane":
		Amane.add("bond_now", float(v))
	else:
		Amane.add_closeness(full_name(id), v)
	changed.emit()


func tier(id: String) -> String:
	var c := close(id)
	if id == "amane":
		return "high" if c >= 45 else ("mid" if c >= 15 else "low")
	return "high" if c >= 50 else ("mid" if c >= 20 else "low")


func fx(id: String, key: String) -> int:
	return int(profile(id).get("fx", {}).get(key, 0))


# --- Schedules -----------------------------------------------------------------------------------

func leave_min(id: String) -> int:
	return int(profile(id).get("leave", 470))


func arrive_min(id: String) -> int:
	return int(profile(id).get("arrive", 490))


func home_min(id: String) -> int:
	return int(profile(id).get("home_leave", 1050))


func door(id: String) -> Vector2i:
	var d: Array = profile(id).get("door", [0, 0])
	return Vector2i(int(d[0]), int(d[1]))


func knows(id: String) -> bool:
	return st()["known"].has(id)


## Remember someone's morning -> "> Notes: ..." line.
func learn(id: String, how: String) -> String:
	if knows(id):
		return ""
	st()["known"][id] = how
	changed.emit()
	return "> Notes: %s leaves home at %s and reaches school at %s." % [short(id), Clock.time_text(leave_min(id)), Clock.time_text(arrive_min(id))]


func today(id: String) -> Dictionary:
	var t: Dictionary = st()["today"]
	if not t.has(id):
		t[id] = {}
	return t[id]


## "morning" (still at home), "away" (at school / on the road), "evening" (back home), "weekend".
func status(id: String, m: int = -1) -> String:
	var t := Clock.minute() if m < 0 else m
	if Clock.is_weekend():
		return "weekend"
	if bool(today(id).get("home", false)) or t >= home_min(id) + 20:
		return "evening"
	if t < leave_min(id) and not bool(today(id).get("out", false)):
		return "morning"
	return "away"


func escort() -> Dictionary:
	return st()["escort"]


func escorting(id: String = "") -> bool:
	var e := escort()
	return not e.is_empty() and (id == "" or str(e.get("who", "")) == id)


## True while this person's usual body (Hayate in the courtyard, Hina at the gate...) should be hidden:
## they're walking with you, already home for the day, or not out of the house yet. Amane: only before he
## leaves home in the morning, or after you walked him home (otherwise he is wherever Senpai is).
func hides(id: String, m: int = -1) -> bool:
	if not data.has(id):
		return false
	var t := Clock.minute() if m < 0 else m
	if id == "amane":
		if not Amane.st()["met"] or escorting("amane"):
			return false
		var sa := status(id, t)
		return sa == "morning" or bool(today(id).get("home", false))
	if escorting(id):
		return true
	var s := status(id, t)
	if s == "evening":
		return true
	return s == "morning" or (s == "away" and t < arrive_min(id) and not bool(today(id).get("arrived", false)))


func start_escort(id: String, mode: String) -> void:
	st()["escort"] = {"who": id, "mode": mode, "day": Clock.day()}
	if mode == "school":
		today(id)["out"] = true
	changed.emit()


func end_escort() -> void:
	st()["escort"] = {}
	changed.emit()


# --- Words ---------------------------------------------------------------------------------------

func fill(t: String) -> String:
	return Amane.fill(t).replace("{who}", "someone")


## A line for `key`: tiered keys first (ring_self -> ring_self_mid), weekday dicts (morning_day), never the
## same line twice in a row. Entries may be {who, t} (a different speaker: the father, the mother...).
func pick(id: String, key: String) -> Dictionary:
	var lines: Dictionary = data.get(id, {}).get("lines", {})
	var arr = lines.get(key + "_" + tier(id), lines.get(key, []))
	if arr is Dictionary:
		arr = arr.get(Clock.weekday(), [])
	if not arr is Array or (arr as Array).is_empty():
		return {"who": short(id), "t": ""}
	var rk := id + ":" + key
	var i: int = _rng.randi() % (arr as Array).size()
	if arr.size() > 1 and i == int(_recent.get(rk, -1)):
		i = (i + 1) % arr.size()
	_recent[rk] = i
	var e = arr[i]
	if e is Dictionary:
		return {"who": str(e.get("who", short(id))), "t": fill(str(e.get("t", "")))}
	return {"who": short(id), "t": fill(str(e))}


func line(id: String, key: String) -> String:
	return str(pick(id, key).t)


## Amane's jealousy lines: jealous.<key>.<id> (falls back to .other), or a flat list.
func jealous(key: String, who: String) -> String:
	var j = data.get("amane", {}).get("jealous", {}).get(key, [])
	if j is Dictionary:
		j = j.get(who, j.get("other", []))
	if not j is Array or (j as Array).is_empty():
		return ""
	return fill(str(j[_rng.randi() % j.size()]))


## The parent's line: their own speaker unless the entry names someone else.
func parent_line(id: String, key: String) -> Dictionary:
	var p := pick(id, key)
	if p.who == short(id):
		p.who = str(profile(id).get("parent", "?"))
	return p


# --- Menus (Town.meet / HayateNPC / Amane.converse add these to their choices) ------------------

## Extra choices for talking to `id` (and to the broker "yui"): [{id, text}]. Ids start with "p:".
func menu_items(id: String) -> Array:
	var out := []
	var m := Clock.minute()
	if id == "yui":
		for who in IDS:
			if not knows(who):
				out.append({"id": "p:buy:" + who, "text": "\"When does %s leave home in the morning?\"  (%s)" % [short(who), DataDB.money(BROKER_PRICE)]})
		return out
	if not data.has(id):
		return out
	if not knows(id):
		out.append({"id": "p:ask:" + id, "text": "\"What time do you leave home in the morning?\""})
	if id == "mio" and int(Amane.st()["lore"].size()) >= 3 + 2 * int(st()["trades"]) and _unknown_other("mio") != "":
		out.append({"id": "p:trade:mio", "text": "Trade Mio a ghost story for someone's morning."})
	if m >= 920 and not escorting() and not bool(today(id).get("walked", false)) and status(id) == "away":
		out.append({"id": "p:walk:" + id, "text": "\"Can I walk you home?\""})
	if bool(today(id).get("broken_told", false)) == false and st()["broken"].has(id):
		out.push_front({"id": "p:sorry:" + id, "text": "\"Sorry I didn't come this morning.\""})
	return out


func _unknown_other(except: String) -> String:
	for who in IDS:
		if who != except and not knows(who):
			return who
	return ""


## Run a "p:" menu item. Returns after the last line was shown.
func run_item(item: String, hud: Node) -> void:
	var parts := item.split(":")
	if parts.size() < 3 or hud == null:
		return
	var what := parts[1]
	var id := parts[2]
	match what:
		"ask":
			var need := 20 if id == "amane" else NEED_ASK
			if close(id) >= need:
				await hud.say(short(id), line(id, "ask_tell") + "\n" + learn(id, "asked"))
			else:
				await hud.say(short(id), line(id, "ask_refuse") + "\n> Not close enough yet (%d / %d)." % [close(id), need])
		"buy":
			var yui := "Sato Yui"
			if Game.credits < BROKER_PRICE:
				await hud.say(yui, "\"No money, no rumours.\" Yui smiles like a class rep and goes back to her phone.")
				return
			Game.credits -= BROKER_PRICE
			await hud.say(yui, "Yui lowers her voice. \"%s\"\n> Spent %s\n%s" % [str(profile(id).get("rumour", "")), DataDB.money(BROKER_PRICE), learn(id, "bought")])
		"trade":
			var who := _unknown_other("mio")
			st()["trades"] = int(st()["trades"]) + 1
			await hud.say(short("mio"), "You tell Mio what you've seen around Suzunari. She listens with her camera running, then leans close.\n\"%s\"\n%s" % [str(profile(who).get("mio_says", "")), learn(who, "traded")])
		"walk":
			var need := 15 if id == "amane" else NEED_WALK
			if close(id) >= need:
				var indoors := get_tree().current_scene != null and get_tree().current_scene.name == "School"
				await hud.say(short(id), line(id, "home_accept") + ("\n> %s will wait for you outside the school door." % short(id) if indoors else ""))
				today(id)["walked"] = true
				start_escort(id, "their_home")
			else:
				await hud.say(short(id), line(id, "home_refuse") + "\n> Not close enough yet (%d / %d)." % [close(id), need])
		"sorry":
			today(id)["broken_told"] = true
			st()["broken"].erase(id)
			await hud.say(short(id), line(id, "promise_broken"))


## Someone close offers to walk YOU home (their own words). Returns true if the offer was shown.
func maybe_offer_home(id: String, hud: Node) -> bool:
	var need := 20 if id == "hayate" else (25 if id == "amane" else NEED_OFFER)
	if not data.has(id):
		return false
	var t := today(id)
	if hud == null or Clock.minute() < 920 or Clock.minute() >= Clock.NIGHT or escorting() or close(id) < need \
			or bool(t.get("offered", false)) or bool(t.get("walked", false)) or status(id) != "away":
		return false
	t["offered"] = true
	var pick_id: String = await hud.say(short(id), line(id, "home_offer"),
		[{"id": "yes", "text": "\"Sure. Let's go.\""}, {"id": "no", "text": "\"I'm fine, thanks.\""}])
	if pick_id == "yes":
		t["walked"] = true
		start_escort(id, "my_home")
		await hud.say(short(id), line(id, "pickup_accept"))
	else:
		await hud.say(short(id), "%s nods. \"Okay. Get home safe, then.\"" % short(id))
	return true


# --- Notes tab -----------------------------------------------------------------------------------

func notes_text() -> String:
	var out: Array[String] = ["MORNINGS (who leaves home when)"]
	for id in IDS:
		var p := profile(id)
		if p.is_empty():
			continue
		var when := "%s -> school %s" % [Clock.time_text(leave_min(id)), Clock.time_text(arrive_min(id))] if knows(id) else "?? (ask when you're close, or ask Sato Yui in 2-B)"
		out.append("  %s - %s: %s  [%s]%s" % [short(id), str(p.get("home", "")), when, tier(id),
			"  picked up %d / walked home %d" % [int(st()["pickups"].get(id, 0)), int(st()["walks"].get(id, 0))] if int(st()["pickups"].get(id, 0)) + int(st()["walks"].get(id, 0)) > 0 else ""])
	var pm: Dictionary = st()["pickup_me"]
	if not pm.is_empty():
		out.append("  Tomorrow morning %s comes to pick you up." % short(str(pm.get("who", ""))))
	return "\n".join(out)
