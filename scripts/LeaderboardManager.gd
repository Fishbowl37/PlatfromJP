extends Node
## Firebase Leaderboard Manager
## 
## Handles score submission and leaderboard fetching via Firestore REST API.
## Supports multiple game modes with separate leaderboards.
## NO PLUGINS REQUIRED.
##
## Add this as an autoload: Project Settings > AutoLoad > Add LeaderboardManager.gd

# =============================================================================
# CONFIGURATION
# =============================================================================

## Your Firebase Project ID
const FIREBASE_PROJECT_ID = "platformjp-b7acd"

## Firestore REST API base URL
var FIRESTORE_URL: String:
	get: return "https://firestore.googleapis.com/v1/projects/%s/databases/(default)/documents" % FIREBASE_PROJECT_ID

## Collection names for scores per game mode
const COLLECTIONS = {
	"tower": "leaderboard_tower",
	"freefall": "leaderboard_freefall"
}

## Default collection (for backwards compatibility)
const DEFAULT_MODE = "tower"

## How many scores to fetch for leaderboard
const LEADERBOARD_LIMIT = 100

# =============================================================================
# SIGNALS
# =============================================================================

signal score_submitted(success: bool, rank: int, game_mode: String)
signal leaderboard_loaded(scores: Array, game_mode: String)
signal leaderboard_error(error: String, game_mode: String)
signal player_rank_loaded(rank: int, total: int, game_mode: String)

# =============================================================================
# STATE
# =============================================================================

## Reference to AuthManager
var auth_manager: Node = null

## Cached leaderboard data per game mode
var cached_scores: Dictionary = {
	"tower": [],
	"freefall": []
}
var last_fetch_time: Dictionary = {
	"tower": 0,
	"freefall": 0
}
const CACHE_DURATION = 60  # Seconds before refetch

## Player's current rank per mode
var player_rank: Dictionary = {
	"tower": -1,
	"freefall": -1
}
var player_submitted_score: Dictionary = {
	"tower": 0,
	"freefall": 0
}

# =============================================================================
# LIFECYCLE
# =============================================================================

func _ready() -> void:
	# Wait a frame for other autoloads to initialize
	await get_tree().process_frame
	_connect_managers()

func _connect_managers() -> void:
	if has_node("/root/AuthManager"):
		auth_manager = get_node("/root/AuthManager")
	else:
		push_warning("LeaderboardManager: AuthManager autoload not found!")

# =============================================================================
# PUBLIC API
# =============================================================================

## Get available game modes
func get_game_modes() -> Array:
	return COLLECTIONS.keys()

## Submit a score to the leaderboard for a specific game mode
func submit_score(score: int, distance: float = 0.0, skin_id: String = "default", game_mode: String = "tower") -> void:
	# Validate game mode
	if not COLLECTIONS.has(game_mode):
		push_warning("LeaderboardManager: Invalid game mode '%s', using default" % game_mode)
		game_mode = DEFAULT_MODE
	
	if not auth_manager or not auth_manager.is_signed_in():
		push_warning("LeaderboardManager: Cannot submit score - not authenticated")
		score_submitted.emit(false, -1, game_mode)
		return
	
	# Ensure token is valid
	auth_manager.ensure_valid_token()
	
	# Only submit if it's a new personal best for this mode
	if score <= player_submitted_score.get(game_mode, 0):
		# Still emit success but with current rank
		score_submitted.emit(true, player_rank.get(game_mode, -1), game_mode)
		return
	
	var http = HTTPRequest.new()
	add_child(http)
	http.request_completed.connect(_on_score_submitted.bind(http, score, game_mode))
	
	# Create document with score data
	var doc_id = auth_manager.get_user_id()
	var collection = COLLECTIONS[game_mode]
	var url = "%s/%s/%s" % [FIRESTORE_URL, collection, doc_id]
	
	var timestamp = Time.get_datetime_string_from_system(true)
	var body = JSON.stringify({
		"fields": {
			"user_id": {"stringValue": auth_manager.get_user_id()},
			"display_name": {"stringValue": auth_manager.get_display_name()},
			"score": {"integerValue": str(score)},
			"distance": {"doubleValue": distance},
			"skin_id": {"stringValue": skin_id},
			"game_mode": {"stringValue": game_mode},
			"timestamp": {"stringValue": timestamp}
		}
	})
	
	var headers = [
		"Content-Type: application/json",
	]
	
	# Use PATCH to create or update
	var error = http.request(url + "?updateMask.fieldPaths=user_id&updateMask.fieldPaths=display_name&updateMask.fieldPaths=score&updateMask.fieldPaths=distance&updateMask.fieldPaths=skin_id&updateMask.fieldPaths=game_mode&updateMask.fieldPaths=timestamp", headers, HTTPClient.METHOD_PATCH, body)
	if error != OK:
		push_warning("LeaderboardManager: Failed to submit score")
		http.queue_free()
		score_submitted.emit(false, -1, game_mode)

## Fetch the global leaderboard for a specific game mode
func fetch_leaderboard(game_mode: String = "tower", force_refresh: bool = false) -> void:
	# Validate game mode
	if not COLLECTIONS.has(game_mode):
		push_warning("LeaderboardManager: Invalid game mode '%s', using default" % game_mode)
		game_mode = DEFAULT_MODE
	
	# Check cache
	var current_time = Time.get_unix_time_from_system()
	var mode_scores = cached_scores.get(game_mode, [])
	var mode_fetch_time = last_fetch_time.get(game_mode, 0)
	
	if not force_refresh and mode_scores.size() > 0 and (current_time - mode_fetch_time) < CACHE_DURATION:
		leaderboard_loaded.emit(mode_scores, game_mode)
		return
	
	var http = HTTPRequest.new()
	add_child(http)
	http.request_completed.connect(_on_leaderboard_received.bind(http, game_mode))
	
	# Query: order by score descending, limit results
	# Using Firestore REST API structured query
	var url = "%s:runQuery" % FIRESTORE_URL
	var collection = COLLECTIONS[game_mode]
	
	var query = {
		"structuredQuery": {
			"from": [{"collectionId": collection}],
			"orderBy": [{"field": {"fieldPath": "score"}, "direction": "DESCENDING"}],
			"limit": LEADERBOARD_LIMIT
		}
	}
	
	var body = JSON.stringify(query)
	var headers = ["Content-Type: application/json"]
	
	print("LeaderboardManager: Fetching %s leaderboard from URL: %s" % [game_mode, url])
	
	var error = http.request(url, headers, HTTPClient.METHOD_POST, body)
	if error != OK:
		push_warning("LeaderboardManager: Failed to fetch leaderboard - HTTP error: %d" % error)
		http.queue_free()
		leaderboard_error.emit("Failed to fetch leaderboard", game_mode)

## Get player's rank for a specific mode (1-based, -1 if not ranked)
func get_player_rank(game_mode: String = "tower") -> int:
	return player_rank.get(game_mode, -1)

## Get cached scores for a specific mode
func get_cached_scores(game_mode: String = "tower") -> Array:
	return cached_scores.get(game_mode, [])

## Get top N scores from cache for a specific mode
func get_top_scores(count: int = 10, game_mode: String = "tower") -> Array:
	var mode_scores = cached_scores.get(game_mode, [])
	return mode_scores.slice(0, min(count, mode_scores.size()))

# =============================================================================
# RESPONSE HANDLERS
# =============================================================================

func _on_score_submitted(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray, http: HTTPRequest, submitted_score: int, game_mode: String) -> void:
	http.queue_free()
	
	if result != HTTPRequest.RESULT_SUCCESS or (response_code != 200 and response_code != 201):
		var json = JSON.new()
		if json.parse(body.get_string_from_utf8()) == OK:
			var response = json.get_data()
			var error_msg = response.get("error", {}).get("message", "Unknown error")
			push_warning("LeaderboardManager: Score submission failed - " + error_msg)
		score_submitted.emit(false, -1, game_mode)
		return
	
	player_submitted_score[game_mode] = submitted_score
	
	# Refresh leaderboard to get new rank
	fetch_leaderboard(game_mode, true)
	
	# Calculate rank from updated leaderboard
	await leaderboard_loaded
	
	score_submitted.emit(true, player_rank.get(game_mode, -1), game_mode)

func _on_leaderboard_received(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray, http: HTTPRequest, game_mode: String) -> void:
	http.queue_free()
	
	print("LeaderboardManager: %s response code: %d, Result: %d" % [game_mode, response_code, result])
	
	if result != HTTPRequest.RESULT_SUCCESS or response_code != 200:
		var body_text = body.get_string_from_utf8()
		print("LeaderboardManager: Error response: ", body_text)
		leaderboard_error.emit("Failed to fetch leaderboard (code: %d)" % response_code, game_mode)
		return
	
	var json = JSON.new()
	if json.parse(body.get_string_from_utf8()) != OK:
		leaderboard_error.emit("Failed to parse leaderboard data", game_mode)
		return
	
	var response = json.get_data()
	
	cached_scores[game_mode] = []
	player_rank[game_mode] = -1
	
	var current_user_id = ""
	if auth_manager:
		current_user_id = auth_manager.get_user_id()
	
	var rank = 0
	for item in response:
		if not item.has("document"):
			continue
		
		rank += 1
		var doc = item["document"]
		var fields = doc.get("fields", {})
		
		var score_data = {
			"rank": rank,
			"user_id": _get_string_value(fields, "user_id"),
			"display_name": _get_string_value(fields, "display_name"),
			"score": _get_int_value(fields, "score"),
			"distance": _get_float_value(fields, "distance"),
			"skin_id": _get_string_value(fields, "skin_id"),
			"game_mode": _get_string_value(fields, "game_mode"),
			"timestamp": _get_string_value(fields, "timestamp")
		}
		
		cached_scores[game_mode].append(score_data)
		
		# Check if this is the current player
		if score_data["user_id"] == current_user_id:
			player_rank[game_mode] = rank
			player_submitted_score[game_mode] = score_data["score"]
	
	last_fetch_time[game_mode] = Time.get_unix_time_from_system()
	leaderboard_loaded.emit(cached_scores[game_mode], game_mode)
	
	if player_rank.get(game_mode, -1) > 0:
		player_rank_loaded.emit(player_rank[game_mode], cached_scores[game_mode].size(), game_mode)

# =============================================================================
# FIRESTORE VALUE HELPERS
# =============================================================================

func _get_string_value(fields: Dictionary, key: String) -> String:
	if fields.has(key) and fields[key].has("stringValue"):
		return fields[key]["stringValue"]
	return ""

func _get_int_value(fields: Dictionary, key: String) -> int:
	if fields.has(key) and fields[key].has("integerValue"):
		return int(fields[key]["integerValue"])
	return 0

func _get_float_value(fields: Dictionary, key: String) -> float:
	if fields.has(key) and fields[key].has("doubleValue"):
		return float(fields[key]["doubleValue"])
	return 0.0
