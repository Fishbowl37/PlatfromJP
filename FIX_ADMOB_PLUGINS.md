# Fix: AdMob Plugins Not Found

## The Problem
Your logcat shows:
```
E godot: PoingGodotAdMob not found, make sure you marked all 'PoingAdMob' plugins on export tab
E godot: PoingGodotAdMobInterstitialAd not found
E godot: PoingGodotAdMobRewardedAd not found
```

This means the AdMob native Android plugins are not included in your export.

## ✅ What I Fixed
I've already updated `export_presets.cfg` to enable the AdMob plugins. Now you need to:

## Step 1: Download AdMob Android Plugin

### Option A: Using Godot Editor (Recommended)
1. Open your project in Godot
2. Go to **Project > Tools > AdMob Download Manager > Android > LatestVersion**
3. Wait for the download to complete
4. The plugin will be downloaded to `addons/admob/downloads/android/`

### Option B: Manual Download
1. Go to: https://github.com/poingstudios/godot-admob-android/releases
2. Download the latest release zip file (e.g., `poing-godot-admob-android-v3.0.2.zip`)
3. Extract it to `addons/admob/downloads/android/`

## Step 2: Install the Plugin Files

After downloading, you need to copy the `.aar` files to the Android plugins directory:

1. The downloaded zip should contain `.aar` files
2. Copy all `.aar` files to: `android/plugins/`
3. You should have files like:
   - `PoingGodotAdMob.aar`
   - `PoingGodotAdMobInterstitialAd.aar`
   - `PoingGodotAdMobRewardedAd.aar`
   - `PoingGodotAdMobAdSize.aar`
   - `PoingGodotAdMobAdView.aar`

## Step 3: Verify Export Settings

The export settings are already fixed, but verify in Godot:
1. Go to **Project > Export**
2. Select your Android preset
3. Click **Export** tab (not Options)
4. Scroll down to **Plugins** section
5. Make sure these are checked:
   - ✅ PoingGodotAdMob
   - ✅ PoingGodotAdMobInterstitialAd
   - ✅ PoingGodotAdMobRewardedAd
   - ✅ PoingGodotAdMobAdSize
   - ✅ PoingGodotAdMobAdView

## Step 4: Rebuild and Test

1. **Export your APK again** (the plugins will now be included)
2. **Install on your device**
3. **Check logcat** - you should now see:
   ```
   AdMobBridge: Initializing AdMob...
   AdMobBridge: ✅ AdMob initialized successfully
   AdMobBridge: Loading interstitial ad...
   AdMobBridge: ✅ Interstitial ad loaded
   ```

## Quick Check: Verify Plugin Files

Run this command to check if plugin files exist:
```bash
ls -la android/plugins/*.aar
```

You should see multiple `.aar` files including the AdMob ones.

## If Download Fails

If the download through Godot fails:
1. Check your internet connection
2. Try downloading manually from GitHub
3. Make sure you have write permissions to `addons/admob/downloads/`

## After Fixing

Once the plugins are downloaded and installed:
1. Rebuild your APK
2. The error messages should disappear
3. Ads should start working!

Let me know if you need help with any step!

