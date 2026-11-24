# Harness Builder

Harness Builder is a visual tool for mapping automotive wiring harnesses in a way that is practical at the bench, in the garage, or on the road. It turns scattered connector notes into a structured, easy-to-scan reference for pins, wire colors, and harness relationships.

The project started with a real Honda B20Z2/P75 swap harness workflow, but the long-term goal is a flexible platform for documenting harnesses across vehicles, builds, and projects.

## Why this exists

Working on a harness often means juggling photos, handwritten notes, and memory. Harness Builder aims to replace that friction with a single visual workspace where the important details are captured and easy to revisit.

## Core features

- Visual harness canvas with connectors branching from a central trunk
- Connector-by-connector mapping for pin layouts and wire positions
- Pin-level wire color tracking for fast reference during installs and diagnostics
- Shape-aware connector rendering for common harness-style silhouettes
- Project-based organization for harness documentation and future expansion
- Wire tracing across harnesses, optional wire gauge and hot/signal/ground symbols
- Export to PDF or PNG for printing or sharing
- Mobile-first workflow for use in the workshop or on the job

## Apps in this repo

- **iOS app** (`ios/`): a native SwiftUI app for iPhone and iPad (iOS 17+). This is the primary product. It has the harness canvas, a plug sheet, an add/edit plug wizard, multiple harnesses with templates, wire tracing across harnesses, optional wire gauge and role symbols, and PDF/PNG export. Everything is stored on the device. See [`ios/README.md`](ios/README.md).
- **Web app** (repo root): the original React/Vite version with the harness canvas and connector rendering. It is secondary for now.

## Current status

The iOS app is feature-complete for building, editing, tracing and exporting harnesses on a device, and is being prepared for the App Store. Next up is an optional "Build with AI" feature where you bring your own Anthropic API key. The web app has a working canvas and connector rendering but no persistence yet.

## Roadmap

### Near-term
- Build with AI on iOS (bring your own Anthropic key)
- App Store release of the iOS app
- Web app: persistent project save and load

### Medium-term
- Native Mac app
- Print-friendly (white background) export
- Gauge visualization

### Longer-term
- Multi-project collaboration and shared reference data
- Broader support for additional vehicle harnesses and connector families
- Deeper mobile and field-use refinements

## Tech stack

- iOS: SwiftUI (iOS 17+, Xcode 26), `@Observable`, on-device JSON storage
- Web: React, Vite, SVG-based visualization
