extends SceneTree
## Screenshots inside Suzunari Gakuen (lavapipe, not --headless):
## VK_ICD_FILENAMES=/usr/share/vulkan/icd.d/lvp_icd.json xvfb-run -a -s "-screen 0 1280x800x24" \
##   godot --path . --resolution 1280x800 --script res://tools/shot_school.gd -- <out_dir> [name,name]
## [name, floor, tile, minute]
const SHOTS := [["staff_room", "1f", Vector2i(12, 5), 520], ["entrance", "1f", Vector2i(15, 15), 470],
	["infirmary", "1f", Vector2i(31, 6), 600], ["class_2b", "2f", Vector2i(20, 6), 620], ["library", "2f", Vector2i(30, 7), 935],
	["art_room", "2f", Vector2i(5, 15), 960], ["music_room", "3f", Vector2i(6, 14), 960], ["science_lab", "3f", Vector2i(18, 14), 1010],
	["roof_lunch", "roof", Vector2i(20, 10), 765], ["bell_corridor", "2f", Vector2i(18, 10), 750, "bell"]]
var _i := 0
var _step := 0
var _wait := 0
var _started := false


func _process(_d: float) -> bool:
	if _wait > 0:
		_wait -= 1
		return false
	var args := OS.get_cmdline_user_args()
	var out: String = args[0] if args.size() > 0 else "/tmp"
	var only: PackedStringArray = args[1].split(",") if args.size() > 1 else PackedStringArray()
	while _i < SHOTS.size() and not only.is_empty() and not only.has(str(SHOTS[_i][0])):
		_i += 1
	if _i >= SHOTS.size():
		quit(0)
		return true
	var s: Array = SHOTS[_i]
	match _step:
		0:
			if not _started:
				_started = true
				root.get_node("Game").new_game("Toru", {}, 7, {}, "", 17)
				root.get_node("Game").player_look = load("res://src/core/character_look.gd").cast_look("toru")
				root.get_node("Amane").st()["met"] = true
				root.get_node("Amane").st()["route"] = "friend"
			root.get_node("Clock").st()["minute"] = int(s[3])
			root.get_node("Router").params = {"floor": s[1], "at": [s[2].x, s[2].y]}
			change_scene_to_file("res://scenes/world/school.tscn")
			_wait = 70
		1:
			var hud = current_scene.get("hud")
			for _k in 6:
				if hud and hud.get("_dialogue_open"):
					hud._on_choice("")
			root.get_node("Clock").running = false
			current_scene._apply_light()
			var p = get_first_node_in_group("player")
			p.facing = Vector3(0, 0, -1)
			var a = get_first_node_in_group("amane")
			if a:
				a.global_position = p.global_position + Vector3(2.0, 0.1, 1.0)
				a.set("_approach_cd", 9999.0)
			current_scene.camera_rig.snap_to_target()
			_wait = 80 if str(s[1]) != "roof" else 420  # let the lunch crowd sit down
			if s.size() > 4 and str(s[4]) == "bell":
				current_scene._bell(root.get_node("Clock").period())
				_wait = 260  # mid-walk: students crossing the corridor
		2:
			root.get_texture().get_image().save_png("%s/%s.png" % [out, s[0]])
			print("shot ", s[0])
			_i += 1
			_step = 0
			return false
	_step += 1
	return false
