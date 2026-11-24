# Harness Builder (iOS)

Native SwiftUI app for mapping wiring harnesses. The harness canvas (a trunk
with plugs branching off, pan and pinch zoom) is the product.

- Xcode 26, iPhone and iPad, minimum iOS 17
- Bundle id `BagelBytez.Harness-Builder`, display name "Harness Builder", category Utilities
- Open `Harness Builder/Harness Builder.xcodeproj`
- All data stays on the device (`state.json` in Application Support). No accounts, no server.
- The repo is public. Never commit API keys.

## Code layout (`Harness Builder/Harness Builder/`)

| Folder | What is in it |
| --- | --- |
| `Model/` | Codable models matching the web JSON (`Harness.swift`), templates (`Templates.swift`), wire tracing (`WireTrace.swift`) |
| `Store/` | `HarnessStore`: `@Observable` state, saving, plug and harness actions |
| `Drawing/` | Palette, geometry, plug silhouettes and pin dots, wire color swatches, role symbols |
| `Canvas/` | Trunk layout and the pan/zoom canvas (grid, selection, move buttons) |
| `Sheets/` | Plug sheet, pinout, Add a harness, harness menu, link picker, export sheet |
| `Wizard/` | Add/edit plug wizard (shape picker, pin editor, draft model) |
| `Export/` | PDF and PNG export |
| `Resources/Templates.json` | Bundled example harnesses (cleaned, see below) |
| `MainView.swift` | Header, tabs, first-open card, and the single bottom sheet that swaps content |

`ContentView` is a thin wrapper around `MainView` left over from the Xcode template.

## Things to know

- **One bottom sheet.** `MainView` owns a single sheet whose content swaps (plug, wizard, Add a harness, harness menu, export, link picker). This avoids stacked-sheet problems.
- **Memberwise init order matters.** Swift's memberwise initializers need arguments in property declaration order. This caused a compile error once in `HarnessCanvasView`.
- **Project setting:** `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`. Capture colors in locals before a `Canvas` closure.
- **Example data must stay clean.** No research notes, internal reference codes or personal names in `Templates.json`. Run `tools/clean_examples.py` on new example data.
- **Optional pin fields** `role` (`power`, `signal`, `ground`) and `gauge` (AWG number) exist only in the iOS app. The web schema is unchanged. Gauge is shown as text only ("18 AWG").
- **No Swift compiler in the Claude sandbox.** Code written there is unverified until built in Xcode.

## App icon

`Assets.xcassets/AppIcon.appiconset` holds three 1024x1024 PNGs: light (default), dark, tinted (grayscale). iOS makes every smaller size from them. Artwork is a rounded plug with four pins and four wires on the canvas grid, with a margin of three grid rows on every side.
`tools/make_icon.py` regenerates all three (needs Python with Pillow and `rsvg-convert`).

## Versions and releases

One number scheme keeps Xcode, the App Store and git in step:

| Where | Setting | Today |
| --- | --- | --- |
| Xcode and App Store | Version (`MARKETING_VERSION`) | 1.0 |
| Xcode and App Store Connect | Build (`CURRENT_PROJECT_VERSION`) | 1 |
| Git | tag `ios-v<Version>-build<Build>` | none yet |

- The Version is what people see on the App Store. Bump it for each public release (1.0, 1.1, ...).
- The Build must go up on every upload to App Store Connect, even when the Version stays the same.
- Tag the exact commit you upload, with the same numbers, for example `ios-v1.0-build1`, then draft a GitHub release from that tag (mark it a pre-release until the app is live). The release notes link the feature issues that shipped.
- Do not change `MARKETING_VERSION` or `CURRENT_PROJECT_VERSION` in a feature branch without saying so; change them in the commit that prepares the upload.

## Not done yet

- Build with AI (bring your own Anthropic key, Keychain storage)
- iPad and iOS 17 simulator checks
- App Store screenshots and privacy answers
- Print-friendly white-background export
- Native Mac app
