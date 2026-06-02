# ClaudeBar

macOS menubar app showing Claude Code token usage at a glance.

## What it does

- Menubar item: two lines — top: session `%` + time to session reset; bottom: weekly `%` + time to weekly reset
- Color-coded zones: orange at ≥75% (warning), red + larger text at ≥90% (critical); rows styled independently
- Settings window (⌘,): Launch at Login toggle, threshold sliders, color preset swatches, custom color picker
- Custom color picker: spectrum gradient + hue slider + hex input, styled to match settings window
- Refreshes every 60s; debounced to never call API faster than 30s
- Backs off 5 minutes on HTTP 429
- Error states: `C?` = no token, `C401` = expired token, `C429` = rate limited

## Data source

`GET https://api.anthropic.com/api/oauth/usage` with Bearer token read from macOS Keychain via:
```
security find-generic-password -s "Claude Code-credentials" -w
```
Falls back to keychain service `"Claude Code"` if first is missing.

Response fields used: `five_hour.utilization`, `five_hour.resets_at`, `seven_day.utilization`, `seven_day.resets_at`.

## Files

| File | Purpose |
|------|---------|
| `Sources/main.swift` | NSStatusItem, API polling, zone coloring, NSColor hex extension |
| `Sources/SettingsWindowController.swift` | Settings window — all rows, ToggleButton, login item logic |
| `Sources/ColorPickerWindowController.swift` | Color picker panel — SpectrumView, HueSliderView, hex input |
| `build.sh` | Compile `Sources/*.swift` + bundle + sign → `ClaudeBar.app` |
| `make_icon.swift` | Generate `AppIcon.icns` from `AppNameIcon.webp` (run once when icon changes) |
| `AppIcon.icns` | Generated icon — built from AppNameIcon.webp |
| `AppNameIcon.webp` | Source icon image — orange bg, dark "C%" |
| `release.sh` | Version bump + tag + push → triggers CI release |
| `claudebar.lua` | Hammerspoon version (legacy, kept for reference) |
| `init.lua` | Hammerspoon init that loads claudebar.lua |
| `.github/workflows/release.yml` | CI: builds + zips + publishes GitHub release on `v*` tag |

## Build

```bash
# Icon only needs regenerating when AppNameIcon.webp changes
swift make_icon.swift

# Full build → ClaudeBar.app
bash build.sh

# Install
cp -r ClaudeBar.app /Applications/
xattr -cr /Applications/ClaudeBar.app  # first launch: bypass Gatekeeper
```

Requires: Xcode command line tools (`xcode-select --install`), macOS 13+.

## Releasing

```bash
# 1. Add ## [X.Y.Z] section to CHANGELOG.md
# 2. Run:
./release.sh X.Y.Z
```

CI builds `ClaudeBar-vX.Y.Z.zip` and publishes it as a GitHub release automatically.
Repo: https://github.com/BartekJagniatkowski/claudebar

## Key implementation details

- `NSApp.setActivationPolicy(.accessory)` — no Dock icon
- `LSUIElement = true` in Info.plist — menubar-only
- Login item: managed in Settings window — tries `SMAppService.mainApp` (macOS 13 native), falls back to `~/Library/LaunchAgents/net.claudebar.plist`
- Settings window: Shadcn/ui dark style (`#09090b` bg, `#27272a` borders), 280pt wide, `NSWindow` with `.darkAqua` appearance; `isReleasedWhenClosed = false` on both settings window and color picker panel
- Threshold rows use `NSSlider` (1–100) + read-only value label (tagged 101/102 for lookup in `sliderChanged`); custom "+" swatch is 24×24 matching preset size, fills with picked color + 2px white outline when active
- Color picker: `SpectrumView` uses two stacked `CAGradientLayer`s (horizontal: white→hue, vertical: clear→black); `HueSliderView` uses gradient with 30° stops; `hexString`/`init?(hex:)` both use `deviceRGB` to prevent color space drift
- Two-line menubar title via `NSAttributedString` with `\n`, Menlo 9pt, `baselineOffset: -4`
- `NSColor.labelColor` for text — auto-adapts dark/light mode
- Token fetched on background thread (Process blocks); HTTP via URLSession async
- Ad-hoc codesign (`--sign -`) — works locally, not notarized
- Time format: `Xh Ym` when < 1 day, `Xd Yh` when ≥ 1 day
- Usage zones: `zone(for:)` maps 0–1 utilization to `(NSColor, CGFloat)`; thresholds read from UserDefaults each poll

## Styling

- Font: Menlo Bold 9pt
- Icon: AppNameIcon.webp (orange bg `#C97A58`, dark "C%")
- `baselineOffset: -4` centers two-line block in 22pt menubar height
