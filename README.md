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
- Mobile-friendly workflow for use in the workshop or on the job

## Current status

The app already includes a working visual canvas and a solid foundation for connector rendering. Ongoing development is focused on turning that foundation into a fuller product experience with persistent projects, better data entry, and richer wire-tracing capabilities.

## Roadmap

### Near-term
- Persistent project save and load
- Guided harness and ECU creation workflow
- Connector lookup and preset suggestions

### Medium-term
- Wire-tracing across connectors and components
- Improved pin popups and detail views
- Export and sharing workflows

### Longer-term
- Multi-project collaboration and shared reference data
- Broader support for additional vehicle harnesses and connector families
- Deeper mobile and field-use refinements

## Tech stack

- React
- Vite
- SVG-based visualization
- Planned backend integration for persistence and lookup services
