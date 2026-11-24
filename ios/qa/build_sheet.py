#!/usr/bin/env python3
"""Build the manual QA page from manual-tests.json.

    python3 ios/qa/build_sheet.py [output.html]

The page is published as a private Claude artifact; results are saved there as
the tester taps Pass/Fail/Skip, then copied back and recorded in ios/qa/results/.
manual-tests.json is the source of truth. Edit it, rebuild, republish.
"""
import html
import json
import sys
from pathlib import Path

here = Path(__file__).resolve().parent
plan = json.loads((here / "manual-tests.json").read_text())

ids = [t["id"] for t in plan["tests"]]
keys = {s["k"] for s in plan["sections"]}
assert len(ids) == len(set(ids)), "duplicate test ids"
assert all(t["id"][0] in keys for t in plan["tests"]), "test id with no section"
for t in plan["tests"]:
    assert t.get("tag", "") in ("", "known", "unv"), f"bad tag on {t['id']}"

data = json.dumps(plan, ensure_ascii=False).replace("<", "\\u003c")
page = (here / "sheet.template.html").read_text()
page = page.replace("__TITLE__", html.escape(plan["title"])).replace("__DATA__", data)
out = Path(sys.argv[1]) if len(sys.argv) > 1 else here / "test-run.html"
out.write_text(page)
print(f"wrote {out} ({len(ids)} tests in {len(keys)} sections)")
