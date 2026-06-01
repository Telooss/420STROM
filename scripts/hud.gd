extends CanvasLayer

@export var hit_window_ms: float = 206.0

var _bar_bg: ColorRect
var _zone: ColorRect
var _cursor: ColorRect
var _bpm_label: Label

var beat_interval: float = 0.5

const BAR_H := 14

func _ready() -> void:
	var vp_w := get_viewport().get_visible_rect().size.x

	_bar_bg   = _make_rect(Color(0.08, 0.08, 0.12, 1), Vector2(vp_w, BAR_H), Vector2.ZERO)
	_zone     = _make_rect(Color(0.2, 1.0, 0.4, 0.25), Vector2(1, BAR_H), Vector2.ZERO)
	_cursor   = _make_rect(Color(1, 1, 1, 1), Vector2(4, BAR_H), Vector2.ZERO)

	_bpm_label = Label.new()
	_bpm_label.position = Vector2(8, BAR_H + 2)
	_bpm_label.add_theme_font_size_override("font_size", 14)
	_bpm_label.modulate = Color(0.8, 1.0, 0.8, 1)
	add_child(_bpm_label)

	MusicManager.song_changed.connect(_on_song_changed)
	MusicManager.bpm_updated.connect(_on_bpm_updated)

func _on_song_changed(data: Dictionary) -> void:
	_on_bpm_updated(MusicManager.current_bpm)

func _on_bpm_updated(bpm: float) -> void:
	beat_interval = 60.0 / bpm
	_refresh_zone()
	_bpm_label.text = "%d BPM  /  %d" % [roundi(bpm), roundi(MusicManager.base_bpm)]

func _refresh_zone() -> void:
	var vp_w := get_viewport().get_visible_rect().size.x
	var half_norm := (hit_window_ms / 1000.0 / 2.0) / beat_interval
	var zone_w := half_norm * 2.0 * vp_w
	_zone.size.x = zone_w
	_zone.position.x = vp_w / 2.0 - zone_w / 2.0

func _process(_delta: float) -> void:
	if not MusicManager.is_playing():
		return
	var vp_w := get_viewport().get_visible_rect().size.x
	# Décale de 0.5 : le curseur est au CENTRE pile au moment du beat
	var raw_phase := fmod(MusicManager.get_playback_position(), beat_interval) / beat_interval
	var display_phase := fmod(raw_phase + 0.5, 1.0)
	_cursor.position.x = display_phase * vp_w - 2.0

	var half_norm := (hit_window_ms / 1000.0 / 2.0) / beat_interval
	var in_zone := absf(display_phase - 0.5) < half_norm
	_cursor.color = Color(0.3, 1.0, 0.5, 1) if in_zone else Color(1, 1, 1, 0.9)

func _make_rect(color: Color, size: Vector2, pos: Vector2) -> ColorRect:
	var r := ColorRect.new()
	r.color = color
	r.size = size
	r.position = pos
	add_child(r)
	return r
