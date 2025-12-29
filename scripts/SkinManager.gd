extends Node

# Manages player skins - unlocking, equipping, and persistence

signal skin_changed(skin_id: String)
signal skin_unlocked(skin_id: String)
signal coins_changed(new_amount: int)

# Player's coin balance (earned in-game, used to buy skins)
var coins: int = 0

# Currently equipped skin
var equipped_skin: String = "default"

# Unlocked skins (default is always unlocked)
var unlocked_skins: Array[String] = ["default"]

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
	"golden": {
		"name": "Golden Hero",
		"description": "Shine bright like gold",
		"price": 1000,
		"color_primary": Color(1, 0.85, 0.2),
		"color_secondary": Color(1, 0.7, 0.1),
		"trail_color": Color(1, 0.8, 0.2, 0.6),
		"sprite_modulate": Color(1, 0.9, 0.5),
		"icon": "👑"
	},
	"neon": {
		"name": "Neon Runner",
		"description": "Cyberpunk vibes",
		"price": 1500,
		"color_primary": Color(0, 1, 0.8),
		"color_secondary": Color(1, 0, 0.8),
		"trail_color": Color(0, 1, 0.9, 0.6),
		"sprite_modulate": Color(0.7, 1, 0.9),
		"icon": "⚡"
	},
	"fire": {
		"name": "Flame Walker",
		"description": "Born from fire",
		"price": 2000,
		"color_primary": Color(1, 0.4, 0.1),
		"color_secondary": Color(1, 0.2, 0),
		"trail_color": Color(1, 0.5, 0.1, 0.7),
		"sprite_modulate": Color(1, 0.7, 0.5),
		"icon": "🔥"
	},
	"ice": {
		"name": "Frost Spirit",
		"description": "Cold as ice",
		"price": 2000,
		"color_primary": Color(0.6, 0.9, 1),
		"color_secondary": Color(0.3, 0.7, 1),
		"trail_color": Color(0.7, 0.9, 1, 0.6),
		"sprite_modulate": Color(0.8, 0.95, 1),
		"icon": "❄️"
	},
	"shadow": {
		"name": "Shadow",
		"description": "One with the darkness",
		"price": 2500,
		"color_primary": Color(0.3, 0.2, 0.4),
		"color_secondary": Color(0.1, 0.05, 0.15),
		"trail_color": Color(0.4, 0.2, 0.6, 0.5),
		"sprite_modulate": Color(0.5, 0.4, 0.6),
		"icon": "🌑"
	},
	"rainbow": {
		"name": "Prismatic",
		"description": "All colors of the spectrum",
		"price": 5000,
		"color_primary": Color(1, 1, 1),  # Will cycle colors
		"color_secondary": Color(1, 1, 1),
		"trail_color": Color(1, 0.5, 0.5, 0.6),
		"sprite_modulate": Color(1, 1, 1),
		"is_animated": true,
		"icon": "🌈"
	},
	"ghost": {
		"name": "Phantom",
		"description": "Between worlds",
		"price": 3000,
		"color_primary": Color(0.8, 0.8, 1),
		"color_secondary": Color(0.6, 0.6, 0.9),
		"trail_color": Color(0.7, 0.7, 1, 0.4),
		"sprite_modulate": Color(0.9, 0.9, 1, 0.85),
		"icon": "👻"
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
	unlocked_skins = data.get("unlocked_skins", ["default"])
	
	# Ensure default is always there
	if not "default" in unlocked_skins:
		unlocked_skins.append("default")
