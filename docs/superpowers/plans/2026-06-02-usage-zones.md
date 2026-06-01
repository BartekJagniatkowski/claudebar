# Usage Zones Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add color-coded urgency to the ClaudeBar menubar display — session and weekly rows independently shift color and font size based on configurable usage thresholds stored in UserDefaults.

**Architecture:** All changes are in `Sources/main.swift`. A `zone(for:)` helper maps a 0–1 utilization fraction to a `(NSColor, CGFloat)` pair. `setDisplay` gains per-row color+size params. `handleResponse` normalizes the 0–100 API values to 0–1 before passing to `zone(for:)`. Defaults are registered at launch so first run works without any user setup.

**Tech Stack:** Swift, AppKit, UserDefaults. No new dependencies.

---

## File Map

| File | Changes |
|------|---------|
| `Sources/main.swift` | Add `NSColor(hex:)` extension, `claudeOrange` constant, `colorFromDefaults(key:fallback:)`, `zone(for:)`, update `setDisplay` signature, update `handleResponse` 200 case, register UserDefaults defaults |

---

### Task 1: Add `claudeOrange` constant and `NSColor(hex:)` extension

**Files:**
- Modify: `Sources/main.swift`

Context: `claudeOrange` is defined in `make_icon.swift` but not in `main.swift`. It needs to be accessible to `zone(for:)`. The hex extension lets UserDefaults color values be parsed from strings.

- [ ] **Step 1: Add `claudeOrange` constant after the imports**

In `Sources/main.swift`, insert after `import ServiceManagement` and before `// MARK: - Entry point`:

```swift
private let claudeOrange = NSColor(
    calibratedRed: 0.788, green: 0.478, blue: 0.345, alpha: 1
)
```

- [ ] **Step 2: Add `NSColor(hex:)` extension at the bottom of the file**

Append after the closing `}` of `AppDelegate`, before the final end of file:

```swift
// MARK: - NSColor hex parsing

extension NSColor {
    convenience init?(hex: String) {
        let h = hex.hasPrefix("#") ? String(hex.dropFirst()) : hex
        guard h.count == 6, let value = UInt64(h, radix: 16) else { return nil }
        self.init(
            calibratedRed:   CGFloat((value >> 16) & 0xFF) / 255,
            green: CGFloat((value >>  8) & 0xFF) / 255,
            blue:  CGFloat( value        & 0xFF) / 255,
            alpha: 1
        )
    }
}
```

- [ ] **Step 3: Verify it compiles**

```bash
cd /Users/bartekjagniatkowski/Development/claudebar && swiftc Sources/main.swift -framework AppKit -framework ServiceManagement -o /dev/null 2>&1
```
Expected: no output (clean compile).

- [ ] **Step 4: Commit**

```bash
git add Sources/main.swift
git commit -m "feat: add claudeOrange constant and NSColor hex extension"
```

---

### Task 2: Register UserDefaults defaults

**Files:**
- Modify: `Sources/main.swift:23-34` (`applicationDidFinishLaunching`)

- [ ] **Step 1: Add UserDefaults registration at the top of `applicationDidFinishLaunching`**

Replace:
```swift
func applicationDidFinishLaunching(_ notification: Notification) {
    NSApp.setActivationPolicy(.accessory)
```

With:
```swift
func applicationDidFinishLaunching(_ notification: Notification) {
    UserDefaults.standard.register(defaults: [
        "warningThreshold": 0.75,
        "criticalThreshold": 0.90,
        "warningColor": "#C97A58",
        "criticalColor": "systemRed",
    ])

    NSApp.setActivationPolicy(.accessory)
```

- [ ] **Step 2: Verify it compiles**

```bash
cd /Users/bartekjagniatkowski/Development/claudebar && swiftc Sources/main.swift -framework AppKit -framework ServiceManagement -o /dev/null 2>&1
```
Expected: no output.

- [ ] **Step 3: Commit**

```bash
git add Sources/main.swift
git commit -m "feat: register UserDefaults defaults for usage zone thresholds"
```

---

### Task 3: Add `colorFromDefaults` and `zone(for:)` helpers

**Files:**
- Modify: `Sources/main.swift` (inside `AppDelegate`, in the `// MARK: - Helpers` section)

- [ ] **Step 1: Add `colorFromDefaults(key:fallback:)` inside AppDelegate, after `timeUntil`**

```swift
private func colorFromDefaults(key: String, fallback: NSColor) -> NSColor {
    let val = UserDefaults.standard.string(forKey: key) ?? ""
    if val == "systemRed" { return .systemRed }
    return NSColor(hex: val) ?? fallback
}
```

- [ ] **Step 2: Add `zone(for:)` directly after `colorFromDefaults`**

```swift
private func zone(for utilization: Double) -> (NSColor, CGFloat) {
    let warn = UserDefaults.standard.double(forKey: "warningThreshold")
    let crit = UserDefaults.standard.double(forKey: "criticalThreshold")
    if utilization >= crit {
        return (colorFromDefaults(key: "criticalColor", fallback: .systemRed), 10)
    } else if utilization >= warn {
        return (colorFromDefaults(key: "warningColor", fallback: claudeOrange), 9)
    } else {
        return (.labelColor, 9)
    }
}
```

- [ ] **Step 3: Verify it compiles**

```bash
cd /Users/bartekjagniatkowski/Development/claudebar && swiftc Sources/main.swift -framework AppKit -framework ServiceManagement -o /dev/null 2>&1
```
Expected: no output.

- [ ] **Step 4: Commit**

```bash
git add Sources/main.swift
git commit -m "feat: add colorFromDefaults and zone helpers"
```

---

### Task 4: Update `setDisplay` for per-row color and size

**Files:**
- Modify: `Sources/main.swift:125-146` (`setDisplay`)

- [ ] **Step 1: Replace the entire `setDisplay` method**

Replace:
```swift
private func setDisplay(_ line1: String, _ line2: String) {
    guard let button = statusItem?.button else { return }

    let para = NSMutableParagraphStyle()
    para.alignment = .center
    para.lineSpacing = 0
    para.maximumLineHeight = 11
    para.minimumLineHeight = 11

    let font = NSFont(name: "Menlo", size: 9)
        ?? .monospacedSystemFont(ofSize: 9, weight: .regular)

    let attrs: [NSAttributedString.Key: Any] = [
        .font: font,
        .foregroundColor: NSColor.labelColor,
        .paragraphStyle: para,
        .baselineOffset: -4,
    ]

    let text = line2.isEmpty ? line1 : "\(line1)\n\(line2)"
    button.attributedTitle = NSAttributedString(string: text, attributes: attrs)
}
```

With:
```swift
private func setDisplay(
    _ line1: String, _ line2: String,
    color1: NSColor = .labelColor, size1: CGFloat = 9,
    color2: NSColor = .labelColor, size2: CGFloat = 9
) {
    guard let button = statusItem?.button else { return }

    let para = NSMutableParagraphStyle()
    para.alignment = .center
    para.lineSpacing = 0
    para.maximumLineHeight = 11
    para.minimumLineHeight = 11

    func rowAttrs(color: NSColor, size: CGFloat) -> [NSAttributedString.Key: Any] {
        [
            .font: NSFont(name: "Menlo", size: size)
                ?? .monospacedSystemFont(ofSize: size, weight: .regular),
            .foregroundColor: color,
            .paragraphStyle: para,
            .baselineOffset: -4,
        ]
    }

    if line2.isEmpty {
        button.attributedTitle = NSAttributedString(
            string: line1, attributes: rowAttrs(color: color1, size: size1)
        )
    } else {
        let s = NSMutableAttributedString()
        s.append(NSAttributedString(string: line1,  attributes: rowAttrs(color: color1, size: size1)))
        s.append(NSAttributedString(string: "\n",   attributes: rowAttrs(color: color1, size: size1)))
        s.append(NSAttributedString(string: line2,  attributes: rowAttrs(color: color2, size: size2)))
        button.attributedTitle = s
    }
}
```

- [ ] **Step 2: Verify it compiles**

```bash
cd /Users/bartekjagniatkowski/Development/claudebar && swiftc Sources/main.swift -framework AppKit -framework ServiceManagement -o /dev/null 2>&1
```
Expected: no output. All existing `setDisplay("C?", "re-auth")` call sites still compile because the new params have defaults.

- [ ] **Step 3: Commit**

```bash
git add Sources/main.swift
git commit -m "feat: update setDisplay for per-row color and size"
```

---

### Task 5: Update `handleResponse` 200 case

**Files:**
- Modify: `Sources/main.swift:203-227` (`handleResponse`)

- [ ] **Step 1: Replace the 200 case in `handleResponse`**

Replace:
```swift
case 200:
    guard let data,
          let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
    else {
        setDisplay("C?", "parse err")
        return
    }
    let fh = json["five_hour"] as? [String: Any] ?? [:]
    let sd = json["seven_day"]  as? [String: Any] ?? [:]
    let sessionPct   = Int((fh["utilization"] as? Double ?? 0).rounded())
    let weeklyPct    = Int((sd["utilization"] as? Double ?? 0).rounded())
    let sessionReset = timeUntil(fh["resets_at"] as? String)
    let weeklyReset  = timeUntil(sd["resets_at"] as? String)
    setDisplay("\(sessionPct)% \(sessionReset)", "\(weeklyPct)% \(weeklyReset)")
```

With:
```swift
case 200:
    guard let data,
          let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
    else {
        setDisplay("C?", "parse err")
        return
    }
    let fh = json["five_hour"] as? [String: Any] ?? [:]
    let sd = json["seven_day"]  as? [String: Any] ?? [:]
    let sessionRaw   = fh["utilization"] as? Double ?? 0
    let weeklyRaw    = sd["utilization"] as? Double ?? 0
    let sessionPct   = Int(sessionRaw.rounded())
    let weeklyPct    = Int(weeklyRaw.rounded())
    let sessionReset = timeUntil(fh["resets_at"] as? String)
    let weeklyReset  = timeUntil(sd["resets_at"] as? String)
    let (c1, s1)     = zone(for: sessionRaw / 100)
    let (c2, s2)     = zone(for: weeklyRaw  / 100)
    setDisplay(
        "\(sessionPct)% \(sessionReset)",
        "\(weeklyPct)% \(weeklyReset)",
        color1: c1, size1: s1,
        color2: c2, size2: s2
    )
```

- [ ] **Step 2: Verify it compiles**

```bash
cd /Users/bartekjagniatkowski/Development/claudebar && swiftc Sources/main.swift -framework AppKit -framework ServiceManagement -o /dev/null 2>&1
```
Expected: no output.

- [ ] **Step 3: Commit**

```bash
git add Sources/main.swift
git commit -m "feat: apply usage zones in handleResponse"
```

---

### Task 6: Full build, visual verify, and release

**Files:**
- Modify: `CHANGELOG.md`

- [ ] **Step 1: Full build**

```bash
cd /Users/bartekjagniatkowski/Development/claudebar && bash build.sh 2>&1 && xattr -cr ClaudeBar.app && codesign --force --deep --sign - ClaudeBar.app
```
Expected: `✓ Built: .../ClaudeBar.app`

- [ ] **Step 2: Install and run**

```bash
cp -r /Users/bartekjagniatkowski/Development/claudebar/ClaudeBar.app /Applications/ClaudeBar.app
open /Applications/ClaudeBar.app
```
Expected: menubar shows two rows with default label color (normal zone if usage < 75%).

- [ ] **Step 3: Smoke-test warning zone via defaults override**

```bash
defaults write net.claudebar warningThreshold 0.0
```
Then wait for the next poll (up to 60s) or quit and reopen the app. Expected: both rows turn Claude orange `#C97A58`.

- [ ] **Step 4: Smoke-test critical zone**

```bash
defaults write net.claudebar criticalThreshold 0.0
```
Quit and reopen. Expected: both rows turn red and font size increases to 10pt (text appears slightly larger).

- [ ] **Step 5: Reset overrides**

```bash
defaults delete net.claudebar warningThreshold
defaults delete net.claudebar criticalThreshold
```
Quit and reopen. Expected: rows return to default colors.

- [ ] **Step 6: Add CHANGELOG entry**

Prepend to `CHANGELOG.md` above `## [1.0.0]`:

```markdown
## [1.1.0] — 2026-06-02

### Added
- Color-coded usage zones: warning (orange, default ≥75%) and critical (red + larger text, default ≥90%)
- Session and weekly rows styled independently
- Thresholds and colors configurable via UserDefaults (`defaults write net.claudebar warningThreshold 0.8`)
```

- [ ] **Step 7: Ship**

```bash
cd /Users/bartekjagniatkowski/Development/claudebar
git add CHANGELOG.md
git commit -m "docs: add v1.1.0 changelog entry"
git push origin main
./release.sh 1.1.0
```
Expected: `✓ Tagged v1.1.0 and pushed — CI will build and publish the release.`
