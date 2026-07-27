# Harness Builder

Harness Builder is a visual wiring-harness mapping tool designed for real-world automotive work. It helps you organize connectors, pins, wire colors, and harness relationships in a way that is easy to reference while standing at the car.

The project is currently focused on a Honda B20Z2/P75 swap harness workflow, but the structure is intended to support broader harness documentation over time.

## Feature Highlights

- Visual harness canvas with connectors branching from a central trunk
- Connector-by-connector mapping for pin layouts and wire positions
- Pin-level wire color tracking for fast reference during diagnosis or installation
- Shape-aware connector rendering for common harness-style silhouettes
- Project-based organization for harness documentation and future expansion
- Built for mobile-friendly use in the garage, workshop, or field

## Current Status

The app already includes a working visual canvas and core connector rendering foundation. Ongoing work is focused on turning that foundation into a full project and data-management experience, including saving projects, refining connector entry workflows, and supporting richer wire-tracing features.

## Planned Enhancements

- Persistent project save/load
- Guided harness and ECU creation workflow
- Connector lookup and preset suggestions
- Wire-tracing across connectors and components
- Improved pin hover and detail popups
- Export and sharing workflows

## Tech Stack

- React
- Vite
- SVG-based visualization
- Planned backend integration for persistence and lookup services

## Why It Exists

This tool is meant to make complex harness documentation less painful. Instead of relying on scattered notes, photos, and memory, Harness Builder aims to provide a structured, visual reference that can grow with the project.
