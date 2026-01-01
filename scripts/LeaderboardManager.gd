extends Node
## Firebase Leaderboard Manager
## 
## Handles score submission and leaderboard fetching via Firestore REST API.
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

## Collection name for scores
const SCORES_COLLECTION = "leaderboard"

## How many scores to fetch for leaderboard
const LEADERBOARD_LIMIT = 100

# =============================================================================
# SIGNALS
# =============================================================================

signal score_submitted(success: bool, rank: int)
signal leaderboard_loaded(scores: Array)
signal leaderboard_error(error: String)
signal player_rank_loaded(rank: int, total: int)

# =============================================================================
# STATE
# =============================================================================

## Reference to AuthManager
var auth_manager: Node = null

## Cached leaderboard data
var cached_scores: Array = []
var last_fetch_time: int = 0
const CACHE_DURATION = 60  # Seconds before refetch

## Player's current rank
var player_rank: int = -1
var player_submitted_score: int = 0

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

## Submit a score to the leaderboard
func submit_score(score: int, distance: float = 0.0, skin_id: String = "default") -> void:
	if not auth_manager or not auth_manager.is_signed_in():
		push_warning("LeaderboardManager: Cannot submit score - not authenticated")
		score_submitted.emit(false, -1)
		return
	
	# Ensure token is valid
	auth_manager.ensure_valid_token()
	
	# Only submit if it's a new personal best
	if score <= player_submitted_score:
		# Still emit success but with current rank
		score_submitted.emit(true, player_rank)
		return
	
	var http = HTTPRequest.new()
	add_child(http)
	http.request_completed.connect(_on_score_submitted.bind(http, score))
	
	# Create document with score data
	var doc_id = auth_manager.get_user_id()
	var url = "%s/%s/%s" % [FIRESTORE_URL, SCORES_COLLECTION, doc_id]
	
	var timestamp = Time.get_datetime_string_from_system(true)
	var body = JSON.stringify({
		"fields": {
			"user_id": {"stringValue": auth_manager.get_user_id()},
			"display_name": {"stringValue": auth_manager.get_display_name()},
			"score": {"integerValue": str(score)},
			"distance": {"doubleValue": distance},
			"skin_id": {"stringValue": skin_id},
			"timestamp": {"stringValue": timestamp}
		}
	})
	
	var headers = [
		"Content-Type: application/json",
	]
	
	# Use PATCH to create or update
	var error = http.request(url + "?updateMask.fieldPaths=user_id&updateMask.fieldPaths=display_name&updateMask.fieldPaths=score&updateMask.fieldPaths=distance&updateMask.fieldPaths=skin_id&updateMask.fieldPaths=timestamp", headers, HTTPClient.METHOD_PATCH, body)
	if error != OK:
		push_warning("LeaderboardManager: Failed to submit score")
		http.queue_free()
		score_submitted.emit(false, -1)

## Fetch the global leaderboard
func fetch_leaderboard(force_refresh: bool = false) -> void:
	# Check cache
	var current_time = Time.get_unix_time_from_system()
	if not force_refresh and cached_scores.size() > 0 and (current_time - last_fetch_time) < CACHE_DURATION:
		leaderboard_loaded.emit(cached_scores)
		return
	
	var http = HTTPRequest.new()
	add_child(http)
	http.request_completed.connect(_on_leaderboard_received.bind(http))
	
	# Query: order by score descending, limit results
	# Using Firestore REST API structured query
	var url = "%s:runQuery" % FIRESTORE_URL
	
	var query = {
		"structuredQuery": {
			"from": [{"collectionId": SCORES_COLLECTION}],
			"orderBy": [{"field": {"fieldPath": "score"}, "direction": "DESCENDING"}],
			"limit": LEADERBOARD_LIMIT
		}
	}
	
	var body = JSON.stringify(query)
	var headers = ["Content-Type: application/json"]
	
	print("LeaderboardManager: Fetching from URL: ", url)
	
	var error = http.request(url, headers, HTTPClient.METHOD_POST, body)
	if error != OK:
		push_warning("LeaderboardManager: Failed to fetch leaderboard - HTTP error: %d" % error)
		http.queue_free()
		leaderboard_error.emit("Failed to fetch leaderboard")

## Get player's rank (1-based, -1 if not ranked)
func get_player_rank() -> int:
	return player_rank

## Get cached scores
func get_cached_scores() -> Array:
	return cached_scores

## Get top N scores from cache
func get_top_scores(count: int = 10) -> Array:
	return cached_scores.slice(0, min(count, cached_scores.size()))

# =============================================================================
# RESPONSE HANDLERS
# =============================================================================

func _on_score_submitted(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray, http: HTTPRequest, submitted_score: int) -> void:
	http.queue_free()
	
	if result != HTTPRequest.RESULT_SUCCESS or (response_code != 200 and response_code != 201):
		var json = JSON.new()
		if json.parse(body.get_string_from_utf8()) == OK:
			var response = json.get_data()
			var error_msg = response.get("error", {}).get("message", "Unknown error")
			push_warning("LeaderboardManager: Score submission failed - " + error_msg)
		score_submitted.emit(false, -1)
		return
	
	player_submitted_score = submitted_score
	
	# Refresh leaderboard to get new rank
	fetch_leaderboard(true)
	
	# Calculate rank from updated leaderboard
	await leaderboard_loaded
	
	score_submitted.emit(true, player_rank)

func _on_leaderboard_received(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray, http: HTTPRequest) -> void:
	http.queue_free()
	
	print("LeaderboardManager: Response code: %d, Result: %d" % [response_code, result])
	
	if result != HTTPRequest.RESULT_SUCCESS or response_code != 200:
		var body_text = body.get_string_from_utf8()
		print("LeaderboardManager: Error response: ", body_text)
		leaderboard_error.emit("Failed to fetch leaderboard (code: %d)" % response_code)
		return
	
	var json = JSON.new()
	if json.parse(body.get_string_from_utf8()) != OK:
		leaderboard_error.emit("Failed to parse leaderboard data")
		return
	
	var response = json.get_data()
	
	cached_scores.clear()
	player_rank = -1
	
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
			"timestamp": _get_string_value(fields, "timestamp")
		}
		
		cached_scores.append(score_data)
		
		# Check if this is the current player
		if score_data["user_id"] == current_user_id:
			player_rank = rank
			player_submitted_score = score_data["score"]
	
	last_fetch_time = Time.get_unix_time_from_system()
	leaderboard_loaded.emit(cached_scores)
	
	if player_rank > 0:
		player_rank_loaded.emit(player_rank, cached_scores.size())

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

