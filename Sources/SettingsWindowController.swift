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
    private func makeExplanationRow() -> NSView { NSView() }
    private func makeThresholdRow(isWarning: Bool) -> NSView { NSView() }
    private func makeAboutRow() -> NSView { NSView() }

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
