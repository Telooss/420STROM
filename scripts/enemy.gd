extends Area2D

signal destroyed(on_beat: bool)

const BASE_COLOR := Color(0.85, 0.1, 0.1, 1)
const CONTACT_RANGE := 45.0

@export var move_speed: float = 120.0

@onready var rect: ColorRect = $ColorRect

var _player: Node2D = null

func _ready() -> void:
	add_to_group("enemy")
	rect.color = BASE_COLOR

func _process(delta: float) -> void:
	if _player == null:
		_player = get_tree().get_first_node_in_group("player") as Node2D
		if _player == null:
			return

	var dir := (_player.global_position - global_position).normalized()
	global_position += dir * move_speed * delta

	if global_position.distance_to(_player.global_position) < CONTACT_RANGE:
		_player.on_enemy_contact()

func take_hit(on_beat: bool) -> void:
	destroyed.emit(on_beat)
	queue_free()
