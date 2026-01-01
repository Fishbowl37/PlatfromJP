# GodotGoogleSignIn Plugin Setup Guide

## The Issue You're Facing

You're experiencing **18 conflicts** when trying to install the GodotGoogleSignIn plugin because:
1. Your `project.godot` file references the plugin at `res://addons/GodotGoogleSignIn/plugin.cfg`
2. But the `addons/` folder was empty
3. The plugin structure wasn't properly set up

## What I've Fixed

I've now set up the complete plugin structure for your custom GodotGoogleSignIn plugin:

### ✅ Created Files

1. **`addons/GodotGoogleSignIn/plugin.cfg`** - Plugin configuration
2. **`addons/GodotGoogleSignIn/GodotGoogleSignIn.gd`** - Editor plugin script
3. **`addons/GodotGoogleSignIn/GoogleSignInHelper.gd`** - Helper class to use the plugin
4. **`android/plugins/GodotGoogleSignIn.gdap`** - Android plugin descriptor
5. **`build_plugin.sh`** - Build script for the native plugin

## Next Steps

### 1. Install Java (If Not Already Installed)

The plugin needs to be compiled, which requires Java 17+:

```bash
# Using Homebrew (recommended for macOS)
brew install openjdk@17

# Or download from Adoptium:
# https://adoptium.net/
```

### 2. Build the Plugin

Run the build script from your project root:

```bash
./build_plugin.sh
```

This will:
- Build the native Android plugin (AAR file)
- Copy it to `android/plugins/GodotGoogleSignIn.aar`

### 3. Enable the Plugin in Godot

1. Open your project in **Godot Editor**
2. Go to **Project → Project Settings → Plugins**
3. You should see **GodotGoogleSignIn** in the list
4. Enable it by checking the box

### 4. Configure for Android Export

1. Go to **Project → Export**
2. Select your **Android** export preset
3. Scroll down to the **Plugins** section
4. Enable **GodotGoogleSignIn**

### 5. Set Up Your Google Web Client ID

You need a Google Web Client ID from Google Cloud Console:

1. Go to https://console.cloud.google.com/
2. Create or select your project
3. Go to **APIs & Services → Credentials**
4. Create a **Web Application** OAuth client (not Android)
5. Copy the Client ID

### 6. Update Your AuthManager

I'll update your `AuthManager.gd` to properly use the plugin with your configuration.

## How to Use in Your Game

Once set up, you can use it like this:

```gdscript
# In your AuthManager or where you handle sign-in
var google_sign_in

func _ready():
    if Engine.has_singleton("GodotGoogleSignIn"):
        google_sign_in = Engine.get_singleton("GodotGoogleSignIn")
        google_sign_in.sign_in_success.connect(_on_google_sign_in_success)
        google_sign_in.sign_in_failed.connect(_on_google_sign_in_failed)
        
        # Initialize with your Web Client ID
        google_sign_in.initialize("YOUR_WEB_CLIENT_ID.apps.googleusercontent.com")

func link_google_account():
    if google_sign_in:
        google_sign_in.signIn()

func _on_google_sign_in_success(id_token: String, email: String, display_name: String):
    print("Signed in as: ", email)
    # Use the id_token to authenticate with your backend or Firebase

func _on_google_sign_in_failed(error: String):
    print("Sign in failed: ", error)
```

## Why You Had Conflicts

The conflicts occurred because:
- The Godot editor saw a reference to the plugin in `project.godot` but couldn't find the actual plugin files
- When you tried to install a plugin from another source (Asset Library, GitHub), it conflicted with the existing reference
- Your custom plugin in the `plugin/` folder wasn't connected to the Godot addon system

## Troubleshooting

### "Plugin not found" in Godot Editor

Make sure all these files exist:
- `addons/GodotGoogleSignIn/plugin.cfg`
- `addons/GodotGoogleSignIn/GodotGoogleSignIn.gd`

### "GodotGoogleSignIn not available" when running

This is normal on non-Android platforms. The plugin only works on Android devices.

### Build fails

Make sure:
- Java 17+ is installed
- `plugin/libs/godot-lib.aar` exists (run the build script, it will guide you)

### Sign-in fails on Android

Make sure:
- You're using the **Web Client ID** (not Android Client ID)
- Your app's package name matches Google Cloud Console configuration
- Your APK is signed with the correct certificate (SHA-1 matches Google Console)

## Questions?

If you encounter any issues, let me know! The main steps are:
1. Install Java
2. Run `./build_plugin.sh`
3. Enable the plugin in Godot
4. Configure your Google Client ID

