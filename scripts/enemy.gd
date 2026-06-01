extends Area2D

signal destroyed(on_beat: bool)

const BASE_COLOR := Color(0.85, 0.1, 0.1, 1)
const CONTACT_RANGE := 30.0

@export var move_speed: float = 110.0

@onready var rect: ColorRect = $ColorRect

var _player: Node2D = null
var _stunned: bool = false

func _ready() -> void:
	add_to_group("enemy")
	rect.color = BASE_COLOR

func _process(delta: float) -> void:
	if _stunned:
		return
	if _player == null:
		_player = get_tree().get_first_node_in_group("player") as Node2D
		if _player == null:
			return

	var dir := (_player.global_position - global_position).normalized()
	global_position += dir * move_speed * delta

	if global_position.distance_to(_player.global_position) < CONTACT_RANGE:
		_player.on_enemy_contact()
		_knockback(dir)

func _knockback(dir: Vector2) -> void:
	_stunned = true
	var tween := create_tween()
	tween.tween_property(self, "global_position", global_position - dir * 80.0, 0.2)
	await get_tree().create_timer(0.6).timeout
	_stunned = false

func take_hit(on_beat: bool) -> void:
	destroyed.emit(on_beat)
	queue_free()
