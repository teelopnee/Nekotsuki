extends SceneTree
## M3 "town brain": cats as Amane's spies, weekly rival, nightly living-spirit stages, warnings, the
## night watch, the Ura board and Enma's Ledger. Exit code = failures.
## godot --headless --path . --script res://tools/m3_test.gd

var _step := 0
var _wait := 0
var fails := 0
var _cat: Node


func _check(ok: bool, what: String) -> void:
	if ok:
		print("  ok   ", what)
	else:
		fails += 1
		printerr("  FAIL ", what)


func _process(_d: float) -> bool:
	if _wait > 0:
		_wait -= 1
		return false
	var game = root.get_node("Game")
	var amane = root.get_node("Amane")
	var cats = root.get_node("Cats")
	var bus = root.get_node("EventBus")
	match _step:
		0:
			game.new_game("M3 Tester", {}, 9, {}, "", 17)
			game.location_id = "suzunari"
			change_scene_to_file("res://scenes/world/suzunari.tscn")
			_wait = 60
		1:
			var hud = current_scene.get("hud")
			if hud and hud.get("_dialogue_open"):
				hud._on_choice("")
			amane.st()["met"] = true
			_check(get_nodes_in_group("cat").size() == 8, "8 cats in town")
			var hay = null
			for n in get_nodes_in_group("npc"):
				if str(n.get("npc_name")) == "Inukai Hayate":
					hay = n
			_check(hay != null, "Hayate is in town")
			var npc: Node = null
			for n in get_nodes_in_group("npc"):
				if n.get("role") == "civilian" and not n.is_in_group("amane") and str(n.get("npc_name")) != "Inukai Hayate":
					npc = n
					break
			_check(npc != null, "a townsperson to befriend")
			var p = get_first_node_in_group("player")
			_cat = get_nodes_in_group("cat")[0]
			_cat.global_position = p.global_position + Vector3(2, 0.05, 0)
			cats.memory(str(_cat.cat_id))["attitude"] = 0
			bus.interaction_done.emit("smalltalk", true, npc)
			_check(int(amane.st()["closeness"].get(str(npc.npc_name), 0)) >= 4, "closeness grows when you talk to people")
			_check(str(_cat.reporting) == str(npc.npc_name), "a cat runs off to tell Amane")
			cats.pet(_cat)
			_check(str(_cat.reporting) == "" and int(cats.memory(str(_cat.cat_id))["attitude"]) == 12, "petting stops it")
			bus.interaction_done.emit("smalltalk", true, npc)
			_cat.report_left = 0.05
			_wait = 30
		2:
			_check(int(amane.st()["cat_reports"]) == 1 and str(amane.st()["rival"]) != "", "the cat told Amane")
			_check(amane.pick_rival() == "Inukai Hayate", "week-2 rival is Hayate")
			amane.st()["self"] = 10.0
			amane._ikiryo_night()
			_check(int(amane.st()["plan"]["stage"]) >= 1 and (amane.st()["news"] as Array).size() >= 1, "night 1: the black cat walks")
			var s0 := int(amane.st()["plan"]["stage"])
			_check(amane.warn("Inukai Hayate"), "warning Hayate guards him")
			amane._ikiryo_night()
			_check(int(amane.st()["plan"]["stage"]) == s0, "guarded night: no step")
			amane.st()["self"] = 60.0
			amane._ikiryo_night()
			_check(int(amane.st()["plan"]["stage"]) == s0, "secure Amane: calm night")
			amane.st()["self"] = 10.0
			for i in 6:
				amane._ikiryo_night()
			_check(amane.fate("Inukai Hayate") in ["injured", "hidden"], "unchecked, the spirit gets him (%s)" % amane.fate("Inukai Hayate"))
			_check(amane.morning_event().contains("Hayate"), "morning news tells you")
			_check(amane.night_choice("name").length() > 10 and amane.st()["ikiryo_named"], "naming the cat")
			_check((amane.st()["ura"] as Array).size() >= 2, "Ura board posts (%d)" % (amane.st()["ura"] as Array).size())
			var led = root.get_node("Ledger")
			_check(led.write(), "ledger written")
			var r: Dictionary = led.read()
			_check(r.get("characters", {}).has("Inukai Hayate") and str(r.characters["Inukai Hayate"].fate) != "", "ledger remembers Hayate's fate")
			_check(r.get("cats", {}).size() == 8, "ledger remembers the cats")
			print("m3_test: %d failures" % fails)
			quit(fails)
			return true
	_step += 1
	return false
