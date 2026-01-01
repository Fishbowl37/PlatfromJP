extends Node
## Cloud Save Manager
## 
## Syncs player data (coins, skins, settings) to Firebase Firestore.
## NO PLUGINS REQUIRED - uses REST API.
##
## Add this as an autoload: Project Settings > AutoLoad > Add CloudSaveManager.gd

# =============================================================================
# CONFIGURATION
# =============================================================================

## Your Firebase Project ID
const FIREBASE_PROJECT_ID = "platformjp-b7acd"

## Firestore REST API base URL
var FIRESTORE_URL: String:
	get: return "https://firestore.googleapis.com/v1/projects/%s/databases/(default)/documents" % FIREBASE_PROJECT_ID

## Collection for user data
const USERS_COLLECTION = "users"

## Auto-save delay (seconds) - batches rapid changes
const AUTO_SAVE_DELAY = 2.0

# =============================================================================
# SIGNALS
# =============================================================================

signal data_saved(success: bool)
signal data_loaded(success: bool, data: Dictionary)
signal sync_status_changed(syncing: bool)

# =============================================================================
# STATE
# =============================================================================

var auth_manager: Node = null
var skin_manager: Node = null

var is_syncing: bool = false
var pending_save: bool = false
var save_timer: float = 0.0

var cloud_data: Dictionary = {}
var last_sync_time: int = 0

# =============================================================================
# LIFECYCLE
# =============================================================================

func _ready() -> void:
	await get_tree().process_frame
	_connect_managers()

func _process(delta: float) -> void:
	# Handle delayed auto-save
	if pending_save and not is_syncing:
		save_timer -= delta
		if save_timer <= 0:
			pending_save = false
			save_to_cloud()

func _connect_managers() -> void:
	# Connect to AuthManager
	if has_node("/root/AuthManager"):
		auth_manager = get_node("/root/AuthManager")
		# Load cloud data once authenticated
		if auth_manager.is_signed_in():
			load_from_cloud()
		else:
			auth_manager.auth_completed.connect(_on_auth_completed)
	
	# Connect to GameManager's skin_manager
	if has_node("/root/GameManager"):
		var game_manager = get_node("/root/GameManager")
		if game_manager.skin_manager:
			skin_manager = game_manager.skin_manager
			# Listen for changes to auto-sync
			skin_manager.coins_changed.connect(_on_data_changed)
			skin_manager.skin_unlocked.connect(_on_data_changed)
			skin_manager.skin_changed.connect(_on_data_changed)

func _on_auth_completed(success: bool) -> void:
	if success:
		load_from_cloud()

func _on_data_changed(_arg = null) -> void:
	# Schedule a save (debounced to avoid spamming)
	pending_save = true
	save_timer = AUTO_SAVE_DELAY

# =============================================================================
# PUBLIC API
# =============================================================================

## Save current player data to cloud
func save_to_cloud() -> void:
	if not auth_manager or not auth_manager.is_signed_in():
		push_warning("CloudSaveManager: Cannot save - not authenticated")
		data_saved.emit(false)
		return
	
	if not skin_manager:
		push_warning("CloudSaveManager: Cannot save - skin_manager not found")
		data_saved.emit(false)
		return
	
	if is_syncing:
		# Already syncing, queue another save
		pending_save = true
		save_timer = AUTO_SAVE_DELAY
		return
	
	is_syncing = true
	sync_status_changed.emit(true)
	
	var user_id = auth_manager.get_user_id()
	var url = "%s/%s/%s" % [FIRESTORE_URL, USERS_COLLECTION, user_id]
	
	# Gather data to save
	var save_data = skin_manager.get_save_data()
	var display_name = auth_manager.get_display_name()
	
	var body = JSON.stringify({
		"fields": {
			"display_name": {"stringValue": display_name},
			"coins": {"integerValue": str(save_data.get("coins", 0))},
			"equipped_skin": {"stringValue": save_data.get("equipped_skin", "default")},
			"unlocked_skins": {"arrayValue": {"values": _array_to_firestore(save_data.get("unlocked_skins", ["default"]))}},
			"last_updated": {"stringValue": Time.get_datetime_string_from_system(true)}
		}
	})
	
	var http = HTTPRequest.new()
	add_child(http)
	http.request_completed.connect(_on_save_completed.bind(http))
	
	var headers = ["Content-Type: application/json"]
	var error = http.request(url + "?updateMask.fieldPaths=display_name&updateMask.fieldPaths=coins&updateMask.fieldPaths=equipped_skin&updateMask.fieldPaths=unlocked_skins&updateMask.fieldPaths=last_updated", headers, HTTPClient.METHOD_PATCH, body)
	
	if error != OK:
		push_warning("CloudSaveManager: Failed to initiate save")
		is_syncing = false
		sync_status_changed.emit(false)
		http.queue_free()
		data_saved.emit(false)

## Load player data from cloud
func load_from_cloud() -> void:
	if not auth_manager or not auth_manager.is_signed_in():
		push_warning("CloudSaveManager: Cannot load - not authenticated")
		data_loaded.emit(false, {})
		return
	
	is_syncing = true
	sync_status_changed.emit(true)
	
	var user_id = auth_manager.get_user_id()
	var url = "%s/%s/%s" % [FIRESTORE_URL, USERS_COLLECTION, user_id]
	
	print("CloudSaveManager: Loading data from cloud...")
	
	var http = HTTPRequest.new()
	add_child(http)
	http.request_completed.connect(_on_load_completed.bind(http))
	
	var error = http.request(url)
	if error != OK:
		push_warning("CloudSaveManager: Failed to initiate load")
		is_syncing = false
		sync_status_changed.emit(false)
		http.queue_free()
		data_loaded.emit(false, {})

## Force immediate sync
func sync_now() -> void:
	pending_save = false
	save_to_cloud()

# =============================================================================
# RESPONSE HANDLERS
# =============================================================================

func _on_save_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray, http: HTTPRequest) -> void:
	http.queue_free()
	is_syncing = false
	sync_status_changed.emit(false)
	
	if result == HTTPRequest.RESULT_SUCCESS and (response_code == 200 or response_code == 201):
		print("CloudSaveManager: Data saved successfully!")
		last_sync_time = Time.get_unix_time_from_system()
		data_saved.emit(true)
	else:
		var error_text = body.get_string_from_utf8()
		push_warning("CloudSaveManager: Save failed (code %d): %s" % [response_code, error_text])
		data_saved.emit(false)

func _on_load_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray, http: HTTPRequest) -> void:
	http.queue_free()
	is_syncing = false
	sync_status_changed.emit(false)
	
	if result != HTTPRequest.RESULT_SUCCESS:
		push_warning("CloudSaveManager: Load request failed")
		data_loaded.emit(false, {})
		return
	
	if response_code == 404:
		# No cloud data yet - this is fine for new users
		print("CloudSaveManager: No cloud save found (new user)")
		data_loaded.emit(true, {})
		return
	
	if response_code != 200:
		push_warning("CloudSaveManager: Load failed (code %d)" % response_code)
		data_loaded.emit(false, {})
		return
	
	# Parse the response
	var json = JSON.new()
	if json.parse(body.get_string_from_utf8()) != OK:
		push_warning("CloudSaveManager: Failed to parse cloud data")
		data_loaded.emit(false, {})
		return
	
	var response = json.get_data()
	cloud_data = _parse_firestore_document(response)
	
	print("CloudSaveManager: Loaded cloud data: ", cloud_data)
	
	# Apply cloud data to local state (if cloud has more coins, use cloud)
	_merge_cloud_data()
	
	last_sync_time = Time.get_unix_time_from_system()
	data_loaded.emit(true, cloud_data)

func _merge_cloud_data() -> void:
	if not skin_manager or cloud_data.is_empty():
		return
	
	var local_data = skin_manager.get_save_data()
	var local_coins = local_data.get("coins", 0)
	var cloud_coins = cloud_data.get("coins", 0)
	
	# Use the higher coin count (prevents loss from sync issues)
	if cloud_coins > local_coins:
		print("CloudSaveManager: Cloud has more coins (%d > %d), using cloud data" % [cloud_coins, local_coins])
		skin_manager.load_save_data({
			"coins": cloud_coins,
			"equipped_skin": cloud_data.get("equipped_skin", local_data.get("equipped_skin", "default")),
			"unlocked_skins": cloud_data.get("unlocked_skins", local_data.get("unlocked_skins", ["default"]))
		})
		# Save locally
		if has_node("/root/GameManager"):
			get_node("/root/GameManager").save_game_data()

# =============================================================================
# FIRESTORE HELPERS
# =============================================================================

func _array_to_firestore(arr: Array) -> Array:
	var result = []
	for item in arr:
		result.append({"stringValue": str(item)})
	return result

func _parse_firestore_document(doc: Dictionary) -> Dictionary:
	var result = {}
	var fields = doc.get("fields", {})
	
	for key in fields.keys():
		result[key] = _parse_firestore_value(fields[key])
	
	return result

func _parse_firestore_value(value: Dictionary) -> Variant:
	if value.has("stringValue"):
		return value["stringValue"]
	elif value.has("integerValue"):
		return int(value["integerValue"])
	elif value.has("doubleValue"):
		return float(value["doubleValue"])
	elif value.has("booleanValue"):
		return value["booleanValue"]
	elif value.has("arrayValue"):
		var arr = []
		for item in value["arrayValue"].get("values", []):
			arr.append(_parse_firestore_value(item))
		return arr
	elif value.has("mapValue"):
		return _parse_firestore_document(value["mapValue"])
	return null

