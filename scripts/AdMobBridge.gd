extends Node
## AdMob Bridge
## 
## Connects the AdsManager logic to the actual AdMob plugin.
## Add this as an autoload: Project Settings > AutoLoad > Add AdMobBridge.gd
## 
## SETUP:
## 1. Replace the ad unit IDs below with your real IDs from admob.google.com
## 2. For testing, use Google's test IDs (already set as defaults)

# =============================================================================
# AD UNIT IDS - Replace with your real IDs from AdMob console!
# =============================================================================

## Test IDs (safe to use during development - won't get you banned)
const TEST_BANNER_ID = "ca-app-pub-3940256099942544/6300978111"
const TEST_INTERSTITIAL_ID = "ca-app-pub-3940256099942544/1033173712"
const TEST_REWARDED_ID = "ca-app-pub-3940256099942544/5224354917"

## Your real IDs - REPLACE THESE before publishing!
var banner_id: String = TEST_BANNER_ID
var interstitial_id: String = TEST_INTERSTITIAL_ID
var rewarded_id: String = TEST_REWARDED_ID

## Set to false when you have real ad IDs and are ready to publish
var use_test_ads: bool = true

# =============================================================================
# STATE
# =============================================================================

var admob_plugin = null
var ads_manager: Node = null

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
	# Check if AdMob singleton exists (only on Android/iOS)
	if Engine.has_singleton("AdMob"):
		admob_plugin = Engine.get_singleton("AdMob")
		print("AdMobBridge: AdMob plugin found!")
		_setup_admob()
	else:
		push_warning("AdMobBridge: AdMob plugin not found. Ads only work on Android/iOS exports.")
		return
	
	# Connect to AdsManager
	_connect_to_ads_manager()

func _setup_admob() -> void:
	if not admob_plugin:
		return
	
	# Initialize AdMob
	# Note: The exact initialization may vary based on which AdMob plugin you installed
	# Check the plugin's documentation for the correct method
	
	if admob_plugin.has_method("initialize"):
		admob_plugin.initialize()
	elif admob_plugin.has_method("init"):
		admob_plugin.init(use_test_ads)
	
	# Connect signals - these vary by plugin, common ones listed
	_connect_admob_signals()
	
	is_initialized = true
	print("AdMobBridge: Initialized successfully")
	
	# Pre-load ads
	_load_interstitial()
	_load_rewarded()

func _connect_admob_signals() -> void:
	if not admob_plugin:
		return
	
	# Interstitial signals
	if admob_plugin.has_signal("interstitial_loaded"):
		admob_plugin.interstitial_loaded.connect(_on_interstitial_loaded)
	if admob_plugin.has_signal("interstitial_closed"):
		admob_plugin.interstitial_closed.connect(_on_interstitial_closed)
	if admob_plugin.has_signal("interstitial_failed_to_load"):
		admob_plugin.interstitial_failed_to_load.connect(_on_interstitial_failed)
	
	# Rewarded signals
	if admob_plugin.has_signal("rewarded_ad_loaded"):
		admob_plugin.rewarded_ad_loaded.connect(_on_rewarded_loaded)
	if admob_plugin.has_signal("rewarded_ad_closed"):
		admob_plugin.rewarded_ad_closed.connect(_on_rewarded_closed)
	if admob_plugin.has_signal("rewarded_interstitial_ad_earned_reward"):
		admob_plugin.rewarded_interstitial_ad_earned_reward.connect(_on_rewarded_earned)
	if admob_plugin.has_signal("user_earned_reward"):
		admob_plugin.user_earned_reward.connect(_on_rewarded_earned)
	if admob_plugin.has_signal("rewarded_ad_failed_to_load"):
		admob_plugin.rewarded_ad_failed_to_load.connect(_on_rewarded_failed)
	
	# Banner signals
	if admob_plugin.has_signal("banner_loaded"):
		admob_plugin.banner_loaded.connect(_on_banner_loaded)
	if admob_plugin.has_signal("banner_failed_to_load"):
		admob_plugin.banner_failed_to_load.connect(_on_banner_failed)

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
	if not admob_plugin or not is_initialized:
		return
	
	var ad_id = TEST_INTERSTITIAL_ID if use_test_ads else interstitial_id
	
	if admob_plugin.has_method("load_interstitial"):
		admob_plugin.load_interstitial(ad_id)
		print("AdMobBridge: Loading interstitial...")
	elif admob_plugin.has_method("loadInterstitial"):
		admob_plugin.loadInterstitial(ad_id)

func _load_rewarded() -> void:
	if not admob_plugin or not is_initialized:
		return
	
	var ad_id = TEST_REWARDED_ID if use_test_ads else rewarded_id
	
	if admob_plugin.has_method("load_rewarded"):
		admob_plugin.load_rewarded(ad_id)
		print("AdMobBridge: Loading rewarded ad...")
	elif admob_plugin.has_method("loadRewardedAd"):
		admob_plugin.loadRewardedAd(ad_id)

func _load_banner() -> void:
	if not admob_plugin or not is_initialized:
		return
	
	var ad_id = TEST_BANNER_ID if use_test_ads else banner_id
	var position = _get_banner_position()
	
	if admob_plugin.has_method("load_banner"):
		admob_plugin.load_banner(ad_id, position)
		print("AdMobBridge: Loading banner...")

# =============================================================================
# AD DISPLAY - Called by AdsManager signals
# =============================================================================

func _show_interstitial() -> void:
	if not admob_plugin:
		print("AdMobBridge: No plugin, simulating interstitial")
		# Simulate for testing in editor
		await get_tree().create_timer(0.5).timeout
		_on_interstitial_closed()
		return
	
	if interstitial_loaded:
		if admob_plugin.has_method("show_interstitial"):
			admob_plugin.show_interstitial()
		elif admob_plugin.has_method("showInterstitial"):
			admob_plugin.showInterstitial()
		print("AdMobBridge: Showing interstitial")
	else:
		print("AdMobBridge: Interstitial not loaded yet")
		_load_interstitial()

func _show_rewarded(_reward_type: String) -> void:
	if not admob_plugin:
		print("AdMobBridge: No plugin, simulating rewarded ad")
		# Simulate for testing in editor
		await get_tree().create_timer(1.0).timeout
		_on_rewarded_earned()
		return
	
	if rewarded_loaded:
		if admob_plugin.has_method("show_rewarded"):
			admob_plugin.show_rewarded()
		elif admob_plugin.has_method("showRewardedAd"):
			admob_plugin.showRewardedAd()
		print("AdMobBridge: Showing rewarded ad")
	else:
		print("AdMobBridge: Rewarded ad not loaded yet")
		_load_rewarded()

func _set_banner_visible(visible: bool) -> void:
	if not admob_plugin:
		print("AdMobBridge: Banner visibility set to %s (no plugin)" % visible)
		return
	
	if visible:
		if not banner_loaded:
			_load_banner()
		if admob_plugin.has_method("show_banner"):
			admob_plugin.show_banner()
	else:
		if admob_plugin.has_method("hide_banner"):
			admob_plugin.hide_banner()

func _get_banner_position() -> int:
	# Most plugins use: 0 = TOP, 1 = BOTTOM
	if ads_manager:
		var pos = ads_manager.get_banner_position()
		return 0 if pos == "top" else 1
	return 1  # Default to bottom

# =============================================================================
# ADMOB CALLBACKS
# =============================================================================

func _on_interstitial_loaded() -> void:
	interstitial_loaded = true
	print("AdMobBridge: Interstitial loaded")

func _on_interstitial_closed() -> void:
	interstitial_loaded = false
	print("AdMobBridge: Interstitial closed")
	
	# Notify AdsManager
	if ads_manager:
		ads_manager.on_interstitial_closed()
	
	# Pre-load next ad
	_load_interstitial()

func _on_interstitial_failed(error_code: int = 0) -> void:
	interstitial_loaded = false
	print("AdMobBridge: Interstitial failed to load (error: %d)" % error_code)
	
	if ads_manager:
		ads_manager.on_ad_failed("interstitial", str(error_code))
	
	# Retry after delay
	await get_tree().create_timer(30.0).timeout
	_load_interstitial()

func _on_rewarded_loaded() -> void:
	rewarded_loaded = true
	print("AdMobBridge: Rewarded ad loaded")

func _on_rewarded_earned(_reward_type: String = "", _amount: int = 0) -> void:
	print("AdMobBridge: Reward earned!")
	
	# Notify AdsManager
	if ads_manager:
		ads_manager.on_rewarded_completed()

func _on_rewarded_closed() -> void:
	rewarded_loaded = false
	print("AdMobBridge: Rewarded ad closed")
	
	# Pre-load next ad
	_load_rewarded()

func _on_rewarded_failed(error_code: int = 0) -> void:
	rewarded_loaded = false
	print("AdMobBridge: Rewarded ad failed to load (error: %d)" % error_code)
	
	if ads_manager:
		ads_manager.on_ad_failed("rewarded", str(error_code))
	
	# Retry after delay
	await get_tree().create_timer(30.0).timeout
	_load_rewarded()

func _on_banner_loaded() -> void:
	banner_loaded = true
	print("AdMobBridge: Banner loaded")

func _on_banner_failed(error_code: int = 0) -> void:
	banner_loaded = false
	print("AdMobBridge: Banner failed to load (error: %d)" % error_code)

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

