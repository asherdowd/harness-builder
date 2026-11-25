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

> **There are now two apps in this repo.** The web app (this file's main
> subject, repo root) is the original. The **native SwiftUI iOS app** under
> `ios/` is now the primary product and is where active work happens. See
> "iOS app" below, and `ios/README.md` for the code layout and setup.

## Current state of the web app (as of the original handoff)

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
- **Mobile (superseded):** this section originally planned Capacitor around
  the React app. That was replaced by a native SwiftUI iOS app (see "iOS
  app" below). The web app is secondary for now; the Supabase/Vercel plan
  above has not been built and is on hold.

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

## iOS app

Native SwiftUI app in `ios/Harness Builder/` (Xcode 26, iPhone and iPad,
minimum iOS 17, bundle id `BagelBytez.Harness-Builder`, display name
"Harness Builder", category Utilities). Data is stored on the device only
(`state.json` in Application Support); there is no account or server.

**Built:** harness canvas (trunk, plug silhouettes, pan, pinch zoom, Fit all,
moving grid, tap to select, up/down move buttons on the selected plug);
plug sheet (pinout, wire list, notes, link cards, Edit and Remove, Edit
opens on the selected wire); add/edit plug wizard (shape, rows, up to 60
pins, per-pin color, stripe, function, wire type, gauge, role, confidence,
data-loss warnings); Add a harness (blank or from a template), harness menu
(rename, delete, export), plug-to-plug links for component harnesses; wire
tracing across harnesses with jump and zoom; "Connects to" on a wire you build (pick a pin on another plug, same net on both ends); light and dark appearance (System by default) with a Settings sheet; backup and restore through Files; CSV wire list and a print-friendly PDF/PNG; "Check this harness"; optional per-wire gauge (text
only) and role (hot, signal, ground) symbols; export to PDF or PNG with an
optional wire table; light, dark and tinted app icons.

**Planned next:** "Build with AI" (bring your own Anthropic key, key in the
iOS Keychain, structured tool call, preview with every wire marked "Guess").
See the Civic project doc `ios-swift-progress.md` for the agreed design.

**Working rules for this project:** ask before adding any feature that was
not discussed; do not refactor unless discussed; check and report everywhere
a feature needs to go before writing it; show an HTML POC of significant UX
changes before writing Swift. The repo is public: never commit API keys.
Example data shipped in the app must not contain research notes, internal
reference codes or personal names (`ios/tools/clean_examples.py` cleans it).

**Ideas parked (not planned yet):** wire calculator (AWG, resistance,
round-trip voltage drop, thinnest gauge). If built, it should match the
look of the main builder, with visuals that help people who are not
electrical engineers (advanced hobbyist audience). It needs per-wire length
and current, which the app doesn't store yet. Also parked: continuity test
sheet from nets, cut list and BOM.

**Verification gap:** there is no Swift compiler in the Claude sandbox, so
every iOS change has to be built in Xcode on the Mac before it counts as
working.

## Suggested next step

For the iOS app: the Build with AI feature, plus iPad and iOS 17 simulator
checks and App Store screenshots. For the web app: unchanged, and on hold
(Supabase save/load was the prerequisite for its creation wizard).
