#!/usr/bin/env python3
"""Suzunari theme overlay: turns the inherited ODD-SPACE text into a Japanese seaside town.

1. Auto pass: every string in the listed data files goes through REPLACE (credits -> yen, Paragon -> the police,
   protein paste -> instant noodles...). Strings that still mention things that cannot exist in Suzunari (BAD:
   implants, androids, air bills...) are dropped from line lists when the list has other lines left.
2. Hand-written overrides from data/suzunari/_manual/<file>.json are deep-merged on top (dicts merge, lists replace).
3. Output: data/suzunari/<file>.json (DataDB.apply_theme / NPC barks / Tips load these when DataDB.theme == "suzunari")
   and data/copy_suzunari_auto.json (Copy symbols "suzunari_<symbol>", used when Copy.theme == "suzunari").

Run after editing the base data or the manual overrides:  python3 tools/suzunari_theme.py
"""
import json
import os
import re

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DATA = os.path.join(ROOT, "data")
OUT = os.path.join(DATA, "suzunari")
FILES = ["barks.json", "venues.json", "interactions.json", "counters.json", "items.json", "tips.json"]
COPY_FILES = ["copy.json", "copy_people.json", "copy_reactions.json"]
WORDS = {"a": 1, "one": 1, "two": 2, "three": 3, "four": 4, "five": 5, "six": 6, "ten": 10, "twenty": 20, "fifty": 50}


def _yen(n):
    return "{:,} yen".format(n * 100)


REPLACE = [
    (r"\b(\d+)\s*(?:cr|credits?)\b", lambda m: _yen(int(m.group(1)))),
    (r"\b(a|one|two|three|four|five|six|ten|twenty|fifty) credits?\b", lambda m: _yen(WORDS[m.group(1).lower()])),
    (r"\bcredit chips?\b", "coins"), (r"\bCredits\b", "Money"), (r"\bcredits?\b", "money"), (r"\bCR\b", "YEN"),
    (r"\bon another planet\b", "in another town"), (r"\bon \{planet\}", "in Suzunari"), (r"\bON \{PLANET\}", "IN SUZUNARI"),
    (r"\{PLANET\}", "SUZUNARI"), (r"\{planet\}", "Suzunari"), (r"I'm \{job\}", "I'm {job_a}"),
    (r"\bParagon (habits|heirs)\b", r"police \1"),
    (r"\bParagon Compliance(?: Services)?\b", "the police"), (r"\bParagon officers?\b", "police officers"),
    (r"\bthe Paragon\b", "the police"), (r"\bParagon\b", "the police"),
    (r"\bthe Consortium\b", "the town council"), (r"\bConsortium\b", "council"),
    (r"\bOxyGenix(?: Atmospherics)?\b", "the water company"), (r"\bHalcyon(?: Debt & Trust)?\b", "the bank"),
    (r"\bGristle(?: Nutrition)?(?: Group)?\b", "the konbini chain"), (r"\bLumen(?: Omnimedia)?\b", "the TV news"),
    (r"(?i)\bProtein Paste(?:\(tm\))?", "instant noodles"), (r"\bPASTE\b", "NOODLES"), (r"(?i)\bpaste\b", "instant noodles"),
    (r"\bplanets\b", "towns"), (r"\bplanet\b", "town"), (r"\bthe galaxy\b", "Japan"), (r"\bgalaxy\b", "country"),
    (r"\bholo-?ads?\b", "TV ads"), (r"\bholograms?\b", "billboard"), (r"\bholo\b", "TV"),
    (r"\bneon\b", "lantern"), (r"\brepo[- ]drones?\b", "debt collectors"), (r"\bdrones\b", "crows"), (r"\bdrone\b", "crow"),
    (r"\bwristpads?\b", "phone"), (r"\bstarship\b", "train"), (r"\bspacers?\b", "outsiders"), (r"\bbounty\b", "trouble"),
    (r"\bPARAGON\b", "THE POLICE"), (r"\bCONSORTIUM\b", "TOWN COUNCIL"), (r"\bCREDITS?\b", "YEN"), (r"\bNEON\b", "LANTERN"),
    (r"\bNeon\b", "Lantern"), (r"(?i)\bsynth[- ]?keytar\b", "old keyboard"), (r"\bRepo Stun Baton\b", "Stun Baton"),
    (r"\bRepo Hammer\b", "Sledgehammer"), (r"\bRepo\b", "Debt"), (r"\brepo\b", "debt"),
    (r"\bCorporate\b", "Company"), (r"\bcorporate\b", "company"), (r"\bCOLLATERAL\b", "IN DEBT"),
    (r"\b[Cc]ollateral\b", "in hock"), (r"\bthe ship's deck\b", "the cassette deck"), (r"\bship's deck\b", "cassette deck"),
    (r"The ship\? THE ship\?", "The shrine? THE shrine?"), (r"seen kids debt a whole freighter", "seen kids talk their way out of worse"),
    (r"\bCredit, contacts\b", "Photos, contacts"), (r"voice of a dying robot", "voice of a dying TV announcer"),
    (r"\bDrones\b", "Crows"), (r"Everyone in it is someone's in hock\.", "Everyone in it owes somebody something."),
    (r"when the ship is quiet", "when the house is quiet"), (r"join your crew", "hang out with you"),
    (r"Heard you have a ship\. I've got nothing\.", "Heard you're new in town. I've got nothing to do either."),
    (r"\bkeytar\b", "keyboard"), (r"Implant Workshop", "Phone & Watch Repair"), (r"\bHolo-Ink\b", "Glow-Ink"),
    (r"old synth record", "old enka record"), (r"smiling cyborg: UPGRADE OR BE UPGRADED", "smiling mascot: NEW YEAR, NEW YOU"),
    (r"\bREPO\b", "DEBT"), (r"Interface with their implants", "Look at their phone"), (r"\bimplants\b", "phones"),
    (r"\ba cyberdeck\b", "an old laptop"), (r"\bCyberdeck\b", "Old Laptop"), (r"\bPlanet-sized\b", "Town-sized"), (r"\bPlanet\b", "Town"),
    (r"\bthe the\b", "the"), (r"\bThe the\b", "The"), (r"\ba the police\b", "a police"), (r"\bon Suzunari\b", "in Suzunari"),
    (r"\bAD-BOMB\b", "FIRECRACKER"), (r"\b[Aa]d-bomb\b", "firecracker"), (r"\bA medkit\b", "A first-aid kit"),
    (r"\bmedkits?\b", "first-aid kit"),
    (r"Heals 25 HP if you're synthetic\. Tingles if you're not\.", "A spare phone battery. Licking it is a bad idea. Heals 25 HP."),
    (r"Everything is sharper\. Including the ads\. Especially the ads\.", "Everything is sharper. Including the crack in your screen."),
    (r"about the Odd Duck, the debt, the stars\.", "about Tokyo, the move, the rain that hasn't stopped since."),
    (r"I'm from the Odd Duck\.", "I'm Asagiri-do's nephew."), (r"\bthe Odd Duck\b", "Asagiri-do"),
    (r"The ad-bridge\. .*? patrol under the ads\.", "Under the bridge. The police never walk down there."),
    (r"The ads hypnotise you after a while\.", "I was miles away. This town does that to you."),
    (r"one more grey shape under the ads", "one more grey shape under the shop awnings"),
    (r"You describe the sky with no ads\.", "You describe a sky with no power lines in it."),
    (r"\bMedkit\b", "First-aid Kit"), (r"Your family's ad wakes", "Your family's TV jingle wakes"),
]
## "the police" replaced a singular name (Paragon): fix the verb and capitalise it at the start of a sentence.
POLICE_VERBS = {"doesn't": "don't", "does": "do", "is": "are", "isn't": "aren't", "has": "have", "hasn't": "haven't",
                "was": "were", "wasn't": "weren't"}
POLICE_S = ("says thanks reads gives asks sweeps reminds checks shows wants knows sees files patrols pays calls keeps "
            "comes takes likes needs watches scans gets hates loves finds tracks hunts logs runs sends buys sells owns leaves "
            "makes uses tells thinks raids stops fines arrests follows flags notices bans catches questions searches records "
            "puts").split()


def _police(m):
    v = m.group(2)
    low = v.lower()
    if low in POLICE_VERBS:
        nv = POLICE_VERBS[low]
    elif low in POLICE_S:
        nv = v[:-2] if low.endswith(("ches", "shes", "sses")) else v[:-1]
    else:
        return m.group(0)
    return m.group(1) + " " + nv


def fix_police(s):
    if s.strip().lower() == "the police":  # a grammar symbol used mid-sentence (#faction#)
        return s
    s = re.sub(r"\b([Tt]he police) ([A-Za-z']+)\b", _police, s)
    return re.sub(r"(^|[.!?]\s+|[\"(]\s*)the police\b", lambda m: m.group(1) + "The police", s)
## Whole bark families that only make sense in ODD-SPACE (enemy taunts, planets, crew recruiting, the station).
DROP_BARK_KEYS = ("taunt", "hurt", "yield", "standdown", "biome", "recruit", "station", "crisis")
BAD = re.compile(r"implant|android|robot|cyber|laser|blaster|hover|warp|orbit|chrome|\bvat\b|cryo|quack|q\.u\.a\.c\.k|"
                 r"\bair\b(?! of)|\bO2\b|oxygen|breath|lungs|asteroid|space|synth-|alien|mutant|\bgrub|subsystem|jetpack|"
                 r"hull|airlock|terraform|clone|ad-bomb|odd duck|compliance|megacorp|sprawl|ad network|gravity|scanning|freighter|"
                 r"\bship\b|\bcrew\b|sub-asset|section \d|barcode|\btank\b|in hock|\bcorp\b|credit check|uploading|"
                 r"\bads?\b|\bad-\w+|ad blockers?|\bscanners?\b|"
                 # ODD-SPACE's billing dystopia: fine satire there, wrong for a seaside town (third review #1)
                 r"\bbill(?:ed|ing)\b|invoice|subscri|repossess|\bfees?\b|taxed|sponsored|off-world|isn't bots|speakers say|"
                 r"overlord|customer delight|liquidity|upsell|synergy|explosive|patent|"
                 # the ODD-SPACE saga / galaxy vars: its people, planets and plots don't exist in Suzunari
                 r"\{(?:ally|antagonist|antagonist_title|lieutenant|macguffin|scheme|objective_planet|other_planet|"
                 r"other_crisis|other_controller|local_hint|local_name|crew|heir|controller|crisis)\}", re.I)


def conv(s):
    for pat, rep in REPLACE:
        s = re.sub(pat, rep, s)
    return fix_police(s)


stats = {"strings": 0, "changed": 0, "dropped": 0, "kept_bad": 0}


def walk(o):
    if isinstance(o, str):
        stats["strings"] += 1
        c = conv(o)
        if c != o:
            stats["changed"] += 1
        return c
    if isinstance(o, list):
        out = [walk(x) for x in o]
        if out and all(isinstance(x, str) for x in out):
            good = [x for x in out if not BAD.search(x)]
            stats["dropped"] += len(out) - len(good)
            if good:
                return good
            stats["kept_bad"] += len(out)
        return out
    if isinstance(o, dict):
        return {k: (v if k.startswith("_") else walk(v)) for k, v in o.items()}
    return o


def merge(base, over):
    if isinstance(base, dict) and isinstance(over, dict):
        if over.get("_replace"):
            return {k: v for k, v in over.items() if k != "_replace"}
        out = dict(base)
        for k, v in over.items():
            out[k] = merge(base.get(k), v) if k in base else v
        return out
    return over


def main():
    os.makedirs(OUT, exist_ok=True)
    for f in FILES:
        base = json.load(open(os.path.join(DATA, f)))
        if f == "barks.json":
            base = {k: v for k, v in base.items() if k.split(":")[0] not in DROP_BARK_KEYS}
        themed = walk(base)
        man = os.path.join(OUT, "_manual", f)
        if os.path.exists(man):
            themed = merge(themed, json.load(open(man)))
        themed["_doc"] = "GENERATED by tools/suzunari_theme.py from data/%s + data/suzunari/_manual/%s. Edit those, not this." % (f, f)
        json.dump(themed, open(os.path.join(OUT, f), "w"), indent=1, ensure_ascii=False)
    rules = {}
    for f in COPY_FILES:
        for k, v in json.load(open(os.path.join(DATA, f)))["rules"].items():
            nv = walk(v)
            if nv != v:
                rules["suzunari_" + k] = nv
    man = os.path.join(OUT, "_manual", "copy.json")
    if os.path.exists(man):
        for k, v in json.load(open(man))["rules"].items():
            rules["suzunari_" + k] = v
    json.dump({"_doc": "GENERATED by tools/suzunari_theme.py (auto pass + data/suzunari/_manual/copy.json).", "rules": rules},
              open(os.path.join(DATA, "copy_suzunari_auto.json"), "w"), indent=1, ensure_ascii=False)
    print("suzunari theme:", stats, "copy symbols:", len(rules))


if __name__ == "__main__":
    main()
