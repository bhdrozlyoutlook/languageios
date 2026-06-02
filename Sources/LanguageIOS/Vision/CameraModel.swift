import SwiftUI

#if canImport(AVFoundation) && canImport(UIKit) && os(iOS)
import AVFoundation
import UIKit

/// Drives a live capture session for the object-capture viewfinder. The session only
/// exists on a real device — in the Simulator `AVCaptureDevice.default(for: .video)`
/// returns nil, so `status` lands on `.unavailable` and the UI falls back to the
/// photo library.
@MainActor
final class CameraModel: NSObject, ObservableObject, AVCapturePhotoCaptureDelegate {
    enum Status: Equatable {
        case idle            // not yet configured
        case ready           // running, ready to shoot
        case denied          // permission refused
        case unavailable     // no camera (e.g. Simulator)
    }

    @Published private(set) var status: Status = .idle

    let session = AVCaptureSession()
    private let output = AVCapturePhotoOutput()
    private let queue = DispatchQueue(label: "language-ios.camera")
    private var onCapture: ((Data) -> Void)?
    private var configured = false

    /// Requests permission and starts the session, or reports why it can't.
    func start() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            configureAndRun()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                Task { @MainActor in
                    if granted { self?.configureAndRun() } else { self?.status = .denied }
                }
            }
        default:
            status = .denied
        }
    }

    func stop() {
        guard configured else { return }
        queue.async { [session] in
            if session.isRunning { session.stopRunning() }
        }
    }

    /// Triggers a still capture; the PNG/JPEG data arrives via `onCapture`.
    func capturePhoto(_ onCapture: @escaping (Data) -> Void) {
        guard status == .ready else { return }
        self.onCapture = onCapture
        let settings = AVCapturePhotoSettings()
        output.capturePhoto(with: settings, delegate: self)
    }

    private func configureAndRun() {
        if configured {
            queue.async { [session] in if !session.isRunning { session.startRunning() } }
            status = .ready
            return
        }
        // Device discovery + session configuration are expensive and were blocking the
        // main thread (janky camera-sheet open). Do all of it on the serial queue and
        // only hop back to the main actor to publish `status`.
        queue.async { [weak self, session, output] in
            guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back)
                ?? AVCaptureDevice.default(for: .video),
                let input = try? AVCaptureDeviceInput(device: device) else {
                Task { @MainActor in self?.status = .unavailable }
                return
            }
            session.beginConfiguration()
            session.sessionPreset = .photo
            if session.canAddInput(input) { session.addInput(input) }
            if session.canAddOutput(output) { session.addOutput(output) }
            session.commitConfiguration()
            session.startRunning()
            Task { @MainActor in
                self?.configured = true
                self?.status = .ready
            }
        }
    }

    nonisolated func photoOutput(
        _ output: AVCapturePhotoOutput,
        didFinishProcessingPhoto photo: AVCapturePhoto,
        error: Error?
    ) {
        let data = photo.fileDataRepresentation()
        Task { @MainActor in
            if let data { self.onCapture?(data) }
            self.onCapture = nil
        }
    }
}

/// SwiftUI host for the live preview layer.
struct CameraPreview: UIViewRepresentable {
    let session: AVCaptureSession

    func makeUIView(context: Context) -> PreviewView {
        let view = PreviewView()
        view.videoPreviewLayer.session = session
        view.videoPreviewLayer.videoGravity = .resizeAspectFill
        return view
    }

    func updateUIView(_ uiView: PreviewView, context: Context) {}

    final class PreviewView: UIView {
        override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
        var videoPreviewLayer: AVCaptureVideoPreviewLayer { layer as! AVCaptureVideoPreviewLayer }
    }
}
#endif
