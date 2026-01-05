extends Node
## Ads Manager
## 
## Handles ad display logic based on Firebase RemoteConfig settings.
## Add this as an autoload: Project Settings > AutoLoad > Add AdsManager.gd
## 
## INTEGRATION NOTES:
## This manager provides the LOGIC for when to show ads.
## You need to integrate an actual ad SDK plugin for your platform:
## - AdMob: https://github.com/poing-studios/godot-admob-plugin
## - Or use Godot Asset Library to find "admob" plugins

# =============================================================================
# SIGNALS
# =============================================================================

## Emitted when an interstitial ad should be shown
signal show_interstitial_requested
## Emitted when a rewarded ad should be shown
signal show_rewarded_requested(reward_type: String)
## Emitted when a rewarded ad completes successfully
signal rewarded_ad_completed(reward_type: String)
## Emitted when user closes/skips rewarded ad without completing
signal rewarded_ad_skipped(reward_type: String)
## Emitted when banner visibility should change
signal banner_visibility_changed(visible: bool)
## Emitted when interstitial ad is closed/dismissed
signal interstitial_closed

# =============================================================================
# STATE
# =============================================================================

## Reference to RemoteConfig autoload
var remote_config: Node = null

## Fallback mode: Enable ads even if RemoteConfig isn't configured
## Set to false when you have Firebase RemoteConfig properly set up
var use_fallback_ads: bool = true

## Fallback interstitial frequency (show every N game overs)
## Change this to adjust how often ads show in fallback mode
var fallback_interstitial_frequency: int = 3

## Tracking variables
var game_over_count: int = 0
var session_count: int = 0
var last_interstitial_time: int = 0
var pending_reward_type: String = ""
var is_showing_interstitial: bool = false

## Session persistence
const SESSION_SAVE_PATH = "user://ads_session.cfg"

# =============================================================================
# LIFECYCLE
# =============================================================================

func _ready() -> void:
	_load_session_data()
	_increment_session()
	
	# Wait a frame for other autoloads to initialize
	await get_tree().process_frame
	_connect_to_remote_config()

func _connect_to_remote_config() -> void:
	if has_node("/root/RemoteConfig"):
		remote_config = get_node("/root/RemoteConfig")
	else:
		push_warning("AdsManager: RemoteConfig autoload not found!")

# =============================================================================
# PUBLIC API - Call these from your game code
# =============================================================================

## Call this when a game ends (game over)
## Returns true if an interstitial ad will be shown
func on_game_over() -> bool:
	game_over_count += 1
	_save_session_data()
	
	if _should_show_interstitial():
		_request_interstitial()
		return true
	
	return false

## Check if "continue game" rewarded ad is available
func can_show_continue_ad() -> bool:
	# Fallback mode: Always allow if RemoteConfig isn't available
	if use_fallback_ads and (not remote_config or not remote_config.is_rewarded_enabled()):
		return true
	if not remote_config:
		return false
	return remote_config.is_reward_type_enabled("continue")

## Request rewarded ad to continue game
## Listen to rewarded_ad_completed signal for result
func show_continue_ad() -> void:
	if can_show_continue_ad():
		_request_rewarded("continue")

## Check if "double coins" rewarded ad is available
func can_show_double_coins_ad() -> bool:
	# Fallback mode: Always allow if RemoteConfig isn't available
	if use_fallback_ads and (not remote_config or not remote_config.is_rewarded_enabled()):
		return true
	if not remote_config:
		return false
	return remote_config.is_reward_type_enabled("double_coins")

## Request rewarded ad for double coins
## Listen to rewarded_ad_completed signal for result
func show_double_coins_ad() -> void:
	if can_show_double_coins_ad():
		_request_rewarded("double_coins")

## Get the multiplier for double coins reward
func get_double_coins_multiplier() -> float:
	if not remote_config:
		return 2.0
	return remote_config.get_rewarded_multiplier()

## Check if banner should show in menu
func should_show_banner_in_menu() -> bool:
	# Fallback mode: Allow banner if RemoteConfig isn't available
	if use_fallback_ads and (not remote_config or not remote_config.is_banner_enabled()):
		return true
	if not remote_config:
		return false
	return remote_config.is_banner_enabled()

## Check if banner should show during gameplay
func should_show_banner_in_game() -> bool:
	# Usually you don't want banners during gameplay
	return false

## Show or hide banner ad
func set_banner_visible(visible: bool) -> void:
	banner_visibility_changed.emit(visible)

## Get banner position ("top" or "bottom")
func get_banner_position() -> String:
	if not remote_config:
		return "bottom"
	return remote_config.get_banner_position()

## Reset game over counter (call on app fresh start if desired)
func reset_game_over_count() -> void:
	game_over_count = 0
	_save_session_data()

# =============================================================================
# AD SDK CALLBACKS - Connect your ad plugin's signals to these methods
# =============================================================================

## Call when interstitial is closed (by user or after display)
func on_interstitial_closed() -> void:
	last_interstitial_time = Time.get_unix_time_from_system()
	is_showing_interstitial = false
	interstitial_closed.emit()

## Call when rewarded ad completes (user watched the full ad)
func on_rewarded_completed() -> void:
	if pending_reward_type != "":
		rewarded_ad_completed.emit(pending_reward_type)
		pending_reward_type = ""

## Call when rewarded ad is skipped or closed early
func on_rewarded_skipped() -> void:
	if pending_reward_type != "":
		rewarded_ad_skipped.emit(pending_reward_type)
		pending_reward_type = ""

## Call when any ad fails to load
func on_ad_failed(ad_type: String, error: String) -> void:
	push_warning("AdsManager: %s ad failed - %s" % [ad_type, error])
	if ad_type == "rewarded":
		pending_reward_type = ""
	elif ad_type == "interstitial":
		# If interstitial failed, we're not showing it anymore
		is_showing_interstitial = false
		interstitial_closed.emit()

# =============================================================================
# INTERNAL LOGIC
# =============================================================================

func _should_show_interstitial() -> bool:
	# Fallback mode: Show ads every 3rd game over if RemoteConfig isn't available
	if use_fallback_ads and (not remote_config or not remote_config.is_interstitial_enabled()):
		# Simple fallback: Show every 3rd game over, with 30 second cooldown
		var time_since_last = Time.get_unix_time_from_system() - last_interstitial_time
		if time_since_last < 30:  # 30 second cooldown
			return false
		if session_count <= 1:  # Skip first session
			return false
		return game_over_count > 0 and game_over_count % fallback_interstitial_frequency == 0
	
	# Normal mode: Use RemoteConfig settings
	if not remote_config:
		return false
	
	if not remote_config.is_interstitial_enabled():
		return false
	
	# Check cooldown
	var cooldown = remote_config.get_interstitial_cooldown()
	var time_since_last = Time.get_unix_time_from_system() - last_interstitial_time
	if time_since_last < cooldown:
		return false
	
	# Skip first N sessions for new players
	var skip_sessions = remote_config.get_interstitial_skip_sessions()
	if session_count <= skip_sessions:
		return false
	
	# Show every N game overs
	var frequency = remote_config.get_interstitial_frequency()
	if frequency <= 0:
		return false
	
	return game_over_count > 0 and game_over_count % frequency == 0

func _request_interstitial() -> void:
	last_interstitial_time = Time.get_unix_time_from_system()
	show_interstitial_requested.emit()
	# Don't set is_showing_interstitial yet - wait until ad is actually shown

func _request_rewarded(reward_type: String) -> void:
	pending_reward_type = reward_type
	show_rewarded_requested.emit(reward_type)

# =============================================================================
# SESSION PERSISTENCE
# =============================================================================

func _increment_session() -> void:
	session_count += 1
	_save_session_data()

func _load_session_data() -> void:
	var config = ConfigFile.new()
	if config.load(SESSION_SAVE_PATH) == OK:
		session_count = config.get_value("ads", "session_count", 0)
		game_over_count = config.get_value("ads", "game_over_count", 0)
		last_interstitial_time = config.get_value("ads", "last_interstitial_time", 0)

func _save_session_data() -> void:
	var config = ConfigFile.new()
	config.set_value("ads", "session_count", session_count)
	config.set_value("ads", "game_over_count", game_over_count)
	config.set_value("ads", "last_interstitial_time", last_interstitial_time)
	config.save(SESSION_SAVE_PATH)

