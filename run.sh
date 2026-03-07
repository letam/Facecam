#!/bin/bash
set -e
xcodebuild -project Facecam.xcodeproj -scheme Facecam -configuration Debug build
open "$(ls -td ~/Library/Developer/Xcode/DerivedData/Facecam-*/Build/Products/Debug/Facecam.app | head -1)"
