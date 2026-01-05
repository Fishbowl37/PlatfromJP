# AdMob Debugging Guide

## Step-by-Step Debugging Process

### Step 1: Check Logcat for AdMob Messages

1. **Connect your phone via USB** and enable USB debugging
2. **Open terminal/command prompt** and run:
   ```bash
   adb logcat | grep -i "admob\|AdMob\|ad.*load\|ad.*fail"
   ```
   
   Or for more detailed output:
   ```bash
   adb logcat | grep -E "AdMobBridge|MobileAds|PoingGodotAdMob"
   ```

3. **Launch your app** and look for these messages:
   - `AdMobBridge: Initializing AdMob...` - Should appear when app starts
   - `AdMobBridge: ✅ AdMob initialized successfully` - Should appear after initialization
   - `AdMobBridge: Loading interstitial ad...` - Should appear when trying to load ads
   - `AdMobBridge: Interstitial ad loaded` - Should appear when ad is ready
   - Any error messages with "failed" or "error"

### Step 2: Get Your Test Device ID

When you run the app, look in logcat for a message like:
```
Use RequestConfiguration.Builder().setTestDeviceIds(Arrays.asList("YOUR_DEVICE_ID_HERE"))
```

**Copy that device ID** and add it to `AdMobBridge.gd`:

1. Open `scripts/AdMobBridge.gd`
2. Find line ~33: `var test_device_ids: Array[String] = []`
3. Add your device ID:
   ```gdscript
   var test_device_ids: Array[String] = ["YOUR_DEVICE_ID_HERE"]
   ```
4. Rebuild and install

### Step 3: Test Ads Directly (Bypass RemoteConfig)

The issue might be that RemoteConfig is disabling ads. To test directly:

1. **In your game code**, add a test button or call this from console:
   ```gdscript
   # Force show an interstitial ad
   AdMobBridge.test_show_interstitial()
   
   # Or show a rewarded ad
   AdMobBridge.test_show_rewarded()
   
   # Or show a banner
   AdMobBridge.test_show_banner()
   
   # Check status
   AdMobBridge.test_get_status()
   ```

2. **Or modify MainMenu.gd** to add a test button temporarily:
   ```gdscript
   # In _ready() or create a button
   func _on_test_ad_pressed():
       AdMobBridge.test_show_interstitial()
   ```

### Step 4: Check Common Issues

#### Issue 1: AdMob Not Initializing
**Symptoms:** No "AdMob initialized successfully" message in logcat

**Solutions:**
- Check AndroidManifest.xml has the AdMob App ID (should be at line ~30)
- Verify the app ID format: `ca-app-pub-XXXXXXXXXX~YYYYYYYYYY`
- Check logcat for initialization errors

#### Issue 2: Ads Not Loading
**Symptoms:** "Loading interstitial ad..." but no "ad loaded" message

**Solutions:**
- Check internet connection on device
- Verify you're using test ad IDs (they start with `ca-app-pub-3940256099942544`)
- Add your device ID to `test_device_ids` array
- Check logcat for specific error codes

#### Issue 3: Ads Load But Don't Show
**Symptoms:** "ad loaded" message appears but ad doesn't display

**Solutions:**
- Check if `AdsManager` is calling `show_interstitial_requested.emit()`
- Check if `RemoteConfig` has ads enabled (might be disabled)
- Use test functions to bypass AdsManager

#### Issue 4: RemoteConfig Blocking Ads
**Symptoms:** Ads work with test functions but not in game

**Solutions:**
- RemoteConfig might have `ads_enabled: false`
- Check RemoteConfig.gd or Firebase console
- Temporarily modify `AdsManager._should_show_interstitial()` to return `true` for testing

### Step 5: Enable Debug Logging

Add this to see more details. In `AdMobBridge.gd`, add more print statements:

```gdscript
func _show_interstitial() -> void:
    print("AdMobBridge: _show_interstitial called")
    print("  - is_initialized: ", is_initialized)
    print("  - interstitial_loaded: ", interstitial_loaded)
    print("  - interstitial_ad exists: ", interstitial_ad != null)
    # ... rest of function
```

### Step 6: Verify AndroidManifest.xml

Make sure your `android/build/AndroidManifest.xml` has:

```xml
<meta-data
    android:name="com.google.android.gms.ads.APPLICATION_ID"
    android:value="ca-app-pub-3940256099942544~3347511713"/>
```

This should be inside the `<application>` tag.

### Step 7: Check AdMob Plugin Installation

Verify the AdMob plugin files exist:
- `addons/admob/` directory should exist
- Check if Android plugin was downloaded (in `addons/admob/downloads/android/`)

### Step 8: Common Error Codes

If you see error codes in logcat:
- **ERROR_CODE_NO_FILL (3)**: No ads available (normal for test ads sometimes)
- **ERROR_CODE_NETWORK_ERROR (2)**: Network issue, check internet
- **ERROR_CODE_INTERNAL_ERROR (0)**: Internal AdMob error, try again
- **ERROR_CODE_INVALID_REQUEST (1)**: Invalid ad request, check ad unit IDs

### Quick Test Checklist

- [ ] AndroidManifest.xml has AdMob App ID
- [ ] `use_test_ads = true` in AdMobBridge.gd
- [ ] Test device ID added to `test_device_ids` array
- [ ] App rebuilt and reinstalled after changes
- [ ] Internet connection on device
- [ ] Checked logcat for initialization messages
- [ ] Tried test functions (`test_show_interstitial()`)
- [ ] Verified AdMob plugin is installed

### Still Not Working?

1. **Share logcat output** - Copy all AdMob-related messages
2. **Check if test functions work** - If `test_show_interstitial()` works but game ads don't, it's an AdsManager/RemoteConfig issue
3. **Verify plugin version** - Make sure you have the latest AdMob plugin version
4. **Test on emulator first** - Emulator has built-in test device ID support

### Getting Help

When asking for help, provide:
1. Full logcat output (filtered for AdMob)
2. Whether test functions work
3. Your AdMobBridge.gd configuration
4. AndroidManifest.xml snippet (the meta-data section)
5. What happens when you call test functions

