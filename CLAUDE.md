# Facecam

A native macOS menu bar app that displays a webcam feed in a customizable floating window.

## Build

```bash
xcodebuild -project Facecam.xcodeproj -scheme Facecam -configuration Debug build
```

Run the built app:
```bash
open ~/Library/Developer/Xcode/DerivedData/Facecam-*/Build/Products/Debug/Facecam.app
```

## Project Structure

```
Facecam/
├── FacecamApp.swift        # App entry, MenuBarExtra, CameraWindowController
├── CameraManager.swift     # AVFoundation camera capture (singleton)
├── CameraPreviewView.swift # NSViewRepresentable for video preview layer
├── CameraWindow.swift      # Floating NSPanel with context menu
├── ContentView.swift       # Menu bar dropdown UI
├── Info.plist              # LSUIElement=true, camera usage description
└── Facecam.entitlements    # Camera + sandbox entitlements
```

## Architecture

- **Menu bar app**: Uses `MenuBarExtra` with `.window` style for dropdown
- **Floating window**: `NSPanel` with `.borderless`, `.floating` level, movable by background
- **Camera capture**: `AVCaptureSession` managed by singleton `CameraManager`
- **Shape masking**: Applied via `layer.cornerRadius` on the preview view
- **State sync**: `@AppStorage` for persistence, delegate pattern for context menu changes

## Key Classes

- `CameraManager` - Singleton handling AVFoundation, camera enumeration, permissions
- `CameraWindow` - NSPanel subclass with right-click context menu
- `CameraWindowController` - Manages window lifecycle, conforms to `CameraWindowDelegate`
- `CameraShape` - Enum for circle/rounded/rectangle with corner radius logic

## Deployment Target

macOS 13.0+
