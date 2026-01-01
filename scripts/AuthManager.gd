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

## Google Web Client ID (from Google Cloud Console > Credentials)
## IMPORTANT: Replace with YOUR Web Application Client ID
const GOOGLE_WEB_CLIENT_ID = "437683005712-r3q3c0lgq1sm5itovn210m0k6dm6dvkd.apps.googleusercontent.com"

## Firebase Auth REST API endpoint
const AUTH_URL = "https://identitytoolkit.googleapis.com/v1/accounts"

# =============================================================================
# SIGNALS
# =============================================================================

signal auth_completed(success: bool)
signal auth_error(error: String)
signal display_name_changed(new_name: String)
signal account_linked(success: bool)
signal link_reward_granted(diamonds: int)

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

## Whether user has linked a permanent account (Google, etc.)
var is_account_linked: bool = false

## Whether user has claimed the link reward
var has_claimed_link_reward: bool = false

## Local persistence
const AUTH_SAVE_PATH = "user://auth_data.cfg"

## Reward for linking account
const LINK_REWARD_DIAMONDS = 500

## Google Sign-In plugin reference
var _google_sign_in = null
var _google_sign_in_initialized = false

# =============================================================================
# LIFECYCLE
# =============================================================================

func _ready() -> void:
	_load_auth_data()
	_initialize_google_sign_in()
	
	# If we have saved credentials, try to refresh
	if refresh_token != "":
		_refresh_token()
	else:
		# First time user - sign in anonymously
		sign_in_anonymous()

## Initialize Google Sign-In plugin (Android only)
func _initialize_google_sign_in() -> void:
	print("AuthManager: Checking for Google Sign-In plugin...")
	print("AuthManager: Platform: ", OS.get_name())
	
	if Engine.has_singleton("GodotGoogleSignIn"):
		print("AuthManager: ✓ GodotGoogleSignIn singleton found!")
		_google_sign_in = Engine.get_singleton("GodotGoogleSignIn")
		
		# Connect plugin signals
		if _google_sign_in.sign_in_success.connect(_on_plugin_sign_in_success) != OK:
			push_error("AuthManager: ✗ Failed to connect Google Sign-In success signal")
		else:
			print("AuthManager: ✓ Connected sign_in_success signal")
			
		if _google_sign_in.sign_in_failed.connect(_on_plugin_sign_in_failed) != OK:
			push_error("AuthManager: ✗ Failed to connect Google Sign-In failed signal")
		else:
			print("AuthManager: ✓ Connected sign_in_failed signal")
		
		# Initialize with Web Client ID
		if GOOGLE_WEB_CLIENT_ID != "YOUR_WEB_CLIENT_ID.apps.googleusercontent.com":
			print("AuthManager: Initializing with Web Client ID: ", GOOGLE_WEB_CLIENT_ID)
			_google_sign_in.initialize(GOOGLE_WEB_CLIENT_ID)
			_google_sign_in_initialized = _google_sign_in.isInitialized()
			
			if _google_sign_in_initialized:
				print("AuthManager: ✓ Google Sign-In plugin initialized successfully!")
			else:
				push_error("AuthManager: ✗ Google Sign-In plugin failed to initialize!")
		else:
			push_warning("AuthManager: ✗ GOOGLE_WEB_CLIENT_ID not configured! Please update AuthManager.gd")
	else:
		print("AuthManager: ✗ Google Sign-In plugin not available")

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

## Check if user has linked a permanent account
func is_linked() -> bool:
	return is_account_linked

## Check if user can link account (not already linked)
func can_link_account() -> bool:
	return is_authenticated and not is_account_linked

## Check if user should see the link button
func should_show_link_button() -> bool:
	return is_authenticated and not is_account_linked

## Link with Google Account
## Uses GodotGoogleSignIn plugin on Android, simulates on other platforms.
func link_with_google() -> void:
	if not is_authenticated:
		push_warning("AuthManager: Cannot link - not authenticated")
		account_linked.emit(false)
		return
	
	if is_account_linked:
		push_warning("AuthManager: Account already linked")
		account_linked.emit(false)
		return
	
	print("AuthManager: Starting Google Sign-In...")
	print("AuthManager: Plugin object: ", _google_sign_in)
	print("AuthManager: Plugin initialized: ", _google_sign_in_initialized)
	
	# Check if plugin is initialized
	if _google_sign_in and _google_sign_in_initialized:
		print("AuthManager: ✓ Calling plugin.signIn()...")
		# Start sign-in process
		_google_sign_in.signIn()
		print("AuthManager: ✓ Using GodotGoogleSignIn plugin")
	else:
		# Plugin not available - show error
		print("AuthManager: ✗ GodotGoogleSignIn not available!")
		if not _google_sign_in:
			print("AuthManager:   Reason: Plugin singleton not found")
			push_error("GodotGoogleSignIn plugin not found. Make sure it's enabled in Project Settings → Plugins and in Export settings.")
		elif not _google_sign_in_initialized:
			print("AuthManager:   Reason: Plugin not initialized")
			push_error("GodotGoogleSignIn plugin failed to initialize. Check the Web Client ID.")
		
		# Emit failure signal
		account_linked.emit(false)

## Called by the plugin when sign-in succeeds
func _on_plugin_sign_in_success(id_token: String, email: String, display_name_from_google: String) -> void:
	print("AuthManager: Google Sign-In success!")
	print("AuthManager: Email: ", email)
	print("AuthManager: Display Name: ", display_name_from_google)
	
	# Update display name from Google account
	if display_name_from_google != "":
		display_name = display_name_from_google
		_save_auth_data()
	elif email != "":
		# Use email prefix as name
		display_name = email.split("@")[0]
		_save_auth_data()
	
	# Optional: Link with Firebase using the ID token
	if id_token and not id_token.is_empty():
		complete_google_link(id_token)
	else:
		# Just mark as linked without Firebase integration
		_on_google_link_success()

## Called by the plugin when sign-in fails
func _on_plugin_sign_in_failed(error: String) -> void:
	push_warning("AuthManager: Google Sign-In failed: " + error)
	account_linked.emit(false)

## Call this when you get a Google ID token from a sign-in plugin
func complete_google_link(google_id_token: String) -> void:
	if google_id_token.is_empty():
		account_linked.emit(false)
		return
	
	# Link the Google credential to the anonymous account
	var http = HTTPRequest.new()
	add_child(http)
	http.request_completed.connect(_on_link_completed.bind(http))
	
	var url = "%s:signInWithIdp?key=%s" % [AUTH_URL, FIREBASE_API_KEY]
	var body = JSON.stringify({
		"requestUri": "http://localhost",
		"postBody": "id_token=%s&providerId=google.com" % google_id_token,
		"returnSecureToken": true,
		"returnIdpCredential": true
	})
	var headers = ["Content-Type: application/json"]
	
	var error = http.request(url, headers, HTTPClient.METHOD_POST, body)
	if error != OK:
		push_warning("AuthManager: Failed to link Google account")
		http.queue_free()
		account_linked.emit(false)

func _on_link_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray, http: HTTPRequest) -> void:
	http.queue_free()
	
	if result != HTTPRequest.RESULT_SUCCESS or response_code != 200:
		var body_text = body.get_string_from_utf8()
		push_warning("AuthManager: Link failed: " + body_text)
		account_linked.emit(false)
		return
	
	_on_google_link_success()

func _on_google_link_success() -> void:
	is_account_linked = true
	_save_auth_data()
	
	print("AuthManager: Account linked successfully!")
	account_linked.emit(true)
	
	# Grant reward if not already claimed
	if not has_claimed_link_reward:
		_grant_link_reward()

func _grant_link_reward() -> void:
	has_claimed_link_reward = true
	_save_auth_data()
	
	# Add diamonds via SkinManager
	if has_node("/root/GameManager"):
		var game_manager = get_node("/root/GameManager")
		if game_manager.skin_manager:
			game_manager.skin_manager.add_coins(LINK_REWARD_DIAMONDS)
			game_manager.save_game_data()
			print("AuthManager: Granted %d diamonds for linking account!" % LINK_REWARD_DIAMONDS)
			link_reward_granted.emit(LINK_REWARD_DIAMONDS)

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
		is_account_linked = config.get_value("auth", "is_account_linked", false)
		has_claimed_link_reward = config.get_value("auth", "has_claimed_link_reward", false)

func _save_auth_data() -> void:
	var config = ConfigFile.new()
	config.set_value("auth", "user_id", user_id)
	config.set_value("auth", "refresh_token", refresh_token)
	config.set_value("auth", "display_name", display_name)
	config.set_value("auth", "token_expires_at", token_expires_at)
	config.set_value("auth", "is_account_linked", is_account_linked)
	config.set_value("auth", "has_claimed_link_reward", has_claimed_link_reward)
	config.save(AUTH_SAVE_PATH)

