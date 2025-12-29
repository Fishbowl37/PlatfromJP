# Icy Tower Mobile - Godot 4 Starter Project

A mobile-ready endless tower climbing game inspired by the classic **Icy Tower**, built with Godot 4.

## 🎮 Game Features

- **Momentum-based jumping**: Build speed to jump higher and farther
- **Wall bouncing**: Bounce off walls to change direction while maintaining momentum
- **Combo system**: Chain multi-floor jumps for score multipliers
- **Auto-scrolling difficulty**: The tower scrolls faster as you climb higher
- **Mobile touch controls**: Intuitive split-screen tap controls
- **Score persistence**: High scores are saved locally

## 🚀 Getting Started

### Prerequisites
- [Godot Engine 4.2+](https://godotengine.org/download) (Standard or .NET version)

### Installation
1. Open Godot and click "Import"
2. Navigate to `C:\Godot\Tower\project.godot` and open it
3. Press F5 or click the Play button to run

## 🎯 How to Play

### Controls

**Mobile (Touch)**:
- Tap **left side** of screen → Move left + Jump
- Tap **right side** of screen → Move right + Jump
- Hold to continuously move in that direction

**Desktop (Keyboard)**:
- `A` / `←` → Move left
- `D` / `→` → Move right
- `W` / `↑` / `Space` → Jump

### Tips
- **Build momentum**: Run across platforms to increase jump height
- **Chain combos**: Jump multiple floors in succession for multipliers
- **Watch the danger**: When "HURRY UP!" appears, climb faster!
- **Use walls**: Bounce off walls to change direction quickly

## 📁 Project Structure

```
C:\Godot\Tower\
├── project.godot           # Godot project configuration
├── icon.svg               # Game icon
│
├── scenes/
│   ├── Main.tscn          # Main game scene
│   ├── Player.tscn        # Player character
│   ├── Floor.tscn         # Platform/floor piece
│   ├── Wall.tscn          # Tower wall
│   ├── GameCamera.tscn    # Following camera
│   └── ui/
│       ├── HUD.tscn       # Score, floor, combo display
│       ├── TouchControls.tscn  # Mobile touch input
│       └── GameOver.tscn  # Game over screen
│
└── scripts/
    ├── GameManager.gd     # Global game state (Autoload)
    ├── Main.gd            # Main scene controller
    ├── Player.gd          # Player movement & physics
    ├── Floor.gd           # Platform behavior
    ├── FloorGenerator.gd  # Procedural floor spawning
    ├── GameCamera.gd      # Camera follow & auto-scroll
    ├── Wall.gd            # Wall collision
    ├── ComboSystem.gd     # Combo tracking
    └── ui/
        ├── HUD.gd
        ├── TouchControls.gd
        └── GameOver.gd
```

## 🔧 Customization

### Player Settings (`Player.gd`)
```gdscript
@export var run_speed: float = 350.0          # Horizontal movement speed
@export var base_jump_force: float = 550.0    # Base jump strength
@export var momentum_jump_bonus: float = 0.8  # Extra jump from momentum
@export var wall_bounce_force: float = 300.0  # Wall bounce strength
```

### Difficulty Settings (`GameCamera.gd`)
```gdscript
@export var base_scroll_speed: float = 15.0   # Initial scroll speed
@export var max_scroll_speed: float = 80.0    # Maximum scroll speed
@export var scroll_acceleration: float = 0.5  # Speed increase rate
```

### Floor Generation (`FloorGenerator.gd`)
```gdscript
@export var floor_spacing_min: float = 70.0   # Minimum gap between floors
@export var floor_spacing_max: float = 100.0  # Maximum gap (increases difficulty)
@export var floor_width_min: float = 80.0     # Smallest platform width
@export var floor_width_max: float = 160.0    # Largest platform width
```

## 🏆 Score System

| Action | Points |
|--------|--------|
| Single floor jump | 10 |
| 2-floor jump | 20 × combo |
| 3-floor jump | 30 × combo |
| 5+ floor jump (Super) | +50 bonus |
| 10+ floor jump (Mega) | +200 bonus |
| 15+ floor jump (Ultra) | +500 bonus |

## 📝 License

This project is provided as a starter template. Feel free to use, modify, and distribute.

---

Made with ❤️ using [Godot Engine](https://godotengine.org)

