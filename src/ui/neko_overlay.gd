extends CanvasLayer
## Suzunari HUD additions: date / time / period / forecast in the corner, and the phone (Rinrin chat with
## Amane: reply, leave on read, mute, block; end the day at night). Opening the phone pauses the world.

var level: Node
var _clock: Label
var _forecast: Label
var _phone_btn: Button
var _panel: PanelContainer
var _log: RichTextLabel
var _note: Label
var _end_btn: Button
var _watch_btn: Button
var _tab := 0  ## 0 Rinrin, 1 Ura board, 2 Notes (Town codex)
const TABS := ["Rinrin", "Ura board", "Notes"]
var _title: Label


func _ready() -> void:
	layer = 6
	process_mode = Node.PROCESS_MODE_ALWAYS
	var box := VBoxContainer.new()
	box.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	box.offset_left = -300
	box.offset_top = 12
	box.offset_right = -14
	box.alignment = BoxContainer.ALIGNMENT_BEGIN
	add_child(box)
	_clock = HUD.make_label("", 20, Color(1.0, 0.93, 0.8))
	_clock.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	box.add_child(_clock)
	_forecast = HUD.make_label("", 15, Color(0.75, 0.86, 1.0))
	_forecast.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	box.add_child(_forecast)
	_phone_btn = Button.new()
	_phone_btn.size_flags_horizontal = Control.SIZE_SHRINK_END
	_phone_btn.custom_minimum_size = Vector2(150, 44)
	_phone_btn.pressed.connect(open_phone)
	box.add_child(_phone_btn)
	_build_panel()
	Clock.minute_passed.connect(func(_m): _refresh())
	Amane.changed.connect(_refresh)
	Amane.message_received.connect(func(t): EventBus.toast.emit("Rinrin - Amane: " + t, Color(1.0, 0.75, 0.85)))
	_refresh()


func _build_panel() -> void:
	_panel = PanelContainer.new()
	_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_panel.custom_minimum_size = Vector2(600, 560)
	_panel.offset_left = -300
	_panel.offset_right = 300
	_panel.offset_top = -280
	_panel.offset_bottom = 280
	_panel.visible = false
	add_child(_panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	_panel.add_child(v)
	var top := HBoxContainer.new()
	v.add_child(top)
	_title = HUD.make_label("RINRIN  -  Amane (1-A)", 18, Color(1.0, 0.8, 0.88))
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(_title)
	for i in TABS.size():
		var tab := Button.new()
		tab.text = TABS[i]
		tab.custom_minimum_size = Vector2(96, 40)
		tab.pressed.connect(func():
			_tab = i
			_fill_log())
		top.add_child(tab)
	_log = RichTextLabel.new()
	_log.bbcode_enabled = true
	_log.scroll_following = true
	_log.custom_minimum_size = Vector2(480, 300)
	_log.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(_log)
	_note = HUD.make_label("", 15, Color(0.85, 0.95, 1.0))
	_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_note.custom_minimum_size = Vector2(480, 0)
	v.add_child(_note)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	v.add_child(row)
	for pair in [["reply", "Reply"], ["read", "Leave on read"], ["mute", "Mute"], ["block", "Block"]]:
		var b := Button.new()
		b.text = pair[1]
		b.custom_minimum_size = Vector2(110, 44)
		b.pressed.connect(_reply.bind(pair[0]))
		row.add_child(b)
	var row2 := HBoxContainer.new()
	v.add_child(row2)
	_watch_btn = Button.new()
	_watch_btn.text = "Watch the rooftops"
	_watch_btn.custom_minimum_size = Vector2(200, 44)
	_watch_btn.pressed.connect(func():
		close_phone()
		if level and level.has_method("night_watch"):
			level.night_watch())
	row2.add_child(_watch_btn)
	_end_btn = Button.new()
	_end_btn.text = "Go to bed (end the day)"
	_end_btn.custom_minimum_size = Vector2(240, 44)
	_end_btn.pressed.connect(_end_day)
	row2.add_child(_end_btn)
	var close := Button.new()
	close.text = "Close"
	close.custom_minimum_size = Vector2(120, 44)
	close.pressed.connect(close_phone)
	row2.add_child(close)


func _refresh() -> void:
	_clock.text = "%s  %s  %s" % [Clock.date_text(), Clock.clock_text(), Clock.period()]
	if Game.flags.has("cat_night"):
		_clock.text = "%s  23:40  Night" % Clock.date_text()  # Amane's living spirit walks after 23:00
	_forecast.text = "Forecast: %s" % Amane.FORECAST[Amane.tears_level()]
	var unread := int(Amane.st()["unread"])
	_phone_btn.text = "PHONE" + ("  (%d)" % unread if unread > 0 else "")
	if _panel.visible:
		_fill_log()


func _fill_log() -> void:
	_watch_btn.disabled = Clock.minute() < 21 * 60 or Amane.rival() == "" or Amane.fate(Amane.rival()) in ["injured", "hidden"]
	_end_btn.disabled = Clock.minute() < Clock.NIGHT
	if _tab == 2:
		_title.text = "NOTES  -  what Suzunari told you"
		_log.scroll_following = false
		_log.text = _notes_text()
		return
	_log.scroll_following = true
	if _tab == 1:
		_title.text = "URA BOARD  -  Suzunari Gakuen (anonymous)"
		var u := ""
		for p in Amane.st()["ura"]:
			u += "[color=#8a8aa8]%s %s[/color]  %s\n" % [p.get("day", ""), p.get("time", ""), str(p.get("text", ""))]
		_log.text = u if u != "" else "[color=#8a8aa8]Nothing yet. Give it a day.[/color]"
		return
	_title.text = "RINRIN  -  Amane (1-A)"
	var t := ""
	for m in Amane.st()["messages"]:
		var mine: bool = str(m.get("from", "")) == "me"
		t += "[color=#8a8aa8]%s[/color]  %s%s[/color]\n" % [m.get("time", ""), "[color=#cdebff]You: " if mine else "[color=#ffd6e2]", str(m.get("text", ""))]
	if t == "":
		t = "[color=#8a8aa8]No messages yet.[/color]"
	_log.text = t
	_end_btn.disabled = Clock.minute() < Clock.NIGHT


func open_phone() -> void:
	_note.text = "Answering fast makes him happy. Leaving him on read makes it rain."
	_panel.visible = true
	_fill_log()
	get_tree().paused = true


func close_phone() -> void:
	_panel.visible = false
	get_tree().paused = false
	_refresh()


func _reply(kind: String) -> void:
	_note.text = Amane.phone_reply(kind)
	_fill_log()
	_refresh()


func _end_day() -> void:
	close_phone()
	if level and level.has_method("end_day"):
		level.end_day()


## The codex: remembered lore, places read, people met, the Hyakki Zukan, promises and Easter eggs.
func _notes_text() -> String:
	var c := Town.codex()
	var t := "[color=#ffd6a0]REMEMBERED[/color]  (%d)\n" % c.lore.size()
	for l in c.lore:
		t += "  - %s\n" % l
	t += "\n[color=#ffd6a0]PROMISES[/color]\n"
	for pr in c.promises:
		t += "  - %s\n" % str(pr).replace("_", " ")
	if c.promises.is_empty():
		t += "  [color=#8a8aa8](none - careful what you say in this town)[/color]\n"
	t += "\n[color=#ffd6a0]PEOPLE[/color]\n"
	for p in c.people:
		t += "  - %s\n" % p
	var mornings := People.notes_text().split("\n")
	t += "\n[color=#ffd6a0]%s[/color]\n%s\n" % [mornings[0], "\n".join(mornings.slice(1))]
	t += "\n[color=#ffd6a0]HYAKKI ZUKAN[/color]  (%d / %d)\n  %s\n" % [c.zukan.filter(func(z): return z != "???").size(), c.zukan.size(), ", ".join(c.zukan)]
	t += "\n[color=#ffd6a0]PLACES[/color]  (%d)\n" % c.places.size()
	for p in c.places:
		t += "  - %s\n" % p
	t += "\n[color=#b07dff]??? found: %d / %d[/color]\n" % [c.eggs, c.eggs_total]
	return t
