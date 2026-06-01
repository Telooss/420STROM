extends Area2D

signal destroyed(on_beat: bool)

const BASE_COLOR  := Color(0.85, 0.1, 0.1, 1)
const HIT_COLOR   := Color(1.0, 1.0, 1.0, 1)

@onready var rect: ColorRect = $ColorRect

func _ready() -> void:
	add_to_group("enemy")
	rect.color = BASE_COLOR

func take_hit(on_beat: bool) -> void:
	destroyed.emit(on_beat)
	queue_free()
