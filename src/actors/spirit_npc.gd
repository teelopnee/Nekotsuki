class_name SpiritNPC
extends NPC
## A Suzunari regular from data/town.json "spirits": cast members at their spot (Chiyo, Makabe-sensei, Mio,
## Hina) and the town's yokai (kappa, tanuki, rokurokubi, nopperabo, kuchisake-onna, zashiki-warashi,
## Hanako-san). Present only during their hours; talking opens Town.meet() (exact words to pick).

var spirit_id := ""
var spot := Vector3.ZERO
var _talking_now := false
var _shown := true


func _ready() -> void:
	var sp := Town.spirit(spirit_id)
	npc_name = str(sp.get("name", "?"))
	look = CharacterLook.cast_look(str(sp.get("look", "")))
	loyal = true
	super._ready()
	name_label.text = npc_name
	add_to_group("spirit")
	_refresh()
	Clock.minute_passed.connect(func(_m): _refresh())


func set_home(p: Vector3) -> void:
	spot = p
	_home = p


func _refresh() -> void:
	var on := Town.present(Town.spirit(spirit_id))
	if on == _shown:
		return
	_shown = on
	visible = on
	talk.enabled = on
	set_physics_process(on)
	collision_layer = 8 if on else 0


func _physics_process(_delta: float) -> void:
	if state == "dead" or _talking_now or not _shown:
		return
	var p := get_tree().get_first_node_in_group("player") as Node3D
	var to := spot - global_position
	to.y = 0.0
	if to.length() > 0.5:
		velocity = Vector3(to.normalized().x * 1.6, 0.0, to.normalized().z * 1.6)
		move_and_slide()
		sprite.set_facing(velocity)
		sprite.play("walk")
		return
	if p and p.global_position.distance_to(global_position) < 7.0:
		sprite.set_facing(p.global_position - global_position)
	sprite.play("idle")


func face_player() -> void:
	var p := get_tree().get_first_node_in_group("player") as Node3D
	if p:
		sprite.set_facing(p.global_position - global_position)


func _on_talk(_player: Node) -> void:
	if _talking_now or not _shown:
		return
	_talking_now = true
	await Town.meet(spirit_id, self)
	_talking_now = false
