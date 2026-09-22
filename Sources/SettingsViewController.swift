import AppKit
import ServiceManagement

// Design tokens — shared with ColorPickerWindowController so both surfaces match
let border    = NSColor(hex: "#27272a")!
let textPri   = NSColor(hex: "#fafafa")!
let textSec   = NSColor(hex: "#71717a")!
let textMuted = NSColor(hex: "#52525b")!
let cardFill  = NSColor.white.withAlphaComponent(0.05)
let cardEdge  = NSColor.white.withAlphaComponent(0.06)
let trackFill = NSColor.white.withAlphaComponent(0.1)

private let popoverWidth: CGFloat = 300

struct UsageSnapshot {
    var sessionPct: Int = 0
    var sessionReset: String = "…"
    var weeklyPct: Int = 0
    var weeklyReset: String = "…"
}

class SettingsViewController: NSViewController {

    private let usage: UsageSnapshot
    private let presentColorPicker: (NSColor, @escaping (NSColor) -> Void) -> Void

    private var loginToggle: ToggleButton!
    private var warningCustomBtn: NSButton!
    private var criticalCustomBtn: NSButton!
    private var warningSwatches: [NSButton] = []
    private var criticalSwatches: [NSButton] = []
    private var warningSlider: PillSlider!
    private var criticalSlider: PillSlider!
    private var warningValueLabel: NSTextField!
    private var criticalValueLabel: NSTextField!

    private let warningPresets  = ["#C97A58", "#e8a87c", "#eab308", "#38bdf8"]
    private let criticalPresets = ["#ef4444", "#f87171", "#f97316", "#a855f7"]

    init(usage: UsageSnapshot, presentColorPicker: @escaping (NSColor, @escaping (NSColor) -> Void) -> Void) {
        self.usage = usage
        self.presentColorPicker = presentColorPicker
        super.init(nibName: nil, bundle: nil)
    }
    required init?(coder: NSCoder) { fatalError() }

    override func loadView() {
        view = NSView(frame: NSRect(x: 0, y: 0, width: popoverWidth, height: 1))
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        buildUI()
    }

    // MARK: - Build UI

    private func buildUI() {
        let content = view

        let stack = NSStackView()
        stack.orientation = .vertical
        stack.spacing = 14
        stack.alignment = .width
        stack.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 18),
            stack.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -18),
            stack.topAnchor.constraint(equalTo: content.topAnchor, constant: 18),
            stack.bottomAnchor.constraint(equalTo: content.bottomAnchor, constant: -18),
        ])

        let usageCard = makeUsageCard()
        stack.addArrangedSubview(makeHeaderRow())
        stack.addArrangedSubview(usageCard)
        stack.addArrangedSubview(makeThresholdsSection())
        stack.setCustomSpacing(22, after: usageCard) // 8px lower than the default 14pt gap
        stack.addArrangedSubview(makeDivider())
        stack.addArrangedSubview(makeLoginRow())
        stack.addArrangedSubview(makeDivider())
        let quitRow = makeQuitRow()
        stack.addArrangedSubview(quitRow)
        quitRow.leadingAnchor.constraint(equalTo: stack.leadingAnchor).isActive = true
        quitRow.trailingAnchor.constraint(equalTo: stack.trailingAnchor).isActive = true

        content.layoutSubtreeIfNeeded()
        let h = stack.fittingSize.height + 36
        preferredContentSize = NSSize(width: popoverWidth, height: h)
    }

    // MARK: - Header

    private func makeHeaderRow() -> NSView {
        let container = NSView()
        container.translatesAutoresizingMaskIntoConstraints = false

        let icon = makeAppIcon()
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
        let title = lbl("ClaudeBar", size: 15, color: textPri)
        let sub   = lbl("v\(version)", size: 11, color: textMuted)
        let titleStack = NSStackView(views: [title, sub])
        titleStack.orientation = .vertical
        titleStack.spacing = 2
        titleStack.alignment = .leading
        titleStack.translatesAutoresizingMaskIntoConstraints = false

        let githubBtn = NSButton(image: makeGitHubIcon(), target: self, action: #selector(openGitHub))
        githubBtn.isBordered = false
        githubBtn.focusRingType = .none
        githubBtn.translatesAutoresizingMaskIntoConstraints = false

        [icon, titleStack, githubBtn].forEach { container.addSubview($0) }

        NSLayoutConstraint.activate([
            icon.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            icon.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            icon.widthAnchor.constraint(equalToConstant: 34),
            icon.heightAnchor.constraint(equalToConstant: 34),

            titleStack.leadingAnchor.constraint(equalTo: icon.trailingAnchor, constant: 10),
            titleStack.centerYAnchor.constraint(equalTo: container.centerYAnchor),

            githubBtn.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            githubBtn.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            githubBtn.widthAnchor.constraint(equalToConstant: 26),
            githubBtn.heightAnchor.constraint(equalToConstant: 26),

            container.heightAnchor.constraint(equalToConstant: 34),
        ])

        return container
    }

    private func makeAppIcon() -> NSView {
        let v = NSView(frame: NSRect(x: 0, y: 0, width: 34, height: 34))
        v.wantsLayer = true
        v.layer!.cornerRadius = 10
        let grad = CAGradientLayer()
        grad.colors = [NSColor(hex: "#D98A68")!.cgColor, NSColor(hex: "#B4643F")!.cgColor]
        grad.startPoint = CGPoint(x: 0, y: 1)
        grad.endPoint = CGPoint(x: 1, y: 0)
        grad.frame = v.bounds
        grad.cornerRadius = 10
        v.layer!.addSublayer(grad)

        let label = NSTextField(labelWithString: "C%")
        label.font = .systemFont(ofSize: 12, weight: .heavy)
        label.textColor = NSColor(hex: "#1a1310")!
        label.alignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        v.translatesAutoresizingMaskIntoConstraints = false
        v.addSubview(label)
        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: v.centerXAnchor),
            label.centerYAnchor.constraint(equalTo: v.centerYAnchor),
        ])
        return v
    }

    // MARK: - Usage card

    private func makeUsageCard() -> NSView {
        let card = NSView()
        card.wantsLayer = true
        card.layer!.backgroundColor = cardFill.cgColor
        card.layer!.borderWidth = 1
        card.layer!.borderColor = cardEdge.cgColor
        card.layer!.cornerRadius = 14
        card.translatesAutoresizingMaskIntoConstraints = false

        let (sessionColor, sessionWeight, sessionSize) = zoneStyle(pct: usage.sessionPct)
        let (weeklyColor, weeklyWeight, weeklySize) = zoneStyle(pct: usage.weeklyPct)

        let sessionRow = usageRow(
            symbol: "clock", tint: NSColor(hex: "#D98A68")!, title: "Session",
            subtitle: "resets in \(usage.sessionReset)", value: "\(usage.sessionPct)%",
            valueColor: sessionColor, valueWeight: sessionWeight, valueSize: sessionSize
        )
        let weeklyRow = usageRow(
            symbol: "calendar", tint: NSColor(hex: "#5AC8FA")!, title: "Weekly",
            subtitle: "resets in \(usage.weeklyReset)", value: "\(usage.weeklyPct)%",
            valueColor: weeklyColor, valueWeight: weeklyWeight, valueSize: weeklySize
        )

        let divider = NSView()
        divider.wantsLayer = true
        divider.layer!.backgroundColor = cardEdge.cgColor
        divider.translatesAutoresizingMaskIntoConstraints = false
        divider.heightAnchor.constraint(equalToConstant: 1).isActive = true

        let stack = NSStackView(views: [sessionRow, divider, weeklyRow])
        stack.orientation = .vertical
        stack.spacing = 10
        stack.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 14),
            stack.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -14),
            stack.topAnchor.constraint(equalTo: card.topAnchor, constant: 10),
            stack.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -10),
        ])
        return card
    }

    private func usageRow(
        symbol: String, tint: NSColor, title: String, subtitle: String,
        value: String, valueColor: NSColor, valueWeight: NSFont.Weight, valueSize: CGFloat
    ) -> NSView {
        let container = NSView()
        container.translatesAutoresizingMaskIntoConstraints = false

        let iconBg = NSView()
        iconBg.wantsLayer = true
        iconBg.layer!.backgroundColor = tint.withAlphaComponent(0.22).cgColor
        iconBg.layer!.cornerRadius = 8
        iconBg.translatesAutoresizingMaskIntoConstraints = false

        let iconView = NSImageView()
        iconView.image = NSImage(systemSymbolName: symbol, accessibilityDescription: nil)
        iconView.contentTintColor = tint
        iconView.translatesAutoresizingMaskIntoConstraints = false

        let titleLbl = lbl(title, size: 13, color: textPri)
        let subLbl   = lbl(subtitle, size: 11, color: textSec)
        let textStack = NSStackView(views: [titleLbl, subLbl])
        textStack.orientation = .vertical
        textStack.spacing = 1
        textStack.alignment = .leading
        textStack.translatesAutoresizingMaskIntoConstraints = false

        let valueLbl = NSTextField(labelWithString: value)
        valueLbl.font = .systemFont(ofSize: valueSize, weight: valueWeight)
        valueLbl.textColor = valueColor
        valueLbl.translatesAutoresizingMaskIntoConstraints = false

        [iconBg, iconView, textStack, valueLbl].forEach { container.addSubview($0) }
        NSLayoutConstraint.activate([
            iconBg.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            iconBg.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            iconBg.widthAnchor.constraint(equalToConstant: 28),
            iconBg.heightAnchor.constraint(equalToConstant: 28),

            iconView.centerXAnchor.constraint(equalTo: iconBg.centerXAnchor),
            iconView.centerYAnchor.constraint(equalTo: iconBg.centerYAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 14),
            iconView.heightAnchor.constraint(equalToConstant: 14),

            textStack.leadingAnchor.constraint(equalTo: iconBg.trailingAnchor, constant: 10),
            textStack.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            textStack.trailingAnchor.constraint(lessThanOrEqualTo: valueLbl.leadingAnchor, constant: -8),

            valueLbl.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            valueLbl.centerYAnchor.constraint(equalTo: container.centerYAnchor),

            container.heightAnchor.constraint(equalToConstant: 28),
        ])
        return container
    }

    private func zoneStyle(pct: Int) -> (NSColor, NSFont.Weight, CGFloat) {
        let warn = Int((UserDefaults.standard.double(forKey: "warningThreshold") * 100).rounded())
        let crit = Int((UserDefaults.standard.double(forKey: "criticalThreshold") * 100).rounded())
        if pct >= crit {
            let color = NSColor(hex: UserDefaults.standard.string(forKey: "criticalColor") ?? "") ?? .systemRed
            return (color, .bold, 15)
        }
        if pct >= warn {
            let color = NSColor(hex: UserDefaults.standard.string(forKey: "warningColor") ?? "") ?? NSColor(hex: "#C97A58")!
            return (color, .semibold, 13)
        }
        return (textPri, .regular, 13)
    }

    // MARK: - Thresholds

    private func makeThresholdsSection() -> NSView {
        let container = NSView()
        container.translatesAutoresizingMaskIntoConstraints = false

        let heading = lbl("ALERT THRESHOLDS", size: 11, color: textPri)
        heading.font = .systemFont(ofSize: 11, weight: .bold)

        let warningRow  = makeThresholdRow(isWarning: true)
        let criticalRow = makeThresholdRow(isWarning: false)

        let stack = NSStackView(views: [heading, warningRow, criticalRow])
        stack.orientation = .vertical
        stack.spacing = 12
        stack.alignment = .leading
        stack.setCustomSpacing(20, after: warningRow)
        stack.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            stack.topAnchor.constraint(equalTo: container.topAnchor),
            stack.bottomAnchor.constraint(equalTo: container.bottomAnchor),
        ])
        heading.leadingAnchor.constraint(equalTo: stack.leadingAnchor).isActive = true
        warningRow.leadingAnchor.constraint(equalTo: stack.leadingAnchor).isActive = true
        warningRow.trailingAnchor.constraint(equalTo: stack.trailingAnchor).isActive = true
        criticalRow.leadingAnchor.constraint(equalTo: stack.leadingAnchor).isActive = true
        criticalRow.trailingAnchor.constraint(equalTo: stack.trailingAnchor).isActive = true
        return container
    }

    private func makeThresholdRow(isWarning: Bool) -> NSView {
        let container = NSView()
        container.translatesAutoresizingMaskIntoConstraints = false

        let labelText = isWarning ? "Warning" : "Critical"
        let pctKey    = isWarning ? "warningThreshold" : "criticalThreshold"
        let colorKey  = isWarning ? "warningColor"     : "criticalColor"
        let presets   = isWarning ? warningPresets     : criticalPresets

        let currentPct  = Int((UserDefaults.standard.double(forKey: pctKey) * 100).rounded())
        let selectedHex = (UserDefaults.standard.string(forKey: colorKey) ?? presets[0]).lowercased()
        let isCustomSelected = !presets.map { $0.lowercased() }.contains(selectedHex)
        let sliderColor = NSColor(hex: selectedHex) ?? NSColor(hex: presets[0])!

        let title = lbl(labelText, size: 12, color: textPri)
        title.translatesAutoresizingMaskIntoConstraints = false

        let swatchRow = NSStackView()
        swatchRow.orientation = .horizontal
        swatchRow.spacing = 6
        swatchRow.translatesAutoresizingMaskIntoConstraints = false

        var buttons: [NSButton] = []
        for (i, hex) in presets.enumerated() {
            let btn = makeSwatchBtn(hex: hex, isSelected: !isCustomSelected && hex.lowercased() == selectedHex)
            btn.tag = i
            btn.target = self
            btn.action = isWarning ? #selector(warnSwatchTapped(_:)) : #selector(critSwatchTapped(_:))
            swatchRow.addArrangedSubview(btn)
            buttons.append(btn)
        }
        if isWarning { warningSwatches = buttons } else { criticalSwatches = buttons }

        let customBtn = makeCustomSwatchBtn(isSelected: isCustomSelected, hex: isCustomSelected ? selectedHex : nil)
        customBtn.target = self
        customBtn.action = isWarning ? #selector(openWarningPicker) : #selector(openCriticalPicker)
        if isWarning { warningCustomBtn = customBtn } else { criticalCustomBtn = customBtn }
        swatchRow.addArrangedSubview(customBtn)

        let headerRow = NSView()
        headerRow.translatesAutoresizingMaskIntoConstraints = false
        [title, swatchRow].forEach { headerRow.addSubview($0) }
        NSLayoutConstraint.activate([
            title.leadingAnchor.constraint(equalTo: headerRow.leadingAnchor),
            title.centerYAnchor.constraint(equalTo: headerRow.centerYAnchor),
            swatchRow.trailingAnchor.constraint(equalTo: headerRow.trailingAnchor),
            swatchRow.centerYAnchor.constraint(equalTo: headerRow.centerYAnchor),
            headerRow.heightAnchor.constraint(equalToConstant: 16),
        ])

        let slider = PillSlider()
        slider.value = currentPct
        slider.color = sliderColor
        slider.target = self
        slider.action = isWarning ? #selector(warnSliderChanged(_:)) : #selector(critSliderChanged(_:))
        slider.translatesAutoresizingMaskIntoConstraints = false
        slider.heightAnchor.constraint(equalToConstant: 18).isActive = true
        slider.setContentHuggingPriority(.defaultLow, for: .horizontal)

        let valueLabel = NSTextField(labelWithString: "\(currentPct)%")
        valueLabel.font = .systemFont(ofSize: 11, weight: .bold)
        valueLabel.textColor = sliderColor
        valueLabel.alignment = .center
        valueLabel.translatesAutoresizingMaskIntoConstraints = false
        if isWarning { warningValueLabel = valueLabel } else { criticalValueLabel = valueLabel }

        let valuePill = NSView()
        valuePill.wantsLayer = true
        valuePill.layer!.backgroundColor = trackFill.cgColor
        valuePill.layer!.cornerRadius = 9
        valuePill.translatesAutoresizingMaskIntoConstraints = false
        valuePill.addSubview(valueLabel)
        // Fixed width (not derived from the label's text) so the "N%" text changing during a
        // drag never invalidates this view's size and forces a layout pass mid-gesture — that
        // reflow was what caused the slider track to intermittently render at the wrong width.
        NSLayoutConstraint.activate([
            valueLabel.centerXAnchor.constraint(equalTo: valuePill.centerXAnchor),
            valueLabel.centerYAnchor.constraint(equalTo: valuePill.centerYAnchor),
            valuePill.widthAnchor.constraint(equalToConstant: 40),
            valuePill.heightAnchor.constraint(equalToConstant: 18),
        ])
        valuePill.setContentHuggingPriority(.required, for: .horizontal)
        valuePill.setContentCompressionResistancePriority(.required, for: .horizontal)

        let sliderRow = NSStackView(views: [slider, valuePill])
        sliderRow.orientation = .horizontal
        sliderRow.distribution = .fill
        sliderRow.spacing = 8
        sliderRow.alignment = .centerY
        sliderRow.translatesAutoresizingMaskIntoConstraints = false
        sliderRow.heightAnchor.constraint(equalToConstant: 18).isActive = true
        if isWarning { warningSlider = slider } else { criticalSlider = slider }

        [headerRow, sliderRow].forEach { container.addSubview($0) }
        NSLayoutConstraint.activate([
            headerRow.topAnchor.constraint(equalTo: container.topAnchor),
            headerRow.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            headerRow.trailingAnchor.constraint(equalTo: container.trailingAnchor),

            sliderRow.topAnchor.constraint(equalTo: headerRow.bottomAnchor, constant: 8),
            sliderRow.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            sliderRow.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            sliderRow.bottomAnchor.constraint(equalTo: container.bottomAnchor),
        ])

        return container
    }

    // MARK: - Login row

    private func makeLoginRow() -> NSView {
        let container = NSView()
        container.translatesAutoresizingMaskIntoConstraints = false

        let title = lbl("Launch at Login", size: 13, color: textPri)
        loginToggle = ToggleButton(frame: .zero)
        loginToggle.isOn = isLoginEnabled
        loginToggle.target = self
        loginToggle.action = #selector(didToggleLogin)
        loginToggle.translatesAutoresizingMaskIntoConstraints = false

        [title, loginToggle].forEach { container.addSubview($0) }

        NSLayoutConstraint.activate([
            title.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            title.centerYAnchor.constraint(equalTo: container.centerYAnchor),

            loginToggle.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            loginToggle.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            loginToggle.widthAnchor.constraint(equalToConstant: 38),
            loginToggle.heightAnchor.constraint(equalToConstant: 22),

            container.heightAnchor.constraint(equalToConstant: 22),
        ])

        return container
    }

    // MARK: - Quit row

    private func makeQuitRow() -> NSView {
        let container = HoverHighlightView()
        container.translatesAutoresizingMaskIntoConstraints = false

        let iconView = NSImageView()
        iconView.image = NSImage(systemSymbolName: "power", accessibilityDescription: nil)
        iconView.contentTintColor = .systemRed
        iconView.translatesAutoresizingMaskIntoConstraints = false

        let label = lbl("Quit ClaudeBar", size: 13, color: textPri)

        let shortcutLabel = NSTextField(labelWithString: "⌘Q")
        shortcutLabel.font = .monospacedSystemFont(ofSize: 11, weight: .semibold)
        shortcutLabel.textColor = textSec
        shortcutLabel.translatesAutoresizingMaskIntoConstraints = false

        // A visible chip, not bare dim text, so the shortcut actually reads at a glance.
        let shortcut = NSView()
        shortcut.wantsLayer = true
        shortcut.layer!.backgroundColor = trackFill.cgColor
        shortcut.layer!.cornerRadius = 5
        shortcut.translatesAutoresizingMaskIntoConstraints = false
        shortcut.addSubview(shortcutLabel)
        NSLayoutConstraint.activate([
            shortcutLabel.leadingAnchor.constraint(equalTo: shortcut.leadingAnchor, constant: 6),
            shortcutLabel.trailingAnchor.constraint(equalTo: shortcut.trailingAnchor, constant: -6),
            shortcutLabel.centerYAnchor.constraint(equalTo: shortcut.centerYAnchor),
            shortcut.heightAnchor.constraint(equalToConstant: 18),
        ])

        // Invisible full-row click target so the row acts like one button, with a
        // working ⌘Q key equivalent — the icon/label/shortcut above are just display.
        let btn = NSButton(title: "", target: NSApp, action: #selector(NSApplication.terminate(_:)))
        btn.isBordered = false
        btn.focusRingType = .none
        btn.keyEquivalent = "q"
        btn.keyEquivalentModifierMask = .command
        btn.translatesAutoresizingMaskIntoConstraints = false

        [iconView, label, shortcut, btn].forEach { container.addSubview($0) }
        NSLayoutConstraint.activate([
            iconView.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 8),
            iconView.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 14),
            iconView.heightAnchor.constraint(equalToConstant: 14),

            label.leadingAnchor.constraint(equalTo: iconView.trailingAnchor, constant: 8),
            label.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            label.trailingAnchor.constraint(lessThanOrEqualTo: shortcut.leadingAnchor, constant: -8),

            shortcut.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -8),
            shortcut.centerYAnchor.constraint(equalTo: container.centerYAnchor),

            btn.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            btn.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            btn.topAnchor.constraint(equalTo: container.topAnchor),
            btn.bottomAnchor.constraint(equalTo: container.bottomAnchor),

            container.heightAnchor.constraint(equalToConstant: 30),
        ])
        return container
    }

    // MARK: - GitHub

    private func makeGitHubIcon() -> NSImage {
        // Octicon "mark-github", 16×16 viewBox — loaded as SVG so the path renders
        // correctly instead of a hand-converted (and broken) CGPath reconstruction.
        let svg = """
        <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 16 16"><path fill="\(textMuted.hexString)" d="M8 0C3.58 0 0 3.58 0 8c0 3.54 2.29 6.53 5.47 7.59.4.07.55-.17.55-.38 0-.19-.01-.82-.01-1.49-2.01.37-2.53-.49-2.69-.94-.09-.23-.48-.94-.82-1.13-.28-.15-.68-.52-.01-.53.63-.01 1.08.58 1.23.82.72 1.21 1.87.87 2.33.66.07-.52.28-.87.51-1.07-1.78-.2-3.64-.89-3.64-3.95 0-.87.31-1.59.82-2.15-.08-.2-.36-1.02.08-2.12 0 0 .67-.21 2.2.82.64-.18 1.32-.27 2-.27.68 0 1.36.09 2 .27 1.53-1.04 2.2-.82 2.2-.82.44 1.1.16 1.92.08 2.12.51.56.82 1.27.82 2.15 0 3.07-1.87 3.75-3.65 3.95.29.25.54.73.54 1.48 0 1.07-.01 1.93-.01 2.2 0 .21.15.46.55.38A8.01 8.01 0 0016 8c0-4.42-3.58-8-8-8z"/></svg>
        """
        guard let data = svg.data(using: .utf8), let img = NSImage(data: data) else {
            return NSImage(size: NSSize(width: 16, height: 16))
        }
        img.size = NSSize(width: 16, height: 16)
        return img
    }

    @objc private func openGitHub() {
        guard let url = URL(string: "https://github.com/BartekJagniatkowski/claudebar") else { return }
        NSWorkspace.shared.open(url)
    }

    // MARK: - Swatch actions

    @objc private func warnSwatchTapped(_ sender: NSButton) {
        applySwatchSelection(index: sender.tag, isWarning: true)
    }

    @objc private func critSwatchTapped(_ sender: NSButton) {
        applySwatchSelection(index: sender.tag, isWarning: false)
    }

    private func applySwatchSelection(index: Int, isWarning: Bool) {
        let swatches = isWarning ? warningSwatches : criticalSwatches
        let presets  = isWarning ? warningPresets  : criticalPresets
        let colorKey = isWarning ? "warningColor"  : "criticalColor"

        for (i, btn) in swatches.enumerated() {
            btn.layer!.borderWidth = (i == index) ? 2 : 0
            btn.layer!.borderColor = (i == index) ? textPri.cgColor : NSColor.clear.cgColor
        }
        UserDefaults.standard.set(presets[index], forKey: colorKey)
        resetCustomBtn(isWarning: isWarning)
        applyColor(NSColor(hex: presets[index])!, isWarning: isWarning)
    }

    private func resetCustomBtn(isWarning: Bool) {
        guard let btn = isWarning ? warningCustomBtn : criticalCustomBtn else { return }
        btn.layer!.backgroundColor = NSColor.clear.cgColor
        btn.layer!.borderWidth = 1
        btn.layer!.borderColor = NSColor(hex: "#3f3f46")!.cgColor
        setCustomIcon(btn)
    }

    private func setCustomIcon(_ btn: NSButton) {
        btn.image = makeColorWheelIcon()
        btn.contentTintColor = nil
        btn.imagePosition = .imageOnly
    }

    private func makeColorWheelIcon(size: CGFloat = 14) -> NSImage {
        // The real system glyph (used for Touch Bar color pickers) if it's present —
        // it's the actual glossy rainbow wheel macOS ships, better than anything hand-drawn.
        if let system = NSImage(named: "NSTouchBarColorPickerFill") {
            system.size = NSSize(width: size, height: size)
            return system
        }
        // Fallback: a smooth hand-drawn hue wheel (many thin wedges read as a
        // continuous gradient) with a soft highlight for a bit of gloss.
        return NSImage(size: NSSize(width: size, height: size), flipped: false) { rect in
            let center = CGPoint(x: rect.midX, y: rect.midY)
            let radius = min(rect.width, rect.height) / 2
            let segments = 72
            for i in 0..<segments {
                let start = CGFloat(i) / CGFloat(segments) * 360
                let end = CGFloat(i + 1) / CGFloat(segments) * 360
                let wedge = NSBezierPath()
                wedge.move(to: center)
                wedge.appendArc(withCenter: center, radius: radius, startAngle: start, endAngle: end)
                wedge.close()
                NSColor(hue: CGFloat(i) / CGFloat(segments), saturation: 1, brightness: 1, alpha: 1).setFill()
                wedge.fill()
            }
            let gloss = NSGradient(colors: [
                NSColor.white.withAlphaComponent(0.35),
                NSColor.white.withAlphaComponent(0),
            ])
            gloss?.draw(fromCenter: CGPoint(x: rect.midX - radius * 0.3, y: rect.midY + radius * 0.3), radius: 0,
                        toCenter: CGPoint(x: rect.midX, y: rect.midY), radius: radius)
            return true
        }
    }

    private func applyColor(_ color: NSColor, isWarning: Bool) {
        let slider = isWarning ? warningSlider : criticalSlider
        let label  = isWarning ? warningValueLabel : criticalValueLabel
        slider?.color = color
        label?.textColor = color
    }

    @objc private func warnSliderChanged(_ sender: PillSlider) {
        UserDefaults.standard.set(Double(sender.value) / 100.0, forKey: "warningThreshold")
        warningValueLabel.stringValue = "\(sender.value)%"
    }

    @objc private func critSliderChanged(_ sender: PillSlider) {
        UserDefaults.standard.set(Double(sender.value) / 100.0, forKey: "criticalThreshold")
        criticalValueLabel.stringValue = "\(sender.value)%"
    }

    @objc private func openWarningPicker() {
        openPicker(colorKey: "warningColor", isWarning: true)
    }

    @objc private func openCriticalPicker() {
        openPicker(colorKey: "criticalColor", isWarning: false)
    }

    private func openPicker(colorKey: String, isWarning: Bool) {
        let currentHex = UserDefaults.standard.string(forKey: colorKey) ?? "#C97A58"
        let initial = NSColor(hex: currentHex) ?? NSColor(hex: "#C97A58")!

        presentColorPicker(initial) { [weak self] color in
            UserDefaults.standard.set(color.hexString, forKey: colorKey)
            guard let self else { return }
            let swatches = isWarning ? self.warningSwatches : self.criticalSwatches
            for btn in swatches {
                btn.layer!.borderWidth = 0
                btn.layer!.borderColor = NSColor.clear.cgColor
            }
            let customBtn = isWarning ? self.warningCustomBtn : self.criticalCustomBtn
            if let btn = customBtn {
                btn.layer!.backgroundColor = color.cgColor
                btn.image = nil
                btn.layer!.borderWidth = 2
                btn.layer!.borderColor = textPri.cgColor
            }
            self.applyColor(color, isWarning: isWarning)
        }
    }

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
            } catch {
                loginToggle.isOn = svc.status == .enabled
            }
            return
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

    private func makeSwatchBtn(hex: String, isSelected: Bool) -> NSButton {
        let btn = NSButton()
        btn.title = ""
        btn.isBordered = false
        btn.focusRingType = .none
        btn.wantsLayer = true
        btn.layer!.cornerRadius = 8
        btn.layer!.backgroundColor = NSColor(hex: hex)?.cgColor ?? NSColor.gray.cgColor
        if isSelected {
            btn.layer!.borderWidth = 2
            btn.layer!.borderColor = textPri.cgColor
        }
        btn.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            btn.widthAnchor.constraint(equalToConstant: 16),
            btn.heightAnchor.constraint(equalToConstant: 16),
        ])
        return btn
    }

    private func makeCustomSwatchBtn(isSelected: Bool, hex: String?) -> NSButton {
        let btn = NSButton()
        btn.title = ""
        btn.isBordered = false
        btn.focusRingType = .none
        btn.wantsLayer = true
        btn.layer!.cornerRadius = 8
        btn.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            btn.widthAnchor.constraint(equalToConstant: 16),
            btn.heightAnchor.constraint(equalToConstant: 16),
        ])
        if isSelected, let hex, let color = NSColor(hex: hex) {
            btn.layer!.backgroundColor = color.cgColor
            btn.layer!.borderWidth = 2
            btn.layer!.borderColor = textPri.cgColor
        } else {
            btn.layer!.backgroundColor = NSColor.clear.cgColor
            btn.layer!.borderWidth = 1
            btn.layer!.borderColor = NSColor(hex: "#3f3f46")!.cgColor
            setCustomIcon(btn)
        }
        return btn
    }

}

// MARK: - HoverHighlightView

// Tints its layer with the system accent color on mouse-hover. Purely visual — the
// row it wraps keeps its own click target and key equivalent underneath.
final class HoverHighlightView: NSView {
    private var trackingArea: NSTrackingArea?
    private let highlightLayer = CALayer()

    override init(frame: NSRect) {
        super.init(frame: frame)
        wantsLayer = true
        highlightLayer.backgroundColor = NSColor.clear.cgColor
        highlightLayer.cornerRadius = 8
        layer?.addSublayer(highlightLayer)
    }
    required init?(coder: NSCoder) { fatalError() }

    override func layout() {
        super.layout()
        highlightLayer.frame = bounds // fills the row; the row's content is what's padded, not this box
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let trackingArea { removeTrackingArea(trackingArea) }
        let area = NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
            owner: self, userInfo: nil
        )
        addTrackingArea(area)
        trackingArea = area
    }

    override func mouseEntered(with event: NSEvent) {
        highlightLayer.backgroundColor = NSColor.controlAccentColor.withAlphaComponent(0.2).cgColor
    }

    override func mouseExited(with event: NSEvent) {
        highlightLayer.backgroundColor = NSColor.clear.cgColor
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
        focusRingType = .none
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

// MARK: - PillSlider

final class PillSlider: NSControl {
    var value: Int = 50 { didSet { needsDisplay = true } }
    var color: NSColor = .systemOrange { didSet { needsDisplay = true } }

    override class var cellClass: AnyClass? {
        get { nil } set { }
    }

    override init(frame: NSRect) {
        super.init(frame: frame)
        focusRingType = .none
    }
    required init?(coder: NSCoder) { fatalError() }

    override var intrinsicContentSize: NSSize { NSSize(width: NSView.noIntrinsicMetric, height: 18) }

    override func draw(_ dirtyRect: NSRect) {
        let h: CGFloat = 18
        let r = NSRect(x: 0, y: (bounds.height - h) / 2, width: bounds.width, height: h)
        let track = NSBezierPath(roundedRect: r, xRadius: h / 2, yRadius: h / 2)
        NSColor.white.withAlphaComponent(0.1).setFill()
        track.fill()

        let fillW = max(h, r.width * CGFloat(value) / 100)
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }
        ctx.saveGState()
        track.addClip()
        color.setFill()
        NSRect(x: r.minX, y: r.minY, width: fillW, height: h).fill()
        ctx.restoreGState()

        let thumbD: CGFloat = 16
        let tx = min(max(r.minX + fillW - thumbD / 2, r.minX), r.maxX - thumbD)
        let tr = NSRect(x: tx, y: r.minY + (h - thumbD) / 2, width: thumbD, height: thumbD)
        NSColor.white.setFill()
        NSBezierPath(ovalIn: tr).fill()
    }

    override func mouseDown(with event: NSEvent) { updateValue(with: event) }
    override func mouseDragged(with event: NSEvent) { updateValue(with: event) }

    private func updateValue(with event: NSEvent) {
        guard bounds.width > 0 else { return }
        let p = convert(event.locationInWindow, from: nil)
        let clamped = max(0, min(1, p.x / bounds.width))
        value = Int((clamped * 100).rounded())
        sendAction(action, to: target)
    }
}
