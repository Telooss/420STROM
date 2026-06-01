extends CanvasLayer

@export var hit_window_ms: float = 206.0

var _bar: ColorRect
var _zone_left: ColorRect
var _zone_right: ColorRect
var _cursor: ColorRect

var beat_interval: float = 0.5

const BAR_H := 14

func _ready() -> void:
	var vp_w := get_viewport().get_visible_rect().size.x

	_bar = _make_rect(Color(0.08, 0.08, 0.12, 1), Vector2(vp_w, BAR_H), Vector2.ZERO)
	_zone_left  = _make_rect(Color(0.2, 1.0, 0.4, 0.25), Vector2(1, BAR_H), Vector2.ZERO)
	_zone_right = _make_rect(Color(0.2, 1.0, 0.4, 0.25), Vector2(1, BAR_H), Vector2.ZERO)
	_cursor = _make_rect(Color(1, 1, 1, 1), Vector2(4, BAR_H), Vector2.ZERO)

	MusicManager.song_changed.connect(_on_song_changed)

func _on_song_changed(data: Dictionary) -> void:
	beat_interval = 60.0 / data["bpm"]
	_refresh_zones()

func _refresh_zones() -> void:
	var vp_w := get_viewport().get_visible_rect().size.x
	var half_norm := (hit_window_ms / 1000.0 / 2.0) / beat_interval
	var zone_w := half_norm * vp_w
	_zone_left.size.x = zone_w
	_zone_right.size.x = zone_w
	_zone_right.position.x = vp_w - zone_w

func _process(_delta: float) -> void:
	if not MusicManager.is_playing():
		return
	var vp_w := get_viewport().get_visible_rect().size.x
	var phase := fmod(MusicManager.get_playback_position(), beat_interval) / beat_interval
	_cursor.position.x = phase * vp_w - 2.0

	var half_norm := (hit_window_ms / 1000.0 / 2.0) / beat_interval
	var on_beat := phase < half_norm or phase > (1.0 - half_norm)
	_cursor.color = Color(0.3, 1.0, 0.5, 1) if on_beat else Color(1, 1, 1, 0.9)

func _make_rect(color: Color, size: Vector2, pos: Vector2) -> ColorRect:
	var r := ColorRect.new()
	r.color = color
	r.size = size
	r.position = pos
	add_child(r)
	return r
