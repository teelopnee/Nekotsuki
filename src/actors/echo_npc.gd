class_name EchoNPC
extends NPC
## Ura-Suzunari (data/ura.json): an echo of the past replaying at a landmark (1868, 1890, 1945, 2011, 2016), or the
## goal person of a visit (Sayo on the dry riverbed). Translucent unless `solid`; stands still and repeats itself;
## talking opens Town.scene with the echo's choices.

var echo: Dictionary = {}
var solid := false
var _talking_now := false


func _ready() -> void:
	npc_name = str(echo.get("label", "An echo"))
	var lk := str(echo.get("look", ""))
	look = CharacterLook.cast_look(lk) if lk != "" else CharacterLook.default_look()
	loyal = true
	super._ready()
	name_label.text = npc_name
	add_to_group("echo")
	if not solid:
		sprite.modulate = Color(1.0, 0.55, 0.6, 0.55)
	set_physics_process(false)
	sprite.play("idle")


func face_player() -> void:
	var p := get_tree().get_first_node_in_group("player") as Node3D
	if p:
		sprite.set_facing(p.global_position - global_position)


func _on_talk(_player: Node) -> void:
	if _talking_now:
		return
	_talking_now = true
	face_player()
	await Town.scene(str(echo.get("speaker", "")), Week.fill(str(echo.get("text", ""))), echo.get("choices", []),
		"ura_" + str(echo.get("id", "echo")))
	_talking_now = false
	var lvl := get_tree().get_first_node_in_group("level")
	if lvl and lvl.has_method("ura_scene_done"):
		lvl.ura_scene_done(str(echo.get("id", "")))
