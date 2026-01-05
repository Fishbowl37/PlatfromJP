extends Node
## AdMob Bridge
## 
## Connects the AdsManager logic to the actual AdMob plugin.
## Add this as an autoload: Project Settings > AutoLoad > Add AdMobBridge.gd
## 
## SETUP:
## 1. Replace the ad unit IDs below with your real IDs from admob.google.com
## 2. For testing, use Google's test IDs (already set as defaults)
## 3. To see test ads on your phone, add your device ID to test_device_ids array
##    (Check logcat for "Use RequestConfiguration.Builder().setTestDeviceIds" message)

# =============================================================================
# AD UNIT IDS - Replace with your real IDs from AdMob console!
# =============================================================================

## Test IDs (safe to use during development - won't get you banned)
const TEST_BANNER_ID = "ca-app-pub-3940256099942544/6300978111"
const TEST_INTERSTITIAL_ID = "ca-app-pub-3940256099942544/1033173712"
const TEST_REWARDED_ID = "ca-app-pub-3940256099942544/5224354917"

## Your real IDs - REPLACE THESE before publishing!
var banner_id: String = "ca-app-pub-2751343799151510/7152392744"
var interstitial_id: String = "ca-app-pub-2751343799151510/6452203527"
var rewarded_id: String = "ca-app-pub-2751343799151510/6748728750"

## Set to false when you have real ad IDs and are ready to publish
var use_test_ads: bool = true

## Add your test device IDs here to see test ads on real devices
## To find your device ID, run the app and check logcat for a message like:
## "Use RequestConfiguration.Builder().setTestDeviceIds(Arrays.asList("YOUR_DEVICE_ID"))
var test_device_ids: Array[String] = []

# =============================================================================
# STATE
# =============================================================================

var ads_manager: Node = null

var interstitial_ad: InterstitialAd = null
var rewarded_ad: RewardedAd = null
var ad_view: AdView = null

var interstitial_loaded: bool = false
var rewarded_loaded: bool = false
var banner_loaded: bool = false

var is_initialized: bool = false

# =============================================================================
# LIFECYCLE
# =============================================================================

func _ready() -> void:
	# Wait a frame for other autoloads
	await get_tree().process_frame
	_initialize()

func _initialize() -> void:
	# Check if we're on Android/iOS (AdMob only works on mobile)
	if OS.get_name() != "Android" and OS.get_name() != "iOS":
		push_warning("AdMobBridge: AdMob only works on Android/iOS. Running in editor mode.")
		return
	
	# Initialize AdMob
	_setup_admob()
	
	# Connect to AdsManager
	_connect_to_ads_manager()

func _setup_admob() -> void:
	# Set up RequestConfiguration for test devices
	var request_configuration := RequestConfiguration.new()
	
	# Add test device IDs if in test mode
	if use_test_ads:
		# Add emulator test device ID
		request_configuration.test_device_ids.append(RequestConfiguration.DEVICE_ID_EMULATOR)
		# Add any custom test device IDs
		for device_id in test_device_ids:
			request_configuration.test_device_ids.append(device_id)
	
	# Set request configuration BEFORE initializing
	MobileAds.set_request_configuration(request_configuration)
	
	# Set up initialization listener
	var on_initialization_complete_listener := OnInitializationCompleteListener.new()
	on_initialization_complete_listener.on_initialization_complete = _on_initialization_complete
	
	# Initialize MobileAds
	MobileAds.initialize(on_initialization_complete_listener)
	print("AdMobBridge: Initializing AdMob...")

func _on_initialization_complete(initialization_status: InitializationStatus) -> void:
	is_initialized = true
	print("AdMobBridge: ✅ AdMob initialized successfully")
	
	# Print initialization status for debugging
	var all_ready = true
	for key in initialization_status.adapter_status_map:
		var adapter_status: AdapterStatus = initialization_status.adapter_status_map[key]
		var state_str = ""
		match adapter_status.initialization_state:
			AdapterStatus.InitializationState.READY:
				state_str = "READY ✅"
			AdapterStatus.InitializationState.NOT_READY:
				state_str = "NOT_READY ❌"
				all_ready = false
			_:
				state_str = "UNKNOWN"
		print("AdMobBridge: Adapter '%s' - State: %s (Latency: %dms, Desc: %s)" % [key, state_str, adapter_status.latency, adapter_status.description])
	
	if not all_ready:
		push_warning("AdMobBridge: ⚠️ Some adapters are not ready. Ads may not work properly.")
	
	# Pre-load ads
	print("AdMobBridge: Starting to pre-load ads...")
	_load_interstitial()
	_load_rewarded()

func _connect_to_ads_manager() -> void:
	if has_node("/root/AdsManager"):
		ads_manager = get_node("/root/AdsManager")
		ads_manager.show_interstitial_requested.connect(_show_interstitial)
		ads_manager.show_rewarded_requested.connect(_show_rewarded)
		ads_manager.banner_visibility_changed.connect(_set_banner_visible)
		print("AdMobBridge: Connected to AdsManager")
	else:
		push_warning("AdMobBridge: AdsManager autoload not found!")

# =============================================================================
# AD LOADING
# =============================================================================

func _load_interstitial() -> void:
	if not is_initialized:
		return
	
	var ad_id = TEST_INTERSTITIAL_ID if use_test_ads else interstitial_id
	
	# Destroy existing ad if any
	if interstitial_ad:
		interstitial_ad.destroy()
		interstitial_ad = null
	
	# Create full screen content callback
	var full_screen_content_callback := FullScreenContentCallback.new()
	full_screen_content_callback.on_ad_dismissed_full_screen_content = _on_interstitial_dismissed
	full_screen_content_callback.on_ad_failed_to_show_full_screen_content = _on_interstitial_failed_to_show
	
	# Create load callback
	var interstitial_ad_load_callback := InterstitialAdLoadCallback.new()
	interstitial_ad_load_callback.on_ad_loaded = func(ad: InterstitialAd) -> void:
		interstitial_ad = ad
		interstitial_ad.full_screen_content_callback = full_screen_content_callback
		interstitial_loaded = true
		print("AdMobBridge: ✅ Interstitial ad loaded")
	interstitial_ad_load_callback.on_ad_failed_to_load = _on_interstitial_ad_failed_to_load
	
	# Load the ad
	var ad_request := AdRequest.new()
	var loader := InterstitialAdLoader.new()
	loader.load(ad_id, ad_request, interstitial_ad_load_callback)
	print("AdMobBridge: Loading interstitial ad...")

func _load_rewarded() -> void:
	if not is_initialized:
		return
	
	var ad_id = TEST_REWARDED_ID if use_test_ads else rewarded_id
	
	# Destroy existing ad if any
	if rewarded_ad:
		rewarded_ad.destroy()
		rewarded_ad = null
	
	# Create full screen content callback
	var full_screen_content_callback := FullScreenContentCallback.new()
	full_screen_content_callback.on_ad_dismissed_full_screen_content = _on_rewarded_dismissed
	full_screen_content_callback.on_ad_failed_to_show_full_screen_content = _on_rewarded_failed_to_show
	
	# Create load callback
	var rewarded_ad_load_callback := RewardedAdLoadCallback.new()
	rewarded_ad_load_callback.on_ad_loaded = func(ad: RewardedAd) -> void:
		rewarded_ad = ad
		rewarded_ad.full_screen_content_callback = full_screen_content_callback
		rewarded_loaded = true
		print("AdMobBridge: ✅ Rewarded ad loaded")
	rewarded_ad_load_callback.on_ad_failed_to_load = _on_rewarded_ad_failed_to_load
	
	# Load the ad
	var ad_request := AdRequest.new()
	var loader := RewardedAdLoader.new()
	loader.load(ad_id, ad_request, rewarded_ad_load_callback)
	print("AdMobBridge: Loading rewarded ad...")

func _load_banner() -> void:
	if not is_initialized:
		return
	
	var ad_id = TEST_BANNER_ID if use_test_ads else banner_id
	
	# Destroy existing banner if any
	if ad_view:
		ad_view.destroy()
		ad_view = null
	
	# Determine position
	var position = AdPosition.Values.BOTTOM
	if ads_manager:
		var pos_str = ads_manager.get_banner_position()
		match pos_str:
			"top":
				position = AdPosition.Values.TOP
			"bottom":
				position = AdPosition.Values.BOTTOM
	
	# Create AdView
	var ad_size := AdSize.get_current_orientation_anchored_adaptive_banner_ad_size(AdSize.FULL_WIDTH)
	ad_view = AdView.new(ad_id, ad_size, position)
	
	# Set up ad listener
	var ad_listener := AdListener.new()
	ad_listener.on_ad_loaded = _on_banner_loaded
	ad_listener.on_ad_failed_to_load = _on_banner_failed
	ad_view.ad_listener = ad_listener
	
	# Load the ad
	var ad_request := AdRequest.new()
	ad_view.load_ad(ad_request)
	print("AdMobBridge: Loading banner ad...")

# =============================================================================
# AD DISPLAY - Called by AdsManager signals
# =============================================================================

func _show_interstitial() -> void:
	if not is_initialized:
		print("AdMobBridge: AdMob not initialized, simulating interstitial")
		# Simulate for testing in editor
		await get_tree().create_timer(0.5).timeout
		if ads_manager:
			ads_manager.on_interstitial_closed()
		return
	
	if interstitial_loaded and interstitial_ad:
		interstitial_ad.show()
		print("AdMobBridge: Showing interstitial")
	else:
		print("AdMobBridge: Interstitial not loaded yet")
		_load_interstitial()

func _show_rewarded(_reward_type: String) -> void:
	if not is_initialized:
		print("AdMobBridge: AdMob not initialized, simulating rewarded ad")
		# Simulate for testing in editor
		await get_tree().create_timer(1.0).timeout
		if ads_manager:
			ads_manager.on_rewarded_completed()
		return
	
	if rewarded_loaded and rewarded_ad:
		# Create reward listener
		var on_user_earned_reward_listener := OnUserEarnedRewardListener.new()
		on_user_earned_reward_listener.on_user_earned_reward = _on_rewarded_earned
		rewarded_ad.show(on_user_earned_reward_listener)
		print("AdMobBridge: Showing rewarded ad")
	else:
		print("AdMobBridge: Rewarded ad not loaded yet")
		_load_rewarded()

func _set_banner_visible(visible: bool) -> void:
	if not is_initialized:
		print("AdMobBridge: Banner visibility set to %s (not initialized)" % visible)
		return
	
	if visible:
		if not banner_loaded or not ad_view:
			_load_banner()
		if ad_view:
			ad_view.show()
	else:
		if ad_view:
			ad_view.hide()

# =============================================================================
# ADMOB CALLBACKS
# =============================================================================


func _on_interstitial_ad_failed_to_load(error: LoadAdError) -> void:
	interstitial_loaded = false
	print("AdMobBridge: Interstitial failed to load - %s (code: %d)" % [error.message, error.code])
	
	if ads_manager:
		ads_manager.on_ad_failed("interstitial", error.message)
	
	# Retry after delay
	await get_tree().create_timer(30.0).timeout
	_load_interstitial()

func _on_interstitial_dismissed() -> void:
	interstitial_loaded = false
	interstitial_ad = null
	print("AdMobBridge: Interstitial dismissed")
	
	# Notify AdsManager
	if ads_manager:
		ads_manager.on_interstitial_closed()
	
	# Pre-load next ad
	_load_interstitial()

func _on_interstitial_failed_to_show(error: AdError) -> void:
	print("AdMobBridge: Interstitial failed to show - %s" % error.message)
	interstitial_loaded = false
	interstitial_ad = null
	_load_interstitial()


func _on_rewarded_ad_failed_to_load(error: LoadAdError) -> void:
	rewarded_loaded = false
	print("AdMobBridge: Rewarded ad failed to load - %s (code: %d)" % [error.message, error.code])
	
	if ads_manager:
		ads_manager.on_ad_failed("rewarded", error.message)
	
	# Retry after delay
	await get_tree().create_timer(30.0).timeout
	_load_rewarded()

func _on_rewarded_dismissed() -> void:
	rewarded_loaded = false
	rewarded_ad = null
	print("AdMobBridge: Rewarded ad dismissed")
	
	# Pre-load next ad
	_load_rewarded()

func _on_rewarded_failed_to_show(error: AdError) -> void:
	print("AdMobBridge: Rewarded ad failed to show - %s" % error.message)
	rewarded_loaded = false
	rewarded_ad = null
	_load_rewarded()

func _on_rewarded_earned(rewarded_item: RewardedItem) -> void:
	print("AdMobBridge: Reward earned! Type: %s, Amount: %d" % [rewarded_item.type, rewarded_item.amount])
	
	# Notify AdsManager
	if ads_manager:
		ads_manager.on_rewarded_completed()

func _on_banner_loaded() -> void:
	banner_loaded = true
	print("AdMobBridge: Banner loaded")

func _on_banner_failed(error: LoadAdError) -> void:
	banner_loaded = false
	print("AdMobBridge: Banner failed to load - %s (code: %d)" % [error.message, error.code])

# =============================================================================
# PUBLIC API - For manually setting real ad IDs
# =============================================================================

## Call this to switch to production ads with your real IDs
func set_production_ads(real_banner: String, real_interstitial: String, real_rewarded: String) -> void:
	banner_id = real_banner
	interstitial_id = real_interstitial
	rewarded_id = real_rewarded
	use_test_ads = false
	print("AdMobBridge: Switched to production ad IDs")

## Add a test device ID to see test ads on your device
## Find your device ID in logcat when running the app
func add_test_device_id(device_id: String) -> void:
	if device_id not in test_device_ids:
		test_device_ids.append(device_id)
		print("AdMobBridge: Added test device ID: %s" % device_id)

# =============================================================================
# TEST FUNCTIONS - Use these to test ads directly (bypasses AdsManager/RemoteConfig)
# =============================================================================

## Test function: Force show an interstitial ad (for debugging)
func test_show_interstitial() -> void:
	print("AdMobBridge: TEST - Force showing interstitial")
	_show_interstitial()

## Test function: Force show a rewarded ad (for debugging)
func test_show_rewarded() -> void:
	print("AdMobBridge: TEST - Force showing rewarded ad")
	_show_rewarded("test")

## Test function: Force show a banner ad (for debugging)
func test_show_banner() -> void:
	print("AdMobBridge: TEST - Force showing banner")
	_set_banner_visible(true)

## Test function: Check AdMob status
func test_get_status() -> Dictionary:
	var status = {
		"is_initialized": is_initialized,
		"interstitial_loaded": interstitial_loaded,
		"rewarded_loaded": rewarded_loaded,
		"banner_loaded": banner_loaded,
		"use_test_ads": use_test_ads,
		"os_name": OS.get_name()
	}
	print("AdMobBridge: TEST - Status: ", status)
	return status
