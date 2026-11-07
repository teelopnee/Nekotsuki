extends Control
## NEW GAME: who is Asagiri Toru? (docs/GDD.md 4.1). Toru is always a boy of seventeen; the player picks his given
## name and one tag in each of the five categories of data/toru.json (why he wants to be invisible, personality,
## skill, secret, goal). Every option says what it does. Emits `begin(name, tags)`; the title screen starts the game.

signal begin(given_name: String, tags: Dictionary)
signal cancelled

const DEFAULT := {"wound": "class_turned", "personality": "kind", "skill": "nothing", "secret": "sees_ghosts", "goal": "grandpa"}
const INK := Color(1.0, 0.94, 0.86)
const ACCENT := Color(1.0, 0.72, 0.55)

var picks := {}
var name_edit: LineEdit
var desc: Label
var _buttons := {}  ## cat -> {id: Button}
var _first: Button


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = Color(0.05, 0.03, 0.07, 0.96)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var scroll := ScrollContainer.new()
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	var margin := MarginContainer.new()
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for side in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + side, 48)
	for side in ["top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 22)
	scroll.add_child(margin)
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 8)
	margin.add_child(box)
	box.add_child(HUD.make_label("WHO IS ASAGIRI TORU?", 30, INK))
	box.add_child(HUD.make_label("Seventeen, second year, class 2-B. New in Suzunari this spring. The rest is up to you.", 16, Color(0.85, 0.8, 0.78)))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row.add_child(HUD.make_label("Name:  Asagiri", 20, INK))
	name_edit = LineEdit.new()
	name_edit.text = "Toru"
	name_edit.max_length = 12
	name_edit.custom_minimum_size = Vector2(220, 44)
	name_edit.add_theme_font_size_override("font_size", 20)
	row.add_child(name_edit)
	box.add_child(row)
	for c in Toru.categories():
		var cat := str(c.id)
		box.add_child(HUD.make_label(str(c.get("title", cat)), 17, ACCENT))
		var flow := HFlowContainer.new()
		flow.add_theme_constant_override("h_separation", 8)
		flow.add_theme_constant_override("v_separation", 6)
		var group := ButtonGroup.new()
		_buttons[cat] = {}
		for o in c.get("options", []):
			var b := Button.new()
			b.text = str(o.name)
			b.toggle_mode = true
			b.button_group = group
			b.custom_minimum_size = Vector2(0, 44)
			b.add_theme_font_size_override("font_size", 17)
			b.pressed.connect(_pick.bind(cat, str(o.id)))
			b.focus_entered.connect(_show.bind(cat, str(o.id)))
			b.mouse_entered.connect(_show.bind(cat, str(o.id)))
			flow.add_child(b)
			_buttons[cat][str(o.id)] = b
			if _first == null:
				_first = b
		box.add_child(flow)
	desc = HUD.make_label("", 17, Color(0.95, 0.9, 0.84))
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.custom_minimum_size = Vector2(0, 64)
	box.add_child(desc)
	var bottom := HBoxContainer.new()
	bottom.add_theme_constant_override("separation", 14)
	bottom.alignment = BoxContainer.ALIGNMENT_CENTER
	for spec in [["RANDOM", _randomise], ["BACK", _back], ["BEGIN", _begin]]:
		var b := Button.new()
		b.text = spec[0]
		b.custom_minimum_size = Vector2(190, 52)
		b.add_theme_font_size_override("font_size", 20)
		b.pressed.connect(spec[1])
		bottom.add_child(b)
	box.add_child(bottom)
	for cat in DEFAULT:
		_pick(cat, DEFAULT[cat])
	_show("wound", str(picks.get("wound", "")))
	if _first:
		_first.grab_focus.call_deferred()


func _pick(cat: String, id: String) -> void:
	picks[cat] = id
	for oid in _buttons.get(cat, {}):
		var b: Button = _buttons[cat][oid]
		b.set_pressed_no_signal(str(oid) == id)  # (no_signal skips the ButtonGroup, so unpress the rest by hand)
	_show(cat, id)


func _show(cat: String, id: String) -> void:
	var o := Toru.option(cat, id)
	if desc and not o.is_empty():
		desc.text = "%s - %s" % [str(o.name), str(o.get("desc", ""))]


func _randomise() -> void:
	var r := Toru.random_origin()
	for cat in r:
		_pick(str(cat), str(r[cat]))


func given_name() -> String:
	var n := name_edit.text.strip_edges() if name_edit else ""
	return n if n != "" else "Toru"


func _begin() -> void:
	begin.emit(given_name(), picks.duplicate())


func _back() -> void:
	cancelled.emit()
	queue_free()
