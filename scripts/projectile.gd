extends Node2D

var direction: Vector2 = Vector2.RIGHT
var speed: float = 700.0

func _process(delta: float) -> void:
	position += direction * speed * delta
	if not get_viewport_rect().has_point(global_position):
		queue_free()
