extends StaticBody2D
class_name Wall

enum WallSide { LEFT, RIGHT }

@export var wall_side: WallSide = WallSide.LEFT
@export var wall_height: float = 10000.0

func _ready() -> void:
	update_collision()

func update_collision() -> void:
	if has_node("CollisionShape2D"):
		var shape = $CollisionShape2D.shape as RectangleShape2D
		if shape:
			shape.size = Vector2(20, wall_height)

func extend_height(new_height: float) -> void:
	if new_height > wall_height:
		wall_height = new_height
		update_collision()

