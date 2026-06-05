import SwiftUI
import AVFoundation
import Combine

struct CameraPreviewView: NSViewRepresentable {
    let captureSession: AVCaptureSession
    let shape: CameraShape

    func makeNSView(context: Context) -> CameraPreviewNSView {
        let view = CameraPreviewNSView()
        view.setupPreviewLayer(with: captureSession)
        return view
    }

    func updateNSView(_ nsView: CameraPreviewNSView, context: Context) {
        nsView.updateShape(shape)
    }
}

class CameraPreviewNSView: NSView {
    private var previewLayer: AVCaptureVideoPreviewLayer?
    private let processedLayer = CALayer()
    private var currentShape: CameraShape = .circle
    private var blurCancellable: AnyCancellable?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.masksToBounds = true
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        wantsLayer = true
        layer?.masksToBounds = true
    }

    func setupPreviewLayer(with session: AVCaptureSession) {
        let previewLayer = AVCaptureVideoPreviewLayer(session: session)
        previewLayer.videoGravity = .resizeAspectFill
        previewLayer.frame = bounds
        previewLayer.autoresizingMask = [.layerWidthSizable, .layerHeightSizable]

        // Mirror to match the processed blur output so toggling blur doesn't flip the image
        if let connection = previewLayer.connection, connection.isVideoMirroringSupported {
            connection.automaticallyAdjustsVideoMirroring = false
            connection.isVideoMirrored = true
        }

        layer?.addSublayer(previewLayer)
        self.previewLayer = previewLayer

        // Layer that displays segmented + blurred frames when blur is enabled
        processedLayer.frame = bounds
        processedLayer.autoresizingMask = [.layerWidthSizable, .layerHeightSizable]
        processedLayer.contentsGravity = .resizeAspectFill
        processedLayer.isHidden = true
        layer?.addSublayer(processedLayer)

        blurCancellable = CameraManager.shared.$isBackgroundBlurEnabled
            .receive(on: DispatchQueue.main)
            .sink { [weak self] enabled in
                self?.setBlurEnabled(enabled)
            }

        updateShape(currentShape)
    }

    private func setBlurEnabled(_ enabled: Bool) {
        processedLayer.isHidden = !enabled
        previewLayer?.isHidden = enabled

        if enabled {
            CameraManager.shared.blurProcessor.onProcessedFrame = { [weak self] cgImage in
                self?.processedLayer.contents = cgImage
            }
        } else {
            CameraManager.shared.blurProcessor.onProcessedFrame = nil
            processedLayer.contents = nil
        }
    }

    func updateShape(_ shape: CameraShape) {
        currentShape = shape
        updateCornerRadius()
    }

    override func layout() {
        super.layout()
        previewLayer?.frame = bounds
        processedLayer.frame = bounds
        updateCornerRadius()
    }

    private func updateCornerRadius() {
        let minDimension = min(bounds.width, bounds.height)
        let cornerRadius: CGFloat

        switch currentShape {
        case .circle:
            cornerRadius = minDimension / 2
        case .rounded:
            cornerRadius = minDimension * 0.15
        case .rectangle:
            cornerRadius = 0
        }

        layer?.cornerRadius = cornerRadius
    }

    override var isFlipped: Bool { false }
}
