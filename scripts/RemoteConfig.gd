extends Node
## Firebase Remote Configuration Manager
## 
## Fetches game configuration from Firebase Firestore.
## Add this as an autoload: Project Settings > AutoLoad > Add RemoteConfig.gd
##
## NO PLUGINS REQUIRED - uses Firebase REST API directly.

# =============================================================================
# CONFIGURATION - Set your Firebase Project ID here
# =============================================================================

## Your Firebase Project ID (from Firebase Console > Project Settings)
const FIREBASE_PROJECT_ID = "platformjp-b7acd"

## Firestore REST API base URL
var FIRESTORE_URL: String:
	get: return "https://firestore.googleapis.com/v1/projects/%s/databases/(default)/documents" % FIREBASE_PROJECT_ID

## Use fallback config if Firebase is unreachable
const USE_FALLBACK_ON_ERROR = true

# =============================================================================
# SIGNALS
# =============================================================================

signal config_loaded(config: Dictionary)
signal config_error(error: String)
signal ads_config_loaded(ads_config: Dictionary)
signal update_available(version_info: Dictionary)
signal announcement_received(announcement: Dictionary)

# =============================================================================
# STATE
# =============================================================================

var game_config: Dictionary = {}
var ads_config: Dictionary = {}
var announcements: Array = []
var is_loaded: bool = false

## Announcements that have been shown (persisted locally)
var shown_announcements: Array = []
const ANNOUNCEMENTS_SAVE_PATH = "user://shown_announcements.cfg"

# =============================================================================
# LIFECYCLE
# =============================================================================

func _ready() -> void:
	_load_shown_announcements()
	
	# Fetch all config on startup
	fetch_all_config()

# =============================================================================
# PUBLIC API
# =============================================================================

## Fetch all configuration from Firebase
func fetch_all_config() -> void:
	_fetch_game_config()
	_fetch_ads_config()
	_fetch_announcements()

## Manually refresh config
func refresh() -> void:
	fetch_all_config()

# =============================================================================
# CONFIG GETTERS
# =============================================================================

## Get current game version from config
func get_server_version() -> String:
	return game_config.get("version_current", "0.0.0")

## Get minimum supported version
func get_minimum_version() -> String:
	return game_config.get("version_minimum", "0.0.0")

## Check if current client version is supported
func is_version_supported(client_version: String) -> bool:
	var min_version = get_minimum_version()
	return _compare_versions(client_version, min_version) >= 0

## Check if a force update is required
func is_force_update_required() -> bool:
	return game_config.get("force_update", false)

## Get update URL (app store link)
func get_update_url() -> String:
	return game_config.get("version_update_url", "")

## Check if a feature is enabled
func is_feature_enabled(feature_name: String) -> bool:
	# Map common feature names to config keys
	var key = feature_name + "_enabled" if not feature_name.ends_with("_enabled") else feature_name
	return game_config.get(key, true)

## Get a balance/multiplier value
func get_multiplier(key: String) -> float:
	return game_config.get(key, 1.0)

## Get coin multiplier (for events)
func get_coin_multiplier() -> float:
	return game_config.get("coin_multiplier", 1.0)

## Get score multiplier (for events)
func get_score_multiplier() -> float:
	return game_config.get("score_multiplier", 1.0)

## Get pending announcements (not yet shown)
func get_pending_announcements() -> Array:
	var pending = []
	for ann in announcements:
		if not ann.get("active", false):
			continue
		var ann_id = ann.get("id", "")
		if ann.get("show_once", false) and ann_id in shown_announcements:
			continue
		pending.append(ann)
	return pending

## Mark announcement as shown
func mark_announcement_shown(announcement_id: String) -> void:
	if announcement_id not in shown_announcements:
		shown_announcements.append(announcement_id)
		_save_shown_announcements()

# =============================================================================
# ADS CONFIG GETTERS
# =============================================================================

## Check if ads are enabled globally
func are_ads_enabled() -> bool:
	return ads_config.get("ads_enabled", false)

## Check if interstitial ads are enabled
func is_interstitial_enabled() -> bool:
	return are_ads_enabled() and ads_config.get("interstitial_enabled", false)

## Get interstitial frequency (show every N game overs)
func get_interstitial_frequency() -> int:
	return int(ads_config.get("interstitial_frequency", 3))

## Get interstitial cooldown in seconds
func get_interstitial_cooldown() -> int:
	return int(ads_config.get("interstitial_cooldown", 60))

## Get number of sessions to skip for new players
func get_interstitial_skip_sessions() -> int:
	return int(ads_config.get("interstitial_skip_sessions", 2))

## Check if rewarded ads are enabled
func is_rewarded_enabled() -> bool:
	return are_ads_enabled() and ads_config.get("rewarded_enabled", false)

## Check if specific reward type is enabled
func is_reward_type_enabled(reward_type: String) -> bool:
	if not is_rewarded_enabled():
		return false
	var key = "rewarded_" + reward_type
	return ads_config.get(key, false)

## Get rewarded ad multiplier (for double coins, etc.)
func get_rewarded_multiplier() -> float:
	return ads_config.get("rewarded_multiplier", 2.0)

## Check if banner ads are enabled
func is_banner_enabled() -> bool:
	return are_ads_enabled() and ads_config.get("banner_enabled", false)

## Get banner position ("top" or "bottom")
func get_banner_position() -> String:
	return ads_config.get("banner_position", "bottom")

# =============================================================================
# FIREBASE FETCHING
# =============================================================================

func _fetch_game_config() -> void:
	var http = HTTPRequest.new()
	add_child(http)
	http.request_completed.connect(_on_game_config_received.bind(http))
	
	var url = FIRESTORE_URL + "/config/game"
	var error = http.request(url)
	if error != OK:
		_handle_error("Failed to request game config")
		http.queue_free()

func _fetch_ads_config() -> void:
	var http = HTTPRequest.new()
	add_child(http)
	http.request_completed.connect(_on_ads_config_received.bind(http))
	
	var url = FIRESTORE_URL + "/config/ads"
	var error = http.request(url)
	if error != OK:
		_handle_error("Failed to request ads config")
		http.queue_free()

func _fetch_announcements() -> void:
	var http = HTTPRequest.new()
	add_child(http)
	http.request_completed.connect(_on_announcements_received.bind(http))
	
	var url = FIRESTORE_URL + "/announcements"
	var error = http.request(url)
	if error != OK:
		push_warning("RemoteConfig: Failed to request announcements")
		http.queue_free()

# =============================================================================
# FIREBASE RESPONSE HANDLERS
# =============================================================================

func _on_game_config_received(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray, http: HTTPRequest) -> void:
	http.queue_free()
	
	if result != HTTPRequest.RESULT_SUCCESS or response_code != 200:
		_handle_error("Game config request failed: %d" % response_code)
		return
	
	var data = _parse_firestore_response(body)
	if data.is_empty():
		_handle_error("Failed to parse game config")
		return
	
	game_config = data
	is_loaded = true
	config_loaded.emit(game_config)
	
	# Check for version updates
	var client_version = _get_game_version()
	var server_version = get_server_version()
	if server_version != "" and server_version != client_version:
		var version_info = {
			"current": server_version,
			"minimum": get_minimum_version(),
			"update_url": get_update_url(),
			"force_update": is_force_update_required()
		}
		update_available.emit(version_info)

func _on_ads_config_received(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray, http: HTTPRequest) -> void:
	http.queue_free()
	
	if result != HTTPRequest.RESULT_SUCCESS or response_code != 200:
		push_warning("RemoteConfig: Ads config request failed")
		return
	
	var data = _parse_firestore_response(body)
	if not data.is_empty():
		ads_config = data
		ads_config_loaded.emit(ads_config)

func _on_announcements_received(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray, http: HTTPRequest) -> void:
	http.queue_free()
	
	if result != HTTPRequest.RESULT_SUCCESS or response_code != 200:
		return
	
	var json = JSON.new()
	if json.parse(body.get_string_from_utf8()) != OK:
		return
	
	var response = json.get_data()
	if not response.has("documents"):
		return
	
	announcements.clear()
	for doc in response["documents"]:
		var ann = _parse_firestore_document(doc)
		# Extract document ID from the name field
		var name_parts = doc.get("name", "").split("/")
		ann["id"] = name_parts[-1] if name_parts.size() > 0 else ""
		announcements.append(ann)
	
	# Sort by priority if available
	announcements.sort_custom(func(a, b): return a.get("priority", 0) < b.get("priority", 0))
	
	# Emit signals for pending announcements
	for ann in get_pending_announcements():
		announcement_received.emit(ann)

# =============================================================================
# FIRESTORE PARSING HELPERS
# =============================================================================

func _parse_firestore_response(body: PackedByteArray) -> Dictionary:
	var json = JSON.new()
	if json.parse(body.get_string_from_utf8()) != OK:
		return {}
	
	var response = json.get_data()
	if not response is Dictionary:
		return {}
	
	return _parse_firestore_document(response)

func _parse_firestore_document(doc: Dictionary) -> Dictionary:
	var result = {}
	var fields = doc.get("fields", {})
	
	for key in fields.keys():
		result[key] = _parse_firestore_value(fields[key])
	
	return result

func _parse_firestore_value(value: Dictionary) -> Variant:
	# Firestore wraps values in type objects
	if value.has("stringValue"):
		return value["stringValue"]
	elif value.has("integerValue"):
		return int(value["integerValue"])
	elif value.has("doubleValue"):
		return float(value["doubleValue"])
	elif value.has("booleanValue"):
		return value["booleanValue"]
	elif value.has("nullValue"):
		return null
	elif value.has("arrayValue"):
		var arr = []
		for item in value["arrayValue"].get("values", []):
			arr.append(_parse_firestore_value(item))
		return arr
	elif value.has("mapValue"):
		return _parse_firestore_document(value["mapValue"])
	else:
		return null

# =============================================================================
# INTERNAL HELPERS
# =============================================================================

func _get_game_version() -> String:
	return ProjectSettings.get_setting("application/config/version", "1.0.0")

func _compare_versions(v1: String, v2: String) -> int:
	var parts1 = v1.split(".")
	var parts2 = v2.split(".")
	
	for i in range(max(parts1.size(), parts2.size())):
		var p1 = int(parts1[i]) if i < parts1.size() else 0
		var p2 = int(parts2[i]) if i < parts2.size() else 0
		
		if p1 > p2:
			return 1
		elif p1 < p2:
			return -1
	
	return 0

func _handle_error(error_msg: String) -> void:
	push_warning("RemoteConfig: " + error_msg)
	config_error.emit(error_msg)
	
	if USE_FALLBACK_ON_ERROR and not is_loaded:
		_use_fallback_config()

func _use_fallback_config() -> void:
	game_config = {
		"version_current": "1.0.0",
		"version_minimum": "1.0.0",
		"skins_enabled": true,
		"themes_enabled": true,
		"leaderboard_enabled": false,
		"free_fall_mode_enabled": true,
		"coin_multiplier": 1.0,
		"score_multiplier": 1.0
	}
	
	ads_config = {
		"ads_enabled": false,
		"interstitial_enabled": false,
		"rewarded_enabled": false,
		"banner_enabled": false
	}
	
	is_loaded = true
	config_loaded.emit(game_config)
	ads_config_loaded.emit(ads_config)

# =============================================================================
# PERSISTENCE
# =============================================================================

func _load_shown_announcements() -> void:
	var config = ConfigFile.new()
	if config.load(ANNOUNCEMENTS_SAVE_PATH) == OK:
		shown_announcements = config.get_value("data", "shown", [])

func _save_shown_announcements() -> void:
	var config = ConfigFile.new()
	config.set_value("data", "shown", shown_announcements)
	config.save(ANNOUNCEMENTS_SAVE_PATH)
