import AppKit
import ServiceManagement

private let claudeOrange = NSColor(
    calibratedRed: 0.788, green: 0.478, blue: 0.345, alpha: 1
)

// MARK: - Entry point

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()

// MARK: - App Delegate

class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var timer: Timer?
    private var lastCallDate: Date = .distantPast
    private var backoffUntil: Date = .distantPast

    private let pollInterval: TimeInterval = 60
    private let minCallGap: TimeInterval = 30
    private let backoffDuration: TimeInterval = 300

    func applicationDidFinishLaunching(_ notification: Notification) {
        UserDefaults.standard.register(defaults: [
            "warningThreshold": 0.75,
            "criticalThreshold": 0.90,
            "warningColor": "#C97A58",
            "criticalColor": "systemRed",
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

        let loginItem = NSMenuItem(
            title: "Launch at Login",
            action: #selector(toggleLogin(_:)),
            keyEquivalent: ""
        )
        loginItem.state = loginEnabled ? .on : .off
        menu.addItem(loginItem)

        menu.addItem(.separator())
        menu.addItem(NSMenuItem(
            title: "Quit claudebar",
            action: #selector(NSApp.terminate(_:)),
            keyEquivalent: "q"
        ))

        statusItem.menu = menu
    }

    // MARK: - Login item

    private var loginEnabled: Bool {
        if #available(macOS 13.0, *) {
            return SMAppService.mainApp.status == .enabled
        }
        return FileManager.default.fileExists(atPath: launchAgentURL.path)
    }

    private var launchAgentURL: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/LaunchAgents/net.claudebar.plist")
    }

    @objc private func toggleLogin(_ sender: NSMenuItem) {
        if #available(macOS 13.0, *) {
            let svc = SMAppService.mainApp
            do {
                if svc.status == .enabled {
                    try svc.unregister()
                    sender.state = .off
                } else {
                    try svc.register()
                    sender.state = .on
                }
                return
            } catch {}
        }
        toggleLaunchAgent(sender)
    }

    private func toggleLaunchAgent(_ sender: NSMenuItem) {
        let url = launchAgentURL
        if FileManager.default.fileExists(atPath: url.path) {
            launchctl("unload", url.path)
            try? FileManager.default.removeItem(at: url)
            sender.state = .off
        } else {
            let exe = Bundle.main.executablePath
                ?? "/Applications/claudebar.app/Contents/MacOS/claudebar"
            let plist: [String: Any] = [
                "Label": "net.claudebar",
                "ProgramArguments": [exe],
                "RunAtLoad": true,
                "KeepAlive": false,
            ]
            if let data = try? PropertyListSerialization.data(
                fromPropertyList: plist, format: .xml, options: 0
            ) {
                try? data.write(to: url)
                launchctl("load", url.path)
                sender.state = .on
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
            s.append(NSAttributedString(string: line1,  attributes: rowAttrs(color: color1, size: size1)))
            s.append(NSAttributedString(string: "\n",   attributes: rowAttrs(color: color1, size: size1)))
            s.append(NSAttributedString(string: line2,  attributes: rowAttrs(color: color2, size: size2)))
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
        case 401:
            setDisplay("401", "re-auth")
        case 429:
            backoffUntil = Date().addingTimeInterval(backoffDuration)
            setDisplay("429", "5m wait")
        default:
            setDisplay("C\(code)", "")
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
        if val == "systemRed" { return .systemRed }
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
