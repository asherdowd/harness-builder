#!/usr/bin/env python3
"""Makes Templates.json safe to ship as example data:
 - removes research notes (description, per-wire notes, build actions, status, ...),
 - trims wire function labels to the plain function ("ECT (confirmed, true pin 13)" -> "ECT"),
 - replaces internal reference codes (VX-EH-03, ECU-A ...) with plain plug names.
Ids and sameCircuitAs are internal keys and are left alone.
Usage: python3 clean_examples.py "Harness Builder/Harness Builder/Resources/Templates.json"
"""
import json, re, sys

path = sys.argv[1]
data = json.load(open(path))

names = {}
for t in data["templates"]:
    for c in t["harness"]["connectors"]:
        names[c["id"]] = c.get("displayName") or c["name"]

FULL = re.compile(r"\b(?:VX|CRV|SHK|ECU|STNK)-EH-[A-Z0-9.-]*[A-Z0-9]")
BLOCK = re.compile(r"\bECU-([A-D])\b")
PARTIAL = re.compile(r"\b(?:VX|CRV|SHK|ECU|STNK)-EH\b")
LEFT = re.compile(r"\b(?:VX|CRV|SHK|ECU|STNK)-")

def clean(text):
    def full(m):
        return names.get(re.sub(r"\.\d+$", "", m.group(0)), "another plug")
    text = FULL.sub(full, text)
    text = BLOCK.sub(lambda m: f"ECU plug {m.group(1)}", text)
    text = PARTIAL.sub("another plug", text)
    return text

SKIP = {"id", "sameCircuitAs"}
left = []

def walk(o, key=None):
    if isinstance(o, dict):
        return {k: (v if k in SKIP else walk(v, k)) for k, v in o.items()}
    if isinstance(o, list):
        return [walk(v, key) for v in o]
    if isinstance(o, str):
        new = clean(o)
        if LEFT.search(new):
            left.append(new[:80])
        return new
    return o

out = walk(data)

NOTE_FIELDS = ["description", "anomalies", "status", "condition", "buildAction", "location",
               "shapeNote", "partNumber", "gender"]
PIN_NOTE_FIELDS = ["colorNote", "colorCrossRef"]
NOTE_PAREN = re.compile(r"\s*\((?:confirmed|VX-specific|repeat|GSR-only|H22A-only|documented|partial|Civic-only)[^)]*\)", re.I)
DROP_GUESS = re.compile(r"^(?:Unresolved|Matches unused)", re.I)

def clean_guess(g):
    g = NOTE_PAREN.sub("", g)
    g = g.split(" \u2014 ")[0].strip()
    g = re.sub(r"\s+or\s+VTP", " or VTP", g)
    return None if (not g or DROP_GUESS.match(g)) else g

for t in out["templates"]:
    for c in t["harness"]["connectors"]:
        c["name"] = c.get("displayName") or c["name"]
        for f in NOTE_FIELDS:
            c.pop(f, None)
        c["hasOpenIssue"] = False
        c["membershipUncertain"] = False
        for r in c["rows"]:
            for p in r["pins"]:
                for f in PIN_NOTE_FIELDS:
                    p.pop(f, None)
                if p.get("guess"):
                    g = clean_guess(p["guess"])
                    if g is None:
                        p.pop("guess", None)
                    else:
                        p["guess"] = g
json.dump(out, open(path, "w"), indent=2, ensure_ascii=False)
print("remaining codes:", left)
