# Advanced Dictionary Messaging Design

**Goal:** Make the offline ECDICT feature understandable to regular users by presenting it as an advanced English dictionary with clear benefits, boundaries, and activation feedback.

## Problem

- `ECDICT` is a technical name that does not explain what the feature does.
- Users cannot tell whether it replaces translation, extends dictionary definitions, or requires manual setup after installation.
- After installation, users do not get strong enough feedback that the advanced dictionary is actually being used.

## Product Decisions

### Naming

- Use `Advanced English Dictionary` as the primary user-facing label.
- Keep `ECDICT` only as secondary technical attribution when helpful.
- Avoid the word `plugin`, which implies extra configuration.

### Value Framing

- Explain the feature as an upgrade for English word definitions.
- Emphasize three concrete benefits:
  - More complete definitions
  - Better technical terms
  - Works offline after installation
- Explicitly state the boundary:
  - It improves dictionary definitions, but does not replace Apple Translation.

### State Messaging

- Before installation:
  - Explain what the feature improves and why it is worth installing.
- After installation:
  - Say it is enabled, not just installed.
  - Clarify that English word lookups now prefer the advanced dictionary.
- On errors:
  - Keep recovery actions obvious and simple.

### In-Context Feedback

- When a lookup result comes from the advanced dictionary, show an `Advanced Dictionary` badge in the result panel.
- When the app falls back to the system dictionary, show a `System Dictionary` badge.
- This badge should be lightweight, readable, and placed near the word header.

## Scope

### Included

- Rename the feature in settings and the main window.
- Add short benefit messaging near the install controls.
- Add result-source badges in the overlay.

### Not Included

- A full learn-more popover
- Source-specific analytics
- Separate manual switch between advanced and system dictionaries

## Success Criteria

- A new user can understand the feature in one quick scan.
- A user who installs it can tell what changed.
- A user can verify whether a shown definition came from the advanced dictionary or the system dictionary.
