class_name StageNPC
extends NPC
## Someone who only exists in a staged ending (EndingStage): a cast look from data/cast_looks.json, a name tag, no AI,
## no talk menu. EndingStage walks, turns and emotes them.

var cast_id := ""
var label := ""


func _ready() -> void:
	npc_name = label
	look = CharacterLook.cast_look(cast_id) if cast_id != "" else CharacterLook.default_look()
	loyal = true
	super._ready()
	name_label.text = npc_name
	add_to_group("stage_actor")
	set_physics_process(false)
	sprite.play("idle")


func _on_talk(_player: Node) -> void:
	pass  # they speak in the ending's lines, not through the talk menu
