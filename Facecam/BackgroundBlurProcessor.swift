import AVFoundation
import CoreImage.CIFilterBuiltins
import Vision

/// Processes camera frames with person segmentation to blur the background
/// while keeping the person sharp.
class BackgroundBlurProcessor: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate {
    /// Set from the main thread; read on the video queue. Frames are dropped when disabled.
    var isEnabled = false

    /// Called on the main thread with each processed frame.
    var onProcessedFrame: ((CGImage) -> Void)?

    private let ciContext = CIContext()

    /// Previous frame's smoothed mask (at native mask resolution); only touched on the video queue.
    private var smoothedMask: CIImage?
    /// Weight of the new mask per frame; lower = more smoothing, more lag.
    private let maskSmoothingAmount: Float = 0.15

    private let segmentationRequest: VNGeneratePersonSegmentationRequest = {
        let request = VNGeneratePersonSegmentationRequest()
        request.qualityLevel = .balanced
        request.outputPixelFormat = kCVPixelFormatType_OneComponent8
        return request
    }()

    func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        guard isEnabled else {
            smoothedMask = nil
            return
        }
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }

        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, options: [:])
        guard (try? handler.perform([segmentationRequest])) != nil,
              let maskBuffer = segmentationRequest.results?.first?.pixelBuffer else { return }

        let original = CIImage(cvPixelBuffer: pixelBuffer)
        var mask = CIImage(cvPixelBuffer: maskBuffer)

        // Temporally smooth the mask (EMA with the previous frame) so borderline
        // pixels like furniture edges don't flicker in and out of the blur
        if let previous = smoothedMask, previous.extent == mask.extent {
            let mix = CIFilter.mix()
            mix.inputImage = mask
            mix.backgroundImage = previous
            mix.amount = maskSmoothingAmount
            if let mixed = mix.outputImage {
                mask = mixed
            }
        }

        // Render to a concrete image so the filter graph doesn't grow unbounded across frames
        if let smoothedCG = ciContext.createCGImage(mask, from: mask.extent) {
            let concrete = CIImage(cgImage: smoothedCG)
            smoothedMask = concrete
            mask = concrete
        }

        // Feather the mask edge slightly, then scale up to the frame size
        let maskExtent = mask.extent
        mask = mask
            .clampedToExtent()
            .applyingGaussianBlur(sigma: 1.5)
            .cropped(to: maskExtent)
        let scaleX = original.extent.width / mask.extent.width
        let scaleY = original.extent.height / mask.extent.height
        mask = mask.transformed(by: CGAffineTransform(scaleX: scaleX, y: scaleY))

        // Blur the whole frame, then composite the sharp person back on top
        let blurRadius = original.extent.width / 50
        let blurred = original
            .clampedToExtent()
            .applyingGaussianBlur(sigma: blurRadius)
            .cropped(to: original.extent)

        let blend = CIFilter.blendWithMask()
        blend.inputImage = original
        blend.backgroundImage = blurred
        blend.maskImage = mask

        guard let outputImage = blend.outputImage,
              let cgImage = ciContext.createCGImage(outputImage, from: original.extent) else { return }

        DispatchQueue.main.async { [weak self] in
            self?.onProcessedFrame?(cgImage)
        }
    }
}
