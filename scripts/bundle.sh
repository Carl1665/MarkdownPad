#!/bin/bash
set -e

echo "Building MarkdownPad..."
swift build -c release

APP_NAME="MarkdownPad"
BUILD_DIR=".build/release"
BUNDLE_DIR="build/${APP_NAME}.app"

# Clean previous bundle
rm -rf "$BUNDLE_DIR"

# Create .app structure
mkdir -p "$BUNDLE_DIR/Contents/MacOS"
mkdir -p "$BUNDLE_DIR/Contents/Resources"

# Copy executable
cp "$BUILD_DIR/$APP_NAME" "$BUNDLE_DIR/Contents/MacOS/"

# Copy Info.plist
cp "Resources/Info.plist" "$BUNDLE_DIR/Contents/"

echo "Bundle created at: $BUNDLE_DIR"
echo "Run with: open $BUNDLE_DIR"
