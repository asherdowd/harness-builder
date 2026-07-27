Harness Builder

Read PROJECT_NOTES.md before making changes — it covers current state (what's built vs. stubbed), architecture decisions and why, and next steps.

Read harness-data-entry-rules.md before writing any code that parses a raw connector description into data, or before "correcting" a connector shape based on outside research — firsthand description always outranks reference photos/lookups.

Check the relevant implementation under src/ before editing anything — the docs describe intent and state, but the current code is the source of truth for how something actually works right now.