#!/bin/bash
set -e
if [ "$1" = "--build" ]; then
    xcodebuild -project Facecam.xcodeproj -scheme Facecam -configuration Debug build
fi
open "$(ls -td ~/Library/Developer/Xcode/DerivedData/Facecam-*/Build/Products/Debug/Facecam.app | head -1)"
