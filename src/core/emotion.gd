class_name Emotion
extends RefCounted
## Expressive chibi reactions: an emotion picks a body animation (rendered by tools/sprite_forge.py
## for school/cast variants) plus a manga emote above the head. Data: data/emotions.json.

static var _data: Dictionary = {}


static func table() -> Dictionary:
	if _data.is_empty():
		var path := "res://data/emotions.json"
		if FileAccess.file_exists(path):
			var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
			if parsed is Dictionary:
				_data = parsed
	return _data


## Show `feeling` on an actor that has a `sprite: BillboardSprite` (NPC, Player).
static func express(actor: Node3D, feeling: String, seconds: float = 2.5) -> void:
	var e: Dictionary = table().get(feeling, {})
	if e.is_empty() or actor == null:
		return
	var spr = actor.get("sprite")
	if spr is BillboardSprite:
		(spr as BillboardSprite).emote(str(e.get("anim", "")), seconds)
	FX.emote(actor, str(e.get("fx", "")), seconds)
