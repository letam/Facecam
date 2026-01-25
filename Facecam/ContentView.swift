import SwiftUI

struct ContentView: View {
    @ObservedObject var cameraManager: CameraManager
    @ObservedObject var windowController: CameraWindowController
    @Binding var selectedShape: CameraShape
    @Binding var isCameraVisible: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if !cameraManager.isAuthorized {
                unauthorizedView
            } else {
                authorizedView
            }

            Divider()

            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
            .keyboardShortcut("q")
        }
        .padding()
        .frame(width: 250)
        .onAppear {
            windowController.isVisible = isCameraVisible
            windowController.updateShape(selectedShape)
        }
    }

    @ViewBuilder
    private var unauthorizedView: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "camera.fill")
                    .foregroundColor(.orange)
                Text("Camera Access Required")
                    .font(.headline)
            }

            Text("Facecam needs camera access to show your webcam feed.")
                .font(.caption)
                .foregroundColor(.secondary)

            if cameraManager.authorizationStatus == .notDetermined {
                Button("Grant Access") {
                    cameraManager.checkAuthorization()
                }
                .buttonStyle(.borderedProminent)
            } else {
                Button("Open System Settings") {
                    cameraManager.openSystemPreferences()
                }
                .buttonStyle(.bordered)
            }
        }
    }

    @ViewBuilder
    private var authorizedView: some View {
        Toggle(isOn: $isCameraVisible) {
            Label("Show Camera", systemImage: "video.fill")
        }
        .toggleStyle(.switch)
        .onChange(of: isCameraVisible) { newValue in
            windowController.isVisible = newValue
        }

        Divider()

        if cameraManager.availableCameras.count > 1 {
            VStack(alignment: .leading, spacing: 4) {
                Text("Camera")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Picker("Camera", selection: Binding(
                    get: { cameraManager.selectedCamera },
                    set: { cameraManager.selectCamera($0) }
                )) {
                    ForEach(cameraManager.availableCameras, id: \.uniqueID) { camera in
                        Text(camera.localizedName).tag(camera as AVCaptureDevice?)
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)
            }

            Divider()
        }

        VStack(alignment: .leading, spacing: 4) {
            Text("Shape")
                .font(.caption)
                .foregroundColor(.secondary)

            Picker("Shape", selection: $selectedShape) {
                ForEach(CameraShape.allCases) { shape in
                    Label(shape.rawValue, systemImage: iconForShape(shape))
                        .tag(shape)
                }
            }
            .labelsHidden()
            .pickerStyle(.menu)
            .onChange(of: selectedShape) { newValue in
                windowController.updateShape(newValue)
            }
        }

        Divider()

        Button {
            windowController.centerOnScreen()
        } label: {
            Label("Full Screen View", systemImage: "arrow.up.left.and.arrow.down.right")
        }
        .disabled(!isCameraVisible)
    }

    private func iconForShape(_ shape: CameraShape) -> String {
        switch shape {
        case .circle: return "circle.fill"
        case .rounded: return "app.fill"
        case .rectangle: return "rectangle.fill"
        }
    }
}

import AVFoundation

#Preview {
    ContentView(
        cameraManager: CameraManager.shared,
        windowController: CameraWindowController(),
        selectedShape: .constant(.circle),
        isCameraVisible: .constant(false)
    )
}
