import AppKit
import AVFoundation
import SwiftUI

protocol CameraWindowDelegate: AnyObject {
    func cameraWindowDidChangeShape(_ shape: CameraShape)
    func cameraWindowDidRequestHide()
}

class ResizableContentView: NSView {
    private let resizeEdgeThreshold: CGFloat = 8
    private var resizeDirection: ResizeDirection = .none
    private weak var parentWindow: NSWindow?
    var onDoubleClick: (() -> Void)?

    enum ResizeDirection {
        case none, left, right, top, bottom
        case topLeft, topRight, bottomLeft, bottomRight
    }

    init(frame: NSRect, window: NSWindow) {
        self.parentWindow = window
        super.init(frame: frame)
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        trackingAreas.forEach { removeTrackingArea($0) }
        let options: NSTrackingArea.Options = [.mouseMoved, .activeAlways, .inVisibleRect]
        addTrackingArea(NSTrackingArea(rect: bounds, options: options, owner: self, userInfo: nil))
    }

    private func resizeDirection(for point: NSPoint) -> ResizeDirection {
        let nearLeft = point.x < resizeEdgeThreshold
        let nearRight = point.x > bounds.width - resizeEdgeThreshold
        let nearBottom = point.y < resizeEdgeThreshold
        let nearTop = point.y > bounds.height - resizeEdgeThreshold

        if nearLeft && nearBottom { return .bottomLeft }
        if nearRight && nearBottom { return .bottomRight }
        if nearLeft && nearTop { return .topLeft }
        if nearRight && nearTop { return .topRight }
        if nearLeft { return .left }
        if nearRight { return .right }
        if nearBottom { return .bottom }
        if nearTop { return .top }
        return .none
    }

    private func cursor(for direction: ResizeDirection) -> NSCursor {
        switch direction {
        case .left, .right: return .resizeLeftRight
        case .top, .bottom: return .resizeUpDown
        case .topLeft, .bottomRight: return .crosshair
        case .topRight, .bottomLeft: return .crosshair
        case .none: return .arrow
        }
    }

    override func mouseMoved(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        let direction = resizeDirection(for: point)
        cursor(for: direction).set()
    }

    override func mouseDown(with event: NSEvent) {
        // Handle double-click to hide
        if event.clickCount == 2 {
            onDoubleClick?()
            return
        }

        let point = convert(event.locationInWindow, from: nil)
        resizeDirection = resizeDirection(for: point)

        if resizeDirection == .none {
            super.mouseDown(with: event)
        }
    }

    override func mouseDragged(with event: NSEvent) {
        guard resizeDirection != .none, let window = parentWindow else {
            super.mouseDragged(with: event)
            return
        }

        var frame = window.frame
        let deltaX = event.deltaX
        let deltaY = event.deltaY
        let aspectRatio = window.aspectRatio
        let hasAspectRatio = aspectRatio.width > 0 && aspectRatio.height > 0

        switch resizeDirection {
        case .right, .bottomRight:
            var newWidth = frame.width + deltaX
            if hasAspectRatio {
                newWidth = max(window.minSize.width, min(window.maxSize.width, newWidth))
                let newHeight = newWidth * aspectRatio.height / aspectRatio.width
                frame.size = NSSize(width: newWidth, height: newHeight)
                frame.origin.y -= (newHeight - window.frame.height)
            } else {
                frame.size.width = newWidth
            }
        case .left, .bottomLeft:
            var newWidth = frame.width - deltaX
            if hasAspectRatio {
                newWidth = max(window.minSize.width, min(window.maxSize.width, newWidth))
                let newHeight = newWidth * aspectRatio.height / aspectRatio.width
                let widthDiff = newWidth - window.frame.width
                frame.origin.x -= widthDiff
                frame.origin.y -= (newHeight - window.frame.height)
                frame.size = NSSize(width: newWidth, height: newHeight)
            } else {
                frame.origin.x += deltaX
                frame.size.width = newWidth
            }
        case .top, .topRight:
            var newHeight = frame.height + deltaY
            if hasAspectRatio {
                newHeight = max(window.minSize.height, min(window.maxSize.height, newHeight))
                let newWidth = newHeight * aspectRatio.width / aspectRatio.height
                frame.size = NSSize(width: newWidth, height: newHeight)
            } else {
                frame.size.height = newHeight
            }
        case .topLeft:
            var newHeight = frame.height + deltaY
            if hasAspectRatio {
                newHeight = max(window.minSize.height, min(window.maxSize.height, newHeight))
                let newWidth = newHeight * aspectRatio.width / aspectRatio.height
                let widthDiff = newWidth - window.frame.width
                frame.origin.x -= widthDiff
                frame.size = NSSize(width: newWidth, height: newHeight)
            } else {
                frame.size.height = newHeight
            }
        case .bottom:
            var newHeight = frame.height - deltaY
            if hasAspectRatio {
                newHeight = max(window.minSize.height, min(window.maxSize.height, newHeight))
                let newWidth = newHeight * aspectRatio.width / aspectRatio.height
                let heightDiff = newHeight - window.frame.height
                frame.origin.y -= heightDiff
                frame.size = NSSize(width: newWidth, height: newHeight)
            } else {
                frame.origin.y += deltaY
                frame.size.height = newHeight
            }
        case .none:
            break
        }

        // Enforce min/max size
        frame.size.width = max(window.minSize.width, min(window.maxSize.width, frame.size.width))
        frame.size.height = max(window.minSize.height, min(window.maxSize.height, frame.size.height))

        window.setFrame(frame, display: true)
    }

    override func mouseUp(with event: NSEvent) {
        resizeDirection = .none
        NSCursor.arrow.set()
        super.mouseUp(with: event)
    }

    override func mouseExited(with event: NSEvent) {
        NSCursor.arrow.set()
    }
}

class CameraWindow: NSPanel, NSMenuDelegate {
    private var cameraView: NSView?
    private var currentShape: CameraShape = .circle
    weak var windowDelegate: CameraWindowDelegate?

    private let defaultWindowSize = NSSize(width: 200, height: 200)
    private let minimumWindowSize = NSSize(width: 100, height: 100)
    private let maximumWindowSize = NSSize(width: 2000, height: 2000)

    // Full screen toggle state
    private(set) var isFullScreen: Bool = false
    private var previousFrame: NSRect?
    private var previousShape: CameraShape?
    private var fullScreenMenuItem: NSMenuItem?
    private var savePresetMenu: NSMenu?
    private var restorePresetMenu: NSMenu?

    init() {
        let savedFrame = Self.loadSavedFrame() ?? NSRect(
            x: 100,
            y: 100,
            width: 200,
            height: 200
        )

        super.init(
            contentRect: savedFrame,
            styleMask: [.borderless, .resizable, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        setupWindow()
        setupCameraView()
        setupResizeHandling()
        setupContextMenu()
    }

    private func setupWindow() {
        level = .floating
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        isMovableByWindowBackground = true
        hasShadow = true
        backgroundColor = .clear
        isOpaque = false

        minSize = minimumWindowSize
        maxSize = maximumWindowSize

        aspectRatio = NSSize(width: 1, height: 1)
    }

    private func setupCameraView() {
        // Use resizable content view for edge dragging
        let resizableView = ResizableContentView(frame: contentView?.bounds ?? .zero, window: self)
        resizableView.autoresizingMask = [.width, .height]
        resizableView.onDoubleClick = { [weak self] in
            self?.windowDelegate?.cameraWindowDidRequestHide()
        }
        contentView = resizableView

        let hostingView = NSHostingView(
            rootView: CameraPreviewView(
                captureSession: CameraManager.shared.captureSession,
                shape: currentShape
            )
        )

        hostingView.frame = resizableView.bounds
        hostingView.autoresizingMask = [.width, .height]

        resizableView.addSubview(hostingView)
        cameraView = hostingView

        CameraManager.shared.startCapture()
    }

    private func setupResizeHandling() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(windowDidResize),
            name: NSWindow.didResizeNotification,
            object: self
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(windowDidMove),
            name: NSWindow.didMoveNotification,
            object: self
        )
    }

    private func setupContextMenu() {
        let menu = NSMenu()

        // Shape submenu
        let shapeMenu = NSMenu()
        for shape in CameraShape.allCases {
            let item = NSMenuItem(
                title: shape.rawValue,
                action: #selector(shapeMenuItemClicked(_:)),
                keyEquivalent: ""
            )
            item.representedObject = shape
            item.target = self
            shapeMenu.addItem(item)
        }
        let shapeItem = NSMenuItem(title: "Shape", action: nil, keyEquivalent: "")
        shapeItem.submenu = shapeMenu
        menu.addItem(shapeItem)

        // Camera submenu (if multiple cameras)
        let cameras = CameraManager.shared.availableCameras
        if cameras.count > 1 {
            let cameraMenu = NSMenu()
            for camera in cameras {
                let item = NSMenuItem(
                    title: camera.localizedName,
                    action: #selector(cameraMenuItemClicked(_:)),
                    keyEquivalent: ""
                )
                item.representedObject = camera
                item.target = self
                cameraMenu.addItem(item)
            }
            let cameraItem = NSMenuItem(title: "Camera", action: nil, keyEquivalent: "")
            cameraItem.submenu = cameraMenu
            menu.addItem(cameraItem)
        }

        // Full screen toggle option
        let fullScreenItem = NSMenuItem(
            title: "Full Screen View",
            action: #selector(toggleFullScreenClicked),
            keyEquivalent: ""
        )
        fullScreenItem.target = self
        fullScreenMenuItem = fullScreenItem
        menu.addItem(fullScreenItem)

        menu.addItem(NSMenuItem.separator())

        // Save preset submenu (dynamic)
        let saveMenu = NSMenu()
        saveMenu.delegate = self
        self.savePresetMenu = saveMenu
        let savePresetItem = NSMenuItem(title: "Save Position", action: nil, keyEquivalent: "")
        savePresetItem.submenu = saveMenu
        menu.addItem(savePresetItem)

        // Restore preset submenu (dynamic)
        let restoreMenu = NSMenu()
        restoreMenu.delegate = self
        self.restorePresetMenu = restoreMenu
        let restorePresetItem = NSMenuItem(title: "Restore Position", action: nil, keyEquivalent: "")
        restorePresetItem.submenu = restoreMenu
        menu.addItem(restorePresetItem)

        menu.addItem(NSMenuItem.separator())

        // Hide option
        let hideItem = NSMenuItem(
            title: "Hide",
            action: #selector(hideMenuItemClicked),
            keyEquivalent: ""
        )
        hideItem.target = self
        menu.addItem(hideItem)

        menu.addItem(NSMenuItem.separator())

        // Quit option
        let quitItem = NSMenuItem(
            title: "Quit Facecam",
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q"
        )
        menu.addItem(quitItem)

        contentView?.menu = menu
    }

    @objc private func shapeMenuItemClicked(_ sender: NSMenuItem) {
        guard let shape = sender.representedObject as? CameraShape else { return }
        updateShape(shape)
        windowDelegate?.cameraWindowDidChangeShape(shape)
    }

    @objc private func cameraMenuItemClicked(_ sender: NSMenuItem) {
        guard let camera = sender.representedObject as? AVCaptureDevice else { return }
        CameraManager.shared.selectCamera(camera)
    }

    @objc private func hideMenuItemClicked() {
        windowDelegate?.cameraWindowDidRequestHide()
    }

    @objc private func toggleFullScreenClicked() {
        toggleFullScreen()
    }

    @objc private func savePresetClicked(_ sender: NSMenuItem) {
        let slot = sender.tag
        let state = WindowState(frame: frame, shape: currentShape)
        WindowStateManager.shared.saveState(state, toSlot: slot)
    }

    @objc private func restorePresetClicked(_ sender: NSMenuItem) {
        let slot = sender.tag
        guard let state = WindowStateManager.shared.loadState(fromSlot: slot) else { return }

        updateShape(state.cameraShape)
        windowDelegate?.cameraWindowDidChangeShape(state.cameraShape)
        setFrame(state.frame, display: true, animate: true)
        saveFrame()

        // Exit full screen mode if we were in it
        if isFullScreen {
            isFullScreen = false
            previousFrame = nil
            previousShape = nil
            updateFullScreenMenuItemTitle()
        }
    }

    func toggleFullScreen() {
        if isFullScreen {
            exitFullScreen()
        } else {
            enterFullScreen()
        }
    }

    private func enterFullScreen() {
        guard let screen = NSScreen.main else { return }

        // Save current state before going full screen
        previousFrame = frame
        previousShape = currentShape

        let margin: CGFloat = 100
        let screenFrame = screen.visibleFrame

        // Calculate size with margin, maintaining square aspect ratio
        let availableWidth = screenFrame.width - (margin * 2)
        let availableHeight = screenFrame.height - (margin * 2)
        let size = min(availableWidth, availableHeight)

        let newOrigin = NSPoint(
            x: screenFrame.midX - size / 2,
            y: screenFrame.midY - size / 2
        )

        // Switch to rounded rectangle shape for full screen
        updateShape(.rounded)
        windowDelegate?.cameraWindowDidChangeShape(.rounded)

        setFrame(NSRect(origin: newOrigin, size: NSSize(width: size, height: size)), display: true, animate: true)

        isFullScreen = true
        updateFullScreenMenuItemTitle()
    }

    private func exitFullScreen() {
        guard let savedFrame = previousFrame else { return }

        // Restore previous shape
        if let savedShape = previousShape {
            updateShape(savedShape)
            windowDelegate?.cameraWindowDidChangeShape(savedShape)
        }

        setFrame(savedFrame, display: true, animate: true)
        saveFrame()

        isFullScreen = false
        previousFrame = nil
        previousShape = nil
        updateFullScreenMenuItemTitle()
    }

    private func updateFullScreenMenuItemTitle() {
        fullScreenMenuItem?.title = isFullScreen ? "Exit Full Screen" : "Full Screen View"
    }

    @objc private func windowDidResize(_ notification: Notification) {
        saveFrame()
        updateShapeAfterResize()
    }

    @objc private func windowDidMove(_ notification: Notification) {
        saveFrame()
    }

    func updateShape(_ shape: CameraShape) {
        currentShape = shape

        if let hostingView = cameraView as? NSHostingView<CameraPreviewView> {
            hostingView.rootView = CameraPreviewView(
                captureSession: CameraManager.shared.captureSession,
                shape: shape
            )
        }
    }

    private func updateShapeAfterResize() {
        updateShape(currentShape)
    }

    private func saveFrame() {
        let frameDict: [String: CGFloat] = [
            "x": frame.origin.x,
            "y": frame.origin.y,
            "width": frame.size.width,
            "height": frame.size.height
        ]
        UserDefaults.standard.set(frameDict, forKey: "CameraWindowFrame")
    }

    private static func loadSavedFrame() -> NSRect? {
        guard let frameDict = UserDefaults.standard.dictionary(forKey: "CameraWindowFrame"),
              let x = frameDict["x"] as? CGFloat,
              let y = frameDict["y"] as? CGFloat,
              let width = frameDict["width"] as? CGFloat,
              let height = frameDict["height"] as? CGFloat else {
            return nil
        }
        return NSRect(x: x, y: y, width: width, height: height)
    }

    // MARK: - NSMenuDelegate

    func menuNeedsUpdate(_ menu: NSMenu) {
        if menu === savePresetMenu {
            menu.removeAllItems()
            for slot in 1...10 {
                let hasState = WindowStateManager.shared.hasState(inSlot: slot)
                let title = hasState ? "Slot \(slot) (overwrite)" : "Slot \(slot)"
                let item = NSMenuItem(
                    title: title,
                    action: #selector(savePresetClicked(_:)),
                    keyEquivalent: ""
                )
                item.tag = slot
                item.target = self
                menu.addItem(item)
            }
        } else if menu === restorePresetMenu {
            menu.removeAllItems()
            let savedSlots = WindowStateManager.shared.savedSlots()
            if savedSlots.isEmpty {
                let emptyItem = NSMenuItem(title: "No saved positions", action: nil, keyEquivalent: "")
                emptyItem.isEnabled = false
                menu.addItem(emptyItem)
            } else {
                for slot in savedSlots {
                    let item = NSMenuItem(
                        title: "Slot \(slot)",
                        action: #selector(restorePresetClicked(_:)),
                        keyEquivalent: ""
                    )
                    item.tag = slot
                    item.target = self
                    menu.addItem(item)
                }
            }
        }
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}
