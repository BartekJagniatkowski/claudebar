# ClaudeBar Usage Zones — Design Spec

**Date:** 2026-06-02
**Scope:** Color-coded urgency display with configurable thresholds via UserDefaults

---

## Goal

Make high usage immediately visible at a glance — without adding UI chrome. The menubar text itself communicates urgency through color and size. Both session and weekly stats are evaluated and styled independently.

---

## Out of Scope

- macOS notifications
- Preferences window (future release)
- Custom font / Iosevka (future release — see font preference memory)
- Apple Developer signing / notarization

---

## Section 1: Usage Zones

Each stat (session % and weekly %) is independently classified into one of three zones:

| Zone | Default threshold | Text color | Font size |
|------|-----------------|------------|-----------|
| Normal | < 75% | `NSColor.labelColor` | Menlo Bold 9pt |
| Warning | ≥ 75% | Claude orange `#C97A58` | Menlo Bold 9pt |
| Critical | ≥ 90% | `NSColor.systemRed` | Menlo Bold 10pt |

The two display rows are styled independently. Session can be critical while weekly is normal. No new UI elements or menu changes are required.

---

## Section 2: UserDefaults Configuration

Four keys registered at launch with defaults so first run works without any setup:

| Key | Type | Default |
|-----|------|---------|
| `warningThreshold` | Double | `0.75` |
| `criticalThreshold` | Double | `0.90` |
| `warningColor` | String (hex) | `"#C97A58"` |
| `criticalColor` | String (hex) | `"systemRed"` (sentinel for `NSColor.systemRed`) |

Registered in `applicationDidFinishLaunching` via:
```swift
UserDefaults.standard.register(defaults: [
    "warningThreshold": 0.75,
    "criticalThreshold": 0.90,
    "warningColor": "#C97A58",
    "criticalColor": "systemRed",
])
```

Thresholds are read on each `handleResponse` call — no live-reload needed, next poll picks up changes.

Users can override from Terminal:
```bash
defaults write net.claudebar warningThreshold 0.8
defaults write net.claudebar criticalThreshold 0.95
```

`criticalColor` value `"systemRed"` is a sentinel resolved to `NSColor.systemRed`. Any other value is parsed as a hex string. Same pattern for `warningColor`.

---

## Section 3: Display Logic Changes

### New helper: `zone(for:)`

Added to `AppDelegate`. Reads thresholds from `UserDefaults` and returns the color + font size for a given utilization value (0.0–1.0):

```swift
private func zone(for utilization: Double) -> (NSColor, CGFloat) {
    let warn = UserDefaults.standard.double(forKey: "warningThreshold")
    let crit = UserDefaults.standard.double(forKey: "criticalThreshold")
    switch utilization {
    case _ where utilization >= crit:
        return (colorFromDefaults(key: "criticalColor", fallback: .systemRed), 10)
    case _ where utilization >= warn:
        return (colorFromDefaults(key: "warningColor", fallback: claudeOrange), 9)
    default:
        return (.labelColor, 9)
    }
}

private func colorFromDefaults(key: String, fallback: NSColor) -> NSColor {
    let val = UserDefaults.standard.string(forKey: key) ?? ""
    if val == "systemRed" { return .systemRed }
    return NSColor(hex: val) ?? fallback
}
```

### Updated: `setDisplay(_:_:color1:size1:color2:size2:)`

`setDisplay` gains per-row color and size parameters (with defaults matching current behaviour so all existing call sites still compile):

```swift
private func setDisplay(
    _ line1: String, _ line2: String,
    color1: NSColor = .labelColor, size1: CGFloat = 9,
    color2: NSColor = .labelColor, size2: CGFloat = 9
)
```

Each row builds its own `NSAttributedString` with its own `.foregroundColor` and `.font`.

### Updated: `handleResponse` (200 case)

The API returns utilization as 0–100 (e.g. `42.7`). Normalize to 0–1 before passing to `zone(for:)`:

```swift
let sessionRaw = fh["utilization"] as? Double ?? 0   // 0–100
let weeklyRaw  = sd["utilization"] as? Double ?? 0   // 0–100
let sessionPct = Int(sessionRaw.rounded())
let weeklyPct  = Int(weeklyRaw.rounded())
let (c1, s1) = zone(for: sessionRaw / 100)
let (c2, s2) = zone(for: weeklyRaw  / 100)
setDisplay(
    "\(sessionPct)% \(sessionReset)",
    "\(weeklyPct)% \(weeklyReset)",
    color1: c1, size1: s1,
    color2: c2, size2: s2
)
```

### NSColor hex extension

A small `NSColor` extension parses `#RRGGBB` hex strings. Added to `main.swift`:

```swift
extension NSColor {
    convenience init?(hex: String) {
        let h = hex.hasPrefix("#") ? String(hex.dropFirst()) : hex
        guard h.count == 6, let value = UInt64(h, radix: 16) else { return nil }
        self.init(
            red:   CGFloat((value >> 16) & 0xFF) / 255,
            green: CGFloat((value >>  8) & 0xFF) / 255,
            blue:  CGFloat( value        & 0xFF) / 255,
            alpha: 1
        )
    }
}
```

---

## Files Changed

| File | Change |
|------|--------|
| `Sources/main.swift` | Register UserDefaults, add `zone(for:)`, add `colorFromDefaults(key:fallback:)`, update `setDisplay` signature, update `handleResponse` 200 case, add `NSColor` hex extension |
