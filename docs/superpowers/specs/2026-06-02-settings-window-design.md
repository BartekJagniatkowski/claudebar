# ClaudeBar Settings Window — Design Spec

**Date:** 2026-06-02
**Scope:** Settings window, About info, custom color picker. No Homebrew, no auto-update, no font change.

---

## Goal

Replace the sparse menu with a settings panel that feels like a modern tool — not a macOS system preference pane. Users can configure launch-at-login, usage zone thresholds, and zone colors without touching `defaults write`.

---

## Visual Style

Shadcn/ui dark — not macOS system dark.

| Token | Value |
|-------|-------|
| Window background | `#09090b` (zinc-950) |
| Border / separator | `#27272a` (zinc-800) |
| Primary text | `#fafafa` |
| Secondary text | `#71717a` (zinc-500) |
| Muted text | `#52525b` (zinc-600) |
| Input background | `#09090b` |
| Accent (orange) | `#C97A58` |

Layout: rows separated by `1px #27272a` lines, no filled card backgrounds. Padding `14px 0` per row, `0px` horizontal padding (content flush to window insets of `24px`).

Window size: `320 × auto` (fits content, not resizable). Appears centred on screen.

---

## Menu Changes

**Remove:** "Launch at Login" menu item
**Add:** "Settings…" menu item (opens settings window)
**Keep:** separator + "Quit ClaudeBar"

---

## Settings Window — Row Layout (top to bottom)

### 1. Launch at Login
- Label: `Launch at Login` (primary text, 13pt medium)
- Subtitle: `Start ClaudeBar when you log in` (secondary text, 11pt)
- Control: NSSwitch / toggle (right-aligned), bound to `SMAppService` / LaunchAgent (existing logic)

### 2. Threshold explanation
- No label, no control
- Body text (muted, 11pt, line-height 1.5): `Menubar text shifts color when session or weekly usage crosses a threshold. Each row is evaluated independently.`

### 3. Warning threshold
- Label: `Warning` (primary, 13pt medium)
- Subtitle: `orange above this %` (secondary, 11pt)
- Control right: integer text field showing `75`, colored `#C97A58`, bordered (`#27272a`), width 44pt
- Below label: row of 4 color swatches (24×24pt, radius 4pt) + `custom` button
  - Presets: `#C97A58`, `#e8a87c`, `#eab308`, `#38bdf8`
  - Selected swatch: `outline: 2px #fafafa, offset 2px`
  - "custom" button: `border: 1px #3f3f46`, radius 4pt, muted text — opens custom color picker
- Value persisted to `UserDefaults` key `warningThreshold` (0–1) and `warningColor` (hex string)

### 4. Critical threshold
- Identical structure to Warning
- Presets: `#ef4444`, `#f87171`, `#f97316`, `#a855f7`
- % field colored `#f87171`
- Persisted to `criticalThreshold` and `criticalColor`

### 5. About
- Label: `ClaudeBar` (primary, 13pt medium)
- Subtitle: `v1.x.x` (muted, 11pt) — read from `Bundle.main.infoDictionary["CFBundleShortVersionString"]`
- Control right: GitHub SVG icon (18×18, fill `#52525b`) — clicking opens `https://github.com/BartekJagniatkowski/claudebar` in default browser

---

## Custom Color Picker Window

A second `NSPanel` that appears when the user clicks "custom" on either threshold row.

**Appearance:** Same `#09090b` background, `#27272a` borders, `.darkAqua` forced appearance. Same traffic-light chrome. Title: `Pick Color`.

**Layout (top to bottom, 14px insets):**

1. **Spectrum gradient** — 100% width × 120pt height, `border-radius 6pt`
   - Horizontal: saturation (left=white → right=hue)
   - Vertical: brightness (top=full → bottom=black)
   - Rendered as two overlaid `CAGradientLayer`s
   - Draggable crosshair dot (10pt circle, white border)

2. **Hue slider** — 100% width × 12pt height, `border-radius 6pt`
   - Rainbow gradient left→right
   - Draggable round thumb (15pt, white, shadow)
   - Moving thumb updates spectrum gradient + preview

3. **Hex input row** — preview swatch (28×28pt, radius 5pt) + `NSTextField` (monospace, hex string)
   - Editing hex field updates spectrum + hue positions
   - Invalid hex: field border turns red, value not committed

4. **Confirm** — no explicit button; closing the window commits the current color. Cancel = Escape key or red traffic light (reverts to previous color).

**Communication:** Color picker calls back to the settings window via a closure: `onColorSelected: (NSColor) -> Void`. Settings window updates the swatch and writes to UserDefaults immediately.

---

## Files

| File | Change |
|------|--------|
| `Sources/main.swift` | Update menu (add Settings…, remove Launch at Login item); open `SettingsWindowController` on click |
| `Sources/SettingsWindowController.swift` | New — NSWindowController managing the settings panel and all its rows |
| `Sources/ColorPickerWindowController.swift` | New — NSWindowController for the custom color picker panel |

Splitting into 3 files keeps `main.swift` from growing further and gives each window a clear owner.

---

## Out of Scope

- Font change (Iosevka — future release)
- Homebrew distribution
- Auto-update mechanism
- Notification threshold alerts (separate future spec)
