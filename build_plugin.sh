#!/bin/bash

# Build script for GodotGoogleSignIn plugin
# This script builds the native Android plugin and copies it to the correct location

set -e

echo "Building GodotGoogleSignIn Android Plugin..."
echo ""

# Check for Java
if ! command -v java &> /dev/null; then
    echo "❌ Error: Java is not installed!"
    echo "Please install JDK 17 or higher:"
    echo "  - Download from: https://adoptium.net/"
    echo "  - Or use Homebrew: brew install openjdk@17"
    exit 1
fi

# Get the directory where this script is located
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PLUGIN_DIR="$SCRIPT_DIR/plugin"
ANDROID_PLUGINS_DIR="$SCRIPT_DIR/android/plugins"

# Ensure godot-lib.aar is in place
if [ ! -f "$PLUGIN_DIR/libs/godot-lib.aar" ]; then
    echo "❌ Error: godot-lib.aar not found in $PLUGIN_DIR/libs/"
    echo ""
    echo "Please copy your Godot library AAR file to:"
    echo "  $PLUGIN_DIR/libs/godot-lib.aar"
    echo ""
    echo "You can find it in one of these locations:"
    echo "  - android/build/libs/debug/godot-lib.template_debug.aar"
    echo "  - android/build/libs/release/godot-lib.template_release.aar"
    exit 1
fi

echo "✓ Found godot-lib.aar"

# Build the plugin
cd "$PLUGIN_DIR"
echo ""
echo "Building plugin AAR..."
./gradlew assembleRelease

# Check if build was successful
AAR_FILE="$PLUGIN_DIR/build/outputs/aar/GoogleSignIn-release.aar"
if [ ! -f "$AAR_FILE" ]; then
    echo "❌ Build failed: AAR file not found at $AAR_FILE"
    exit 1
fi

echo "✓ Build successful!"

# Create android/plugins directory if it doesn't exist
mkdir -p "$ANDROID_PLUGINS_DIR"

# Copy the AAR to the android/plugins directory
echo ""
echo "Copying plugin to android/plugins/..."
cp "$AAR_FILE" "$ANDROID_PLUGINS_DIR/GodotGoogleSignIn.aar"

echo "✓ Plugin copied successfully!"
echo ""
echo "========================================="
echo "✅ Plugin built and installed successfully!"
echo "========================================="
echo ""
echo "Next steps:"
echo "1. Open your project in Godot Editor"
echo "2. Go to Project → Export → Android"
echo "3. In the 'Plugins' section, enable 'GodotGoogleSignIn'"
echo "4. Make sure you have configured your Google Web Client ID"
echo ""
echo "The plugin is ready to use!"

