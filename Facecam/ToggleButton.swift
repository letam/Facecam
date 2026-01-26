import AppKit

class DraggableButtonView: NSView {
    var onToggle: (() -> Void)?
    var onDrag: ((NSPoint) -> Void)?
    var onRestorePreset: ((Int) -> Void)?

    private var isDragging = false
    private var dragStartLocation: NSPoint = .zero
    private var isHovered = false

    override init(frame: NSRect) {
        super.init(frame: frame)
        setupTrackingArea()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupTrackingArea()
    }

    private func setupTrackingArea() {
        let trackingArea = NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(trackingArea)
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        let fillOpacity: CGFloat = isHovered ? 0.4 : 0.15
        let strokeOpacity: CGFloat = isHovered ? 0.5 : 0.2
        let iconOpacity: CGFloat = isHovered ? 1.0 : 0.5

        // Draw circle background
        let circlePath = NSBezierPath(ovalIn: bounds.insetBy(dx: 1, dy: 1))
        NSColor.black.withAlphaComponent(fillOpacity).setFill()
        circlePath.fill()

        NSColor.white.withAlphaComponent(strokeOpacity).setStroke()
        circlePath.lineWidth = 1
        circlePath.stroke()

        // Draw camera icon
        let iconSize: CGFloat = 18
        let iconRect = NSRect(
            x: (bounds.width - iconSize) / 2,
            y: (bounds.height - iconSize) / 2,
            width: iconSize,
            height: iconSize
        )

        if let image = NSImage(systemSymbolName: "camera.fill", accessibilityDescription: nil) {
            let config = NSImage.SymbolConfiguration(pointSize: iconSize, weight: .medium)
            let configuredImage = image.withSymbolConfiguration(config)
            configuredImage?.draw(in: iconRect, from: .zero, operation: .sourceOver, fraction: iconOpacity)
        }
    }

    override func mouseEntered(with event: NSEvent) {
        isHovered = true
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.15
            self.animator().frame = self.frame.insetBy(dx: -2, dy: -2)
        }
        needsDisplay = true
    }

    override func mouseExited(with event: NSEvent) {
        isHovered = false
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.15
            self.animator().frame = self.frame.insetBy(dx: 2, dy: 2)
        }
        needsDisplay = true
    }

    override func mouseDown(with event: NSEvent) {
        isDragging = false
        dragStartLocation = event.locationInWindow
    }

    override func mouseDragged(with event: NSEvent) {
        isDragging = true
        guard let window = window else { return }

        let currentLocation = event.locationInWindow
        let delta = NSPoint(
            x: currentLocation.x - dragStartLocation.x,
            y: currentLocation.y - dragStartLocation.y
        )

        let newOrigin = NSPoint(
            x: window.frame.origin.x + delta.x,
            y: window.frame.origin.y + delta.y
        )

        window.setFrameOrigin(newOrigin)
    }

    override func mouseUp(with event: NSEvent) {
        if !isDragging {
            onToggle?()
        } else {
            onDrag?(window?.frame.origin ?? .zero)
        }
        isDragging = false
    }

    override func rightMouseDown(with event: NSEvent) {
        let menu = NSMenu()

        let showItem = NSMenuItem(
            title: "Show Camera",
            action: #selector(showCameraClicked),
            keyEquivalent: ""
        )
        showItem.target = self
        menu.addItem(showItem)

        // Restore preset submenu
        let savedSlots = WindowStateManager.shared.savedSlots()
        if !savedSlots.isEmpty {
            let restorePresetMenu = NSMenu()
            for slot in savedSlots {
                let item = NSMenuItem(
                    title: "Slot \(slot)",
                    action: #selector(restorePresetClicked(_:)),
                    keyEquivalent: ""
                )
                item.tag = slot
                item.target = self
                restorePresetMenu.addItem(item)
            }
            let restorePresetItem = NSMenuItem(title: "Restore Position", action: nil, keyEquivalent: "")
            restorePresetItem.submenu = restorePresetMenu
            menu.addItem(restorePresetItem)
        }

        menu.addItem(NSMenuItem.separator())

        let quitItem = NSMenuItem(
            title: "Quit Facecam",
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q"
        )
        menu.addItem(quitItem)

        NSMenu.popUpContextMenu(menu, with: event, for: self)
    }

    @objc private func showCameraClicked() {
        onToggle?()
    }

    @objc private func restorePresetClicked(_ sender: NSMenuItem) {
        let slot = sender.tag
        onRestorePreset?(slot)
    }
}

class ToggleButton: NSPanel {
    var onToggle: (() -> Void)? {
        didSet {
            buttonView?.onToggle = onToggle
        }
    }

    var onRestorePreset: ((Int) -> Void)? {
        didSet {
            buttonView?.onRestorePreset = onRestorePreset
        }
    }

    private var buttonView: DraggableButtonView?
    private let buttonSize: CGFloat = 44

    init() {
        let savedPosition = Self.loadSavedPosition()
        let frame = NSRect(
            x: savedPosition?.x ?? 20,
            y: savedPosition?.y ?? 100,
            width: 44,
            height: 44
        )

        super.init(
            contentRect: frame,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        setupWindow()
        setupButton()
    }

    private func setupWindow() {
        level = .floating
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        hasShadow = false
        backgroundColor = .clear
        isOpaque = false
    }

    private func setupButton() {
        let dragView = DraggableButtonView(frame: NSRect(x: 0, y: 0, width: buttonSize, height: buttonSize))
        dragView.onToggle = onToggle
        dragView.onDrag = { [weak self] _ in
            self?.savePosition()
        }

        contentView?.addSubview(dragView)
        buttonView = dragView
    }

    private func savePosition() {
        let position: [String: CGFloat] = [
            "x": frame.origin.x,
            "y": frame.origin.y
        ]
        UserDefaults.standard.set(position, forKey: "ToggleButtonPosition")
    }

    private static func loadSavedPosition() -> NSPoint? {
        guard let dict = UserDefaults.standard.dictionary(forKey: "ToggleButtonPosition"),
              let x = dict["x"] as? CGFloat,
              let y = dict["y"] as? CGFloat else {
            return nil
        }
        return NSPoint(x: x, y: y)
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}
