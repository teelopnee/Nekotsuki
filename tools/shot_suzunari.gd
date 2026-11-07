extends SceneTree
## Screenshots of Suzunari (needs a GPU or lavapipe, not --headless):
## VK_ICD_FILENAMES=/usr/share/vulkan/icd.d/lvp_icd.json xvfb-run -a -s "-screen 0 1280x800x24" \
##   godot --path . --resolution 1280x800 --script res://tools/shot_suzunari.gd -- <out_dir>
## Shots: home morning, shopping street (Amane crying, rain), school gate, school corridor at dusk.

## [name, tile, minute, tears, Amane emote ("talk" = open a topic talk and show the exact-words menu)]
const SHOTS := [["shrine_morning", Vector2i(24, 6), 480, 0.0, ""], ["steps_dusk", Vector2i(5, 14), 1085, 2.4, "peek"],
	["school_gate", Vector2i(22, 30), 800, 0.0, "fluster"], ["river_rain", Vector2i(17, 43), 720, 4.2, "wail"],
	["jizo_crossroads", Vector2i(47, 33), 1095, 0.0, ""], ["station_night", Vector2i(9, 38), 1200, 1.0, ""],
	["talk_words", Vector2i(27, 40), 900, 1.6, "talk"], ["street_noon", Vector2i(20, 39), 740, 0.0, "happy"],
	["home_evening", Vector2i(24, 47), 1060, 0.0, ""],
	["house_inukai", Vector2i(53, 25), 466, 0.0, ""], ["house_shirasagi", Vector2i(51, 52), 456, 0.0, ""],
	["house_kuroe", Vector2i(52, 40), 485, 1.6, ""], ["house_hayase", Vector2i(12, 40), 470, 0.0, ""],
	["house_nekomori", Vector2i(34, 6), 466, 0.0, ""], ["pickup_hina", Vector2i(16, 40), 478, 0.0, "pickup:hina"],
	["walk_reiji_dusk", Vector2i(40, 47), 1086, 0.0, "pickup:reiji"]]
var _step := 0
var _wait := 0
var _shot := 0
var _out := "/tmp"


func _process(_d: float) -> bool:
	if _wait > 0:
		_wait -= 1
		return false
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		_out = args[0]
	var game = root.get_node("Game")
	var amane = root.get_node("Amane")
	var clock = root.get_node("Clock")
	match _step:
		0:
			game.new_game("Toru", {}, 7, {}, "", 17)
			game.player_look = load("res://src/core/character_look.gd").cast_look("toru")
			game.location_id = "suzunari"
			amane.st()["met"] = true
			change_scene_to_file("res://scenes/world/suzunari.tscn")
			_wait = 60
		1:
			var hud = current_scene.get("hud")
			for _i in 6:
				if hud and hud.get("_dialogue_open"):
					hud._on_choice("")
			var only := OS.get_cmdline_user_args()[1].split(",") if OS.get_cmdline_user_args().size() > 1 else PackedStringArray()
			while _shot < SHOTS.size() and not only.is_empty() and not only.has(str(SHOTS[_shot][0])):
				_shot += 1
			if _shot >= SHOTS.size():
				quit(0)
				return true
			var s: Array = SHOTS[_shot]
			clock.st()["minute"] = int(s[2])
			clock.running = false
			amane.set_tears(float(s[3]))
			amane.st()["rain"] = amane.rain_target()
			current_scene._apply_light()
			var p = get_first_node_in_group("player")
			p.global_position = current_scene.builder.center(s[1].x, s[1].y) + Vector3(0, 0.2, 0)
			p.facing = Vector3(0, 0, -1)
			var a = get_first_node_in_group("amane")
			a.global_position = p.global_position + Vector3(2.2, 0.1, 1.2)
			a.set("_approach_cd", 9999.0)
			for n in get_nodes_in_group("npc"):
				if str(n.get("npc_name")) == "Inukai Hayate":
					n.global_position = p.global_position + Vector3(-2.4, 0.1, 1.0)
					n.spot = n.global_position
			var cs := get_nodes_in_group("cat")
			for i in mini(2, cs.size()):
				cs[i].global_position = p.global_position + Vector3(0.8 + i * 1.6, 0.05, 2.6)
				cs[i].home = cs[i].global_position
			if str(s[4]) == "talk":
				amane.st()["topics_today"] = []
				amane.converse(a, hud)
				for b in hud._dialogue_choices.get_children():
					if not b.is_queued_for_deletion():
						b.pressed.emit()
						break
			elif str(s[4]).begins_with("pickup:"):
				var who := str(s[4]).split(":")[1]
				root.get_node("People").start_escort(who, "school")
				var c = current_scene.home._spawn_companion(who, p.global_position + Vector3(1.6, 0.1, 0.4))
				c.say(root.get_node("People").line(who, "walk"), 30.0)
				a.global_position = p.global_position + Vector3(-2.6, 0.1, 3.0)
			elif str(s[4]) != "":
				load("res://src/core/emotion.gd").express(a, str(s[4]), 30.0)
			current_scene.camera_rig.snap_to_target()
			_wait = 90
			_step = 2
			return false
		2:
			var img: Image = root.get_texture().get_image()
			img.save_png("%s/%s.png" % [_out, SHOTS[_shot][0]])
			print("shot ", SHOTS[_shot][0])
			_shot += 1
			_step = 1
			return false
	_step += 1
	return false
