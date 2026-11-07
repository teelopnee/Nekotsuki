extends SceneTree
## Home visits (People autoload + HomeVisits): every friend's lines (200+, all keys, no sci-fi leaks), houses and
## doors on the map, mornings at home (Amane / Hayate hidden until they leave), ringing the bell, waiting, the
## walk to school and the arrival, promises kept and broken, asking for schedules (too early / close enough),
## buying them from Sato Yui, Mio's trade, walking someone home, being walked home, being picked up at your own
## door, and Amane's reaction for every route (romance cut-in with every answer).
## godot --headless --path . --script res://tools/people_test.gd   (exit code = failures)

const LEAKS := ["credit", "paragon", "planet", "consortium", "corp", "neon", "drone", "{", "#"]
const KEYS := ["wait_outside", "ring_self_low", "ring_self_mid", "ring_self_high", "ring_parent", "parent_about_you",
	"parent_left", "parent_evening", "come_out_low", "come_out_mid", "come_out_high", "come_out_rushed", "come_out_rain",
	"pickup_accept", "pickup_decline", "walk", "walk_close", "walk_rain", "arrive", "ask_tell", "ask_refuse", "home_offer",
	"home_accept", "home_refuse", "home_walk", "goodbye", "offer_pickup", "at_your_door", "promise_yes", "promise_broken",
	"morning_day"]

var _step := 0
var _wait := 0
var fails := 0


func _check(ok: bool, what: String) -> void:
	if ok:
		print("  ok   ", what)
	else:
		fails += 1
		printerr("  FAIL ", what)


func _buttons(hud) -> Array:
	var out := []
	for b in hud._dialogue_choices.get_children():
		if not b.is_queued_for_deletion():
			out.append(b)
	return out


func _close_all(hud) -> void:
	for _i in 14:
		if not hud._dialogue_open:
			return
		hud._on_choice("")


## Click through plain lines until a button containing `text` shows up; press it. Returns false if it never did.
func _press_text(hud, text: String) -> bool:
	for _i in 10:
		if not hud._dialogue_open:
			return false
		for b in _buttons(hud):
			if str(b.text).contains(text):
				b.pressed.emit()
				return true
		hud._on_choice("")
	return false


func _count(v) -> int:
	if v is Array:
		return (v as Array).size()
	if v is Dictionary:
		var n := 0
		for k in v:
			if not str(k).begins_with("_"):
				n += _count(v[k])
		return n
	return 0


func _leaky(t: String) -> String:
	var low := t.to_lower()
	for w in LEAKS:
		if low.contains(w):
			return w
	return ""


func _process(_d: float) -> bool:
	if _wait > 0:
		_wait -= 1
		return false
	var game = root.get_node("Game")
	var people = root.get_node("People")
	var amane = root.get_node("Amane")
	var clock = root.get_node("Clock")
	var lvl = current_scene
	var hud = lvl.get("hud") if lvl else null
	match _step:
		0:
			game.new_game("People Tester", {}, 9, {}, "", 17)
			game.location_id = "suzunari"
			amane.st()["met"] = true
			amane.st()["route"] = "friend"
			change_scene_to_file("res://scenes/world/suzunari.tscn")
			_wait = 60
		1:
			_close_all(hud)
			_data_checks(people)
			_map_checks(people, lvl)
			_wait = 6
		2:
			_check(people.hides("amane") and not lvl.amane.visible, "Amane is still at home before 7:52")
			var hay = _first_named("Inukai Hayate", false)
			_check(hay != null and not hay.visible, "Hayate isn't in the courtyard before 8:10")
			# Hayate's door, schedule unknown: wait a little, then ring the bell -> pick him up.
			lvl.player.global_position = lvl.builder.center(53, 23) + Vector3(0, 0.1, 0.4)
			lvl.home.visit("hayate")
			_check(hud._dialogue_open and _buttons(hud).size() == 3, "door: ring / wait / leave")
			var m0: int = clock.minute()
			_press_text(hud, "Wait outside")
			_check(clock.minute() == m0 + 5 and hud._dialogue_open, "waiting outside passes 5 minutes")
			var before: int = people.close("hayate")
			_press_text(hud, "Ring the bell")
			_check(_press_text(hud, "walk to school together"), "ringing brings someone to the door and he comes out")
			_close_all(hud)
			_check(people.escorting("hayate") and people.escort().mode == "school", "walking Hayate to school")
			_check(get_nodes_in_group("companion").size() == 1, "Hayate walks beside you")
			_check(people.close("hayate") >= before, "Hayate likes being rushed (%d -> %d)" % [before, people.close("hayate")])
			# Amane, friend route: he trails and barks; ignore: texts; boundary: a brave text; romance: cuts in.
			var j0 := int(amane.st()["jealousy"].get("Inukai Hayate", 0))
			lvl.home._amane_react("hayate")
			_check(int(amane.st()["jealousy"].get("Inukai Hayate", 0)) > j0, "friend route: Amane notices and follows")
			amane.st()["route"] = "ignore"
			var msgs: int = (amane.st()["messages"] as Array).size()
			lvl.home._amane_react("hayate")
			_check((amane.st()["messages"] as Array).size() == msgs + 1, "ignore route: Amane texts instead")
			amane.st()["route"] = "boundary"
			var self0: float = float(amane.st()["self"])
			lvl.home._amane_react("hayate")
			_check(float(amane.st()["self"]) > self0, "boundary route: a brave text, his self-worth grows")
			amane.st()["route"] = "romance"
			amane.st()["bond_now"] = 50.0
			for tone in ["Take his hand", "walk with us", "just friends", "Not now"]:
				lvl.home._amane_react("hayate")
				var shown: bool = hud._dialogue_open and str(hud._dialogue_text.text).length() > 30
				_check(shown and _press_text(hud, tone) and str(hud._dialogue_text.text).contains("> Tears"),
					"romance route: Amane cuts in -> \"%s\" answers + impact" % tone)
				_close_all(hud)
			amane.st()["route"] = "friend"
			lvl.player.global_position = lvl.builder.center(20, 29) + Vector3(0, 0.1, 0)
			_wait = 8
		3:
			_check(hud._dialogue_open and str(hud._dialogue_text.text).contains("> Hayate"), "arrival at school: his line + closeness")
			var promised := _press_text(hud, "Same time tomorrow")
			_close_all(hud)
			_check(not people.escorting() and int(people.st()["pickups"].get("hayate", 0)) == 1, "pick-up counted, escort over")
			_check(not promised or people.st()["promise"].has("hayate"), "a promise for tomorrow is kept in People")
			# Ask for schedules: too early, then close enough; buy from Yui; Mio's trade.
			people.run_item("p:ask:hina", hud)
			_check(not people.knows("hina") and str(hud._dialogue_text.text).contains("Not close enough"), "Hina won't tell a stranger")
			_close_all(hud)
			amane.st()["closeness"]["Hayase Hina"] = 40
			people.run_item("p:ask:hina", hud)
			_check(people.knows("hina") and str(hud._dialogue_text.text).contains("7:55"), "close enough: Hina tells you 7:55")
			_close_all(hud)
			game.credits = 0
			people.run_item("p:buy:mio", hud)
			_check(not people.knows("mio"), "Yui wants money first")
			_close_all(hud)
			game.credits = 12
			people.run_item("p:buy:mio", hud)
			_check(people.knows("mio") and game.credits == 7, "Yui sells Mio's morning for %s" % root.get_node("DataDB").money(5))
			_close_all(hud)
			for i in 3:
				amane.st()["lore"]["test_%d" % i] = 1
			var items: Array = people.menu_items("mio")
			_check(items.any(func(it): return str(it.id) == "p:trade:mio"), "Mio trades a morning for ghost stories")
			var known_n: int = people.st()["known"].size()
			people.run_item("p:trade:mio", hud)
			_check(people.st()["known"].size() == known_n + 1, "the trade reveals someone else's morning")
			_close_all(hud)
			var yui: Array = people.menu_items("yui")
			_check(yui.size() >= 1, "Yui still has rumours to sell (%d)" % yui.size())
			root.get_node("Town").meet("yui")
			_check(hud._dialogue_open and _buttons(hud).size() >= 4 + yui.size(), "Yui's talk lists her rumours for sale")
			_close_all(hud)
			# Hina's door with a known schedule: wait for her exact minute, then say no.
			clock.st()["minute"] = 470
			people.today("hina").erase("out")
			lvl.player.global_position = lvl.builder.center(12, 39)
			lvl.home.visit("hina")
			_press_text(hud, "Wait for Hina")
			_check(clock.minute() == 475, "waiting for Hina lands on 7:55 exactly")
			_check(_press_text(hud, "just passing by"), "Hina comes out; you can decline")
			_close_all(hud)
			_check(not people.escorting(), "declining starts no walk")
			# Reiji left at 7:40.
			lvl.home.visit("reiji")
			_check(hud._dialogue_open and str(hud._dialogue_text.text).length() > 30, "Reiji already left: the housekeeper says so")
			_close_all(hud)
			# A promise to Reiji you don't keep.
			people.st()["promise"]["reiji"] = clock.day()
			people.today("reiji").erase("picked")
			var rc: int = people.close("reiji")
			lvl.home._on_minute(clock.minute())
			_check(people.st()["broken"].has("reiji") and people.close("reiji") < rc, "Reiji waited three minutes and remembers (%d -> %d)" % [rc, people.close("reiji")])
			_check(people.menu_items("reiji").any(func(it): return str(it.id).begins_with("p:sorry")), "you can apologise to Reiji")
			# After school: walk Hina home.
			clock.st()["minute"] = 930
			people.run_item("p:walk:hina", hud)
			_close_all(hud)
			_check(people.escorting("hina") and people.escort().mode == "their_home", "walking Hina home")
			_wait = 4
		4:
			_check(get_nodes_in_group("companion").size() >= 1, "Hina walks with you")
			lvl.player.global_position = lvl.builder.center(12, 39)
			_wait = 6
		5:
			_check(hud._dialogue_open and str(hud._dialogue_text.text).contains("> Hina"), "at her door: goodbye + closeness")
			_close_all(hud)
			_check(int(people.st()["walks"].get("hina", 0)) == 1 and not people.escorting(), "walk home counted")
			_check(not root.get_node("Town").present(root.get_node("Town").spirit("hina")), "Hina is home for the evening")
			# Hayate offers to walk YOU home.
			amane.st()["closeness"]["Inukai Hayate"] = 30
			people.today("hayate").erase("offered")
			people.maybe_offer_home("hayate", hud)
			_press_text(hud, "Sure")
			_close_all(hud)
			_check(people.escorting("hayate") and people.escort().mode == "my_home", "Hayate walks you home")
			lvl.player.global_position = lvl.builder.center(27, 47)
			_wait = 8
		6:
			_close_all(hud)
			_check(int(people.st()["walks"].get("hayate", 0)) == 1 and not people.escorting(), "home: Hayate says goodbye")
			# Evening: ringing gets the parents.
			clock.st()["minute"] = 1100
			lvl.home.visit("mio")
			_check(hud._dialogue_open, "evening visit: Mio's grandmother answers")
			_close_all(hud)
			# Next morning, someone you said yes to is at your door.
			people.st()["pickup_me"] = {"who": "hina", "day": clock.day() + 1}
			clock.next_day()
			while clock.is_weekend():
				people.st()["pickup_me"] = {"who": "hina", "day": clock.day() + 1}
				clock.next_day()
			lvl.home.resume()
			_check(hud._dialogue_open and _press_text(hud, "Let's go"), "Hina is at your door in the morning")
			_close_all(hud)
			_check(people.escorting("hina") and people.escort().mode == "school", "and walks you to school")
			people.end_escort()
			lvl.home.dismiss(false)
			var notes: String = people.notes_text()
			_check(notes.contains("MORNINGS") and notes.contains("7:55"), "Notes list the mornings you know")
			print("people_test: %d failure(s)" % fails)
			quit(fails)
	_step += 1
	return false


func _first_named(n: String, visible_only: bool) -> Node:
	for x in get_nodes_in_group("npc"):
		if x.get("npc_name") == n and (x.visible or not visible_only):
			return x
	return null


func _data_checks(people) -> void:
	for id in people.IDS:
		var d: Dictionary = people.data.get(id, {})
		var lines: Dictionary = d.get("lines", {})
		var n := _count(lines) + _count(d.get("jealous", {}))
		_check(n >= 200, "%s has %d lines" % [id, n])
		var missing := []
		for k in KEYS:
			if _count(lines.get(k, [])) == 0:
				missing.append(k)
		if id != "amane" and _count(lines.get("amane_cut_in", [])) == 0:
			missing.append("amane_cut_in")
		_check(missing.is_empty(), "%s has every line key %s" % [id, str(missing)])
		var leaks := []
		for k in lines:
			for e in (lines[k] if lines[k] is Array else []):
				var t := str(e.get("t", "")) if e is Dictionary else str(e)
				var w := _leaky(t)
				if w != "":
					leaks.append("%s/%s:%s" % [id, k, w])
		_check(leaks.is_empty(), "%s: no sci-fi leaks %s" % [id, str(leaks.slice(0, 4))])
		var p: Dictionary = d.get("profile", {})
		_check(int(p.leave) >= 457 and int(p.arrive) > int(p.leave) and int(p.arrive) <= 510, "%s: %s -> %s, before the 8:30 bell" % [id, p.leave, p.arrive])
	for tone in ["kind", "honest", "boundary", "hand"]:
		_check(people.jealous("cut_in_reply", tone) != "", "Amane answers a %s reply" % tone)
	for who in ["hayate", "hina", "mio", "reiji"]:
		_check(people.jealous("cut_in", who) != "" and people.jealous("follow", who) != "" and people.jealous("text", who) != "",
			"Amane has jealous lines about %s" % who)


func _map_checks(people, lvl) -> void:
	var b = lvl.builder
	for id in people.IDS:
		var d: Vector2i = people.door(id)
		_check(b.cell(d.x, d.y) in ["_", ".", ","] and b.cell(d.x, d.y - 1) == "b", "%s's door %s is on the street, in front of a house" % [id, str(d)])
	var doors := 0
	for n in lvl.find_children("*", "Interactable", true, false):
		if str(n.get("prompt")).begins_with("Visit the "):
			doors += 1
	_check(doors == people.IDS.size(), "five house doors in town (%d)" % doors)
