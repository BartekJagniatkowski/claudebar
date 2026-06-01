# Changelog

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
