# Paragraph Overlay Visual Refresh Design

**Goal:** Redesign the paragraph translation overlay so it reads like a native macOS reading panel: clearer information hierarchy, lower visual noise, stronger section grouping, explicit copy semantics, and better long-form readability.

## Scope

- Only update the paragraph translation overlay UI.
- Do not change OCR, translation, hotkey detection, or paragraph selection logic.
- Do not add a language-switch control in this iteration.
- Keep existing dismiss, drag, and text-selection capabilities unless the redesign needs to restyle them.

## Problem Summary

The current paragraph overlay works functionally, but it still feels tool-oriented instead of user-oriented:

- `PARAGRAPH` is an implementation label, not a useful user-facing label.
- The current `ENGLISH` / `TRANSLATION` hierarchy is too flat, so users must parse the panel instead of instantly scanning it.
- The original text and translated text are separated only by a divider, not by distinct content groups.
- The single copy icon is ambiguous because it does not explain what will be copied.
- Text density is still too tight for paragraph reading, especially for longer English headlines and multi-line translations.

## Product Decisions

### 1. Remove Technical Framing

- Remove the `PARAGRAPH` title entirely.
- Treat the overlay as a result panel, not a diagnostic surface.
- Keep only controls that directly support reading and dismissal.

### 2. Use Two Explicit Reading Sections

The panel body becomes two stacked content blocks:

- `Original (English)`
- `Translation (中文)` or the localized target language name

Each block contains:

- a compact title row
- a block-level copy action
- readable body text

This makes the panel understandable in one scan.

### 3. Prefer Language Labels Over Generic Category Labels

The label must tell the user which language they are reading, not only whether it is the source or the result.

Recommended header format:

- `Original (English)`
- `Translation (简体中文)`

This keeps the semantic meaning (`Original` / `Translation`) while also exposing the concrete language pair.

### 4. Add Stronger Grouping Without Heavy Chrome

Each section should feel like its own reading region, but still stay consistent with macOS translucency:

- use soft inset blocks inside the panel
- use subtle background fill or stroke, not dense card styling
- increase vertical spacing between sections
- keep shadows and borders restrained

The result should feel structured, not boxed-in.

### 5. Make Copy Actions Explicit

The current single copy icon is removed from the shared header.

Instead:

- `Original` section gets its own `Copy`
- `Translation` section gets its own `Copy`

Optional fallback:

- if no content exists for a section, hide or disable that section’s copy action

The copy button should provide inline success feedback:

- `Copy` → `Copied`

### 6. Improve Reading Comfort

Typography should support actual paragraph reading rather than short-label scanning:

- section titles stay small and secondary
- original text uses medium weight with increased line height
- translated text gets slightly larger or slightly stronger weight than the original
- line spacing should be visibly looser than the current implementation

Target effect:

- headlines wrap more comfortably
- translated paragraphs feel easier to scan
- the translated result becomes the primary focal point

## Layout

### Top Bar

Top bar should only contain:

- drag region
- close button

No `PARAGRAPH` label.
No global copy button.

This keeps the header visually quiet and makes the content blocks carry the meaning.

### Content Blocks

Recommended visual structure:

```text
Original (English)                        Copy
OpenAI's Codex AI Coding Tool Stabilizes
After Demand Overload

Translation (简体中文)                    Copy
OpenAI 的 Codex AI 编码工具在需求过载后
恢复稳定
```

Visual rules:

- consistent internal padding
- compact title-to-body spacing
- larger gap between blocks than between title and body
- translation block may use slightly stronger text emphasis

## States

### Loading

When OCR is still locating text:

- show a simplified panel body
- use a single clear status message instead of multiple stacked labels
- preserve the top bar structure

When original text is already known but translation is still loading:

- render the original section normally
- render the translation section with `Translating…`

### Error

- If original text exists, keep the original block visible.
- Show the error inside the translation block.
- If no original text exists, show one compact empty/error state instead of multiple labels.

## Implementation Notes

- Update `OverlayView` to use a section-based presentation model for paragraph mode.
- Add a small helper for displaying the source and target language names in the overlay.
- Reuse the existing copy-feedback pattern but move it to per-section buttons.
- Keep paragraph text selectable.
- Keep the current drag affordance, but style it through the simplified top bar.

## Testing

Manual validation should cover:

- original vs translation distinction is obvious at first glance
- copy buttons clearly map to their own sections
- copied feedback appears inline and resets correctly
- long English text wraps with better readability
- translated text feels visually prioritized
- loading and error states still look coherent after removing `PARAGRAPH`
