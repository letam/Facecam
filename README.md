# Facecam

A native macOS menu bar app that displays your webcam feed in a customizable floating window. Perfect for screen recordings, presentations, and video calls.

## Features

- **Floating camera window** - Always-on-top overlay that appears on all spaces
- **Window shapes** - Circle, rounded rectangle, or rectangle
- **Resizable** - Drag edges to resize while maintaining aspect ratio
- **Draggable** - Move the window anywhere on screen by dragging
- **Full screen view** - Expand the camera to a large centered view
- **Position presets** - Save and restore up to 10 window positions with live preview on hover
- **Multiple cameras** - Switch between connected cameras
- **Double-click to hide** - Quickly toggle visibility
- **Menu bar controls** - Toggle camera, change shape, and switch cameras from the menu bar
- **Remembers position** - Window position and size persist across launches

## Requirements

- macOS 13.0+
- A connected camera

## Build & Run

```bash
./run.sh
```

Or manually:

```bash
# Build
xcodebuild -project Facecam.xcodeproj -scheme Facecam -configuration Debug build

# Run
open "$(ls -td ~/Library/Developer/Xcode/DerivedData/Facecam-*/Build/Products/Debug/Facecam.app | head -1)"
```

## Usage

1. Launch the app - a camera icon appears in the menu bar and the camera window shows automatically
2. **Menu bar dropdown** - Click the menu bar icon to toggle visibility, change shape, switch cameras, or enter full screen
3. **Right-click the camera window** - Access shape, camera, full screen, position presets, and hide/quit options
4. **Drag edges** - Resize the camera window
5. **Drag anywhere else** - Move the window
6. **Double-click** - Hide the camera window
