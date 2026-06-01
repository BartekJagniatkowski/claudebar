# ClaudeBar

macOS menubar app showing Claude Code token usage at a glance.

## What it does

- Menubar item: two lines — top: session `%` + time to session reset; bottom: weekly `%` + time to weekly reset
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
| `Sources/main.swift` | Full Swift app — NSStatusItem, API calls, login item |
| `build.sh` | Compile + bundle + sign → `ClaudeBar.app` |
| `make_icon.swift` | Generate `AppIcon.icns` from `AppNameIcon.webp` (run once when icon changes) |
| `AppIcon.icns` | Generated icon — built from AppNameIcon.webp |
| `AppNameIcon.webp` | Source icon image — orange bg, dark "C%" |
| `claudebar.lua` | Hammerspoon version (legacy, kept for reference) |
| `init.lua` | Hammerspoon init that loads claudebar.lua |

## Build

```bash
# Icon only needs regenerating when AppNameIcon.webp changes
swift make_icon.swift

# Full build → ClaudeBar.app
bash build.sh

# Install
cp -r ClaudeBar.app /Applications/
```

Requires: Xcode command line tools (`xcode-select --install`), macOS 13+.

## Key implementation details

- `NSApp.setActivationPolicy(.accessory)` — no Dock icon
- `LSUIElement = true` in Info.plist — menubar-only
- Login item: tries `SMAppService.mainApp` (macOS 13 native), falls back to `~/Library/LaunchAgents/net.claudebar.plist`
- Two-line menubar title via `NSAttributedString` with `\n`, Menlo 9pt, `baselineOffset: -4`
- `NSColor.labelColor` for text — auto-adapts dark/light mode
- Token fetched on background thread (Process blocks); HTTP via URLSession async
- Ad-hoc codesign (`--sign -`) — works locally, not notarized
- Time format: `Xh Ym` when < 1 day, `Xd Yh` when ≥ 1 day

## Styling

- Font: Menlo Bold 9pt
- Icon: AppNameIcon.webp (orange bg `#C97A58`, dark "C%")
- `baselineOffset: -4` centers two-line block in 22pt menubar height
