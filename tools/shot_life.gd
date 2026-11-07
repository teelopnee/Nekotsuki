extends SceneTree
## Screenshots of Toru's life screens: the NEW GAME creator, a cat spirit night at the rival's window, and the
## ledger page (an entry with its stamp, the Johari mirror).
## VK_ICD_FILENAMES=/usr/share/vulkan/icd.d/lvp_icd.json xvfb-run -a -s "-screen 0 1280x800x24" godot --path . \
##   --resolution 1280x800 --script res://tools/shot_life.gd -- <out_dir>

var _step := 0
var _wait := 0
var _out := "user://shots"
var _page: Control
var _creator: Control


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if not args.is_empty():
		_out = args[0]
	DirAccess.make_dir_recursive_absolute(_out)


func _shot(name: String) -> void:
	var img := root.get_texture().get_image()
	if img:
		img.save_png("%s/%s.png" % [_out, name])
		print("shot ", name)


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
	var amane = root.get_node("Amane")
	var clock = root.get_node("Clock")
	var lvl = current_scene
	var hud = lvl.get("hud") if lvl else null
	match _step:
		0:
			_creator = load("res://src/ui/toru_creator.gd").new()
			root.add_child(_creator)
			_creator._pick("secret", "cat_allergy")
			_wait = 20
		1:
			_shot("life_creator")
			_creator.queue_free()
			game.new_game("Toru", {}, -1, load("res://src/core/character_look.gd").cast_look("toru"), "", 17)
			game.location_id = "suzunari"
			root.get_node("Toru").apply_origin({"wound": "class_turned", "personality": "soft_hearted", "skill": "cooking", "secret": "sees_ghosts", "goal": "grandpa"})
			amane.st()["met"] = true
			clock.st()["day"] = 8
			amane.add_closeness("Inukai Hayate", 30)
			amane.pick_rival()
			game.flags["cat_night"] = {"day": 8, "rival": amane.rival()}
			change_scene_to_file("res://scenes/world/suzunari.tscn")
			_wait = 120
		2:
			if hud and hud._dialogue_open:
				for b in hud._dialogue_choices.get_children():
					if str(b.text).contains("Open your eyes"):
						b.pressed.emit()
			_close_all(hud)
			lvl.player.global_position = lvl._cat_rival_pos + Vector3(-1.5, 0.1, 2.5)
			_wait = 90
		3:
			_shot("life_cat_night")
			lvl.player.global_position = lvl.builder.center(13, 39) + Vector3(0, 0.1, 0)
			lvl.player.facing = Vector3(0, 0, 1)
			lvl.cat_leap()
			_wait = 240
		4:
			lvl.player.facing = Vector3(1, 0, 0)
			_shot("life_cat_roof")
			lvl.player.global_position = lvl._cat_rival_pos + Vector3(-1.5, 0.1, 2.5)
			_wait = 60
		5:
			lvl._cat_rival_window()
			_wait = 30
		6:
			_shot("life_cat_window")
			_close_all(hud)
			# A life's worth of deeds for the ledger page.
			game.flags["cat_night_log"] = [{"day": 8, "rival": "Inukai Hayate", "outcome": "resist", "stage": 0}, {"day": 15, "rival": "Inukai Hayate", "outcome": "plan", "stage": 1}]
			game.flags["deeds"] = [{"day": 8, "kind": "knock", "id": "pot"}, {"day": 8, "kind": "eavesdrop", "id": "mio"}]
			game.flags["ending"] = "right_distance"
			root.get_node("Toru").join("cooking")
			root.get_node("Toru").st()["sessions"]["cooking"] = 6
			amane.st()["route"] = "friend"
			var holder := Node.new()
			root.add_child(holder)
			root.get_node("Ledger").show_page(holder)
			_wait = 10
		7:
			for n in root.find_children("*", "Control", true, false):
				if n.get_script() and str(n.get_script().resource_path).ends_with("ledger_page.gd"):
					_page = n
			_wait = 400
		8:
			_page.advance()
			_wait = 400
		9:
			_shot("life_ledger_entry")
			_page.skip_all()
			_wait = 60
		10:
			_page.stage = "entry"
			_page.index = _page.entries.size()
			_page._busy = false
			_page._skip = false
			_page.advance()
			_wait = 160
		11:
			_shot("life_ledger_mirror")
			quit(0)
	_step += 1
	return false
