import SwiftUI
import AVFoundation

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
    private var currentShape: CameraShape = .circle

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

        layer?.addSublayer(previewLayer)
        self.previewLayer = previewLayer

        updateShape(currentShape)
    }

    func updateShape(_ shape: CameraShape) {
        currentShape = shape
        updateCornerRadius()
    }

    override func layout() {
        super.layout()
        previewLayer?.frame = bounds
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
