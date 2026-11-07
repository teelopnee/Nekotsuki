extends SceneTree
## Screenshots of Ura-Suzunari (GPU or lavapipe, not --headless):
## godot --path . --resolution 1280x800 --script res://tools/shot_ura.gd -- <out_dir>
## Shots: arriving at the steps (echoes, kasha), the dry riverbed with Sayo.

var _step := 0
var _wait := 0
var _out := "/tmp"


func _process(_d: float) -> bool:
	if _wait > 0:
		_wait -= 1
		return false
	if OS.get_cmdline_user_args().size() > 0:
		_out = OS.get_cmdline_user_args()[0]
	var game = root.get_node("Game")
	var lvl = current_scene
	match _step:
		0:
			game.new_game("Toru", {}, 7, {}, "", 17)
			game.player_look = load("res://src/core/character_look.gd").cast_look("toru")
			game.location_id = "suzunari"
			root.get_node("Amane").st()["met"] = true
			change_scene_to_file("res://scenes/world/suzunari.tscn")
			_wait = 60
		1:
			root.get_node("Clock").st()["minute"] = 1085
			root.get_node("Week").enter_ura("riverbed")
			_wait = 150
		2:
			var hud = lvl.get("hud")
			for _i in 6:
				if hud and hud._dialogue_open:
					hud._on_choice("")
			var p = lvl.player
			p.global_position = lvl.builder.center(4, 21)
			p.facing = Vector3(0, 0, -1)
			for e in get_nodes_in_group("enemy"):
				e.global_position = p.global_position + Vector3(3.5, 0.1, 2.5)
				break
			lvl.camera_rig.snap_to_target()
			_wait = 90
		3:
			root.get_texture().get_image().save_png("%s/ura_steps.png" % _out)
			var p = lvl.player
			p.global_position = lvl.builder.center(27, 46)
			lvl.camera_rig.snap_to_target()
			_wait = 90
		4:
			root.get_texture().get_image().save_png("%s/ura_riverbed.png" % _out)
			quit(0)
	_step += 1
	return false
