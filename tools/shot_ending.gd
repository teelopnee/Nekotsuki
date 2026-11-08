extends SceneTree
## Screenshots of staged endings (EndingStage, data/endings.json stage), one PNG per spoken line (GPU or lavapipe):
## godot --path . --resolution 1280x800 --script res://tools/shot_ending.gd -- <out_dir> [ending_id,ending_id...]
## Default: okaeri,red_thread,cat_who_waits,dog_and_cat. Files: <out_dir>/end_<id>_<n>.png

var _step := 0
var _wait := 0
var _out := "/tmp"
var _ids: Array = ["okaeri", "red_thread", "cat_who_waits", "dog_and_cat"]
var _i := 0
var _n := 0
var _last := ""
var _settle := 0
var _running := false


func _process(_d: float) -> bool:
	if _wait > 0:
		_wait -= 1
		return false
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		_out = args[0]
	if args.size() > 1:
		_ids = args[1].split(",")
	var lvl = current_scene
	var hud = lvl.get("hud") if lvl else null
	match _step:
		0:
			var game = root.get_node("Game")
			game.new_game("Toru", {}, 7, {}, "", 17)
			game.player_look = load("res://src/core/character_look.gd").cast_look("toru")
			game.location_id = "suzunari"
			root.get_node("Amane").st()["met"] = true
			root.get_node("Clock").st()["minute"] = 1200
			change_scene_to_file("res://scenes/world/suzunari.tscn")
			_wait = 90
			_step = 1
		1:
			for _k in 8:
				if hud and hud._dialogue_open:
					hud._on_choice("")
			if _i >= _ids.size():
				quit(0)
				return true
			var id := str(_ids[_i])
			var e: Dictionary = root.get_node("Week").endings.get("endings", {}).get(id, {})
			_n = 0
			_last = ""
			_running = true
			_play(lvl, e.get("stage", []), hud)
			_step = 2
		2:
			if not _running:
				_i += 1
				change_scene_to_file("res://scenes/world/suzunari.tscn")  # a fresh town for the next ending
				_wait = 90
				_step = 1
				return false
			if hud and hud._dialogue_open:
				var t := str(hud._dialogue_text.text)
				if t != _last:
					_last = t
					_settle = 40  # let the typewriter and the close-up camera finish
				elif _settle > 0:
					_settle -= 1
				else:
					_n += 1
					root.get_texture().get_image().save_png("%s/end_%s_%d.png" % [_out, str(_ids[_i]), _n])
					hud._on_choice("")
	return false


func _play(lvl, stage: Array, hud) -> void:
	await lvl.stage_ending(stage, hud)
	_running = false
