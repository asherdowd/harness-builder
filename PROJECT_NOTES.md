# Harness Builder — Project Notes

Context doc for picking this project back up — whether that's a future
Claude Code session, another chat, or you six months from now. The code
shows *what* exists; this covers *why*, and what's still ahead.

---

## What this is

A tool for visually mapping wiring harnesses and components (starting with
a real B20Z2/P75 Honda swap harness) — connector by connector, pin by pin,
with wire colors and confidence levels — so the pinout is easy to reference
while actually working on the car, and easy to trace across harnesses/ECUs
later.

## Current state (as of this handoff)

**Built and working:**
- `HarnessCanvas` — renders a harness as a central trunk with connectors
  branching off in sequence, alternating sides, spaced evenly
- Distinct SVG silhouette per connector shape family (`src/components/shapes/`),
  modeled on real Sumitomo/Denso-style Honda connector references where
  verified — see "Shape accuracy" below
- Row/pin layout is data-driven (`rows` array per connector) with one
  inference rule layered on top: certain shape families have a known fixed
  row count for this era of Honda (see `FORCED_ROW_COUNT` in
  `src/lib/geometry.js`) and will re-chunk a flat pin list into the correct
  row layout even if the source data wasn't grouped that way
- Nav shell: hamburger → drawer with Projects (Existing / New) and Settings
- `ExistingProjectsView` — lists projects (currently hardcoded to the one
  seed harness, not reading from real storage yet)
- `NewProjectView` — Harness/ECU picker exists but is inert past selection
  (shows a "coming next" placeholder)
- `SettingsView` — rows exist (dark mode, export prefs, suggestion prefs)
  but none are wired to real behavior yet

**Not built yet:**
- Persistence — nothing is actually saved. Existing Projects is a hardcoded
  array, not read from a database
- The harness/ECU creation wizard itself (plug shape, rows, pin orientation
  entry; connector-type search/lookup with presets + live search fallback;
  ECU type selection + validation)
- Wire-color-coded pinout hover/click popups
- Cross-connector "trace this wire" highlighting
- Any of the actual auth/database/hosting infrastructure below — only
  *planned*, not implemented

## Architecture decisions (and why)

Decided during planning, not yet built:

- **Frontend:** Vite + React (this codebase). Chosen over Next.js because
  this is a single-canvas tool, not a multi-page site — SSR/routing
  machinery buys nothing here, and Vite output wraps more cleanly in
  Capacitor later.
- **Hosting:** Vercel — static site + one serverless function.
- **Backend/data:** Supabase (Postgres + auth). Chosen over Firebase because
  the data is inherently relational (harnesses → connectors → rows → pins,
  eventually cross-linked into shared "nets"/signals for wire-tracing across
  components) — Postgres joins are a much more natural fit than a NoSQL
  document store for that.
- **Why a real backend at all (vs. local-only storage):** cross-device
  access matters for this use case specifically — the whole point is being
  able to reference a pinout on a phone while standing at the actual
  harness, possibly a different device than whatever built the project.
- **The one required serverless piece:** the connector/ECU lookup feature
  (search + suggest, described below) calls Claude with web search enabled.
  That call needs an API key, which can't live in client-side code once this
  is a real hosted app — hence one small `/api/lookup`-style serverless
  function to hold the key server-side.
- **Mobile:** Capacitor, wrapping this same React/Vite app, targeting both
  iOS and Android from one codebase. A genuinely native rewrite (Kotlin
  Multiplatform / Swift) was discussed as a *possible future* step beyond
  Capacitor, not a replacement for it — nothing about the current plan
  blocks that if it's wanted later, but it would mean rewriting the UI
  layer from scratch, sharing only the backend/data model.

## Shape accuracy — what's confirmed vs. inferred

A few connector shapes were originally drawn from generic web reference
photos of "common Honda connectors" rather than the actual harness in hand,
and at least one was **wrong** as a result (EH-13 / TPS was drawn as a flat
trapezoid based on a stock photo, when the real connector is round — fixed
after the person clarified against the physical part). Going forward:

- **Firsthand description always outranks outside research.** If a shape
  gets redrawn based on reference photos/lookups, it should be flagged as a
  hypothesis to confirm, never silently substituted for what was actually
  described.
- Full parsing rules for turning a raw spoken-style connector description
  into structured data live in **`harness-data-entry-rules.md`** (same repo
  root) — read that before writing any code that ingests new connector
  descriptions, or before "fixing" a shape based on external research.

## Data model note for later

The current `HARNESS.connectors` shape is fine for a single self-contained
harness, but it doesn't yet have a way to say "this pin on EH-06 and this
pin on the ECU are the same electrical wire." Tracing a wire across
harnesses/ECUs (a stated goal) will need a **net/signal** concept — a table
or field that groups pin IDs across different connector records under a
shared identifier — once we get to real persistence. Don't build this
speculatively; design it deliberately when cross-component wire tracing is
actually being built.

## Suggested next step

Wire up Supabase (auth + Postgres) for real project save/load, replacing
the hardcoded array in `ExistingProjectsView`. That's the natural
prerequisite for the harness/ECU creation wizard, since the wizard's whole
job is producing a record that needs somewhere real to be saved.
