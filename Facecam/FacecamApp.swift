import SwiftUI

@main
struct FacecamApp: App {
    @StateObject private var cameraManager = CameraManager.shared
    @StateObject private var windowController = CameraWindowController()

    @AppStorage("selectedShape") private var selectedShape: CameraShape = .circle
    @AppStorage("isCameraVisible") private var isCameraVisible: Bool = true

    var body: some Scene {
        MenuBarExtra("Facecam", systemImage: "camera.fill") {
            ContentView(
                cameraManager: cameraManager,
                windowController: windowController,
                selectedShape: $selectedShape,
                isCameraVisible: $isCameraVisible
            )
            .onAppear {
                windowController.onShapeChanged = { [self] newShape in
                    selectedShape = newShape
                }
            }
        }
        .menuBarExtraStyle(.window)
    }
}

enum CameraShape: String, CaseIterable, Identifiable {
    case circle = "Circle"
    case rounded = "Rounded Rectangle"
    case rectangle = "Rectangle"

    var id: String { rawValue }

    var cornerRadiusMultiplier: CGFloat {
        switch self {
        case .circle: return 0.5
        case .rounded: return 0.15
        case .rectangle: return 0
        }
    }
}

class CameraWindowController: ObservableObject, CameraWindowDelegate {
    private var window: CameraWindow?
    private var toggleButton: ToggleButton?
    var onShapeChanged: ((CameraShape) -> Void)?

    @Published var isVisible: Bool = false {
        didSet {
            if isVisible {
                showWindow()
            } else {
                hideWindow()
            }
        }
    }

    var shape: CameraShape = .circle {
        didSet {
            window?.updateShape(shape)
        }
    }

    init() {
        setupToggleButton()

        // Show camera on launch
        DispatchQueue.main.async { [weak self] in
            self?.isVisible = true
        }
    }

    private func setupToggleButton() {
        toggleButton = ToggleButton()
        toggleButton?.onToggle = { [weak self] in
            self?.isVisible = true
        }
        toggleButton?.onRestorePreset = { [weak self] slot in
            self?.restorePreset(slot: slot)
        }
    }

    func restorePreset(slot: Int) {
        guard let state = WindowStateManager.shared.loadState(fromSlot: slot) else { return }

        // Show window first if needed
        isVisible = true

        // Apply the preset
        shape = state.cameraShape
        window?.updateShape(state.cameraShape)
        window?.setFrame(state.frame, display: true, animate: true)
        onShapeChanged?(state.cameraShape)
    }

    private func showWindow() {
        if window == nil {
            window = CameraWindow()
            window?.windowDelegate = self
        }
        window?.updateShape(shape)
        window?.makeKeyAndOrderFront(nil)
        toggleButton?.orderOut(nil)
    }

    private func hideWindow() {
        window?.orderOut(nil)
        toggleButton?.makeKeyAndOrderFront(nil)
    }

    func updateShape(_ shape: CameraShape) {
        self.shape = shape
        window?.updateShape(shape)
    }

    func toggleFullScreen() {
        window?.toggleFullScreen()
    }

    var isFullScreen: Bool {
        window?.isFullScreen ?? false
    }

    // MARK: - CameraWindowDelegate

    func cameraWindowDidChangeShape(_ shape: CameraShape) {
        self.shape = shape
        onShapeChanged?(shape)
    }

    func cameraWindowDidRequestHide() {
        isVisible = false
    }
}
