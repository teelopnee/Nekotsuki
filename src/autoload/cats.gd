extends Node
## Suzunari's cats are Amane's eyes (docs/GDD.md 4.5). Each cat has a name and remembers how you treat it
## (Game.flags["cats"]). A cat within 12 m that sees you get close to someone - and doesn't like you yet -
## runs to Amane; when it arrives he "knows" (Amane.notice_rival). Petting raises its attitude.

const NAMES := ["Mochi", "Kuro", "Tora", "Shiro", "Mikan", "Daifuku", "Goma", "Kinako", "Sora", "Hana", "Tama", "Ponzu"]
const FURS := [["#2a2630", "#2a2630"], ["#f2eee6", "#f2eee6"], ["#e8a050", "#f4efe6"], ["#8a8a96", "#c8c8d0"],
	["#e8a050", "#2a2630"], ["#2a2630", "#f4efe6"]]
const EYES := ["#ffd23e", "#7ad66a", "#6ab4ff", "#e8a050"]
const WATCH_RANGE := 12.0
const LIKES_YOU := 40


func st() -> Dictionary:
	if not Game.flags.has("cats") or not Game.flags["cats"] is Dictionary:
		Game.flags["cats"] = {}
	return Game.flags["cats"]


func _ready() -> void:
	EventBus.interaction_done.connect(_on_interaction)


func memory(id: String) -> Dictionary:
	var s := st()
	if not s.has(id):
		var r := RandomNumberGenerator.new()
		r.seed = hash(id)
		var fur: Array = FURS[r.randi() % FURS.size()]
		s[id] = {"name": NAMES[r.randi() % NAMES.size()], "attitude": r.randi_range(0, 25),
			"variant": ["cat_a", "cat_b", "cat_c"][r.randi() % 3], "fur": fur[0], "patch": fur[1], "eyes": EYES[r.randi() % EYES.size()]}
	return s[id]


## Put `count` cats on walkable tiles of a level (same cats every day: ids cat_0..).
func spawn_in(level: Node, count: int) -> Array:
	var out := []
	for i in count:
		var id := "cat_%d" % i
		var m := memory(id)
		var c := CatNPC.new()
		c.cat_id = id
		c.cat_name = str(m["name"])
		c.look = {"variant": m["variant"], "colors": {"hair": m["fur"], "scarf": m["patch"], "iris": m["eyes"], "dark": "#1a1030"}}
		level.actors.add_child(c)
		c.global_position = level.random_floor_position(6.0) + Vector3(0, 0.05, 0)
		c.home = c.global_position
		out.append(c)
	return out


func pet(cat: Node) -> void:
	var m := memory(str(cat.get("cat_id")))
	m["attitude"] = mini(100, int(m["attitude"]) + roundi(12 * Toru.cats_mult()))
	Toru.on_pet()
	FX.emote(cat, "heart", 1.6)
	var line := "%s purrs." % m["name"]
	if Toru.sneezes():
		var pl := get_tree().get_first_node_in_group("player")
		if pl:
			Emotion.express(pl, "sneeze", 1.2)
		line = "Achoo! %s purrs anyway. (Cat allergy: it only half counts.)" % m["name"]
	if str(cat.get("reporting")) != "":
		cat.cancel_report()
		line = "%s forgets what it was going to tell Amane. It purrs instead." % m["name"]
	if int(m["attitude"]) >= LIKES_YOU:
		line += " (%s likes you now - it won't tell on you.)" % m["name"]
	EventBus.toast.emit(line, Color(1.0, 0.85, 0.6))


func _on_interaction(_verb: String, success: bool, npc: Node) -> void:
	if not success or npc == null or npc.is_in_group("amane") or not Amane.st()["met"] or Toru.quirk("cat_servant"):
		return
	var p := get_tree().get_first_node_in_group("player") as Node3D
	if p == null:
		return
	for c in get_tree().get_nodes_in_group("cat"):
		if str(c.reporting) != "" or c.global_position.distance_to(p.global_position) > WATCH_RANGE:
			continue
		if int(memory(str(c.cat_id))["attitude"]) >= LIKES_YOU:
			continue
		c.start_report(str(npc.get("npc_name")))
		return


func report_done(cat: Node, who: String) -> void:
	var a := get_tree().get_first_node_in_group("amane") as Node3D
	Amane.st()["cat_reports"] = int(Amane.st()["cat_reports"]) + 1
	Amane.notice_rival(who, a)
	Amane.post("cat")
	EventBus.toast.emit("%s reached Amane. He knows about %s now." % [memory(str(cat.get("cat_id")))["name"], who], Color(1.0, 0.6, 0.7))
