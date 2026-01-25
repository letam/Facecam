import AVFoundation
import AppKit
import Combine

class CameraManager: ObservableObject {
    static let shared = CameraManager()

    @Published var availableCameras: [AVCaptureDevice] = []
    @Published var selectedCamera: AVCaptureDevice?
    @Published var isAuthorized: Bool = false
    @Published var authorizationStatus: AVAuthorizationStatus = .notDetermined

    let captureSession = AVCaptureSession()
    private var currentInput: AVCaptureDeviceInput?

    private init() {
        checkAuthorization()
        loadAvailableCameras()
        setupNotifications()
    }

    private func setupNotifications() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(deviceWasConnected),
            name: .AVCaptureDeviceWasConnected,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(deviceWasDisconnected),
            name: .AVCaptureDeviceWasDisconnected,
            object: nil
        )
    }

    @objc private func deviceWasConnected(_ notification: Notification) {
        loadAvailableCameras()
    }

    @objc private func deviceWasDisconnected(_ notification: Notification) {
        loadAvailableCameras()
        if let disconnected = notification.object as? AVCaptureDevice,
           disconnected == selectedCamera {
            selectCamera(availableCameras.first)
        }
    }

    func checkAuthorization() {
        authorizationStatus = AVCaptureDevice.authorizationStatus(for: .video)

        switch authorizationStatus {
        case .authorized:
            isAuthorized = true
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                DispatchQueue.main.async {
                    self?.isAuthorized = granted
                    self?.authorizationStatus = granted ? .authorized : .denied
                    if granted {
                        self?.loadAvailableCameras()
                        self?.selectCamera(self?.availableCameras.first)
                    }
                }
            }
        case .denied, .restricted:
            isAuthorized = false
        @unknown default:
            isAuthorized = false
        }
    }

    func loadAvailableCameras() {
        let discoverySession = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.builtInWideAngleCamera, .externalUnknown],
            mediaType: .video,
            position: .unspecified
        )

        DispatchQueue.main.async {
            self.availableCameras = discoverySession.devices

            if self.selectedCamera == nil && !self.availableCameras.isEmpty {
                self.selectCamera(self.availableCameras.first)
            }
        }
    }

    func selectCamera(_ device: AVCaptureDevice?) {
        guard let device = device else { return }

        captureSession.beginConfiguration()

        if let currentInput = currentInput {
            captureSession.removeInput(currentInput)
        }

        do {
            let input = try AVCaptureDeviceInput(device: device)
            if captureSession.canAddInput(input) {
                captureSession.addInput(input)
                currentInput = input
                selectedCamera = device
            }
        } catch {
            print("Error setting up camera input: \(error.localizedDescription)")
        }

        captureSession.commitConfiguration()
    }

    func startCapture() {
        guard isAuthorized else {
            checkAuthorization()
            return
        }

        if !captureSession.isRunning {
            DispatchQueue.global(qos: .userInitiated).async {
                self.captureSession.startRunning()
            }
        }
    }

    func stopCapture() {
        if captureSession.isRunning {
            DispatchQueue.global(qos: .userInitiated).async {
                self.captureSession.stopRunning()
            }
        }
    }

    func openSystemPreferences() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Camera") {
            NSWorkspace.shared.open(url)
        }
    }
}
