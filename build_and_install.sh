#!/bin/bash
# Automated build and sign script for PlatformJP
# Usage: ./build_and_install.sh [debug|release]

set -e  # Exit on error

BUILD_TYPE="${1:-debug}"  # Default to debug if not specified

echo "🎮 Building and signing PlatformJP ($BUILD_TYPE)..."

APK_PATH="$HOME/Downloads/platformjp.apk"
BUILD_TOOLS="$HOME/Library/Android/sdk/build-tools/35.0.0"

# Set keystore based on build type
if [ "$BUILD_TYPE" = "release" ]; then
    KEYSTORE="$HOME/platformjp-release.keystore"
    KEY_ALIAS="platformjp"
    KEY_PASS="PlatformJP2026!"
    echo "🚀 Using RELEASE keystore"
else
    KEYSTORE="$HOME/.android/debug.keystore"
    KEY_ALIAS="androiddebugkey"
    KEY_PASS="android"
    echo "🐛 Using DEBUG keystore"
fi

# Check if APK exists
if [ ! -f "$APK_PATH" ]; then
    echo "❌ Error: $APK_PATH not found"
    echo "📦 Please export from Godot first: Project → Export → Android"
    exit 1
fi

echo "✅ APK found at $APK_PATH"

# Sign the APK
echo "🔐 Signing APK with $BUILD_TYPE keystore..."
java -jar "$BUILD_TOOLS/lib/apksigner.jar" sign \
    --ks "$KEYSTORE" \
    --ks-key-alias "$KEY_ALIAS" \
    --ks-pass "pass:$KEY_PASS" \
    --key-pass "pass:$KEY_PASS" \
    "$APK_PATH"

echo "✅ APK signed successfully"

# Verify signature
echo "🔍 Verifying signature..."
java -jar "$BUILD_TOOLS/lib/apksigner.jar" verify "$APK_PATH"

echo "✅ Signature verified"

# For debug, install to device
if [ "$BUILD_TYPE" = "debug" ]; then
    echo "📱 Installing to device..."
    adb install -r "$APK_PATH"
    echo "🎉 Done! App installed successfully"
    echo ""
    echo "To view logs, run: adb logcat -s godot:V GodotGoogleSignIn:D"
else
    echo "📦 Release APK ready for Play Store upload!"
    echo "📍 Location: $APK_PATH"
    echo ""
    echo "⚠️  IMPORTANT: Add this SHA-1 to Google Cloud Console:"
    echo "   51:33:62:EF:68:60:58:7D:94:37:B1:2B:01:39:B7:21:22:53:01:CD"
fi
