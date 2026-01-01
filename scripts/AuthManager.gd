extends Node
## Firebase Anonymous Authentication Manager
## 
## Provides invisible user identity for leaderboards and cloud saves.
## Uses Firebase Auth REST API - NO PLUGINS REQUIRED.
##
## Add this as an autoload: Project Settings > AutoLoad > Add AuthManager.gd

# =============================================================================
# CONFIGURATION
# =============================================================================

## Your Firebase Web API Key (from Firebase Console > Project Settings > General)
const FIREBASE_API_KEY = "AIzaSyBtThVxcLHak1Axpb8V8hk86SQpW3MrPbc"

## Firebase Auth REST API endpoint
const AUTH_URL = "https://identitytoolkit.googleapis.com/v1/accounts"

# =============================================================================
# SIGNALS
# =============================================================================

signal auth_completed(success: bool)
signal auth_error(error: String)
signal display_name_changed(new_name: String)

# =============================================================================
# STATE
# =============================================================================

## Current user ID (Firebase UID)
var user_id: String = ""

## ID token for authenticated requests (expires after 1 hour)
var id_token: String = ""

## Refresh token (used to get new id_token)
var refresh_token: String = ""

## Token expiration timestamp
var token_expires_at: int = 0

## Player's display name for leaderboard
var display_name: String = ""

## Whether user is authenticated
var is_authenticated: bool = false

## Local persistence
const AUTH_SAVE_PATH = "user://auth_data.cfg"

# =============================================================================
# LIFECYCLE
# =============================================================================

func _ready() -> void:
	_load_auth_data()
	
	# If we have saved credentials, try to refresh
	if refresh_token != "":
		_refresh_token()
	else:
		# First time user - sign in anonymously
		sign_in_anonymous()

# =============================================================================
# PUBLIC API
# =============================================================================

## Sign in anonymously (creates new account if needed)
func sign_in_anonymous() -> void:
	var http = HTTPRequest.new()
	add_child(http)
	http.request_completed.connect(_on_sign_in_completed.bind(http))
	
	var url = "%s:signUp?key=%s" % [AUTH_URL, FIREBASE_API_KEY]
	var body = JSON.stringify({"returnSecureToken": true})
	var headers = ["Content-Type: application/json"]
	
	var error = http.request(url, headers, HTTPClient.METHOD_POST, body)
	if error != OK:
		_handle_error("Failed to initiate anonymous sign-in")
		http.queue_free()

## Get current user ID (empty if not authenticated)
func get_user_id() -> String:
	return user_id

## Get display name
func get_display_name() -> String:
	return display_name

## Set display name (for leaderboard)
func set_display_name(new_name: String) -> void:
	# Sanitize: alphanumeric, max 16 chars
	new_name = new_name.strip_edges()
	var sanitized = ""
	for c in new_name:
		if c.is_valid_identifier() or c == " ":
			sanitized += c
	sanitized = sanitized.substr(0, 16)
	
	if sanitized.length() < 2:
		sanitized = _generate_random_name()
	
	display_name = sanitized
	_save_auth_data()
	display_name_changed.emit(display_name)

## Check if token needs refresh (call before making authenticated requests)
func ensure_valid_token() -> void:
	if not is_authenticated:
		return
	
	# Refresh if token expires in less than 5 minutes
	var current_time = Time.get_unix_time_from_system()
	if current_time > token_expires_at - 300:
		_refresh_token()

## Get authorization header for Firebase requests
func get_auth_header() -> String:
	return "Bearer " + id_token if id_token != "" else ""

## Check if user is authenticated
func is_signed_in() -> bool:
	return is_authenticated and user_id != ""

# =============================================================================
# FIREBASE AUTH HANDLERS
# =============================================================================

func _on_sign_in_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray, http: HTTPRequest) -> void:
	http.queue_free()
	
	if result != HTTPRequest.RESULT_SUCCESS:
		_handle_error("Sign-in request failed")
		return
	
	var json = JSON.new()
	if json.parse(body.get_string_from_utf8()) != OK:
		_handle_error("Failed to parse sign-in response")
		return
	
	var response = json.get_data()
	
	if response_code != 200:
		var error_msg = response.get("error", {}).get("message", "Unknown error")
		_handle_error("Sign-in failed: " + error_msg)
		return
	
	# Extract auth data
	user_id = response.get("localId", "")
	id_token = response.get("idToken", "")
	refresh_token = response.get("refreshToken", "")
	
	# Calculate token expiration (Firebase tokens last 1 hour)
	var expires_in = int(response.get("expiresIn", "3600"))
	token_expires_at = Time.get_unix_time_from_system() + expires_in
	
	is_authenticated = true
	
	# Generate display name if new user
	if display_name == "":
		display_name = _generate_random_name()
	
	_save_auth_data()
	auth_completed.emit(true)
	print("AuthManager: Signed in as %s (%s)" % [display_name, user_id.substr(0, 8)])

func _refresh_token() -> void:
	if refresh_token == "":
		sign_in_anonymous()
		return
	
	var http = HTTPRequest.new()
	add_child(http)
	http.request_completed.connect(_on_token_refreshed.bind(http))
	
	var url = "https://securetoken.googleapis.com/v1/token?key=%s" % FIREBASE_API_KEY
	var body = "grant_type=refresh_token&refresh_token=%s" % refresh_token
	var headers = ["Content-Type: application/x-www-form-urlencoded"]
	
	var error = http.request(url, headers, HTTPClient.METHOD_POST, body)
	if error != OK:
		_handle_error("Failed to refresh token")
		http.queue_free()

func _on_token_refreshed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray, http: HTTPRequest) -> void:
	http.queue_free()
	
	if result != HTTPRequest.RESULT_SUCCESS or response_code != 200:
		# Refresh failed - sign in again
		refresh_token = ""
		sign_in_anonymous()
		return
	
	var json = JSON.new()
	if json.parse(body.get_string_from_utf8()) != OK:
		sign_in_anonymous()
		return
	
	var response = json.get_data()
	
	user_id = response.get("user_id", user_id)
	id_token = response.get("id_token", "")
	refresh_token = response.get("refresh_token", refresh_token)
	
	var expires_in = int(response.get("expires_in", "3600"))
	token_expires_at = Time.get_unix_time_from_system() + expires_in
	
	is_authenticated = true
	_save_auth_data()
	auth_completed.emit(true)

# =============================================================================
# HELPERS
# =============================================================================

func _generate_random_name() -> String:
	var adjectives = ["Swift", "Brave", "Lucky", "Cosmic", "Mighty", "Golden", "Shadow", "Storm", "Fire", "Ice", "Thunder", "Crystal", "Ninja", "Star", "Sky"]
	var nouns = ["Jumper", "Climber", "Runner", "Player", "Hero", "Knight", "Wizard", "Phoenix", "Dragon", "Tiger", "Eagle", "Wolf", "Fox", "Hawk", "Bear"]
	
	var adj = adjectives[randi() % adjectives.size()]
	var noun = nouns[randi() % nouns.size()]
	var num = randi() % 1000
	
	return "%s%s%d" % [adj, noun, num]

func _handle_error(error_msg: String) -> void:
	push_warning("AuthManager: " + error_msg)
	auth_error.emit(error_msg)
	auth_completed.emit(false)

# =============================================================================
# PERSISTENCE
# =============================================================================

func _load_auth_data() -> void:
	var config = ConfigFile.new()
	if config.load(AUTH_SAVE_PATH) == OK:
		user_id = config.get_value("auth", "user_id", "")
		refresh_token = config.get_value("auth", "refresh_token", "")
		display_name = config.get_value("auth", "display_name", "")
		token_expires_at = config.get_value("auth", "token_expires_at", 0)

func _save_auth_data() -> void:
	var config = ConfigFile.new()
	config.set_value("auth", "user_id", user_id)
	config.set_value("auth", "refresh_token", refresh_token)
	config.set_value("auth", "display_name", display_name)
	config.set_value("auth", "token_expires_at", token_expires_at)
	config.save(AUTH_SAVE_PATH)

