extends CanvasLayer

## ⚠ Doit rester identique à hit_window_ms dans beat_controller.gd
@export var hit_window_ms: float = 234.0

var _bar_bg: ColorRect
var _zone: ColorRect
var _cursor: ColorRect
var _bpm_label: Label
var _tap_label: Label
var _calib_label: Label
var _combo_label: Label
var _hearts: Array[ColorRect] = []
var beat_interval: float = 0.5

const BAR_H     := 14
const HEART_SIZE := 20
const HEART_GAP  := 6

func _ready() -> void:
	var vp := get_viewport().get_visible_rect().size

	_bar_bg  = _make_rect(Color(0.08, 0.08, 0.12, 1), Vector2(vp.x, BAR_H), Vector2.ZERO)
	_zone    = _make_rect(Color(0.2, 1.0, 0.4, 0.25), Vector2(1, BAR_H), Vector2.ZERO)
	_cursor  = _make_rect(Color(1, 1, 1, 1), Vector2(4, BAR_H), Vector2.ZERO)

	_bpm_label = _make_label(Vector2(8, BAR_H + 2), Color(0.8, 1.0, 0.8, 1))
	_tap_label = _make_label(Vector2(vp.x - 160, BAR_H + 2), Color(1.0, 0.9, 0.4, 1))
	_tap_label.text = "TAP: —"

	_calib_label = _make_label(Vector2(vp.x / 2.0 - 200, vp.y / 2.0 - 20), Color(1, 1, 0.3, 1))
	_calib_label.add_theme_font_size_override("font_size", 22)
	_calib_label.visible = false

	_combo_label = _make_label(Vector2(vp.x / 2.0 - 60, vp.y * 0.35), Color(1, 1, 1, 1))
	_combo_label.add_theme_font_size_override("font_size", 48)
	_combo_label.text = ""

	# Cœurs en haut à droite
	var bc := get_parent()
	var max_hp: int = bc.max_hp if bc.get("max_hp") != null else 3
	for i in max_hp:
		var h := _make_rect(Color(1.0, 0.2, 0.2, 1),
			Vector2(HEART_SIZE, HEART_SIZE),
			Vector2(vp.x - (HEART_SIZE + HEART_GAP) * (max_hp - i), BAR_H + 4))
		_hearts.append(h)

	MusicManager.song_changed.connect(_on_song_changed)
	get_parent().tap_bpm_updated.connect(_on_tap_bpm_updated)
	get_parent().calibration_status.connect(_on_calibration_status)
	get_parent().combo_changed.connect(_on_combo_changed)
	get_parent().hp_changed.connect(_on_hp_changed)

func _on_song_changed(_data: Dictionary) -> void:
	beat_interval = 60.0 / MusicManager.current_bpm
	_refresh_zone()
	_bpm_label.text = "%d BPM" % roundi(MusicManager.base_bpm)

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
	var raw_phase := fmod(MusicManager.get_playback_position(), beat_interval) / beat_interval
	var display_phase := fmod(raw_phase + 0.5, 1.0)
	_cursor.position.x = display_phase * vp_w - 2.0
	var half_norm := (hit_window_ms / 1000.0 / 2.0) / beat_interval
	_cursor.color = Color(0.3, 1.0, 0.5, 1) if absf(display_phase - 0.5) < half_norm else Color(1, 1, 1, 0.9)

func _on_hp_changed(current: int, _maximum: int) -> void:
	for i in _hearts.size():
		_hearts[i].color = Color(1.0, 0.2, 0.2, 1) if i < current else Color(0.3, 0.3, 0.3, 1)

func _on_tap_bpm_updated(bpm: float) -> void:
	_tap_label.text = "TAP: %d BPM" % roundi(bpm)
	_tap_label.modulate = Color(0.3, 1.0, 0.4, 1) if absf(bpm - MusicManager.base_bpm) <= 5.0 else Color(1.0, 0.9, 0.4, 1)

func _on_calibration_status(text: String) -> void:
	if text.is_empty():
		_calib_label.visible = false
		return
	_calib_label.text = text
	_calib_label.visible = true
	if text.begins_with("Calibration OK"):
		await get_tree().create_timer(3.0).timeout
		_calib_label.visible = false

func _on_combo_changed(count: int) -> void:
	if count == 0:
		_combo_label.text = ""
		return
	_combo_label.text = "x%d" % count
	_combo_label.modulate = Color(1, 1, 1, 1)
	var tween := create_tween()
	tween.tween_property(_combo_label, "scale", Vector2(1.4, 1.4), 0.05)
	tween.tween_property(_combo_label, "scale", Vector2(1.0, 1.0), 0.1)

func show_game_over(final_combo: int) -> void:
	var vp := get_viewport().get_visible_rect().size
	var _overlay := _make_rect(Color(0, 0, 0, 0.75), vp, Vector2.ZERO)

	var title := _make_label(Vector2(vp.x / 2.0 - 120, vp.y / 2.0 - 80), Color(1, 0.2, 0.2, 1))
	title.text = "GAME OVER"
	title.add_theme_font_size_override("font_size", 52)

	var score := _make_label(Vector2(vp.x / 2.0 - 110, vp.y / 2.0), Color(1, 1, 1, 1))
	score.text = "Meilleur combo : x%d" % final_combo
	score.add_theme_font_size_override("font_size", 22)

	var hint := _make_label(Vector2(vp.x / 2.0 - 80, vp.y / 2.0 + 50), Color(0.7, 0.7, 0.7, 1))
	hint.text = "R pour recommencer"
	hint.add_theme_font_size_override("font_size", 18)

func _make_label(pos: Vector2, color: Color) -> Label:
	var l := Label.new()
	l.position = pos
	l.add_theme_font_size_override("font_size", 14)
	l.modulate = color
	add_child(l)
	return l

func _make_rect(color: Color, size: Vector2, pos: Vector2) -> ColorRect:
	var r := ColorRect.new()
	r.color = color
	r.size = size
	r.position = pos
	add_child(r)
	return r
