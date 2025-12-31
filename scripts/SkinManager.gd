extends Node

# Manages player skins - unlocking, equipping, and persistence

signal skin_changed(skin_id: String)
signal skin_unlocked(skin_id: String)
signal coins_changed(new_amount: int)

# Player's coin balance (earned in-game, used to buy skins)
var coins: int = 0

# Currently equipped skin
var equipped_skin: String = "default"

# Unlocked skins (free skins are always unlocked)
var unlocked_skins: Array[String] = ["default", "knight", "karasu"]

# Skin definitions - add new skins here!
const SKINS = {
	"default": {
		"name": "Classic",
		"description": "The original tower climber",
		"price": 0,
		"color_primary": Color(1, 1, 1),
		"color_secondary": Color(1, 1, 1),
		"trail_color": Color(0.4, 0.6, 1.0, 0.5),
		"sprite_modulate": Color(1, 1, 1),
		"icon": "🧍"
	},
	"knight": {
		"name": "Knight",
		"description": "A brave knight in armor",
		"price": 0,
		"color_primary": Color(0.7, 0.7, 0.8),
		"color_secondary": Color(0.5, 0.5, 0.6),
		"trail_color": Color(0.6, 0.6, 0.8, 0.6),
		"sprite_modulate": Color(1, 1, 1),
		"sprite_frames_path": "res://assets/sprites/player/knight/knight_frames.tres",
		"icon": "⚔️"
	},
	"karasu": {
		"name": "Karasu",
		"description": "Swift as a shadow raven",
		"price": 0,
		"color_primary": Color(0.2, 0.2, 0.3),
		"color_secondary": Color(0.1, 0.1, 0.15),
		"trail_color": Color(0.3, 0.2, 0.4, 0.6),
		"sprite_modulate": Color(2.5, 2.5, 2.5),
		"sprite_frames_path": "res://assets/sprites/player/Karasu/karasu_frames.tres",
		"icon": "🪶"
	},
	"kitsune": {
		"name": "Kitsune",
		"description": "A mystical fox spirit",
		"price": 1000,
		"color_primary": Color(1.0, 0.8, 0.4),
		"color_secondary": Color(0.9, 0.5, 0.2),
		"trail_color": Color(1.0, 0.7, 0.3, 0.6),
		"sprite_modulate": Color(1, 1, 1),
		"sprite_frames_path": "res://assets/sprites/player/Kitsune/kitsune_frames.tres",
		"icon": "🦊"
	}
}

func _ready() -> void:
	# Skins are loaded via GameManager's load_game_data()
	pass

func get_all_skins() -> Dictionary:
	return SKINS

func get_skin_data(skin_id: String) -> Dictionary:
	if SKINS.has(skin_id):
		return SKINS[skin_id]
	return SKINS["default"]

func get_equipped_skin() -> String:
	return equipped_skin

func get_equipped_skin_data() -> Dictionary:
	return get_skin_data(equipped_skin)

func is_skin_unlocked(skin_id: String) -> bool:
	return skin_id in unlocked_skins

func can_afford_skin(skin_id: String) -> bool:
	var skin_data = get_skin_data(skin_id)
	return coins >= skin_data["price"]

func unlock_skin(skin_id: String) -> bool:
	if is_skin_unlocked(skin_id):
		return false
	
	var skin_data = get_skin_data(skin_id)
	if coins < skin_data["price"]:
		return false
	
	# Deduct coins and unlock
	coins -= skin_data["price"]
	unlocked_skins.append(skin_id)
	
	skin_unlocked.emit(skin_id)
	coins_changed.emit(coins)
	
	# Save immediately
	GameManager.save_game_data()
	
	return true

func equip_skin(skin_id: String) -> bool:
	if not is_skin_unlocked(skin_id):
		return false
	
	equipped_skin = skin_id
	skin_changed.emit(skin_id)
	
	# Save immediately
	GameManager.save_game_data()
	
	return true

func add_coins(amount: int) -> void:
	coins += amount
	coins_changed.emit(coins)

func get_coins() -> int:
	return coins

# Get animated color for rainbow skin
func get_rainbow_color(time: float) -> Color:
	var hue = fmod(time * 0.5, 1.0)
	return Color.from_hsv(hue, 0.8, 1.0)

# Called by Player to get current trail color (handles animated skins)
func get_current_trail_color() -> Color:
	var skin_data = get_equipped_skin_data()
	if skin_data.get("is_animated", false):
		return get_rainbow_color(Time.get_ticks_msec() / 1000.0)
	return skin_data["trail_color"]

# Called by Player to get current sprite modulate (handles animated skins)
func get_current_sprite_modulate() -> Color:
	var skin_data = get_equipped_skin_data()
	if skin_data.get("is_animated", false):
		return get_rainbow_color(Time.get_ticks_msec() / 1000.0)
	return skin_data["sprite_modulate"]

# For serialization
func get_save_data() -> Dictionary:
	return {
		"coins": coins,
		"equipped_skin": equipped_skin,
		"unlocked_skins": unlocked_skins
	}

func load_save_data(data: Dictionary) -> void:
	coins = data.get("coins", 0)
	equipped_skin = data.get("equipped_skin", "default")
	
	# Convert generic Array to Array[String]
	unlocked_skins.clear()
	var loaded_skins = data.get("unlocked_skins", ["default"])
	for skin_id in loaded_skins:
		unlocked_skins.append(str(skin_id))
	
	# Ensure free skins are always unlocked
	if not "default" in unlocked_skins:
		unlocked_skins.append("default")
	if not "knight" in unlocked_skins:
		unlocked_skins.append("knight")
	if not "karasu" in unlocked_skins:
		unlocked_skins.append("karasu")
