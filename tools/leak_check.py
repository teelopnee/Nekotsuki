#!/usr/bin/env python3
"""Every line the Suzunari theme can show, checked for ODD-SPACE sci-fi words (docs/REVIEW.md hard review #7).
Scans data/suzunari/*.json, data/copy_suzunari_auto.json, data/people/*.json, data/town.json, data/school.json,
data/weeks/*.json, data/endings.json, data/lessons.json, data/amane*.json, data/hayate.json. Exit code = number of leaks.
python3 tools/leak_check.py"""
import glob, json, os, re, sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
PAT = re.compile(r"\b(credits?|paragon|planets?|consortium|corp|corporate|neon|drones?|ad network|gravity|scanning|collateral|"
                 r"uploading|android|robots?|cyborg|laser|blaster|hover|orbit|spaceport|galaxy|aliens?|synth|holograms?|holo|"
                 r"implants?|chrome|cyber\w*|repo|bounty|plasma|starship|spaceship|airlock|oxygen|freighter|keytar|in hock|"
                 r"ads?|ad-\w+|ad blockers?|medkits?)\b", re.I)
# "the police" stands in for a singular name (Paragon): "the police says" / a sentence starting "the police".
GRAMMAR = re.compile(r"\b[Tt]he police (doesn't|does|is|isn't|has|hasn't|was|wasn't|says|thanks|reads|gives|asks|sweeps|"
                     r"reminds|checks|shows|wants|knows|sees|files|patrols|pays|calls|keeps)\b|(^|[.!?]\s+)the police\b\s*\S")
FILES = (sorted(glob.glob(os.path.join(ROOT, "data/suzunari/*.json"))) + [os.path.join(ROOT, "data/copy_suzunari_auto.json")]
         + sorted(glob.glob(os.path.join(ROOT, "data/people/*.json")))
         + sorted(glob.glob(os.path.join(ROOT, "data/weeks/*.json")))
         + [os.path.join(ROOT, "data", f) for f in ["town.json", "school.json", "lessons.json", "amane.json", "endings.json", "ura.json", "weekend.json",
                                                    "amane_talk.json", "hayate.json"]])
# Words that are fine in Suzunari in these exact places (ids, flags, not text).
SKIP_KEYS = {"flag", "requires", "id", "icon", "look", "variant", "verb", "kind"}


def walk(v, path, out):
    if isinstance(v, str):
        m = (PAT.search(re.sub(r"\{[A-Za-z_]+\}|#[A-Za-z_.]+#", "", v)) or re.search(r"\{(?:town|planet|PLANET)\}", v)
             or GRAMMAR.search(v))
        if m:
            out.append("%s  [%s]  %s" % (path, m.group(0), v[:110]))
    elif isinstance(v, list):
        for i, x in enumerate(v):
            walk(x, "%s[%d]" % (path, i), out)
    elif isinstance(v, dict):
        for k, x in v.items():
            if not k.startswith("_") and k not in SKIP_KEYS:
                walk(x, path + "." + k, out)


def main():
    leaks, lines = [], 0
    for f in FILES:
        if not os.path.exists(f):
            continue
        out = []
        walk(json.load(open(f)), os.path.relpath(f, ROOT), out)
        leaks += out
    for l in leaks:
        print("LEAK", l)
    print("leak_check: %d leak(s) in %d files" % (len(leaks), len(FILES)))
    sys.exit(min(len(leaks), 100))


if __name__ == "__main__":
    main()
