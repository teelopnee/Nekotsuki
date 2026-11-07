extends SceneTree
## School days and the 13 weeks (Week autoload): a lesson is one event that jumps the clock, late after 8:30, absent
## when in town during class, holidays have no lessons, exam days grade what you studied, every beat of every
## week plays every choice (night dreams at day end), each week closes with a summary + hook, every final choice
## on Tanabata maps to an ending with pages, Amane's topics don't repeat, reply order changes, talks cost time.
## godot --headless --path . --script res://tools/week_test.gd   (exit code = failures)

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


func _process(_d: float) -> bool:
	if _wait > 0:
		_wait -= 1
		return false
	var game = root.get_node("Game")
	var week = root.get_node("Week")
	var clock = root.get_node("Clock")
	var amane = root.get_node("Amane")
	var town = root.get_node("Town")
	var lvl = current_scene
	var hud = lvl.get("hud") if lvl else null
	match _step:
		0:
			game.new_game("Week Tester", {}, 9, {}, "", 17)
			game.location_id = "suzunari"
			change_scene_to_file("res://scenes/world/suzunari.tscn")
			_wait = 60
		1:
			_close_all(hud)
			clock.running = false
			_data_checks(week, town, amane)
			# Lessons: in school at 8:30 -> one event -> 12:30.
			game.location_id = "school"
			clock.st()["minute"] = 510
			week._on_minute(510)
			_check(hud._dialogue_open and _buttons(hud).size() == 4, "homeroom starts a lesson event with 4 choices")
			_buttons(hud)[0].pressed.emit()
			_check(clock.minute() == 750 and int(week.st()["study"]) == 1, "paying attention: studied, clock jumps to lunch (%d)" % clock.minute())
			_close_all(hud)
			# Late for the afternoon block.
			clock.st()["minute"] = 812
			week._on_minute(812)
			_check(hud._dialogue_open and str(hud._dialogue_text.text).to_lower().contains("late"), "arriving 12 minutes into a block = late")
			_buttons(hud)[3].pressed.emit()
			_check(int(week.st()["late"]) == 1 and clock.minute() == 920, "late mark counted, afternoon over")
			_close_all(hud)
			# Absent: next day, in town during class.
			clock.next_day()
			game.location_id = "suzunari"
			var posts: int = (amane.st()["ura"] as Array).size()
			clock.st()["minute"] = 530
			week._on_minute(530)
			_check(int(week.st()["truant"]) == 1 and (amane.st()["ura"] as Array).size() == posts + 1, "in town 20 minutes into class = absent + Ura board post")
			_check(not hud._dialogue_open, "absence is a toast, not a modal")
			week._on_minute(531)
			_check(int(week.st()["truant"]) == 1, "one absence per block")
			_beats(week, clock, amane, game, lvl, hud)
			# Night of day 2 with 2 absences: Haruka hears about it.
			week.st()["truant"] = 2
			week.before_day_end(hud)
			_check(hud._dialogue_open, "two absences reach Aunt Haruka at night")
			_close_all(hud)
			# Week close on day 7.
			clock.st()["day"] = 7
			amane.st()["met"] = true
			week.before_day_end(hud)
			var t: String = str(hud._dialogue_text.text)
			_check(t.contains("WEEK 1") and t.contains("Amane:") and t.contains("Closest"), "day 7 closes week 1 with a summary")
			hud._on_choice("")
			_check(str(hud._dialogue_text.text).contains("WEEK 2"), "and a hook for week 2")
			_close_all(hud)
			_check((week.st()["closed"] as Array).has(1), "week 1 marked closed")
			week.before_day_end(hud)
			_check(not hud._dialogue_open, "it closes once")
			_endings(week, game, amane)
			_calendar(week, clock, game, hud)
			_topics(amane, clock, hud)
			# A talk costs time.
			clock.running = true
			clock.st()["minute"] = 930
			town.st()["today"] = []
			town.meet("tanuki")
			_close_all(hud)
			_check(clock.minute() >= 940, "a conversation costs 10 minutes (%d)" % clock.minute())
			clock.running = false
			# The real ending flow: pages, then the end card with the summary (then back to the title).
			game.flags.erase("ending")
			week.ending("leave")
			_check(hud._dialogue_open and str(hud._dialogue_text.text).contains("Toryanse"), "an ending plays its pages")
			for _i in 6:
				if str(hud._dialogue_text.text).contains("EPISODE 0"):
					break
				hud._on_choice("")
			_check(str(hud._dialogue_text.text).contains("THE CAT WHO WAITS") and str(hud._dialogue_text.text).contains("EPISODE 0"), "the end card names the ending")
			_check(str(game.flags.get("ending", "")) == "cat_who_waits", "the ending is recorded for Enma's Ledger")
			print("week_test: %d failure(s)" % fails)
			quit(fails)
	_step += 1
	return false


func _data_checks(week, town, amane) -> void:
	var missing := []
	var titles: Dictionary = town.data.get("lore_titles", {})
	for wn in week.weeks:
		for d in week.weeks[wn].days:
			for bt in week.weeks[wn].days[d].get("beats", []):
				for c in bt.get("choices", []):
					var fx: Dictionary = c.get("fx", {})
					if fx.has("lore") and not titles.has(str(fx.lore)):
						missing.append(str(fx.lore))
					if fx.has("egg") and not town.data.eggs.has(str(fx.egg)):
						missing.append("egg " + str(fx.egg))
					if fx.has("zukan") and not town.ZUKAN.has(str(fx.zukan)):
						missing.append("zukan " + str(fx.zukan))
	_check(missing.is_empty(), "story lore / eggs / zukan exist %s" % str(missing))
	_check(week.weeks.size() == 13, "thirteen weeks of story (%d)" % week.weeks.size())
	var short := []
	for wn in week.weeks:
		if (week.weeks[wn].days as Dictionary).size() != 7 or not week.weeks[wn].has("close"):
			short.append(wn)
	_check(short.is_empty(), "every week has 7 days and a close %s" % str(short))
	for wd in ["Mon", "Tue", "Wed", "Thu", "Fri"]:
		_check((week.lessons.subjects.get(wd, []) as Array).size() == 2, "%s has two lesson blocks" % wd)


func _beats(week, clock, amane, game, lvl, hud) -> void:
	amane.st()["met"] = true
	var played := 0
	var night := 0
	var bad := []
	for wn in week.weeks:
		for d in week.weeks[wn].days:
			for bt in week.weeks[wn].days[d].get("beats", []):
				var choices: Array = bt.get("choices", [])
				for i in choices.size():
					var cfx: Dictionary = choices[i].get("fx", {})
					if cfx.has("final") or cfx.has("enter_ura"):
						continue  # endings and Ura-Suzunari leave the level: ura_test / _endings check them
					clock.st()["day"] = (int(wn) - 1) * 7 + int(d)
					week.st()["done"].erase(str(bt.id))
					town_picked_reset(bt)
					_meet_needs(bt, game, amane, choices[i])
					var where := str(bt.get("where", "any"))
					game.location_id = "school" if where == "school" else "suzunari"
					clock.st()["minute"] = int(bt.get("after", 450))
					if bt.has("near"):
						var n: Array = bt["near"]
						lvl.player.global_position = lvl.builder.center(int(n[0]), int(n[1])) + Vector3(0, 0.1, 0)
					week.today()["lesson_am"] = true
					week.today()["lesson_pm"] = true
					if str(bt.get("when", "")) == "night":
						week.play_beat(bt)
						night += 1
					else:
						week._check_beats(clock.minute())
					var btns := _buttons(hud)
					var idx := -1
					for k in btns.size():
						if str(btns[k].text).contains(str(choices[i].t).left(18)):
							idx = k
					if not hud._dialogue_open or idx < 0:
						bad.append("w%s/%s/%d" % [wn, bt.id, i])
						_close_all(hud)
						continue
					btns[idx].pressed.emit()
					if str(hud._dialogue_text.text).strip_edges().length() < 20:
						bad.append("w%s/%s/%d text" % [wn, bt.id, i])
					played += 1
					_close_all(hud)
					if str(bt.id) == "d5_question" and i == 1:
						_check(amane.route() == "romance", "Sunday's question sets the route (flirt -> romance)")
	_check(bad.is_empty() and played >= 260, "every story beat choice plays (%d, %d dreams) %s" % [played, night, str(bad.slice(0, 8))])
	# Fallback: Sunday's question finds you anywhere once Omagatoki has passed.
	week.st()["done"].erase("d5_question")
	clock.st()["day"] = 5
	clock.st()["minute"] = 1150
	lvl.player.global_position = lvl.builder.center(27, 47)
	week._check_beats(1150)
	_check(hud._dialogue_open and str(hud._dialogue_text.text).contains("What am I to you"), "Sunday's question comes to you if you missed it")
	_close_all(hud)
	clock.st()["day"] = 2


## Satisfy a beat's `needs` (and a choice's `when`) so every branch can be played.
func _meet_needs(bt: Dictionary, game, amane, choice: Dictionary) -> void:
	for src in [bt.get("needs", {}), choice.get("when", {})]:
		for k in src:
			var v = src[k]
			match k:
				"flag":
					game.flags[str(v)] = true
				"no_flag":
					game.flags.erase(str(v))
				"lore":
					amane.st()["lore"][str(v)] = 1
				"rival":
					amane.st()["rival"] = "Inukai Hayate" if bool(v) else ""
				"routes":
					amane.st()["route"] = str((v as Array)[0])
				"max_close":
					for who in v:
						amane.st()["closeness"][str(who)] = mini(int(amane.st()["closeness"].get(str(who), 0)), int(v[who]))
				"min_close":
					for who in v:
						amane.st()["closeness"][str(who)] = maxi(int(amane.st()["closeness"].get(str(who), 0)), int(v[who]))


func town_picked_reset(bt: Dictionary) -> void:
	root.get_node("Town").st()["picked"].erase("wk_" + str(bt.id))


func _topics(amane, clock, hud) -> void:
	var s: Dictionary = amane.st()
	s["topics_today"] = []
	s["topics_seen"] = {"mother": 1, "food": clock.day() - 1}
	var ids := []
	for c in amane.topic_choices():
		ids.append(str(c.id))
	_check(not ids.has("mother"), "once-only topics don't come back")
	_check(not ids.has("food"), "everyday topics rest for a few days")
	s["topics_seen"]["food"] = clock.day() - 1
	clock.st()["day"] = clock.day() + 3
	var again: String = amane.asked_before("food")
	_check(again != "" and not again.contains("{"), "asked again: \"%s\"" % again.left(60))
	var orders := {}
	for d in 6:
		clock.st()["day"] = 10 + d
		var o := []
		for c in amane.reply_choices("food"):
			o.append(str(c.id))
		orders[str(o)] = true
	_check(orders.size() >= 3, "reply order changes from day to day (%d orders in 6 days)" % orders.size())
	amane.set_tears(0.0)
	var scaled := false
	for c in amane.reply_choices("food"):
		if c.has("scale"):
			scaled = true
	_check(not scaled, "calm: every reply is the same size")


func _endings(week, game, amane) -> void:
	var ids := {}
	var finals := []
	for c in week.weeks[13].days["7"].beats[0].choices:
		finals.append(str(c.fx.final))
	_check(finals.size() >= 7, "Tanabata offers the final choices (%d)" % finals.size())
	var cases := [["tadaima", {"memory_2016": true}, "romance", 60.0, 30.0], ["tadaima", {}, "boundary", 20.0, 60.0],
		["bell", {}, "romance", 60.0, 20.0], ["remove_bell", {}, "friend", 60.0, 20.0], ["remove_bell", {}, "friend", 10.0, 20.0],
		["walk_beside", {}, "boundary", 20.0, 60.0], ["leave", {}, "none", 20.0, 20.0], ["ura", {"makabe_letter_sent": true}, "friend", 50.0, 20.0],
		["ura", {"sayo_found": true, "letter_101": true}, "friend", 50.0, 20.0], ["ura", {}, "romance", 50.0, 20.0], ["ura", {}, "ignore", 5.0, 20.0],
		["seal", {}, "ignore", 5.0, 20.0], ["return_god", {}, "none", 5.0, 20.0]]
	for cs in cases:
		for f in ["memory_2016", "makabe_letter_sent", "sayo_found", "letter_101"]:
			game.flags.erase(f)
		for f in cs[1]:
			game.flags[f] = true
		amane.st()["route"] = cs[2]
		amane.st()["bond_now"] = cs[3]
		amane.st()["self"] = cs[4]
		ids[week.ending_id(cs[0])] = true
	var missing := []
	for id in ids:
		if not (week.endings.endings as Dictionary).has(id) or (week.endings.endings[id].get("pages", []) as Array).is_empty():
			missing.append(id)
	_check(missing.is_empty() and ids.size() >= 12, "final choices reach %d different endings, all written %s" % [ids.size(), str(missing)])
	_check((week.endings.endings as Dictionary).size() >= 13, "%d endings written" % (week.endings.endings as Dictionary).size())


func _calendar(week, clock, game, hud) -> void:
	game.location_id = "school"
	clock.st()["day"] = 22  # Showa Day (Golden Week)
	week.st()["today"] = {}
	_check(week.block(530) == "", "holidays have no lessons")
	clock.st()["day"] = 34  # midterms
	clock.st()["minute"] = 510
	week._on_minute(510)
	_check(hud._dialogue_open and str(hud._dialogue_text.text).begins_with("EXAM"), "exam days are exams")
	_buttons(hud)[0].pressed.emit()
	_check(str(hud._dialogue_text.text).contains("> Grade:"), "an exam gives a grade from what you studied")
	_close_all(hud)
	game.location_id = "suzunari"
	week.st()["closed"] = [1]
	clock.st()["day"] = 14
	week.before_day_end(hud)
	for _i in 4:
		if hud._dialogue_open and str(hud._dialogue_text.text).contains("WEEK 2"):
			break
		hud._on_choice("")
	_check(hud._dialogue_open and str(hud._dialogue_text.text).contains("WEEK 2"), "week 2 closes on day 14")
	_close_all(hud)
	_check((week.st()["closed"] as Array).has(2), "week 2 marked closed")
