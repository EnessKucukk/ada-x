#!/bin/bash
# Uygulamayı derler: build/Ada-X.app ve build/Ada-X.zip
set -euo pipefail
cd "$(dirname "$0")"

APP=build/Ada-X.app
rm -rf build
mkdir -p "$APP/Contents/MacOS"

for arch in arm64 x86_64; do
  swiftc -O -swift-version 5 -target "$arch-apple-macos12" Sources/*.swift -o "build/Ada-X-$arch"
done
lipo -create -output "$APP/Contents/MacOS/Ada-X" build/Ada-X-arm64 build/Ada-X-x86_64
cp Info.plist "$APP/Contents/"
codesign --force --sign - "$APP"

(cd build && ditto -c -k --keepParent Ada-X.app Ada-X.zip)
echo "Hazır: build/Ada-X.app ve build/Ada-X.zip"
