import AppKit
import AVFoundation
import SwiftUI

protocol CameraWindowDelegate: AnyObject {
    func cameraWindowDidChangeShape(_ shape: CameraShape)
    func cameraWindowDidRequestHide()
}

class CameraWindow: NSPanel {
    private var cameraView: NSView?
    private var currentShape: CameraShape = .circle
    weak var windowDelegate: CameraWindowDelegate?

    private let defaultWindowSize = NSSize(width: 200, height: 200)
    private let minimumWindowSize = NSSize(width: 100, height: 100)
    private let maximumWindowSize = NSSize(width: 600, height: 600)

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
        let hostingView = NSHostingView(
            rootView: CameraPreviewView(
                captureSession: CameraManager.shared.captureSession,
                shape: currentShape
            )
        )

        hostingView.frame = contentView?.bounds ?? .zero
        hostingView.autoresizingMask = [.width, .height]

        contentView?.addSubview(hostingView)
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

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}
