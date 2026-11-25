# QA for the iOS app

Two kinds of checks, and both are recorded in this repo before every App Store upload.

| Kind | Where it lives | How it runs | Where the result is recorded |
| --- | --- | --- | --- |
| Unit tests | `ios/Harness Builder/Harness BuilderTests/` (once the Xcode test target exists) | Cmd-U in Xcode, every build | `ios/qa/results/<tag>.md` |
| Manual tests | `ios/qa/manual-tests.json` | A private Claude page you tap through on a phone | `ios/qa/results/<tag>.md` |

`<tag>` is the release tag, for example `ios-v1.0-build1` (see "Versions and releases" in `ios/README.md`).

## Manual tests

- `manual-tests.json` is the source of truth: sections (A to L), and for each test an id, title, steps and expected result. A test tagged `known` is a known limitation; `unv` means the expected result is unverified and the tester should record what happens.
- `build_sheet.py` turns it into a single HTML page (`python3 ios/qa/build_sheet.py out.html`). `sheet.template.html` is the page design.
- The page is published as a private Claude artifact. Each Pass, Fail or Skip tap saves as you go. **Copy summary** produces a markdown report.
- When the plan changes (new feature, new section), edit the JSON, rebuild, and republish the page. Update the `updated` line so it says which build the plan is for.

### Doing a run

1. Install the build you plan to archive on a fresh simulator or device.
2. Open the page, fill in Date, Version / build, Device and iOS version, and work through every check. Use Skip with a note when a check does not apply.
3. Tap **Copy summary** and paste it into the chat. It is saved as `ios/qa/results/<tag>.md` and committed.
4. File an issue for each failure and put its number in the Issue box.

## Unit tests

Swift Testing, in `ios/Harness Builder/Harness BuilderTests/`. The app is the test host, so the tests use the real bundled templates. The whole suite runs in a few seconds, apart from the export file tests.

| File | Covers |
| --- | --- |
| `ModelTests` | Decoding the web JSON, role and gauge fields, pin numbering, save and load |
| `WireColorTests` | Color codes, names, the wizard's color parts |
| `PlugDraftTests` | Wizard sizes and limits (60 pins), changing shape, the data-loss count |
| `StoreTests` | Harness and plug actions, links, templates, saving, unreadable save file |
| `TraceTests` | Wire tracing, canvas outlines, "goes to pin N" matching |
| `WireConnectTests` | Connecting wires you build to pins on other plugs: draft, store, and tracing from both ends |
| `SettingsTests` | Appearance setting and the light/dark palette |
| `BackupAndCSVTests` | Backup and restore, CSV wire list, wired and spare counts |
| `MapChecksTests` | The "Check this harness" rules |
| `PrintExportTests` | Print-friendly export: real files, white page, dark export unchanged |
| `LayoutTests` | Plug placement on the trunk, drawing every shape |
| `TemplateTests` | Bundled examples load, are consistent, and stay free of research notes, codes and personal names |
| `ExportTests` | Wire table page splitting, real PDF and PNG files, 60-pin harnesses |

Run with Cmd-U in Xcode before every archive. Paste the pass/fail summary (or the failing test names) into the chat and it is added to the results file under "Unit tests".

Not covered by unit tests (the manual run covers these): gestures, sheets, the drawn canvas, share sheet, icons, iPad layout.

## Gate before archiving

- Unit tests: all pass.
- Manual run: no open failures. Every skipped check has a reason.
- The results file for the tag is committed, then the tag is created on the commit that is uploaded.

## Results

One file per tag in `results/`. Results are a record of what was tested, not a plan: never edit an old file, add a new one for the next run.
