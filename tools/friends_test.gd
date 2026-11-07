extends SceneTree
## Friends and exams (docs/GDD.md 4.13): companions (ask to hang out, follow you, gifts, closeness ticks, curfew,
## splitting up, into the school), exam prep (the hint, cramming at home, a friend tutoring you), copying in an
## exam (clean / caught), the ranking board, and the ledger's brush fonts.
## godot --headless --path . --script res://tools/friends_test.gd   (exit code = failures)

var _step := 0
var _wait := 0
var fails := 0
var _c0 := 0


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


func _ids(items: Array) -> Array:
	var out := []
	for it in items:
		out.append(str(it.id))
	return out


func _process(_d: float) -> bool:
	if _wait > 0:
		_wait -= 1
		return false
	var game = root.get_node("Game")
	var clock = root.get_node("Clock")
	var amane = root.get_node("Amane")
	var people = root.get_node("People")
	var party = root.get_node("Party")
	var week = root.get_node("Week")
	var toru = root.get_node("Toru")
	var lvl = current_scene
	var hud = lvl.get("hud") if lvl else null
	match _step:
		0:
			game.new_game("Friend Tester", {}, -1, {}, "", 17)
			game.location_id = "suzunari"
			toru.apply_origin({})
			amane.st()["met"] = true
			change_scene_to_file("res://scenes/world/suzunari.tscn")
			_wait = 60
		1:
			_close_all(hud)
			clock.st()["day"] = 6
			clock.st()["minute"] = 940
			for n in ["Inukai Hayate", "Hayase Hina", "Shirasagi Reiji"]:
				amane.st()["closeness"][n] = 40
			amane.st()["closeness"]["Kuroe Mio"] = 10
			_check(_ids(people.menu_items("hayate")).has("p:hang:hayate"), "after school you can ask Hayate to hang out")
			people.run_item("p:hang:hayate", hud)
			_close_all(hud)
			_check(party.has("hayate"), "Hayate is hanging out with you")
			people.run_item("p:hang:hina", hud)
			_close_all(hud)
			_check(party.members().size() == 2, "two friends at once")
			_check(not _ids(people.menu_items("reiji")).has("p:hang:reiji"), "a third has to wait (max 2)")
			people.run_item("p:hang:mio", hud)
			_close_all(hud)
			_check(not party.has("mio"), "not close enough to Mio yet")
			_wait = 20
		2:
			var bodies := get_nodes_in_group("party")
			_check(bodies.size() == 2, "both follow you through town (%d)" % bodies.size())
			_check(people.hides("hayate"), "Hayate's usual body steps aside while he's with you")
			var base: float = (1.0 + toru.stat("charm") / 200.0)
			_check(toru.close_mult() > base * 1.2, "Hina's gift: people warm to you faster")
			_check(party.ask_gift("hina").length() > 20, "Hina tells you something true")
			_c0 = int(amane.st()["closeness"].get("Inukai Hayate", 0))
			clock.advance(31)
			_check(int(amane.st()["closeness"].get("Inukai Hayate", 0)) > _c0, "half an hour together brings you closer")
			# Talk to Hina: split up.
			var hina = null
			for b in bodies:
				if str(b.person) == "hina":
					hina = b
			hina._on_talk(null)
			_check(hud._dialogue_open and _buttons(hud).size() == 3, "talking to a companion: gift / keep going / split up")
			_press(hud, "head off")
			_close_all(hud)
			_check(not party.has("hina"), "split up with Hina")
			# Reiji: rules.
			people.run_item("p:hang:reiji", hud)
			_close_all(hud)
			_check(party.excused(), "with Reiji, nothing gets marked")
			party.ask_gift("reiji")
			party.leave("reiji")
			_check(party.excused() and not party.excused(), "Reiji's council pass excuses one late mark, once")
			# Curfew: Hayate goes home.
			clock.st()["minute"] = party.curfew("hayate") - 1
			clock.advance(2)
			_check(not party.has("hayate"), "Hayate goes home at his curfew (%s)" % clock.clock_text())
			# Exams: day 33 is the day before the midterms.
			clock.st()["day"] = 33
			clock.st()["minute"] = 1000
			_check(week.days_to_exam() == 1 and week.objective().contains("Exams in 1"), "the objective warns about tomorrow's exams")
			for bt in week.day_data().get("beats", []):
				week.st()["done"][str(bt.id)] = 33  # today's story beats are not what this test is about
			_close_all(hud)
			var s0: int = toru.stat("study")
			week.cram(hud, "home")
			_check(hud._dialogue_open and _press(hud, "Study for an hour"), "your desk at home: study for an hour")
			_close_all(hud)
			_check(toru.stat("study") > s0 and clock.minute() >= 1060, "cramming raised Study (%d -> %d)" % [s0, toru.stat("study")])
			_check(_ids(people.menu_items("reiji")).has("p:tutor:reiji"), "Reiji can tutor you before the exams")
			var s1: int = toru.stat("study")
			people.run_item("p:tutor:reiji", hud)
			_close_all(hud)
			_check(toru.stat("study") >= s1 + 5, "Reiji's tutoring (%d -> %d)" % [s1, toru.stat("study")])
			# Exam day: copy (clean), then copy (caught).
			clock.st()["day"] = 34
			clock.st()["minute"] = 515
			week.copy_roll = 0.99
			var notes: Array[String] = []
			week._exam("am", "", notes)
			_check(hud._dialogue_open and _press(hud, "Copy from"), "the exam offers copying")
			_close_all(hud)
			var g1 := str(game.flags.get("exam_d34_am", ""))
			_check(g1 in ["A", "B"], "copied cleanly: grade %s" % g1)
			week.copy_roll = 0.0
			var mk := int(amane.st()["closeness"].get("Makabe-sensei", 0))
			var notes2: Array[String] = []
			clock.st()["minute"] = 805
			week._exam("pm", "", notes2)
			_press(hud, "Copy from")
			_close_all(hud)
			_check(str(game.flags.get("exam_d34_pm", "")) == "F", "caught copying: F")
			_check(int(amane.st()["closeness"].get("Makabe-sensei", 0)) <= mk - 8, "Makabe-sensei is disappointed")
			var deeds := []
			for d in game.flags.get("deeds", []):
				deeds.append(str(d.kind))
			_check(deeds.has("cheat") and deeds.has("cheat_caught"), "the ledger saw both")
			week.copy_roll = -1.0
			# The ranking board after the last exam day.
			clock.st()["day"] = 35
			week._exam_results(hud)
			_check(hud._dialogue_open and str(hud._dialogue_text.text).contains("of 160"), "the ranking board goes up")
			_close_all(hud)
			_check(week.st().get("ranks", {}).has("midterm"), "midterm rank kept (%s)" % str(week.st().get("ranks", {})))
			var types := []
			for e in root.get_node("Ledger").entries():
				types.append(str(e.type))
			_check(types.has("cheat") and types.has("exam"), "Domyo and Dosho write about the exams %s" % str(types))
			# Fonts for the ledger page.
			_check(load("res://assets/fonts/yuji_syuku_ledger.woff2") is Font and load("res://assets/fonts/caveat_brush.woff2") is Font, "brush fonts load")
			var f: Font = load("res://assets/fonts/yuji_syuku_ledger.woff2")
			_check(f.has_char(0x5584) and f.has_char(0x60AA) and f.has_char(ord("A")), "Domyo's font has 善 and 悪 and Latin")
			# Into the school with a friend.
			clock.st()["day"] = 36
			clock.st()["minute"] = 940
			people.run_item("p:hang:hayate", hud)
			_close_all(hud)
			lvl.enter_school([21, 31])
			_wait = 120
		3:
			_close_all(hud)
			var hay := false
			for b in get_nodes_in_group("party"):
				hay = hay or str(b.person) == "hayate"
			_check(str(game.location_id) == "school" and hay, "Hayate comes into the school with you")
			print("friends_test: %d failure(s)" % fails)
			quit(fails)
	_step += 1
	return false
