extends SceneTree
## Toru's life (docs/GDD.md 4.1, 4.11, 4.13, 4.14): the NEW GAME creator and what the origin tags change, stats,
## clubs (join, practise, an event), part-time jobs (interview, a shift, the weekend menu), Sunday night (debt,
## Saki's call), the cat spirit night (jealous night -> play the cat -> rival's window -> resist / plan, roofs,
## knocking things over, next morning), and the ledger page Domyo and Dosho write at the end.
## godot --headless --path . --script res://tools/life_test.gd   (exit code = failures)

var _step := 0
var _wait := 0
var fails := 0
var _tries := 0
var _page: Control
var _self0 := 0.0
var _day0 := 0
var _sub := 0
var _watcher: Node = null


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


func _press(hud, contains: String) -> bool:
	for b in _buttons(hud):
		if str(b.text).contains(contains):
			b.pressed.emit()
			return true
	return false


func _close_all(hud) -> void:
	for _i in 14:
		if hud == null or not hud._dialogue_open:
			return
		hud._on_choice("")


func _process(_d: float) -> bool:
	if _wait > 0:
		_wait -= 1
		return false
	var game = root.get_node("Game")
	var clock = root.get_node("Clock")
	var amane = root.get_node("Amane")
	var toru = root.get_node("Toru")
	var ledger = root.get_node("Ledger")
	var lvl = current_scene
	var hud = lvl.get("hud") if lvl else null
	match _step:
		0:
			# The creator screen: five categories, every option a button, random + name + begin.
			var c: Control = load("res://src/ui/toru_creator.gd").new()
			root.add_child(c)
			var cats: Array = toru.categories()
			_check(cats.size() == 5, "five tag categories (%d)" % cats.size())
			var all_ok := true
			for cat in cats:
				all_ok = all_ok and c._buttons.get(str(cat.id), {}).size() == cat.options.size() and cat.options.size() >= 5
			_check(all_ok, "every option of every category is a button")
			c._randomise()
			_check(c.picks.size() == 5, "RANDOM picks one tag per category")
			c.name_edit.text = "Shun"
			var got := []
			c.begin.connect(func(n, tags): got.append([n, tags]))
			c._begin()
			_check(not got.is_empty() and got[0][0] == "Shun" and (got[0][1] as Dictionary).size() == 5, "BEGIN hands over the name and the tags")
			c.queue_free()
			# The origin changes things.
			game.new_game("Shun", {}, -1, {}, "", 17)
			game.location_id = "suzunari"
			toru.apply_origin({"wound": "debtor", "personality": "soft_hearted", "skill": "karate", "secret": "cat_allergy", "goal": "run_away"})
			_check(game.credits == 30, "in debt: you start with 3,000 yen (%d)" % game.credits)
			_check(toru.tears_mult() >= 1.5 and toru.quirk("soft_heart"), "soft-hearted: his tears hit you x1.5 (quirk)")
			_check(toru.sneezes() and toru.cats_mult() < 1.0, "allergic to cats: you sneeze, petting half counts")
			_check(toru.stat("stamina") == 40 and toru.stat("courage") == 30, "karate + debt raise stamina and courage (%d, %d)" % [toru.stat("stamina"), toru.stat("courage")])
			_check(toru.mult("club_bonus", "kendo") > 1.3 and toru.mult("job_bonus", "konbini") > 1.1, "skill and goal bonuses for clubs and jobs")
			amane.st()["met"] = true
			amane.set_tears(1.2)
			var shrunk := false
			for topic in amane.talk.get("topics", {}):
				for r in amane.reply_choices(str(topic)):
					if float(r.get("scale", 1.0)) < 1.0:
						shrunk = true
				if shrunk:
					break
			_check(shrunk, "soft-hearted: cold words already shrink at tears level 1")
			amane.set_tears(0.0)
			change_scene_to_file("res://scenes/world/suzunari.tscn")
			_wait = 60
		1:
			_close_all(hud)
			for id in ["Work_kendo", "Work_track", "Work_go_home", "Work_konbini", "Work_cat_cafe", "Work_sweets", "Work_fish_market", "Work_shrine"]:
				_check(lvl.find_child(id, true, false) != null, "%s is in town" % id)
			# Monday after school: join Track (Hayate) and practise.
			clock.st()["day"] = 6
			clock.st()["minute"] = 935
			_check(clock.weekday() == "Mon", "day 6 is a Monday")
			toru.use_club("track", hud)
			_check(hud._dialogue_open and _press(hud, "Join"), "the captain's pitch offers to join")
			_close_all(hud)
			_check(toru.club() == "track", "joined the Track Club")
			var ag0: int = toru.stat("agility")
			var c0 := int(amane.st()["closeness"].get("Inukai Hayate", 0))
			toru.use_club("track", hud)
			_check(hud._dialogue_open and _buttons(hud).size() == 3, "practice: three ways to train")
			_press(hud, "everything")
			_close_all(hud)
			_check(toru.stat("agility") > ag0, "training hard raised agility (%d -> %d)" % [ag0, toru.stat("agility")])
			_check(int(amane.st()["closeness"].get("Inukai Hayate", 0)) > c0, "practising beside Hayate brings you closer")
			_check(clock.minute() >= 1050, "practice runs until 17:30 (%s)" % clock.clock_text())
			toru.use_club("track", hud)
			_check(hud._dialogue_open and str(hud._dialogue_text.text).contains("over for today"), "one practice a day")
			_close_all(hud)
			# Every 4th practice is an event.
			clock.st()["day"] = 7
			clock.st()["minute"] = 935
			toru.st()["sessions"]["track"] = 3
			toru.use_club("track", hud)
			_check(hud._dialogue_open and str(hud._dialogue_text.text).contains("RELAY TRIALS"), "the 4th practice is an event (relay trials)")
			_buttons(hud)[0].pressed.emit()
			_close_all(hud)
			_check(bool(game.flags.get("relay_team", false)), "made the relay team")
			# A job: interview, then a night shift at the konbini (Monday 18:30).
			clock.st()["day"] = 6
			toru.st()["club_log"].erase("6")
			clock.st()["minute"] = 1115
			toru.use_job("konbini", hud)
			_check(hud._dialogue_open and _press(hud, "like the job"), "Yamane-san's interview")
			_close_all(hud)
			_check(toru.hired("konbini"), "hired at Suzunari Mart")
			var cr0: int = game.credits
			toru.use_job("konbini", hud)
			_check(hud._dialogue_open and _buttons(hud).size() == 3, "a shift: three ways to work")
			_press(hud, "Work hard")
			_close_all(hud)
			_check(game.credits > cr0 + 20, "paid for the shift (%d -> %d)" % [cr0, game.credits])
			_check(clock.minute() >= 1290, "the shift ends at 21:30 (%s)" % clock.clock_text())
			# Fish market needs stamina 30: turned down when you're weak.
			toru.st()["stats"]["stamina"] = 10
			toru.use_job("fish_market", hud)
			_press(hud, "like the job")
			_check(hud._dialogue_open and str(hud._dialogue_text.text).contains("Stamina 30"), "the fish market turns away the weak")
			_close_all(hud)
			_check(not toru.hired("fish_market"), "not hired")
			toru.st()["stats"]["stamina"] = 40
			# Weekend: Aunt Haruka's menu offers your shift.
			clock.st()["day"] = 4
			clock.st()["minute"] = 480
			toru.hire("sweets")
			var items: Array = toru.weekend_items()
			var ids := []
			for it in items:
				ids.append(str(it.id))
			_check(ids.has("job:sweets"), "Saturday: the weekend menu offers the Asagiri-do shift %s" % str(ids))
			toru.work("sweets", hud)
			_press(hud, "Chat")
			_close_all(hud)
			_check(clock.minute() >= 720, "worked the morning at Asagiri-do (%s)" % clock.clock_text())
			# The recruitment board lists every club.
			toru.use_board(hud)
			_check(hud._dialogue_open and _buttons(hud).size() >= 10, "the club board lists all 8 clubs (+ leave)")
			_close_all(hud)
			# Sunday night: the debt goes to Tokyo.
			clock.st()["day"] = 5
			var cr1: int = game.credits
			toru.day_end(hud)
			_close_all(hud)
			_check(game.credits == cr1 - 20, "Sunday night: 2,000 yen to the loan office (%d -> %d)" % [cr1, game.credits])
			_check(toru.status_text().contains("Track Club") and toru.status_text().contains("Suzunari Mart"), "pause menu page shows club + jobs")
			_check(toru.goal_epilogue("") != "", "the goal has an epilogue line")
			# A jealous night: week 2, Hayate is the rival, Amane's jealousy is high.
			clock.st()["day"] = 8
			clock.st()["minute"] = 1300
			amane.pick_rival()
			amane.st()["self"] = 20.0
			amane.st()["jealousy"] = {amane.rival(): 30}
			_check(amane.cat_night_due(), "a jealous night in week 2 is a cat night")
			_self0 = float(amane.st()["self"])
			_day0 = clock.day()
			lvl.end_day()
			_wait = 30
		2:
			if lvl.get("cat_night") != true and _tries < 40:
				_tries += 1
				if hud and hud._dialogue_open:
					_close_all(hud)  # anything before the cat night (night beats, week close)
				_wait = 15
				return false
			_tries = 0
			_check(lvl.get("cat_night") == true, "tonight you are the cat (cat mode)")
			_check(hud._dialogue_open and _press(hud, "Open your eyes"), "the night opens with a choice to play or sleep")
			_close_all(hud)
			_check(lvl.player.has_meta("cat_mode") and str(lvl.player.sprite.sheet_name) == "kasha", "the player is a black cat with two tails")
			_check(not clock.running, "the clock stands still all night")
			_check(lvl.find_child("RivalWindow", true, false) != null, "the rival's window is waiting")
			var visible_npcs := 0
			for n in get_nodes_in_group("npc"):
				if n.visible and not n.is_in_group("cat"):
					visible_npcs += 1
			_check(visible_npcs == 0, "the town is asleep (%d people about)" % visible_npcs)
			_check(amane.objective_text().contains("Dawn in"), "the objective counts down to dawn")
			# Knock something over, listen at a window, leap across the roofs.
			var knock: Dictionary = lvl.cat.knocks[0]
			var spot = null
			for it in get_nodes_in_group("cat_spot"):
				if str(it.prompt).contains("flower pot"):
					spot = it
			lvl._cat_knock(knock, spot)
			_close_all(hud)
			_check(not spot.enabled and (game.flags.get("deeds", []) as Array).size() >= 1, "knocked the florist's pot over (the ledger noticed)")
			_check(get_nodes_in_group("night_watch").size() == 3, "the night watch is out (patrol, drunk, stone dogs)")
			# LEAP: from the shopping street up onto the roofs.
			lvl.player.global_position = lvl.builder.center(13, 39) + Vector3(0, 0.1, 0)
			lvl.player.facing = Vector3(0, 0, 1)
			_check(lvl.cat_leap(), "LEAP finds the roof ahead")
			_wait = 120
		3:
			if lvl.player.has_meta("hopping") and _tries < 600:
				_tries += 1
				return false  # still in the air
			_tries = 0
			if _sub == 0:
				_check(lvl.player.global_position.y > 3.0, "the cat is up on the roofs (y %.1f)" % lvl.player.global_position.y)
				var nw = get_nodes_in_group("night_watch")[0]
				_check(not nw.sees(lvl.player), "nobody sees you on the roofs")
				lvl.player.facing = Vector3(0, 0, -1)
				lvl.cat_leap()
				_sub = 1
				_wait = 120
				return false
			if _sub == 1:
				_check(lvl.player.global_position.y < 1.0, "LEAP off the edge back down to the street (y %.1f)" % lvl.player.global_position.y)
				var w = null
				for n in get_nodes_in_group("night_watch"):
					if str(n.spec.get("name", "")) == "Omawari-san":
						w = n
				_watcher = w
				lvl.player.global_position = w.global_position + w.facing * 2.5
				lvl.player.set_meta("sneaking", false)
				_sub = 2
				_wait = 150
				return false
			_check(lvl.cat_spotted >= 1, "walking in front of Omawari-san's torch gets you spotted (%d)" % lvl.cat_spotted)
			_check(((amane.st()["ura"] as Array).back().text as String).contains("TWO tails"), "...and the Ura board hears about a two-tailed cat")
			lvl.player.global_position = _watcher.global_position + _watcher.facing * 6.0
			lvl.player.set_meta("sneaking", true)
			_check(not _watcher.sees(lvl.player), "SNEAK: at 6 m the torch misses you")
			lvl.player.set_meta("sneaking", false)
			lvl.player.global_position = Vector3(0, -30, 0)
			# The rival's window: watch first, then resist.
			lvl._cat_rival_window()
			_check(hud._dialogue_open and str(hud._dialogue_text.text).contains("Tonight's step"), "at the rival's window the next step of the plan is spelled out")
			_press(hud, "watch him sleep")
			hud._on_choice("")  # his answer to watching
			_check(hud._dialogue_open and _buttons(hud).size() == 2, "after watching, only the decision is left")
			_press(hud, "Turn around")
			_close_all(hud)
			_wait = 90
		4:
			_close_all(hud)
			_check(lvl.get("cat_night") == false and not game.flags.has("cat_night"), "morning: back to being Toru")
			_check(clock.day() == _day0 + 1, "the night ended the day (day %d -> %d)" % [_day0, clock.day()])
			_check(float(amane.st()["self"]) > _self0 and int(amane.st()["plan"]["stage"]) == 0, "resisting: his self grew, the plan did not move")
			_check(float(amane.st()["tears"]) >= 0.9, "...and he woke up crying (tears %.1f)" % float(amane.st()["tears"]))
			_check(not amane.cat_night_due(), "one cat night a week")
			var log: Array = game.flags.get("cat_night_log", [])
			_check(log.size() == 1 and str(log[0].outcome) == "resist", "the night is in the ledger log")
			# Next week the cat goes on with the plan (dawn).
			clock.st()["day"] = 15
			amane.st()["plan"]["target"] = "Inukai Hayate"
			amane.st()["plan"]["guarded"] = false
			amane.st()["jealousy"] = {"Inukai Hayate": 40}
			amane.cat_outcome("dawn", "")
			_check(int(amane.st()["plan"]["stage"]) == 1, "undecided at dawn: the plan goes on by itself")
			# The ledger page.
			game.flags["ending"] = "right_distance"
			var es: Array = ledger.entries()
			var types := []
			for e in es:
				types.append(str(e.type))
			_check(types.has("cat_resist") and types.has("cat_plan") and types.has("club") and types.has("job") and types.has("knock"),
				"the scribes have entries for the cat nights, the club, the job and the pot (%s)" % str(types))
			_check(types.has("goal") and types.has("ending") and types[0].begins_with("route_"), "...and Amane, the goal and the ending")
			var bad := 0
			for e in es:
				if str(e.domyo) == "" or str(e.dosho) == "":
					bad += 1
			_check(bad == 0, "Domyo and Dosho both have a word on every entry")
			var holder := Node.new()
			root.add_child(holder)
			ledger.show_page(holder)
			_wait = 5
		5:
			for n in root.find_children("*", "Control", true, false):
				if n.get_script() and str(n.get_script().resource_path).ends_with("ledger_page.gd"):
					_page = n
			_check(_page != null, "the ledger page opens")
			if _page:
				_page.skip_all()
			_wait = 30
		6:
			if _page and str(_page.stage) != "tally" and _tries < 400:
				_tries += 1
				return false
			_check(_page != null and str(_page.stage) == "tally", "WRITE IT ALL reaches the totals")
			var t: Dictionary = _page.tally if _page else {}
			_check(int(t.get("good", 0)) + int(t.get("bad", 0)) + int(t.get("argued", 0)) == _page.entries.size(), "every entry got a stamp %s" % str(t))
			_check(int(t.get("bad", 0)) >= 2 and int(t.get("good", 0)) >= 2, "good and bad deeds both on the page")
			var done := []
			_page.closed.connect(func(): done.append(true))
			_page.advance()
			_check(not done.is_empty(), "closing the ledger")
			print("life_test: %d failure(s)" % fails)
			quit(fails)
	_step += 1
	return false
