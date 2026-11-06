extends Node
## Enma's Ledger (閻魔帳, docs/LORE.md 9): what every episode remembers. Written at the end of each day and
## read by later episodes (user://ledger.json). Dōmyō writes the good, Dōshō the bad - here it is just JSON.

const PATH := "user://ledger.json"


func snapshot() -> Dictionary:
	var a := Amane.st()
	var chars := {"amane": {"route": Amane.route(), "bond_now": a["bond_now"], "bond_past": a["bond_past"],
		"self": a["self"], "trust": a["trust"], "ikiryo_named": a["ikiryo_named"], "cat_reports": a["cat_reports"]}}
	for who in a["closeness"]:
		chars[str(who)] = {"closeness": a["closeness"][who], "fate": Amane.fate(str(who))}
	for who in a["fates"]:
		if not chars.has(str(who)):
			chars[str(who)] = {"closeness": 0, "fate": a["fates"][who]}
	var cats := {}
	for id in Cats.st():
		cats[id] = {"name": Cats.st()[id]["name"], "attitude": Cats.st()[id]["attitude"]}
	return {"version": 1, "episode": 0, "player": Game.player_name, "day": Clock.day(), "date": Clock.date_text(),
		"rival": Amane.rival(), "stage": int(a["plan"]["stage"]), "characters": chars, "cats": cats}


func write() -> bool:
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(JSON.stringify(snapshot(), "\t"))
	f.close()
	return true


func read() -> Dictionary:
	if not FileAccess.file_exists(PATH):
		return {}
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	return parsed if parsed is Dictionary else {}
