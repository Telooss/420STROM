extends Area2D

var direction: Vector2 = Vector2.RIGHT
var speed: float = 700.0
var on_beat: bool = false

func _ready() -> void:
	area_entered.connect(_on_area_entered)

func _process(delta: float) -> void:
	position += direction * speed * delta
	if not get_viewport_rect().has_point(global_position):
		queue_free()

func _on_area_entered(area: Area2D) -> void:
	if area.is_in_group("enemy"):
		area.take_hit(on_beat)
		queue_free()
