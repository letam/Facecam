import AppKit
import SwiftUI

class ToggleButton: NSPanel {
    var onToggle: (() -> Void)?

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
        setupDragging()
    }

    private func setupWindow() {
        level = .floating
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        isMovableByWindowBackground = true
        hasShadow = true
        backgroundColor = .clear
        isOpaque = false
    }

    private func setupButton() {
        let hostingView = NSHostingView(rootView: ToggleButtonView(action: { [weak self] in
            self?.onToggle?()
        }))

        hostingView.frame = contentView?.bounds ?? .zero
        hostingView.autoresizingMask = [.width, .height]

        contentView?.addSubview(hostingView)
    }

    private func setupDragging() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(windowDidMove),
            name: NSWindow.didMoveNotification,
            object: self
        )
    }

    @objc private func windowDidMove(_ notification: Notification) {
        savePosition()
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

    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}

struct ToggleButtonView: View {
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(.ultraThinMaterial)
                    .overlay(
                        Circle()
                            .strokeBorder(Color.white.opacity(0.3), lineWidth: 1)
                    )

                Image(systemName: "camera.fill")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(.white)
            }
        }
        .buttonStyle(.plain)
        .frame(width: 44, height: 44)
        .scaleEffect(isHovered ? 1.1 : 1.0)
        .animation(.easeInOut(duration: 0.15), value: isHovered)
        .onHover { hovering in
            isHovered = hovering
        }
    }
}
