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

    private let warningPresets  = ["#C97A58", "#e8a87c", "#eab308", "#38bdf8"]
    private let criticalPresets = ["#ef4444", "#f87171", "#f97316", "#a855f7"]

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
        win.isReleasedWhenClosed = false
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
            pctField.centerYAnchor.constraint(equalTo: title.centerYAnchor),
            pctField.widthAnchor.constraint(equalToConstant: 52),
            pctField.heightAnchor.constraint(equalToConstant: 30),

            swatchRow.topAnchor.constraint(equalTo: subtitle.bottomAnchor, constant: 10),
            swatchRow.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            swatchRow.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -14),
        ])

        return container
    }

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
            githubBtn.centerYAnchor.constraint(equalTo: title.centerYAnchor),
            githubBtn.widthAnchor.constraint(equalToConstant: 22),
            githubBtn.heightAnchor.constraint(equalToConstant: 22),
        ])

        return container
    }

    private func makeGitHubIcon() -> NSImage {
        // GitHub mark rendered via CGPath, 16×16 viewBox scaled to 18×18, y-flipped for NSImage
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
        guard let url = URL(string: "https://github.com/BartekJagniatkowski/claudebar") else { return }
        NSWorkspace.shared.open(url)
    }

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
            let shouldEnable = svc.status != .enabled
            do {
                try shouldEnable ? svc.register() : svc.unregister()
                loginToggle.isOn = shouldEnable
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
            guard let data = try? PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0),
                  (try? data.write(to: url)) != nil else { return }
            launchctl("load", url.path)
            loginToggle.isOn = FileManager.default.fileExists(atPath: url.path)
        }
    }

    private func launchctl(_ verb: String, _ path: String) {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/bin/launchctl")
        p.arguments = [verb, path]
        guard (try? p.run()) != nil else { return }
        p.waitUntilExit()
    }

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
        NSColor.white.setFill()
        NSBezierPath(ovalIn: tr).fill()
    }

    override var intrinsicContentSize: NSSize { NSSize(width: 38, height: 22) }

    override func mouseUp(with event: NSEvent) {
        isOn.toggle()
        sendAction(action, to: target)
    }
}
