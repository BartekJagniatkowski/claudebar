# Settings Window & Color Picker Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a Shadcn/ui dark-themed settings window with launch-at-login toggle, usage zone threshold/color configuration, and a custom matching color picker panel.

**Architecture:** Three Swift source files compiled together. `SettingsWindowController` owns the settings panel UI and opens `ColorPickerWindowController` as a floating sub-panel. `AppDelegate` sheds all login-item logic (moved to `SettingsWindowController`) and gains a single `openSettings` action. `build.sh` compiles `Sources/*.swift` instead of just `main.swift`.

**Tech Stack:** Swift 5.9+, AppKit, ServiceManagement, macOS 13+, programmatic auto-layout, no storyboards, CAGradientLayer for color picker gradients.

---

## File Map

| File | Change |
|------|--------|
| `build.sh` | `swiftc Sources/*.swift` instead of `swiftc Sources/main.swift` |
| `Sources/main.swift` | Remove login menu item + all login helpers; add Settings… item + `settingsController` property; add `hexString` to NSColor extension; change `criticalColor` default from `"systemRed"` to `"#ef4444"`; simplify `colorFromDefaults` |
| `Sources/SettingsWindowController.swift` | New — full settings panel with all 5 rows + `ToggleButton` class |
| `Sources/ColorPickerWindowController.swift` | New — `SpectrumView` + `HueSliderView` + hex field in floating NSPanel |

---

### Task 1: Update build.sh + main.swift

**Files:**
- Modify: `build.sh`
- Modify: `Sources/main.swift`

- [ ] **Step 1: Update build.sh to compile all Swift sources**

In `build.sh`, change the `swiftc` invocation on line 9. Replace:

```bash
swiftc "$SRC" \
    -framework AppKit \
    -framework ServiceManagement \
    -O \
    -o claudebar_bin
```

With (drop the `SRC` variable entirely and use the glob directly):

```bash
swiftc Sources/*.swift \
    -framework AppKit \
    -framework ServiceManagement \
    -O \
    -o claudebar_bin
```

Also remove line 3 (`SRC="Sources/main.swift"`) since it's no longer used.

- [ ] **Step 2: Update main.swift — remove login helpers, add settingsController**

Replace the entire `AppDelegate` class (lines 17–301) with the version below. Key changes:
- Add `private var settingsController: SettingsWindowController?`
- Replace `buildMenu()` — remove LaunchAtLogin item, add "Settings…" (⌘,)
- Add `@objc private func openSettings()`
- Delete `loginEnabled`, `launchAgentURL`, `toggleLogin`, `toggleLaunchAgent`, `launchctl` — these move to `SettingsWindowController`
- Change default for `criticalColor` from `"systemRed"` to `"#ef4444"`
- Simplify `colorFromDefaults` — remove `"systemRed"` special case

```swift
class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var timer: Timer?
    private var lastCallDate: Date = .distantPast
    private var backoffUntil: Date = .distantPast
    private var settingsController: SettingsWindowController?

    private let pollInterval: TimeInterval = 60
    private let minCallGap: TimeInterval = 30
    private let backoffDuration: TimeInterval = 300

    func applicationDidFinishLaunching(_ notification: Notification) {
        UserDefaults.standard.register(defaults: [
            "warningThreshold": 0.75,
            "criticalThreshold": 0.90,
            "warningColor": "#C97A58",
            "criticalColor": "#ef4444",
        ])
        NSApp.setActivationPolicy(.accessory)
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        setDisplay("C…", "")
        buildMenu()
        refresh()
        timer = Timer.scheduledTimer(withTimeInterval: pollInterval, repeats: true) { [weak self] _ in
            self?.refresh()
        }
    }

    // MARK: - Menu

    private func buildMenu() {
        let menu = NSMenu()
        menu.addItem(NSMenuItem(
            title: "Settings…",
            action: #selector(openSettings),
            keyEquivalent: ","
        ))
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(
            title: "Quit ClaudeBar",
            action: #selector(NSApp.terminate(_:)),
            keyEquivalent: "q"
        ))
        statusItem.menu = menu
    }

    @objc private func openSettings() {
        if settingsController == nil {
            settingsController = SettingsWindowController()
        }
        settingsController?.showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    // MARK: - Display

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
            s.append(NSAttributedString(string: line1, attributes: rowAttrs(color: color1, size: size1)))
            s.append(NSAttributedString(string: "\n",  attributes: rowAttrs(color: color1, size: size1)))
            s.append(NSAttributedString(string: line2, attributes: rowAttrs(color: color2, size: size2)))
            button.attributedTitle = s
        }
    }

    // MARK: - Token

    private func getToken() -> String? {
        for service in ["Claude Code-credentials", "Claude Code"] {
            let p = Process()
            p.executableURL = URL(fileURLWithPath: "/usr/bin/security")
            p.arguments = ["find-generic-password", "-s", service, "-w"]
            let out = Pipe()
            p.standardOutput = out
            p.standardError = Pipe()
            guard (try? p.run()) != nil else { continue }
            p.waitUntilExit()
            guard p.terminationStatus == 0 else { continue }
            let raw = String(data: out.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            guard !raw.isEmpty,
                  let data = raw.data(using: .utf8),
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let oauth = json["claudeAiOauth"] as? [String: Any],
                  let token = oauth["accessToken"] as? String
            else { continue }
            return token
        }
        return nil
    }

    // MARK: - Refresh

    private func refresh() {
        let now = Date()
        guard now >= backoffUntil, now.timeIntervalSince(lastCallDate) >= minCallGap else { return }
        lastCallDate = now
        DispatchQueue.global(qos: .background).async { [weak self] in
            guard let self else { return }
            guard let token = self.getToken() else {
                DispatchQueue.main.async { self.setDisplay("C?", "re-auth") }
                return
            }
            var req = URLRequest(url: URL(string: "https://api.anthropic.com/api/oauth/usage")!)
            req.timeoutInterval = 10
            req.setValue("application/json", forHTTPHeaderField: "Accept")
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            req.setValue("oauth-2025-04-20", forHTTPHeaderField: "anthropic-beta")
            req.setValue("claude-code/2.1.0", forHTTPHeaderField: "User-Agent")
            URLSession.shared.dataTask(with: req) { data, response, _ in
                let code = (response as? HTTPURLResponse)?.statusCode ?? 0
                DispatchQueue.main.async { self.handleResponse(code: code, data: data) }
            }.resume()
        }
    }

    private func handleResponse(code: Int, data: Data?) {
        switch code {
        case 200:
            guard let data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
            else { setDisplay("C?", "parse err"); return }
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
                color1: c1, size1: s1, color2: c2, size2: s2
            )
        case 401: setDisplay("401", "re-auth")
        case 429:
            backoffUntil = Date().addingTimeInterval(backoffDuration)
            setDisplay("429", "5m wait")
        default: setDisplay("C\(code)", "")
        }
    }

    // MARK: - Helpers

    private func timeUntil(_ iso: String?) -> String {
        guard let iso else { return "?" }
        let fmt = ISO8601DateFormatter()
        fmt.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        var date = fmt.date(from: iso)
        if date == nil {
            fmt.formatOptions = [.withInternetDateTime]
            date = fmt.date(from: iso)
        }
        guard let date else { return "?" }
        let diff = date.timeIntervalSinceNow
        guard diff > 0 else { return "now" }
        let totalH = Int(diff) / 3600
        let d = totalH / 24
        let h = totalH % 24
        let m = Int(diff) % 3600 / 60
        if d > 0 { return "\(d)d \(h)h" }
        return h > 0 ? "\(h)h \(m)m" : "\(m)m"
    }

    private func colorFromDefaults(key: String, fallback: NSColor) -> NSColor {
        let val = UserDefaults.standard.string(forKey: key) ?? ""
        return NSColor(hex: val) ?? fallback
    }

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
}
```

- [ ] **Step 3: Add hexString to NSColor extension in main.swift**

Append `hexString` to the existing `NSColor` extension at the bottom of `Sources/main.swift`:

```swift
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

    var hexString: String {
        guard let c = usingColorSpace(.deviceRGB) else { return "#000000" }
        return String(format: "#%02X%02X%02X",
            Int(c.redComponent   * 255),
            Int(c.greenComponent * 255),
            Int(c.blueComponent  * 255))
    }
}
```

- [ ] **Step 4: Build — expect compile error (SettingsWindowController not yet created)**

```bash
cd /Users/bartekjagniatkowski/Development/claudebar && bash build.sh
```

Expected output includes: `error: cannot find type 'SettingsWindowController'`
This confirms the reference is wired. Task 2 satisfies it.

- [ ] **Step 5: Commit**

```bash
git add build.sh Sources/main.swift
git commit -m "refactor: compile all Sources/*.swift, move login to settings, hexString extension"
```

---

### Task 2: SettingsWindowController — window shell + helpers

**Files:**
- Create: `Sources/SettingsWindowController.swift`

- [ ] **Step 1: Create the file**

Create `Sources/SettingsWindowController.swift` with the full class shell, color constants, helper methods, and `ToggleButton`:

```swift
import AppKit
import ServiceManagement

// Design tokens
private let bg        = NSColor(hex: "#09090b")!
private let border    = NSColor(hex: "#27272a")!
private let textPri   = NSColor(hex: "#fafafa")!
private let textSec   = NSColor(hex: "#71717a")!
private let textMuted = NSColor(hex: "#52525b")!

class SettingsWindowController: NSWindowController, NSWindowDelegate, NSTextFieldDelegate {

    private var loginToggle: ToggleButton!
    private var warningPctField: NSTextField!
    private var criticalPctField: NSTextField!
    private var warningSwatches: [NSButton] = []
    private var criticalSwatches: [NSButton] = []
    private var colorPickerController: ColorPickerWindowController?
    private var activeColorKey: String = ""

    let warningPresets  = ["#C97A58", "#e8a87c", "#eab308", "#38bdf8"]
    let criticalPresets = ["#ef4444", "#f87171", "#f97316", "#a855f7"]

    init() {
        let win = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 320, height: 100),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        win.title = "Settings"
        win.appearance = NSAppearance(named: .darkAqua)
        win.backgroundColor = bg
        win.isMovableByWindowBackground = false
        super.init(window: win)
        win.delegate = self
        buildUI()
    }
    required init?(coder: NSCoder) { fatalError() }

    // MARK: - Build UI

    private func buildUI() {
        let content = window!.contentView!
        content.wantsLayer = true

        let stack = NSStackView()
        stack.orientation = .vertical
        stack.spacing = 0
        stack.alignment = .width
        stack.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 24),
            stack.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -24),
            stack.topAnchor.constraint(equalTo: content.topAnchor, constant: 8),
            stack.bottomAnchor.constraint(equalTo: content.bottomAnchor, constant: -8),
        ])

        stack.addArrangedSubview(makeLoginRow())
        stack.addArrangedSubview(makeDivider())
        stack.addArrangedSubview(makeExplanationRow())
        stack.addArrangedSubview(makeDivider())
        stack.addArrangedSubview(makeThresholdRow(isWarning: true))
        stack.addArrangedSubview(makeDivider())
        stack.addArrangedSubview(makeThresholdRow(isWarning: false))
        stack.addArrangedSubview(makeDivider())
        stack.addArrangedSubview(makeAboutRow())

        content.layoutSubtreeIfNeeded()
        let h = stack.fittingSize.height + 16
        window!.setContentSize(NSSize(width: 320, height: max(h, 360)))
        window!.center()
    }

    // MARK: - Row stubs (filled in Tasks 3–5)

    private func makeLoginRow() -> NSView { NSView() }
    private func makeExplanationRow() -> NSView { NSView() }
    private func makeThresholdRow(isWarning: Bool) -> NSView { NSView() }
    private func makeAboutRow() -> NSView { NSView() }

    // MARK: - Shared helpers

    private func makeDivider() -> NSView {
        let v = NSView()
        v.wantsLayer = true
        v.layer!.backgroundColor = border.cgColor
        v.translatesAutoresizingMaskIntoConstraints = false
        v.heightAnchor.constraint(equalToConstant: 1).isActive = true
        return v
    }

    private func lbl(_ text: String, size: CGFloat, color: NSColor) -> NSTextField {
        let f = NSTextField(labelWithString: text)
        f.font = .systemFont(ofSize: size, weight: size >= 13 ? .medium : .regular)
        f.textColor = color
        f.lineBreakMode = .byWordWrapping
        f.translatesAutoresizingMaskIntoConstraints = false
        return f
    }

    private func makePctField(key: String, color: NSColor) -> NSTextField {
        let val = Int((UserDefaults.standard.double(forKey: key) * 100).rounded())
        let f = NSTextField()
        f.stringValue = "\(val)"
        f.font = .systemFont(ofSize: 13)
        f.textColor = color
        f.isBezeled = false
        f.drawsBackground = true
        f.backgroundColor = bg
        f.alignment = .center
        f.wantsLayer = true
        f.layer!.cornerRadius = 6
        f.layer!.borderWidth = 1
        f.layer!.borderColor = border.cgColor
        f.delegate = self
        f.identifier = NSUserInterfaceItemIdentifier(key)
        f.translatesAutoresizingMaskIntoConstraints = false
        return f
    }

    private func makeSwatchBtn(hex: String, isSelected: Bool) -> NSButton {
        let btn = NSButton()
        btn.isBordered = false
        btn.wantsLayer = true
        btn.layer!.cornerRadius = 4
        btn.layer!.backgroundColor = NSColor(hex: hex)?.cgColor ?? NSColor.gray.cgColor
        if isSelected {
            btn.layer!.borderWidth = 2
            btn.layer!.borderColor = textPri.cgColor
        }
        btn.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            btn.widthAnchor.constraint(equalToConstant: 24),
            btn.heightAnchor.constraint(equalToConstant: 24),
        ])
        return btn
    }

    // MARK: - NSTextFieldDelegate — percent fields

    func controlTextDidEndEditing(_ obj: Notification) {
        guard let field = obj.object as? NSTextField else { return }
        let key = field.identifier?.rawValue ?? ""
        guard key == "warningThreshold" || key == "criticalThreshold" else { return }
        let text = field.stringValue.trimmingCharacters(in: .whitespaces)
        if let val = Int(text), val >= 1, val <= 100 {
            UserDefaults.standard.set(Double(val) / 100.0, forKey: key)
            field.layer!.borderColor = border.cgColor
        } else {
            field.layer!.borderColor = NSColor.systemRed.cgColor
        }
    }
}

// MARK: - ToggleButton

class ToggleButton: NSButton {
    var isOn: Bool = false { didSet { needsDisplay = true } }
    private let onColor  = NSColor(hex: "#C97A58")!
    private let offColor = NSColor(hex: "#27272a")!

    override init(frame: NSRect) {
        super.init(frame: frame)
        isBordered = false
        title = ""
    }
    required init?(coder: NSCoder) { fatalError() }

    override func draw(_ dirtyRect: NSRect) {
        let w: CGFloat = 38, h: CGFloat = 22
        let r = NSRect(x: 0, y: (bounds.height - h) / 2, width: w, height: h)
        let track = NSBezierPath(roundedRect: r, xRadius: h / 2, yRadius: h / 2)
        (isOn ? onColor : offColor).setFill()
        track.fill()
        let ts: CGFloat = 18
        let tx: CGFloat = isOn ? w - ts - 2 : 2
        let tr = NSRect(x: tx, y: (bounds.height - ts) / 2, width: ts, height: ts)
        NSBezierPath(ovalIn: tr).fill()  // thumb always white; set fill before calling
    }

    override var intrinsicContentSize: NSSize { NSSize(width: 38, height: 22) }

    override func mouseUp(with event: NSEvent) {
        isOn.toggle()
        sendAction(action, to: target)
    }
}
```

Note: `ToggleButton.draw` above has a bug — needs to set white fill before drawing the thumb. Fix the draw method:

```swift
override func draw(_ dirtyRect: NSRect) {
    let w: CGFloat = 38, h: CGFloat = 22
    let r = NSRect(x: 0, y: (bounds.height - h) / 2, width: w, height: h)
    let track = NSBezierPath(roundedRect: r, xRadius: h / 2, yRadius: h / 2)
    (isOn ? onColor : offColor).setFill()
    track.fill()

    let ts: CGFloat = 18
    let tx: CGFloat = isOn ? w - ts - 2 : 2
    let tr = NSRect(x: tx, y: (bounds.height - ts) / 2, width: ts, height: ts)
    NSColor.white.setFill()
    NSBezierPath(ovalIn: tr).fill()
}
```

- [ ] **Step 2: Build — must compile cleanly now**

```bash
bash build.sh
```

Expected: `✓ Built: .../ClaudeBar.app` with no errors.

- [ ] **Step 3: Smoke test**

```bash
open ClaudeBar.app
```

Click menubar → "Settings…". Window should open (mostly empty, dark background). Close with ✕.

- [ ] **Step 4: Commit**

```bash
git add Sources/SettingsWindowController.swift
git commit -m "feat: SettingsWindowController shell + ToggleButton"
```

---

### Task 3: SettingsWindowController — Login at Login row

**Files:**
- Modify: `Sources/SettingsWindowController.swift`

- [ ] **Step 1: Add login item logic to SettingsWindowController**

Insert these methods into `SettingsWindowController` (after the `makeAboutRow` stub, before the closing `}`):

```swift
// MARK: - Login item

private var isLoginEnabled: Bool {
    if #available(macOS 13.0, *) {
        return SMAppService.mainApp.status == .enabled
    }
    return FileManager.default.fileExists(atPath: launchAgentURL.path)
}

private var launchAgentURL: URL {
    FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("Library/LaunchAgents/net.claudebar.plist")
}

@objc private func didToggleLogin() {
    if #available(macOS 13.0, *) {
        let svc = SMAppService.mainApp
        do {
            if svc.status == .enabled { try svc.unregister() }
            else { try svc.register() }
            loginToggle.isOn = (svc.status == .enabled)
            return
        } catch {}
    }
    toggleLaunchAgent()
}

private func toggleLaunchAgent() {
    let url = launchAgentURL
    if FileManager.default.fileExists(atPath: url.path) {
        launchctl("unload", url.path)
        try? FileManager.default.removeItem(at: url)
        loginToggle.isOn = false
    } else {
        let exe = Bundle.main.executablePath
            ?? "/Applications/ClaudeBar.app/Contents/MacOS/claudebar"
        let plist: [String: Any] = [
            "Label":            "net.claudebar",
            "ProgramArguments": [exe],
            "RunAtLoad":        true,
            "KeepAlive":        false,
        ]
        if let data = try? PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0) {
            try? data.write(to: url)
            launchctl("load", url.path)
            loginToggle.isOn = true
        }
    }
}

private func launchctl(_ verb: String, _ path: String) {
    let p = Process()
    p.executableURL = URL(fileURLWithPath: "/bin/launchctl")
    p.arguments = [verb, path]
    try? p.run()
    p.waitUntilExit()
}
```

- [ ] **Step 2: Replace makeLoginRow() stub**

Replace `private func makeLoginRow() -> NSView { NSView() }` with:

```swift
private func makeLoginRow() -> NSView {
    let container = NSView()
    container.translatesAutoresizingMaskIntoConstraints = false

    let title    = lbl("Launch at Login", size: 13, color: textPri)
    let subtitle = lbl("Start ClaudeBar when you log in", size: 11, color: textSec)
    loginToggle = ToggleButton(frame: .zero)
    loginToggle.isOn = isLoginEnabled
    loginToggle.target = self
    loginToggle.action = #selector(didToggleLogin)
    loginToggle.translatesAutoresizingMaskIntoConstraints = false

    [title, subtitle, loginToggle].forEach { container.addSubview($0) }

    NSLayoutConstraint.activate([
        title.topAnchor.constraint(equalTo: container.topAnchor, constant: 14),
        title.leadingAnchor.constraint(equalTo: container.leadingAnchor),
        title.trailingAnchor.constraint(lessThanOrEqualTo: loginToggle.leadingAnchor, constant: -8),

        subtitle.topAnchor.constraint(equalTo: title.bottomAnchor, constant: 2),
        subtitle.leadingAnchor.constraint(equalTo: container.leadingAnchor),
        subtitle.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -14),

        loginToggle.trailingAnchor.constraint(equalTo: container.trailingAnchor),
        loginToggle.centerYAnchor.constraint(equalTo: container.centerYAnchor),
        loginToggle.widthAnchor.constraint(equalToConstant: 38),
        loginToggle.heightAnchor.constraint(equalToConstant: 22),
    ])

    return container
}
```

- [ ] **Step 3: Build + verify**

```bash
bash build.sh && open ClaudeBar.app
```

Settings → Launch at Login row should appear with label, subtitle, and orange/gray toggle reflecting real login item state. Clicking toggle should enable/disable launch at login.

- [ ] **Step 4: Commit**

```bash
git add Sources/SettingsWindowController.swift
git commit -m "feat: settings — launch at login row"
```

---

### Task 4: SettingsWindowController — Explanation + Warning + Critical rows

**Files:**
- Modify: `Sources/SettingsWindowController.swift`

- [ ] **Step 1: Replace makeExplanationRow() stub**

```swift
private func makeExplanationRow() -> NSView {
    let container = NSView()
    container.translatesAutoresizingMaskIntoConstraints = false

    let text = lbl(
        "Menubar text shifts color when session or weekly usage crosses a threshold. Each row is evaluated independently.",
        size: 11, color: textMuted
    )
    text.maximumNumberOfLines = 0
    container.addSubview(text)

    NSLayoutConstraint.activate([
        text.topAnchor.constraint(equalTo: container.topAnchor, constant: 10),
        text.leadingAnchor.constraint(equalTo: container.leadingAnchor),
        text.trailingAnchor.constraint(equalTo: container.trailingAnchor),
        text.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -10),
    ])

    return container
}
```

- [ ] **Step 2: Replace makeThresholdRow(isWarning:) stub**

```swift
private func makeThresholdRow(isWarning: Bool) -> NSView {
    let container = NSView()
    container.translatesAutoresizingMaskIntoConstraints = false

    let labelText   = isWarning ? "Warning"  : "Critical"
    let subText     = isWarning ? "orange above this %" : "red above this %"
    let pctKey      = isWarning ? "warningThreshold"    : "criticalThreshold"
    let colorKey    = isWarning ? "warningColor"        : "criticalColor"
    let presets     = isWarning ? warningPresets        : criticalPresets
    let pctColor    = isWarning ? NSColor(hex: "#C97A58")! : NSColor(hex: "#f87171")!

    let title       = lbl(labelText, size: 13, color: textPri)
    let subtitle    = lbl(subText,   size: 11, color: textSec)
    let pctField    = makePctField(key: pctKey, color: pctColor)
    if isWarning { warningPctField = pctField } else { criticalPctField = pctField }

    let selectedHex = (UserDefaults.standard.string(forKey: colorKey) ?? presets[0]).lowercased()

    let swatchRow = NSStackView()
    swatchRow.orientation = .horizontal
    swatchRow.spacing = 6
    swatchRow.alignment = .centerY
    swatchRow.translatesAutoresizingMaskIntoConstraints = false

    var buttons: [NSButton] = []
    for (i, hex) in presets.enumerated() {
        let btn = makeSwatchBtn(hex: hex, isSelected: hex.lowercased() == selectedHex)
        btn.tag = i
        btn.target = self
        btn.action = isWarning ? #selector(warnSwatchTapped(_:)) : #selector(critSwatchTapped(_:))
        swatchRow.addArrangedSubview(btn)
        buttons.append(btn)
    }
    if isWarning { warningSwatches = buttons } else { criticalSwatches = buttons }

    let customBtn = NSButton(
        title: "custom", target: self,
        action: isWarning ? #selector(openWarningPicker) : #selector(openCriticalPicker)
    )
    customBtn.isBordered = false
    customBtn.wantsLayer = true
    customBtn.layer!.borderWidth = 1
    customBtn.layer!.borderColor = NSColor(hex: "#3f3f46")!.cgColor
    customBtn.layer!.cornerRadius = 4
    customBtn.font = .systemFont(ofSize: 10)
    customBtn.contentTintColor = textMuted
    swatchRow.addArrangedSubview(customBtn)

    [title, subtitle, pctField, swatchRow].forEach { container.addSubview($0) }

    NSLayoutConstraint.activate([
        title.topAnchor.constraint(equalTo: container.topAnchor, constant: 14),
        title.leadingAnchor.constraint(equalTo: container.leadingAnchor),

        subtitle.topAnchor.constraint(equalTo: title.bottomAnchor, constant: 2),
        subtitle.leadingAnchor.constraint(equalTo: container.leadingAnchor),

        pctField.trailingAnchor.constraint(equalTo: container.trailingAnchor),
        pctField.topAnchor.constraint(equalTo: container.topAnchor, constant: 14),
        pctField.widthAnchor.constraint(equalToConstant: 52),
        pctField.heightAnchor.constraint(equalToConstant: 30),

        swatchRow.topAnchor.constraint(equalTo: subtitle.bottomAnchor, constant: 10),
        swatchRow.leadingAnchor.constraint(equalTo: container.leadingAnchor),
        swatchRow.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -14),
    ])

    return container
}
```

- [ ] **Step 3: Add swatch action handlers**

Add these methods to `SettingsWindowController` (before the closing `}`):

```swift
// MARK: - Swatch actions

@objc private func warnSwatchTapped(_ sender: NSButton) {
    applySwatchSelection(index: sender.tag, swatches: warningSwatches,
                         presets: warningPresets, colorKey: "warningColor")
}

@objc private func critSwatchTapped(_ sender: NSButton) {
    applySwatchSelection(index: sender.tag, swatches: criticalSwatches,
                         presets: criticalPresets, colorKey: "criticalColor")
}

private func applySwatchSelection(index: Int, swatches: [NSButton],
                                   presets: [String], colorKey: String) {
    for (i, btn) in swatches.enumerated() {
        btn.layer!.borderWidth = (i == index) ? 2 : 0
        btn.layer!.borderColor = (i == index) ? textPri.cgColor : NSColor.clear.cgColor
    }
    UserDefaults.standard.set(presets[index], forKey: colorKey)
}

// Placeholder — wired in Task 7
@objc private func openWarningPicker() {}
@objc private func openCriticalPicker() {}
```

- [ ] **Step 4: Build + verify**

```bash
bash build.sh && open ClaudeBar.app
```

Settings window should now show all 5 rows. Verify:
- Explanation text wraps correctly
- Warning row: "75" in orange field, 4 swatches, "custom" button
- Critical row: "90" in red field, 4 different swatches
- Clicking a swatch adds white outline to it and removes from others
- Editing % field to `80` and pressing Tab → `defaults read net.claudebar warningThreshold` shows `0.8`
- Editing % field to `abc` → field border turns red

- [ ] **Step 5: Commit**

```bash
git add Sources/SettingsWindowController.swift
git commit -m "feat: settings — explanation, warning, critical threshold rows"
```

---

### Task 5: SettingsWindowController — About row

**Files:**
- Modify: `Sources/SettingsWindowController.swift`

- [ ] **Step 1: Replace makeAboutRow() stub**

```swift
private func makeAboutRow() -> NSView {
    let container = NSView()
    container.translatesAutoresizingMaskIntoConstraints = false

    let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
    let title   = lbl("ClaudeBar", size: 13, color: textPri)
    let sub     = lbl("v\(version)", size: 11, color: textMuted)

    let githubBtn = NSButton(title: "", target: self, action: #selector(openGitHub))
    githubBtn.isBordered = false
    githubBtn.image = makeGitHubIcon()
    githubBtn.translatesAutoresizingMaskIntoConstraints = false

    [title, sub, githubBtn].forEach { container.addSubview($0) }

    NSLayoutConstraint.activate([
        title.topAnchor.constraint(equalTo: container.topAnchor, constant: 14),
        title.leadingAnchor.constraint(equalTo: container.leadingAnchor),

        sub.topAnchor.constraint(equalTo: title.bottomAnchor, constant: 2),
        sub.leadingAnchor.constraint(equalTo: container.leadingAnchor),
        sub.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -14),

        githubBtn.trailingAnchor.constraint(equalTo: container.trailingAnchor),
        githubBtn.centerYAnchor.constraint(equalTo: container.centerYAnchor),
        githubBtn.widthAnchor.constraint(equalToConstant: 22),
        githubBtn.heightAnchor.constraint(equalToConstant: 22),
    ])

    return container
}

private func makeGitHubIcon() -> NSImage {
    // GitHub mark rendered as CGPath, 16×16 viewBox scaled to 18×18, y-flipped for NSImage
    NSImage(size: NSSize(width: 18, height: 18), flipped: false) { _ in
        guard let ctx = NSGraphicsContext.current?.cgContext else { return false }
        textMuted.setFill()
        ctx.saveGState()
        ctx.translateBy(x: 0, y: 18)
        ctx.scaleBy(x: 18.0/16.0, y: -18.0/16.0)
        let p = CGMutablePath()
        p.move(to: .init(x: 8, y: 0))
        p.addCurve(to: .init(x: 0, y: 8),
                   control1: .init(x: 3.58, y: 0), control2: .init(x: 0, y: 3.58))
        p.addCurve(to: .init(x: 5.47, y: 15.59),
                   control1: .init(x: 0, y: 11.54), control2: .init(x: 2.29, y: 14.53))
        p.addCurve(to: .init(x: 5.46, y: 13.21),
                   control1: .init(x: 5.87, y: 15.66), control2: .init(x: 6.02, y: 15.42))
        p.addCurve(to: .init(x: 2.77, y: 12.27),
                   control1: .init(x: 3.45, y: 13.58), control2: .init(x: 2.93, y: 12.76))
        p.addCurve(to: .init(x: 1.95, y: 10.61),
                   control1: .init(x: 2.68, y: 12.04), control2: .init(x: 2.29, y: 11.33))
        p.addCurve(to: .init(x: 3.18, y: 11.43),
                   control1: .init(x: 1.67, y: 10.99), control2: .init(x: 2.58, y: 10.6))
        p.addCurve(to: .init(x: 5.19, y: 11.02),
                   control1: .init(x: 3.97, y: 12.09), control2: .init(x: 4.96, y: 12.09))
        p.addCurve(to: .init(x: 1.55, y: 7.07),
                   control1: .init(x: 5.17, y: 11.61), control2: .init(x: 1.55, y: 10.13))
        p.addCurve(to: .init(x: 2.37, y: 4.92),
                   control1: .init(x: 1.55, y: 6.2), control2: .init(x: 1.86, y: 5.48))
        p.addCurve(to: .init(x: 2.45, y: 2.8),
                   control1: .init(x: 2.29, y: 4.72), control2: .init(x: 2.01, y: 3.9))
        p.addCurve(to: .init(x: 4.65, y: 3.62),
                   control1: .init(x: 2.45, y: 2.8), control2: .init(x: 3.12, y: 2.59))
        p.addCurve(to: .init(x: 8, y: 3.35),
                   control1: .init(x: 5.29, y: 3.44), control2: .init(x: 6.61, y: 3.35))
        p.addCurve(to: .init(x: 11.35, y: 3.62),
                   control1: .init(x: 9.39, y: 3.35), control2: .init(x: 10.71, y: 3.44))
        p.addCurve(to: .init(x: 13.55, y: 2.8),
                   control1: .init(x: 12.88, y: 2.59), control2: .init(x: 13.55, y: 2.8))
        p.addCurve(to: .init(x: 13.63, y: 4.92),
                   control1: .init(x: 13.99, y: 3.9), control2: .init(x: 13.71, y: 4.72))
        p.addCurve(to: .init(x: 14.45, y: 7.07),
                   control1: .init(x: 14.14, y: 5.48), control2: .init(x: 14.45, y: 6.2))
        p.addCurve(to: .init(x: 10.81, y: 11.02),
                   control1: .init(x: 14.45, y: 10.13), control2: .init(x: 12.59, y: 10.82))
        p.addCurve(to: .init(x: 11.35, y: 13.85),
                   control1: .init(x: 11.05, y: 12.09), control2: .init(x: 11.04, y: 12.09))
        p.addLine(to: .init(x: 11.34, y: 14.32))
        p.addCurve(to: .init(x: 10.53, y: 15.59),
                   control1: .init(x: 11.34, y: 15.42), control2: .init(x: 11.19, y: 15.66))
        p.addCurve(to: .init(x: 16, y: 8),
                   control1: .init(x: 13.71, y: 14.53), control2: .init(x: 16, y: 11.54))
        p.addCurve(to: .init(x: 8, y: 0),
                   control1: .init(x: 16, y: 3.58), control2: .init(x: 12.42, y: 0))
        p.closeSubpath()
        ctx.addPath(p)
        ctx.fillPath()
        ctx.restoreGState()
        return true
    }
}

@objc private func openGitHub() {
    NSWorkspace.shared.open(URL(string: "https://github.com/BartekJagniatkowski/claudebar")!)
}
```

- [ ] **Step 2: Build + verify full settings window**

```bash
bash build.sh && open ClaudeBar.app
```

Verify all 5 rows visible. About row shows "ClaudeBar" + version + GitHub icon on right. Clicking icon opens browser to repo.

- [ ] **Step 3: Commit**

```bash
git add Sources/SettingsWindowController.swift
git commit -m "feat: settings — about row with version and GitHub icon"
```

---

### Task 6: ColorPickerWindowController

**Files:**
- Create: `Sources/ColorPickerWindowController.swift`

- [ ] **Step 1: Create the full file**

Create `Sources/ColorPickerWindowController.swift`:

```swift
import AppKit

// MARK: - SpectrumView

class SpectrumView: NSView {
    var hue: CGFloat = 0 { didSet { updateSatLayer() } }
    var onColorChanged: ((CGFloat, CGFloat) -> Void)?  // (saturation, brightness)

    private var sat: CGFloat = 1
    private var bri: CGFloat = 1

    private let satLayer = CAGradientLayer()
    private let briLayer = CAGradientLayer()
    private let crosshair = CALayer()

    override init(frame: NSRect) {
        super.init(frame: frame)
        wantsLayer = true
        layer!.cornerRadius = 6
        layer!.masksToBounds = true

        satLayer.startPoint = CGPoint(x: 0, y: 0.5)
        satLayer.endPoint   = CGPoint(x: 1, y: 0.5)
        updateSatLayer()
        layer!.addSublayer(satLayer)

        // CALayer y=0 is bottom: clear at top (y=1) fades to black at bottom (y=0)
        briLayer.startPoint = CGPoint(x: 0.5, y: 1)
        briLayer.endPoint   = CGPoint(x: 0.5, y: 0)
        briLayer.colors     = [NSColor.clear.cgColor, NSColor.black.cgColor]
        layer!.addSublayer(briLayer)

        crosshair.bounds          = CGRect(x: 0, y: 0, width: 10, height: 10)
        crosshair.cornerRadius    = 5
        crosshair.borderWidth     = 2
        crosshair.borderColor     = NSColor.white.cgColor
        crosshair.backgroundColor = NSColor.clear.cgColor
        crosshair.shadowColor     = NSColor.black.cgColor
        crosshair.shadowOpacity   = 0.5
        crosshair.shadowRadius    = 2
        layer!.addSublayer(crosshair)
    }
    required init?(coder: NSCoder) { fatalError() }

    override func layout() {
        super.layout()
        CATransaction.withoutAnimation {
            satLayer.frame  = bounds
            briLayer.frame  = bounds
            crosshair.position = CGPoint(x: sat * bounds.width, y: bri * bounds.height)
        }
    }

    func setPosition(sat newSat: CGFloat, bri newBri: CGFloat) {
        sat = newSat
        bri = newBri
        needsLayout = true
    }

    private func updateSatLayer() {
        satLayer.colors = [
            NSColor.white.cgColor,
            NSColor(hue: hue, saturation: 1, brightness: 1, alpha: 1).cgColor,
        ]
    }

    override func mouseDown(with event: NSEvent)    { handleDrag(event) }
    override func mouseDragged(with event: NSEvent) { handleDrag(event) }

    private func handleDrag(_ event: NSEvent) {
        let p = convert(event.locationInWindow, from: nil)
        sat = max(0, min(1, p.x / bounds.width))
        bri = max(0, min(1, p.y / bounds.height))
        CATransaction.withoutAnimation {
            crosshair.position = CGPoint(x: sat * bounds.width, y: bri * bounds.height)
        }
        onColorChanged?(sat, bri)
    }
}

// MARK: - HueSliderView

class HueSliderView: NSView {
    var hue: CGFloat = 0 { didSet { if bounds.width > 0 { updateThumb() } } }
    var onHueChanged: ((CGFloat) -> Void)?

    private let track = CAGradientLayer()
    private let thumb = CALayer()

    override init(frame: NSRect) {
        super.init(frame: frame)
        wantsLayer = true

        track.startPoint = CGPoint(x: 0, y: 0.5)
        track.endPoint   = CGPoint(x: 1, y: 0.5)
        track.colors = stride(from: 0, through: 360, by: 30).map {
            NSColor(hue: CGFloat($0) / 360, saturation: 1, brightness: 1, alpha: 1).cgColor
        }
        track.cornerRadius = 6
        layer!.addSublayer(track)

        let ts: CGFloat = 15
        thumb.bounds          = CGRect(x: 0, y: 0, width: ts, height: ts)
        thumb.cornerRadius    = ts / 2
        thumb.backgroundColor = NSColor.white.cgColor
        thumb.borderWidth     = 1.5
        thumb.borderColor     = NSColor(hex: "#27272a")!.cgColor
        thumb.shadowColor     = NSColor.black.cgColor
        thumb.shadowOpacity   = 0.4
        thumb.shadowRadius    = 2
        layer!.addSublayer(thumb)
    }
    required init?(coder: NSCoder) { fatalError() }

    override func layout() {
        super.layout()
        CATransaction.withoutAnimation {
            track.frame = bounds
            updateThumb()
        }
    }

    private func updateThumb() {
        thumb.position = CGPoint(x: hue * bounds.width, y: bounds.height / 2)
    }

    override func mouseDown(with event: NSEvent)    { handleDrag(event) }
    override func mouseDragged(with event: NSEvent) { handleDrag(event) }

    private func handleDrag(_ event: NSEvent) {
        let p = convert(event.locationInWindow, from: nil)
        hue = max(0, min(0.9999, p.x / bounds.width))
        CATransaction.withoutAnimation { updateThumb() }
        onHueChanged?(hue)
    }
}

// MARK: - ColorPickerWindowController

class ColorPickerWindowController: NSWindowController, NSWindowDelegate, NSTextFieldDelegate {

    var onColorSelected: ((NSColor) -> Void)?

    private let previousColor: NSColor
    private var currentColor:  NSColor
    private var shouldRevert = false

    private var spectrumView:  SpectrumView!
    private var hueSlider:     HueSliderView!
    private var previewSwatch: NSView!
    private var hexField:      NSTextField!

    private var currentHue: CGFloat = 0
    private var currentSat: CGFloat = 1
    private var currentBri: CGFloat = 1

    init(initialColor: NSColor) {
        previousColor = initialColor
        currentColor  = initialColor

        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 240, height: 220),
            styleMask:   [.titled, .closable, .nonactivatingPanel],
            backing:     .buffered,
            defer:       false
        )
        panel.title           = "Pick Color"
        panel.appearance      = NSAppearance(named: .darkAqua)
        panel.backgroundColor = NSColor(hex: "#09090b")!
        panel.isFloatingPanel = true
        super.init(window: panel)
        panel.delegate = self
        buildUI()
        applyColor(initialColor)
    }
    required init?(coder: NSCoder) { fatalError() }

    // MARK: - UI

    private func buildUI() {
        let content = window!.contentView!
        let pad: CGFloat = 14

        spectrumView = SpectrumView(frame: .zero)
        spectrumView.translatesAutoresizingMaskIntoConstraints = false

        hueSlider = HueSliderView(frame: .zero)
        hueSlider.translatesAutoresizingMaskIntoConstraints = false

        previewSwatch = NSView()
        previewSwatch.wantsLayer = true
        previewSwatch.layer!.cornerRadius = 5
        previewSwatch.layer!.borderWidth  = 1
        previewSwatch.layer!.borderColor  = NSColor(hex: "#27272a")!.cgColor
        previewSwatch.translatesAutoresizingMaskIntoConstraints = false

        hexField = NSTextField()
        hexField.isBezeled       = false
        hexField.drawsBackground = true
        hexField.backgroundColor = NSColor(hex: "#09090b")!
        hexField.textColor       = NSColor(hex: "#fafafa")!
        hexField.font            = .monospacedSystemFont(ofSize: 12, weight: .regular)
        hexField.wantsLayer      = true
        hexField.layer!.cornerRadius = 6
        hexField.layer!.borderWidth  = 1
        hexField.layer!.borderColor  = NSColor(hex: "#27272a")!.cgColor
        hexField.delegate            = self
        hexField.translatesAutoresizingMaskIntoConstraints = false

        content.addSubview(spectrumView)
        content.addSubview(hueSlider)
        content.addSubview(previewSwatch)
        content.addSubview(hexField)

        NSLayoutConstraint.activate([
            spectrumView.topAnchor.constraint(equalTo: content.topAnchor, constant: pad),
            spectrumView.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: pad),
            spectrumView.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -pad),
            spectrumView.heightAnchor.constraint(equalToConstant: 120),

            hueSlider.topAnchor.constraint(equalTo: spectrumView.bottomAnchor, constant: 8),
            hueSlider.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: pad),
            hueSlider.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -pad),
            hueSlider.heightAnchor.constraint(equalToConstant: 12),

            previewSwatch.topAnchor.constraint(equalTo: hueSlider.bottomAnchor, constant: 12),
            previewSwatch.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: pad),
            previewSwatch.widthAnchor.constraint(equalToConstant: 28),
            previewSwatch.heightAnchor.constraint(equalToConstant: 28),
            previewSwatch.bottomAnchor.constraint(lessThanOrEqualTo: content.bottomAnchor, constant: -pad),

            hexField.centerYAnchor.constraint(equalTo: previewSwatch.centerYAnchor),
            hexField.leadingAnchor.constraint(equalTo: previewSwatch.trailingAnchor, constant: 8),
            hexField.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -pad),
            hexField.heightAnchor.constraint(equalToConstant: 28),
        ])

        spectrumView.onColorChanged = { [weak self] sat, bri in
            guard let self else { return }
            currentSat = sat
            currentBri = bri
            refreshColor()
        }
        hueSlider.onHueChanged = { [weak self] hue in
            guard let self else { return }
            currentHue = hue
            spectrumView.hue = hue
            refreshColor()
        }
    }

    // MARK: - Color sync

    private func applyColor(_ color: NSColor) {
        guard let rgb = color.usingColorSpace(.deviceRGB) else { return }
        var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        rgb.getHue(&h, saturation: &s, brightness: &b, alpha: &a)
        currentHue = h
        currentSat = s
        currentBri = b
        spectrumView.hue = h
        spectrumView.setPosition(sat: s, bri: b)
        hueSlider.hue = h
        syncUI(color: rgb)
    }

    private func refreshColor() {
        let color = NSColor(hue: currentHue, saturation: currentSat, brightness: currentBri, alpha: 1)
        currentColor = color
        syncUI(color: color)
    }

    private func syncUI(color: NSColor) {
        CATransaction.withoutAnimation {
            previewSwatch.layer!.backgroundColor = color.cgColor
        }
        hexField.stringValue = color.hexString
    }

    // MARK: - NSTextFieldDelegate

    func controlTextDidEndEditing(_ obj: Notification) {
        let raw = hexField.stringValue.trimmingCharacters(in: .whitespaces)
        if let color = NSColor(hex: raw) {
            hexField.layer!.borderColor = NSColor(hex: "#27272a")!.cgColor
            currentColor = color
            applyColor(color)
        } else {
            hexField.layer!.borderColor = NSColor.systemRed.cgColor
        }
    }

    // MARK: - Window lifecycle

    // Escape: revert to previous color
    override func cancelOperation(_ sender: Any?) {
        shouldRevert = true
        window?.close()
    }

    // Close (traffic light or programmatic): commit current color (or previous if reverted)
    func windowWillClose(_ notification: Notification) {
        onColorSelected?(shouldRevert ? previousColor : currentColor)
    }
}
```

- [ ] **Step 2: Build — must compile cleanly**

```bash
bash build.sh
```

Expected: `✓ Built` with no errors.

- [ ] **Step 3: Commit**

```bash
git add Sources/ColorPickerWindowController.swift
git commit -m "feat: add ColorPickerWindowController with spectrum, hue slider, hex input"
```

---

### Task 7: Wire color picker into SettingsWindowController

**Files:**
- Modify: `Sources/SettingsWindowController.swift`

- [ ] **Step 1: Replace placeholder picker actions**

Find and replace these two methods in `SettingsWindowController`:

```swift
// REMOVE these two stubs:
@objc private func openWarningPicker() {}
@objc private func openCriticalPicker() {}
```

Replace with:

```swift
@objc private func openWarningPicker() {
    openPicker(colorKey: "warningColor", swatches: warningSwatches)
}

@objc private func openCriticalPicker() {
    openPicker(colorKey: "criticalColor", swatches: criticalSwatches)
}

private func openPicker(colorKey: String, swatches: [NSButton]) {
    let currentHex = UserDefaults.standard.string(forKey: colorKey) ?? "#C97A58"
    let initial = NSColor(hex: currentHex) ?? NSColor(hex: "#C97A58")!

    let picker = ColorPickerWindowController(initialColor: initial)
    picker.onColorSelected = { [weak self] color in
        guard let self else { return }
        UserDefaults.standard.set(color.hexString, forKey: colorKey)
        // Deselect all preset swatches since a custom color is now active
        for btn in swatches {
            btn.layer!.borderWidth = 0
            btn.layer!.borderColor = NSColor.clear.cgColor
        }
        self.colorPickerController = nil
    }
    colorPickerController = picker
    picker.window?.center()
    picker.showWindow(nil)
}
```

- [ ] **Step 2: Build + verify end-to-end**

```bash
bash build.sh && open ClaudeBar.app
```

Full test checklist:
1. Open Settings (click menubar → Settings…, or ⌘, while app active)
2. Click "custom" on Warning row → color picker opens with dark `#09090b` background
3. Drag hue slider → spectrum gradient shifts color in real time
4. Click/drag in spectrum → crosshair moves; hex field + preview swatch update
5. Type valid hex `#FF0000` in field, press Tab → spectrum + hue slider update to red
6. Type invalid `#ZZZ` → field border turns red; spectrum unchanged
7. Close picker with ✕ → no error; run `defaults read net.claudebar warningColor` → shows picked hex
8. Open picker again → initial color is the last-saved value
9. Change to a different color, press Escape → picker closes; `defaults read net.claudebar warningColor` is back to previous value
10. After picking a color, all 4 preset swatches should show no white outline
11. Click a preset swatch → it gets white outline and `warningColor` updates to that preset hex

- [ ] **Step 3: Commit**

```bash
git add Sources/SettingsWindowController.swift
git commit -m "feat: wire custom color picker into settings window"
```

---

### Task 8: CHANGELOG + release v1.2.0

**Files:**
- Modify: `CHANGELOG.md`

- [ ] **Step 1: Update CHANGELOG.md**

Prepend a new section at the top of `CHANGELOG.md` (below the `# Changelog` heading):

```markdown
## [1.2.0] — 2026-06-02

- Settings window (⌘,): Launch at Login toggle, warning/critical threshold %, color preset swatches, custom color picker
- Custom color picker panel: spectrum gradient, hue slider, hex input field — styled to match settings window (#09090b background)
- Removed "Launch at Login" menu item (moved to Settings window)
- Renamed "Quit claudebar" to "Quit ClaudeBar"
- Build now compiles all Sources/*.swift
```

- [ ] **Step 2: Final build + install + full smoke test**

```bash
bash build.sh
cp -r ClaudeBar.app /Applications/
xattr -cr /Applications/ClaudeBar.app
open /Applications/ClaudeBar.app
```

Smoke test:
- [ ] Menubar shows 2-row % + time display
- [ ] Clicking menubar: "Settings…" + separator + "Quit ClaudeBar" (not "Quit claudebar")
- [ ] Settings window (⌘,): dark `#09090b` bg, 320pt wide, all 5 rows visible
- [ ] Launch at Login toggle reflects real state; clicking toggles it
- [ ] Threshold % fields show current defaults (75, 90); editing + Tab updates UserDefaults
- [ ] Swatch click: selected swatch gets white outline, others clear
- [ ] "custom" button opens color picker in matching dark style
- [ ] Color picker: hue slider drag updates spectrum; spectrum drag updates hex
- [ ] Hex input: valid hex updates preview; invalid → red border
- [ ] Picker close (✕): color committed to UserDefaults
- [ ] Picker Escape: color reverts to previous value
- [ ] About row: "ClaudeBar" + "v1.2.0" + GitHub icon → opens browser
- [ ] Menubar respects updated colors on next 60s poll

- [ ] **Step 3: Release**

```bash
./release.sh 1.2.0
```

Expected: CHANGELOG check passes, `build.sh` version bumped, commit + tag pushed, CI publishes GitHub release `v1.2.0`.
