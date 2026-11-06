extends SceneTree
## Screenshots of Suzunari (needs a GPU or lavapipe, not --headless):
## VK_ICD_FILENAMES=/usr/share/vulkan/icd.d/lvp_icd.json xvfb-run -a -s "-screen 0 1280x800x24" \
##   godot --path . --resolution 1280x800 --script res://tools/shot_suzunari.gd -- <out_dir>
## Shots: home morning, shopping street (Amane crying, rain), school gate, school corridor at dusk.

const SHOTS := [["home_morning", Vector2i(21, 29), 470, 0.0, ""], ["street_rain", Vector2i(20, 20), 720, 4.2, "wail"],
	["school_gate", Vector2i(21, 12), 800, 0.0, "fluster"], ["corridor_dusk", Vector2i(20, 8), 1085, 2.4, "peek"]]
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
			if hud and hud.get("_dialogue_open"):
				hud._on_choice("")
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
			for n in get_nodes_in_group("npc"):
				if str(n.get("npc_name")) == "Inukai Hayate":
					n.global_position = p.global_position + Vector3(-2.4, 0.1, 1.0)
					n.spot = n.global_position
			var cs := get_nodes_in_group("cat")
			for i in mini(2, cs.size()):
				cs[i].global_position = p.global_position + Vector3(0.8 + i * 1.6, 0.05, 2.6)
				cs[i].home = cs[i].global_position
			if str(s[4]) != "":
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
