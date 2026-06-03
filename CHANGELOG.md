# Changelog

## [1.2.4] — 2026-06-03

- Menubar text alignment changed from center to left

## [1.2.3] — 2026-06-03

- Fixed error display: 401 and 429 responses now show `C401`/`C429` (consistent with `C?` and `C\(code)` pattern)
- Rate-limit message changed from `5m wait` to `5 min wait` for clarity
- Fixed `didToggleLogin`: on SMAppService error, toggle now reflects actual login-item state instead of staying wrong; macOS 13+ no longer falls through to LaunchAgent path on failure
- Fixed `build.sh`: `CFBundleIconFile` plist key now correctly omitted when `AppIcon.icns` is absent
- Removed dead `controlTextDidEndEditing` delegate method and `NSTextFieldDelegate` conformance from `SettingsWindowController` (leftover from pre-slider design)

## [1.2.2] — 2026-06-02

- Settings window narrowed to 280pt
- Threshold % fields replaced with sliders; value label shows current %
- Custom color button now a 24×24 "+" swatch — fills with color and shows selection outline when custom is active
- Fixed swatch buttons showing spurious "But" label text
- Hint text shortened; subtitles simplified to "above this %" (no color-specific wording)

## [1.2.1] — 2026-06-02

- Fix color space drift: custom color picker no longer silently alters saved hex values

## [1.2.0] — 2026-06-02

- Settings window (⌘,): Launch at Login toggle, warning/critical threshold %, color preset swatches, custom color picker
- Custom color picker panel: spectrum gradient, hue slider, hex input field — styled to match settings window (#09090b background)
- Removed "Launch at Login" menu item (moved to Settings window)
- Renamed "Quit claudebar" to "Quit ClaudeBar"
- Build now compiles all Sources/*.swift

## [1.1.0] — 2026-06-02

### Added
- Color-coded usage zones: warning (orange, default ≥75%) and critical (red + larger text, default ≥90%)
- Session and weekly rows styled independently
- Thresholds and colors configurable via UserDefaults (`defaults write net.claudebar warningThreshold 0.8`)

## [1.0.0] — 2026-06-01

### Added
- Public GitHub release with pre-built ClaudeBar.app download
- GitHub Actions CI: builds and publishes release zip on version tag
- release.sh script for version bumping, tagging, and pushing
- README install instructions with Gatekeeper workaround

## [0.2.0] — 2026-06-01

### Changed
- App renamed to ClaudeBar
- Icon updated to use AppNameIcon.webp (orange bg, dark "C%")
- Menubar now shows both session and weekly stats inline (no tooltip needed)
- Top row: session % + time to session reset
- Bottom row: weekly % + time to weekly reset
- Time format: `Xh Ym` under 1 day, `Xd Yh` for longer durations

## [0.1.0] — 2026-06-01

### Added
- Initial Swift menubar app
- Reads Claude Code OAuth token from macOS Keychain
- Polls `api.anthropic.com/api/oauth/usage` every 60s
- 30s debounce, 5-minute backoff on 429
- Two-line menubar display (Menlo Bold 9pt)
- Launch at Login via SMAppService (macOS 13+) with LaunchAgent fallback
- Ad-hoc codesign
