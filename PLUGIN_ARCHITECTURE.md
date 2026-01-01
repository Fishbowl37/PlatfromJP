# GodotGoogleSignIn Plugin Architecture

## 📁 File Structure

```
PlatfromJP/
├── addons/
│   └── GodotGoogleSignIn/           ← Godot addon (Editor integration)
│       ├── plugin.cfg               ← Plugin metadata
│       ├── GodotGoogleSignIn.gd     ← Editor plugin script
│       └── GoogleSignInHelper.gd    ← Helper class (optional)
│
├── android/
│   └── plugins/
│       ├── GodotGoogleSignIn.aar    ← Built native plugin (created by build script)
│       └── GodotGoogleSignIn.gdap   ← Plugin descriptor
│
├── plugin/                          ← Native plugin source
│   ├── build.gradle.kts             ← Build configuration
│   ├── gradlew                      ← Build tool
│   ├── libs/
│   │   └── godot-lib.aar           ← Godot engine library
│   └── src/main/kotlin/
│       └── .../GodotGoogleSignIn.kt ← Native Android code
│
├── scripts/
│   └── AuthManager.gd               ← Your game's auth logic
│
├── build_plugin.sh                  ← Build automation script
├── PLUGIN_FIX_SUMMARY.md           ← What was fixed
├── PLUGIN_SETUP.md                 ← Full setup guide
└── PLUGIN_QUICK_REFERENCE.md       ← API reference
```

## 🔄 How It Works

### Build Time
```
┌─────────────────────┐
│ plugin/src/         │
│ (Kotlin Source)     │
└──────────┬──────────┘
           │
           │ ./build_plugin.sh
           ↓
┌─────────────────────┐
│ Build with Gradle   │
│ + godot-lib.aar     │
└──────────┬──────────┘
           │
           ↓
┌─────────────────────────────┐
│ android/plugins/            │
│ GodotGoogleSignIn.aar       │
│ (Native Plugin)             │
└─────────────────────────────┘
```

### Editor Time (Godot)
```
┌─────────────────────┐
│ Open Godot Project  │
└──────────┬──────────┘
           │
           ↓
┌─────────────────────┐      ┌──────────────────────┐
│ Load Addons         │ ───→ │ addons/              │
│                     │      │ GodotGoogleSignIn/   │
└──────────┬──────────┘      │ plugin.cfg           │
           │                 └──────────────────────┘
           ↓
┌─────────────────────┐
│ Enable in Editor    │
│ Project → Plugins   │
└─────────────────────┘
```

### Export Time (Android Build)
```
┌─────────────────────┐
│ Export → Android    │
└──────────┬──────────┘
           │
           ↓
┌─────────────────────────────┐
│ Include Enabled Plugins:    │
│ ✓ GodotGoogleSignIn.aar    │
│ ✓ Dependencies (gdap)       │
└──────────┬──────────────────┘
           │
           ↓
┌─────────────────────┐      ┌──────────────────────┐
│ Build APK/AAB       │ ───→ │ platformjp.apk       │
│ + Native Plugin     │      │ (With Google Auth)   │
└─────────────────────┘      └──────────────────────┘
```

### Runtime (On Android Device)
```
User Opens App
     ↓
┌──────────────────────────┐
│ AuthManager._ready()     │
│ - Load saved auth        │
│ - Initialize plugin      │
│ - Connect signals        │
└──────────┬───────────────┘
           │
           ↓
User Taps "Link Account" Button
     ↓
┌──────────────────────────┐
│ AuthManager.             │
│ link_with_google()       │
└──────────┬───────────────┘
           │
           ↓
┌──────────────────────────┐
│ Native Plugin            │
│ _google_sign_in.signIn() │
└──────────┬───────────────┘
           │
           ↓
┌──────────────────────────────────────┐
│ Android System                       │
│ Google Credential Manager            │
│ (Shows account chooser)              │
└──────────┬───────────────────────────┘
           │
    User Selects Account
           │
           ↓
┌──────────────────────────────────────┐
│ Plugin Receives Credentials          │
│ - ID Token                           │
│ - Email                              │
│ - Display Name                       │
└──────────┬───────────────────────────┘
           │
           ↓
┌──────────────────────────────────────┐
│ Signal: sign_in_success              │
│ ├─> AuthManager._on_plugin_sign_in_  │
│ │    success(token, email, name)     │
│ │                                    │
│ └─> Update display_name              │
│     Mark as linked                   │
│     Grant 500 diamonds               │
└──────────┬───────────────────────────┘
           │
           ↓
┌──────────────────────────────────────┐
│ Signal: account_linked(true)         │
│ Signal: link_reward_granted(500)     │
└──────────────────────────────────────┘
           │
           ↓
┌──────────────────────────────────────┐
│ UI Updates                           │
│ - Hide "Link Account" button         │
│ - Show "✅ Account Linked"          │
│ - Display reward animation           │
└──────────────────────────────────────┘
```

## 🔌 Plugin Communication

### GDScript → Native Plugin
```gdscript
# GDScript (AuthManager.gd)
var _google_sign_in = Engine.get_singleton("GodotGoogleSignIn")
_google_sign_in.initialize(GOOGLE_WEB_CLIENT_ID)
_google_sign_in.signIn()
```
↓ **JNI Bridge** ↓
```kotlin
// Kotlin (GodotGoogleSignIn.kt)
@UsedByGodot
fun initialize(webClientId: String) { ... }

@UsedByGodot
fun signIn() { ... }
```

### Native Plugin → GDScript
```kotlin
// Kotlin (GodotGoogleSignIn.kt)
emitSignal("sign_in_success", idToken, email, displayName)
emitSignal("sign_in_failed", error)
```
↑ **Signal System** ↑
```gdscript
# GDScript (AuthManager.gd)
_google_sign_in.sign_in_success.connect(_on_plugin_sign_in_success)
_google_sign_in.sign_in_failed.connect(_on_plugin_sign_in_failed)

func _on_plugin_sign_in_success(token, email, name):
    # Handle success
```

## 📊 Data Flow

```
┌─────────────────────┐
│ Google Account      │
│ (User's Gmail)      │
└──────────┬──────────┘
           │ OAuth 2.0
           ↓
┌─────────────────────────────────────┐
│ Google Identity Platform            │
│ - Verifies user                     │
│ - Issues ID Token (JWT)             │
└──────────┬──────────────────────────┘
           │ ID Token
           ↓
┌─────────────────────────────────────┐
│ GodotGoogleSignIn Plugin            │
│ - Receives credentials              │
│ - Extracts user info                │
└──────────┬──────────────────────────┘
           │ Signal (token, email, name)
           ↓
┌─────────────────────────────────────┐
│ AuthManager                         │
│ - Updates display name              │
│ - Marks account as linked           │
│ - Grants reward                     │
└──────────┬──────────────────────────┘
           │ Save
           ↓
┌─────────────────────────────────────┐
│ Local Storage                       │
│ user://auth_data.cfg                │
│ - is_account_linked: true           │
│ - display_name: "User Name"         │
│ - has_claimed_link_reward: true     │
└─────────────────────────────────────┘
```

## 🎯 Key Components

### 1. Editor Plugin (`addons/GodotGoogleSignIn/`)
- **Purpose**: Makes plugin visible in Godot Editor
- **When Used**: Editor time only
- **Required For**: Enabling plugin in Project Settings

### 2. Native Plugin (`android/plugins/GodotGoogleSignIn.aar`)
- **Purpose**: Android-specific Google Sign-In implementation
- **When Used**: Runtime on Android devices
- **Required For**: Actual Google authentication

### 3. Plugin Descriptor (`android/plugins/GodotGoogleSignIn.gdap`)
- **Purpose**: Tells Godot about the native plugin and its dependencies
- **When Used**: Export/build time
- **Required For**: Including plugin in APK

### 4. Game Integration (`scripts/AuthManager.gd`)
- **Purpose**: Your game's authentication logic
- **When Used**: Runtime
- **Required For**: Actually using the plugin in your game

## 🔐 Security Flow

```
1. User Taps Button
        ↓
2. App Requests Sign-In
   (with Web Client ID)
        ↓
3. Google verifies:
   - Client ID is valid
   - App package name matches
   - SHA-1 certificate matches (release builds)
        ↓
4. User Chooses Account
        ↓
5. Google Issues ID Token (JWT)
   Contains:
   - User ID
   - Email
   - Display Name
   - Expiration
   - Signature (prevents tampering)
        ↓
6. Plugin Receives Token
        ↓
7. App Uses Token
   - Store display name
   - Link to backend (optional)
   - Grant rewards
```

## 🌐 Why Web Client ID?

**Web Client ID** is used instead of Android Client ID because:

1. **Backend Verification**: Can be verified by Firebase/your server
2. **Cross-Platform**: Works with web, iOS, Android
3. **Token Exchange**: Required for Firebase Authentication
4. **Security**: More secure than Android-only tokens

```
Android Client ID ────────┐
                          │
Web Client ID ────────────┼───→ Used for Authentication
                          │
iOS Client ID ────────────┘
```

---

**This architecture ensures secure, native Google Sign-In on Android while maintaining compatibility with Godot's plugin system!**

