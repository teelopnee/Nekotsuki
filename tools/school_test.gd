extends SceneTree
## Suzunari Gakuen: enter from town, every floor builds (links, plates, features, people, students), every room
## feature plays every choice, stairs up/down, the roof, leaving back to the right door. Data ids are defined.
## godot --headless --path . --script res://tools/school_test.gd   (exit code = failures)

var _step := 0
var _wait := 0
var fails := 0
var _floor_i := 0
const FLOORS := ["1f", "2f", "3f", "roof"]


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
	for _i in 12:
		if not hud._dialogue_open:
			return
		hud._on_choice("")


func _process(_d: float) -> bool:
	if _wait > 0:
		_wait -= 1
		return false
	var game = root.get_node("Game")
	var router = root.get_node("Router")
	match _step:
		0:
			game.new_game("School Tester", {}, 9, {}, "", 17)
			game.location_id = "suzunari"
			root.get_node("Amane").st()["met"] = true
			change_scene_to_file("res://scenes/world/suzunari.tscn")
			_wait = 60
		1:
			_close_all(current_scene.get("hud"))
			var doors := 0
			for n in current_scene.find_children("*", "Interactable", true, false):
				if str(n.get("prompt")) == "Enter Suzunari Gakuen":
					doors += 1
			_check(doors == 2, "two school entrances in town (%d)" % doors)
			_data_checks()
			current_scene.enter_school([31, 28])
			_wait = 90
		2:
			_floor_checks()
			_play_features()
			_floor_i += 1
			if _floor_i < FLOORS.size():
				current_scene.go_floor(FLOORS[_floor_i], Vector2i(2, 3))
				_wait = 90
				_step = 1
		3:
			# stairs: down from 2F lands on 1F next to the up stairs
			current_scene.go_floor("2f", Vector2i(2, 3))
			_wait = 90
		4:
			var s = current_scene
			s.use_link(null, "D", Vector2i(2, 2))
			_wait = 90
		5:
			_check(str(current_scene.get("floor_id")) == "1f", "stairs down from 2F reach 1F")
			var p = get_first_node_in_group("player")
			_check(p.global_position.distance_to(current_scene.builder.center(2, 3)) < 2.5, "arrive beside the stairs")
			current_scene.leave()
			_wait = 90
		6:
			_check(current_scene.name == "Suzunari", "leaving school goes back to town")
			var p = get_first_node_in_group("player")
			_check(p.global_position.distance_to(current_scene.builder.center(31, 28)) < 3.5, "back out at the door we used")
			_check(str(game.location_id) == "suzunari", "location is the town again")
			print("school_test: %d failure(s)" % fails)
			quit(fails)
	_step += 1
	return false


func _floor_checks() -> void:
	var s = current_scene
	var fid: String = str(s.get("floor_id"))
	_check(s.name == "School" and fid == FLOORS[_floor_i], "in school, floor %s" % fid)
	var links: Array = s.build.get("school").links
	var chars := {}
	for l in links:
		chars[l.char] = true
	var want: Array = {"1f": ["S", "X"], "2f": ["S", "D"], "3f": ["D", "K"], "roof": ["D"]}[fid]
	for c in want:
		_check(chars.has(c), "%s has link %s" % [fid, c])
	var plates := 0
	for n in s.find_children("*", "Label3D", true, false):
		if n.font_size == 40:
			plates += 1
	var rooms := 0
	for r in s.data.rooms:
		if str(r.floor) == fid:
			rooms += 1
	_check(plates >= rooms, "%s: room plates (%d / %d)" % [fid, plates, rooms])
	var people := []
	for n in get_nodes_in_group("spirit"):
		people.append(str(n.get("spirit_id")))
	var expect := []
	for sp in root.get_node("Town").data.spirits:
		if str(sp.get("indoor", "")) == fid:
			expect.append(str(sp.id))
	for id in expect:
		_check(people.has(id), "%s: %s is at work" % [fid, id])
	if fid in ["2f", "3f"]:
		var students := 0
		for n in get_nodes_in_group("npc"):
			if n.get("role") == "civilian" and not n.is_in_group("amane") and not n.is_in_group("spirit"):
				students += 1
		_check(students >= 6, "%s: classrooms have students (%d)" % [fid, students])
	if fid == "2f":
		var before := get_nodes_in_group("npc").size()
		s._bell("Lunch")
		var walking := 0
		for n in get_nodes_in_group("npc"):
			if n.get("path") is Array and not (n.get("path") as Array).is_empty():
				walking += 1
		_check(walking >= 3, "2f: the bell sends students walking between rooms (%d)" % walking)
		var routed: Array = s.route("2-A", "LIBRARY")
		_check(routed.size() == 6, "2f: a route goes out of one door, along the corridor, in the other (%d points)" % routed.size())
		_check(get_nodes_in_group("npc").size() >= before, "2f: nobody vanished on the spot")
	if fid == "roof":
		var sheets := 0
		for m in get_nodes_in_group("life_spot"):
			sheets += 1
		_check(sheets >= 30, "roof: picnic sheets and benches to sit on (%d seats)" % sheets)
		_check(s.targets("Lunch").get("_roof", 0) >= 12, "roof: lunch brings a crowd")
	var meshes: int = s.find_children("*", "MeshInstance3D", true, false).size()
	_check(meshes > 150, "%s: rooms are furnished (%d meshes)" % [fid, meshes])
	_check(get_first_node_in_group("amane") != null, "%s: Amane followed you in" % fid)


func _play_features() -> void:
	var s = current_scene
	var hud = s.get("hud")
	var fid: String = str(s.get("floor_id"))
	var played := 0
	var bad := []
	for f in s.data.features:
		if str(f.floor) != fid:
			continue
		var v: Dictionary = s.feature_scene(f)
		var choices: Array = v.get("choices", [])
		for i in choices.size():
			root.get_node("Town").st()["picked"].erase("sc_" + str(f.id))
			_close_all(hud)
			s.use_feature(f)
			var v2: Dictionary = s.feature_scene(f)
			if v2 != v:
				_close_all(hud)
				continue  # a chance variant flipped; the others are covered on the next pick
			var bs := _buttons(hud)
			if i >= bs.size():
				bad.append("%s/%d menu" % [f.id, i])
				continue
			bs[i].pressed.emit()
			var t := str(hud._dialogue_text.text)
			if t.strip_edges().length() < 10:
				bad.append("%s/%d" % [f.id, i])
			played += 1
			_close_all(hud)
	var feats := 0
	for n in s.find_children("*", "Interactable", true, false):
		feats += 1
	_check(bad.is_empty() and played > 0, "%s: every feature choice plays (%d) %s" % [fid, played, str(bad)])
	_check(feats >= 3, "%s: interactables (%d)" % [fid, feats])


func _data_checks() -> void:
	var town = root.get_node("Town")
	var sd := JSON.parse_string(FileAccess.get_file_as_string("res://data/school.json")) as Dictionary
	var titles: Dictionary = town.data.get("lore_titles", {})
	var missing := []
	for f in sd.features:
		var scenes: Array = f.get("variants", [f])
		for v in scenes:
			for c in v.get("choices", []):
				var fx: Dictionary = c.get("fx", {})
				if fx.has("lore") and not titles.has(str(fx.lore)):
					missing.append(str(fx.lore))
				if fx.has("egg") and not town.data.eggs.has(str(fx.egg)):
					missing.append("egg " + str(fx.egg))
				if fx.has("zukan") and not town.ZUKAN.has(str(fx.zukan)):
					missing.append("zukan " + str(fx.zukan))
	_check(missing.is_empty(), "school lore / eggs / zukan ids are defined %s" % str(missing))
	var rooms_with_feature := {}
	for f in sd.features:
		rooms_with_feature[str(f.floor)] = int(rooms_with_feature.get(str(f.floor), 0)) + 1
	_check(sd.features.size() >= 20, "school has %d room features" % sd.features.size())
	for fid in FLOORS:
		_check(int(rooms_with_feature.get(fid, 0)) >= 1, "%s has features" % fid)
