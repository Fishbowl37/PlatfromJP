# PlatformJP - Signing Credentials & Setup

## 🔐 Keystores

### Debug Keystore (for development)
- **Location**: `~/.android/debug.keystore`
- **Alias**: `androiddebugkey`
- **Password**: `android`
- **SHA-1**: (The one you added to Google Cloud Console)

### Release Keystore (for Play Store)
- **Location**: `~/platformjp-release.keystore`
- **Alias**: `platformjp`
- **Password**: `PlatformJP2026!`
- **SHA-1**: `51:33:62:EF:68:60:58:7D:94:37:B1:2B:01:39:B7:21:22:53:01:CD`
- **SHA-256**: `3B:40:AD:14:17:F0:EB:08:C4:35:C4:A3:E3:47:BF:5E:F4:8D:B3:8A:AD:24:C3:E0:7E:9D:42:55:22:91:94:AD`

⚠️ **IMPORTANT**: Keep `platformjp-release.keystore` safe! Back it up securely. If you lose it, you cannot update your app on Play Store!

## 🚀 Build Workflow

### For Development/Testing:
```bash
# 1. Export from Godot (Project → Export → Android)
# 2. Sign and install:
./build_and_install.sh debug
```

### For Play Store Release:
```bash
# 1. Export from Godot (Project → Export → Android)
# 2. Sign for release:
./build_and_install.sh release
# 3. Upload ~/Downloads/platformjp.apk to Play Store Console
```

## 🔧 Google Cloud Console Setup

You need TWO Android OAuth clients:

### 1. Debug OAuth Client (for testing)
- **Application type**: Android
- **Package name**: `com.fishbowl.platformjp`
- **SHA-1**: (Your debug keystore SHA-1)

### 2. Release OAuth Client (for Play Store)
- **Application type**: Android
- **Package name**: `com.fishbowl.platformjp`
- **SHA-1**: `51:33:62:EF:68:60:58:7D:94:37:B1:2B:01:39:B7:21:22:53:01:CD`

**Plus** your existing Web Application client for the plugin.

## 📝 Next Steps for Play Store

1. **Add Release SHA-1 to Google Cloud Console**:
   - Go to https://console.cloud.google.com/
   - APIs & Services → Credentials
   - Create new Android OAuth client with the release SHA-1 above
   
2. **Test Release Build Locally**:
   ```bash
   ./build_and_install.sh release
   adb install -r ~/Downloads/platformjp.apk
   ```
   
3. **Upload to Play Store**:
   - Go to https://play.google.com/console
   - Create new app or select existing
   - Upload `~/Downloads/platformjp.apk`

## ⚠️ Security Notes

- Never commit keystores to git
- Never share passwords publicly
- Back up `platformjp-release.keystore` to a secure location
- Consider using Android Studio or Google Play App Signing for production

