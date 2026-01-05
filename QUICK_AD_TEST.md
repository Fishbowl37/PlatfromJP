# Quick Ad Test Guide

## Immediate Steps to Test Ads

### 1. Check Logcat (Most Important!)

**Connect your phone and run:**
```bash
adb logcat -s AdMobBridge:* MobileAds:* PoingGodotAdMob:*
```

**What to look for:**
- ✅ `AdMobBridge: Initializing AdMob...` - AdMob is starting
- ✅ `AdMobBridge: ✅ AdMob initialized successfully` - AdMob is ready
- ✅ `AdMobBridge: Loading interstitial ad...` - Ad is being requested
- ✅ `AdMobBridge: ✅ Interstitial ad loaded` - Ad is ready to show
- ❌ Any messages with "failed" or "error"

### 2. Get Your Test Device ID

In logcat, look for:
```
Use RequestConfiguration.Builder().setTestDeviceIds(Arrays.asList("XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX"))
```

**Copy that ID** and add it to `scripts/AdMobBridge.gd` line 33:
```gdscript
var test_device_ids: Array[String] = ["YOUR_DEVICE_ID_HERE"]
```

### 3. Test Ads Directly (Bypass Game Logic)

Add this code temporarily to test. In `scripts/MainMenu.gd`, add in `_ready()`:

```gdscript
# TEMPORARY TEST CODE - Remove after testing
func _ready() -> void:
    # ... existing code ...
    
    # Wait 3 seconds for AdMob to initialize, then test
    await get_tree().create_timer(3.0).timeout
    _test_ads()

func _test_ads() -> void:
    print("=== TESTING ADS ===")
    var status = AdMobBridge.test_get_status()
    print("Status: ", status)
    
    if status.is_initialized:
        print("AdMob is initialized! Testing interstitial...")
        AdMobBridge.test_show_interstitial()
    else:
        print("AdMob NOT initialized! Check logcat for errors.")
```

### 4. Quick Checklist

Before testing, verify:
- [ ] AndroidManifest.xml has AdMob App ID (line ~30)
- [ ] `use_test_ads = true` in AdMobBridge.gd (line 28)
- [ ] App rebuilt after any changes
- [ ] Phone has internet connection
- [ ] Checked logcat for initialization messages

### 5. Common Problems & Quick Fixes

**Problem:** "AdMob not initialized" in logcat
- **Fix:** Check AndroidManifest.xml has the meta-data tag with App ID

**Problem:** "Loading ad..." but no "ad loaded"
- **Fix:** Add your test device ID to `test_device_ids` array

**Problem:** Ad loads but doesn't show
- **Fix:** Use `AdMobBridge.test_show_interstitial()` to bypass AdsManager

**Problem:** No ads in game but test functions work
- **Fix:** RemoteConfig is blocking ads. Check `RemoteConfig.are_ads_enabled()`

### 6. What Success Looks Like

When working correctly, you should see in logcat:
```
AdMobBridge: Initializing AdMob...
AdMobBridge: ✅ AdMob initialized successfully
AdMobBridge: Adapter 'com.google.android.gms.ads' - State: READY ✅
AdMobBridge: Loading interstitial ad...
AdMobBridge: ✅ Interstitial ad loaded
AdMobBridge: Showing interstitial
```

Then an ad should appear on screen!

### 7. Still Not Working?

Run this command to get ALL AdMob-related logs:
```bash
adb logcat | grep -iE "admob|mobileads|ad.*load|ad.*fail|ad.*error" > admob_logs.txt
```

Then share the `admob_logs.txt` file for debugging.

