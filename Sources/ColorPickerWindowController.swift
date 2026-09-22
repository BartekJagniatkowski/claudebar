import AppKit

// MARK: - SpectrumView

class SpectrumView: NSView {
    var hue: CGFloat = 0 { didSet { updateSatLayer() } }
    var onColorChanged: ((CGFloat, CGFloat) -> Void)?  // (saturation, brightness)

    private var sat: CGFloat = 1
    private var bri: CGFloat = 1

    private let satLayer = CAGradientLayer()   // horizontal: white → hue
    private let briLayer = CAGradientLayer()   // vertical: clear(top) → black(bottom)
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

        // In CALayer, y=0 is bottom. clear at top (y=1) fades to black at bottom (y=0)
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
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        satLayer.frame  = bounds
        briLayer.frame  = bounds
        crosshair.position = CGPoint(x: sat * bounds.width, y: bri * bounds.height)
        CATransaction.commit()
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
        guard bounds.width > 0, bounds.height > 0 else { return }
        let p = convert(event.locationInWindow, from: nil)
        sat = max(0, min(1, p.x / bounds.width))
        bri = max(0, min(1, p.y / bounds.height))
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        crosshair.position = CGPoint(x: sat * bounds.width, y: bri * bounds.height)
        CATransaction.commit()
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
        thumb.borderColor     = border.cgColor
        thumb.shadowColor     = NSColor.black.cgColor
        thumb.shadowOpacity   = 0.4
        thumb.shadowRadius    = 2
        layer!.addSublayer(thumb)
    }
    required init?(coder: NSCoder) { fatalError() }

    override func layout() {
        super.layout()
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        track.frame = bounds
        updateThumb()
        CATransaction.commit()
    }

    private func updateThumb() {
        thumb.position = CGPoint(x: hue * bounds.width, y: bounds.height / 2)
    }

    override func mouseDown(with event: NSEvent)    { handleDrag(event) }
    override func mouseDragged(with event: NSEvent) { handleDrag(event) }

    private func handleDrag(_ event: NSEvent) {
        guard bounds.width > 0 else { return }
        let p = convert(event.locationInWindow, from: nil)
        hue = max(0, min(0.9999, p.x / bounds.width))
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        updateThumb()
        CATransaction.commit()
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
    private var hexFieldBg:    NSView!

    private var currentHue: CGFloat = 0
    private var currentSat: CGFloat = 1
    private var currentBri: CGFloat = 1

    init(initialColor: NSColor) {
        previousColor = initialColor
        currentColor  = initialColor

        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 240, height: 220),
            styleMask:   [.borderless, .fullSizeContentView],
            backing:     .buffered,
            defer:       false
        )
        panel.appearance          = NSAppearance(named: .darkAqua)
        panel.isOpaque            = false
        panel.backgroundColor     = .clear
        panel.hasShadow           = true
        panel.isMovableByWindowBackground = true
        panel.isFloatingPanel     = true
        panel.level               = .popUpMenu // above the settings popover's own window
        panel.isReleasedWhenClosed = false
        super.init(window: panel)
        panel.delegate = self
        buildUI()
        applyColor(initialColor)
    }
    required init?(coder: NSCoder) { fatalError() }

    // MARK: - UI

    private func buildUI() {
        // Frosted glass chrome matching the settings popover, since this is a
        // borderless panel — no titled-window vibrancy to inherit for free.
        let effect = NSVisualEffectView()
        effect.material = .hudWindow
        effect.state = .active
        effect.blendingMode = .behindWindow
        effect.wantsLayer = true
        effect.layer!.cornerRadius = 20
        effect.layer!.masksToBounds = true
        effect.layer!.borderWidth = 1
        effect.layer!.borderColor = NSColor.white.withAlphaComponent(0.12).cgColor
        window!.contentView = effect

        let closeBtn = NSButton(
            image: NSImage(systemSymbolName: "xmark.circle.fill", accessibilityDescription: nil) ?? NSImage(),
            target: self, action: #selector(closeTapped)
        )
        closeBtn.isBordered = false
        closeBtn.focusRingType = .none
        closeBtn.contentTintColor = textMuted
        closeBtn.translatesAutoresizingMaskIntoConstraints = false
        effect.addSubview(closeBtn)
        NSLayoutConstraint.activate([
            closeBtn.topAnchor.constraint(equalTo: effect.topAnchor, constant: 10),
            closeBtn.trailingAnchor.constraint(equalTo: effect.trailingAnchor, constant: -10),
            closeBtn.widthAnchor.constraint(equalToConstant: 16),
            closeBtn.heightAnchor.constraint(equalToConstant: 16),
        ])

        let content = effect
        let pad: CGFloat = 14

        spectrumView = SpectrumView(frame: .zero)
        spectrumView.translatesAutoresizingMaskIntoConstraints = false

        hueSlider = HueSliderView(frame: .zero)
        hueSlider.translatesAutoresizingMaskIntoConstraints = false

        previewSwatch = NSView()
        previewSwatch.wantsLayer = true
        previewSwatch.layer!.cornerRadius = 8
        previewSwatch.layer!.borderWidth  = 1
        previewSwatch.layer!.borderColor  = cardEdge.cgColor
        previewSwatch.translatesAutoresizingMaskIntoConstraints = false

        hexFieldBg = NSView()
        hexFieldBg.wantsLayer = true
        hexFieldBg.layer!.cornerRadius = 9
        hexFieldBg.layer!.masksToBounds = true
        hexFieldBg.layer!.backgroundColor = trackFill.cgColor
        hexFieldBg.layer!.borderWidth = 1
        hexFieldBg.layer!.borderColor = cardEdge.cgColor
        hexFieldBg.translatesAutoresizingMaskIntoConstraints = false

        hexField = NSTextField()
        hexField.isBezeled       = false
        hexField.drawsBackground = false
        hexField.textColor       = textPri
        hexField.font            = .monospacedSystemFont(ofSize: 12, weight: .regular)
        hexField.delegate            = self
        hexField.translatesAutoresizingMaskIntoConstraints = false
        // Centered via its own intrinsic height inside a taller background pill,
        // rather than stretched to the pill's height — NSTextField doesn't reliably
        // vertically center its text when its frame is taller than the text itself.
        hexFieldBg.addSubview(hexField)
        NSLayoutConstraint.activate([
            hexField.leadingAnchor.constraint(equalTo: hexFieldBg.leadingAnchor, constant: 10),
            hexField.trailingAnchor.constraint(equalTo: hexFieldBg.trailingAnchor, constant: -10),
            hexField.centerYAnchor.constraint(equalTo: hexFieldBg.centerYAnchor),
        ])

        content.addSubview(spectrumView)
        content.addSubview(hueSlider)
        content.addSubview(previewSwatch)
        content.addSubview(hexFieldBg)

        NSLayoutConstraint.activate([
            spectrumView.topAnchor.constraint(equalTo: content.topAnchor, constant: 30),
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

            hexFieldBg.centerYAnchor.constraint(equalTo: previewSwatch.centerYAnchor),
            hexFieldBg.leadingAnchor.constraint(equalTo: previewSwatch.trailingAnchor, constant: 8),
            hexFieldBg.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -pad),
            hexFieldBg.heightAnchor.constraint(equalToConstant: 28),
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
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        previewSwatch.layer!.backgroundColor = color.cgColor
        CATransaction.commit()
        hexField.stringValue = color.hexString
    }

    // MARK: - NSTextFieldDelegate

    func controlTextDidEndEditing(_ obj: Notification) {
        let raw = hexField.stringValue.trimmingCharacters(in: .whitespaces)
        if let color = NSColor(hex: raw) {
            hexFieldBg.layer!.borderColor = cardEdge.cgColor
            currentColor = color
            applyColor(color)
        } else {
            hexFieldBg.layer!.borderColor = NSColor.systemRed.cgColor
        }
    }

    // MARK: - Window lifecycle

    @objc private func closeTapped() {
        window?.close()
    }

    // Escape: revert to previous color
    override func cancelOperation(_ sender: Any?) {
        shouldRevert = true
        window?.close()
    }

    // Close (traffic light or programmatic): commit current or previous if reverted
    func windowWillClose(_ notification: Notification) {
        onColorSelected?(shouldRevert ? previousColor : currentColor)
    }
}
