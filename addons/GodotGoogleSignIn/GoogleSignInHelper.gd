## Google Sign-In Helper Class
## Wrapper for the native Android GodotGoogleSignIn plugin
extends Node

## Emitted when sign-in succeeds
signal sign_in_success(id_token: String, email: String, display_name: String)
## Emitted when sign-in fails
signal sign_in_failed(error: String)
## Emitted when sign-out completes
signal sign_out_complete()

var _plugin = null
var _is_initialized: bool = false

func _ready():
	if Engine.has_singleton("GodotGoogleSignIn"):
		_plugin = Engine.get_singleton("GodotGoogleSignIn")
		
		# Connect plugin signals
		if _plugin.sign_in_success.connect(_on_plugin_sign_in_success) != OK:
			push_error("Failed to connect sign_in_success signal")
		if _plugin.sign_in_failed.connect(_on_plugin_sign_in_failed) != OK:
			push_error("Failed to connect sign_in_failed signal")
		if _plugin.sign_out_complete.connect(_on_plugin_sign_out_complete) != OK:
			push_error("Failed to connect sign_out_complete signal")
		
		print("GodotGoogleSignIn: Plugin found and signals connected")
	else:
		push_warning("GodotGoogleSignIn: Plugin not available (only works on Android)")

## Initialize the plugin with your Google Web Client ID
func initialize(web_client_id: String) -> void:
	if _plugin:
		_plugin.initialize(web_client_id)
		_is_initialized = _plugin.isInitialized()
		print("GodotGoogleSignIn: Initialized with client ID")
	else:
		push_warning("GodotGoogleSignIn: Cannot initialize - plugin not available")

## Check if plugin is available and initialized
func is_available() -> bool:
	return _plugin != null and _is_initialized

## Start Google Sign-In flow (auto-select if previously authorized)
func sign_in() -> void:
	if not is_available():
		sign_in_failed.emit("Plugin not available or not initialized")
		return
	_plugin.signIn()

## Start Google Sign-In with account chooser
func sign_in_with_account_chooser() -> void:
	if not is_available():
		sign_in_failed.emit("Plugin not available or not initialized")
		return
	_plugin.signInWithAccountChooser()

## Start Google Sign-In with Google button flow
func sign_in_with_google_button() -> void:
	if not is_available():
		sign_in_failed.emit("Plugin not available or not initialized")
		return
	_plugin.signInWithGoogleButton()

## Sign out and clear credential state
func sign_out() -> void:
	if _plugin:
		_plugin.signOut()
	else:
		sign_out_complete.emit()

# Plugin signal handlers
func _on_plugin_sign_in_success(id_token: String, email: String, display_name: String) -> void:
	sign_in_success.emit(id_token, email, display_name)

func _on_plugin_sign_in_failed(error: String) -> void:
	sign_in_failed.emit(error)

func _on_plugin_sign_out_complete() -> void:
	sign_out_complete.emit()

