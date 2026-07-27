# Harness Data Entry — Parsing Rules

Reference doc for translating a raw, spoken-style connector description into
the structured JSON the Harness Builder app reads. Use this in any chat
(this one, the data-logging chat, or both) so descriptions get parsed the
same way regardless of which conversation they're typed into.

---

## 1. Firsthand description always outranks outside research

If a shape, color, or layout is ever redrawn or corrected based on reference
photos, manufacturer part lookups, or general knowledge — that is a
**hypothesis**, not a fact. It must be flagged as a guess to confirm against
the physical connector, never silently substituted for what was actually
described. What you say you're looking at wins, every time.

## 2. Stated body shape implies a row count — but only as a default

A stated housing shape (round / square / flat / oval / rectangular) carries
real physical information and can be used to infer row layout **when no
explicit row breakdown is given**. For example: a square 4-pin housing
physically can't be a single flat row of 4 (that would be a rectangle, not
square), so it defaults to 2 rows of 2.

This is a *default*, not a rule that overrides you. If you give an explicit
row-by-row breakdown, that always wins over any shape-implied default —
even if it seems to contradict the shape name. Ask if it's ambiguous rather
than guessing silently.

## 3. "Row N: color, color, ..." is read literally, left to right

Whatever order you list colors in for a given row is taken as pin 1, 2, 3...
in that row, left to right, matching the project's pin-numbering rule
(pin 1 = leftmost, locking tab toward viewer).

## 4. "Top" / "Bottom" on a 2-wire connector = row 1 / row 2, stacked

For a 2-pin connector described by vertical position rather than by row
number, "top" is row 1 and "bottom" is row 2 — one pin per row, stacked
vertically. Same logic extends to 3+ wire vertical stacks if described the
same way.

## 5. Hedge words lower confidence — they don't get silently resolved

Words like "I think," "possibly," "maybe," "could also be X or Y," or a
color correction mid-conversation should be reflected as a lower confidence
value on that specific pin or guess (e.g. Low or Med instead of High) — not
quietly collapsed into a single confident answer. If a color or guess later
gets confirmed outright, confidence should be raised at that point, not
before.

## 6. Location and naming context should be preserved, not just the pins

Details like "next to EH-01," "near the thermostat," "connector torn off,"
or "only connector that reaches the sensor on the Integra intake" carry
diagnostic value beyond the pinout itself (they're often how a connector
gets positively identified later). These should be kept in the connector's
location/description fields, not dropped once a guess is logged.

## 7. Corrections replace, they don't stack as new entries

If a color, shape, or guess is corrected later in conversation ("actually
it's gray, not white" / "confirmed solid yellow and green-black, not just
green"), the correction replaces the earlier value in that same connector's
entry — it does not create a duplicate or a second guess sitting alongside
the first.

---

## Quick template for describing a new connector

```
EH-##
- Location: [where physically, relative to other known connectors if useful]
- Style: [shape] [total pin count], [row count if known]
- Row 1 (N-pos), left to right: color, color, ...
- Row 2 (N-pos), left to right: color, color, ...
- Guess: [best guess at function, or "unknown"]
- Confidence notes: [any hedging — "not sure if X or Y", etc.]
```
