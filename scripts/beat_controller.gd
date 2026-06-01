extends Node2D

## Fenêtre de timing en ms (±moitié de chaque côté du beat).
## Valeur de test : 234ms ≈ 25% du beat à 128 BPM.
## À ajuster par niveau de difficulté (étape 5) : 250ms easy → 80ms expert.
## ⚠ Doit rester identique à hit_window_ms dans hud.gd
@export var hit_window_ms: float = 234.0
@export var speed: float = 300.0

@onready var player_rect: ColorRect = $ColorRect

const PROJECTILE_SCENE := preload("res://scenes/projectile.tscn")
const ENEMY_SCENE      := preload("res://scenes/enemy.tscn")

signal tap_bpm_updated(bpm: float)

var beat_interval: float = 0.5
var combo: int = 0
var song_offset: float = 0.0
var _last_press_time: float = -999.0
var _tap_times: Array[float] = []

const BASE_COLOR  := Color(0.2, 0.6, 1.0, 1)
const THUNK_COLOR := Color(1.0, 1.0, 1.0, 1)
const MISS_COLOR  := Color(0.8, 0.1, 0.1, 1)

func _ready() -> void:
	player_rect.color = BASE_COLOR
	MusicManager.song_changed.connect(_on_song_changed)
	MusicManager.bpm_updated.connect(_on_bpm_updated)
	var songs := MusicManager.scan_songs()
	if songs.is_empty():
		push_error("BeatController: aucune chanson trouvée dans audio/songs/")
		return
	MusicManager.load_song(songs[0])
	_spawn_enemy.call_deferred()

func _on_song_changed(song_data: Dictionary) -> void:
	song_offset = song_data.get("offset", 0.0)
	beat_interval = 60.0 / MusicManager.current_bpm

func _on_bpm_updated(bpm: float) -> void:
	beat_interval = 60.0 / bpm

func _process(delta: float) -> void:
	_handle_movement(delta)
	look_at(get_global_mouse_position())
	if not MusicManager.is_playing():
		return
	var phase_norm := fmod(_compensated_pos(), beat_interval) / beat_interval
	var pulse := 1.0 + 0.12 * (cos(TAU * phase_norm) * 0.5 + 0.5)
	player_rect.scale = Vector2(pulse, pulse)

func _handle_movement(delta: float) -> void:
	var direction := Vector2.ZERO
	if Input.is_key_pressed(KEY_Z): direction.y -= 1
	if Input.is_key_pressed(KEY_S): direction.y += 1
	if Input.is_key_pressed(KEY_Q): direction.x -= 1
	if Input.is_key_pressed(KEY_D): direction.x += 1
	position += direction.normalized() * speed * delta

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			_on_player_shoot()

func _on_player_shoot() -> void:
	if not MusicManager.is_playing():
		return

	_update_tap_bpm()

	var now := Time.get_ticks_msec() / 1000.0
	if now - _last_press_time < beat_interval * 0.5:
		return
	_last_press_time = now

	var pos := _compensated_pos()
	var beat_phase := fmod(pos, beat_interval)
	var half_window := (hit_window_ms / 1000.0) / 2.0
	var on_beat := beat_phase < half_window or beat_phase > (beat_interval - half_window)

	var phase_pct := beat_phase / beat_interval * 100.0
	print("phase: %.0f%%  →  %s" % [phase_pct, "THUNK x%d" % (combo + 1) if on_beat else "miss"])

	_spawn_projectile(on_beat)
	if on_beat:
		_thunk()
	else:
		_miss()

func _spawn_projectile(on_beat: bool) -> void:
	var p := PROJECTILE_SCENE.instantiate()
	p.on_beat = on_beat
	p.direction = Vector2.RIGHT.rotated(rotation)
	get_parent().add_child(p)
	p.global_position = global_position
	var rect := p.get_node("ColorRect") as ColorRect
	rect.color = Color(1.0, 1.0, 1.0, 1) if on_beat else Color(0.5, 0.5, 0.5, 0.6)

func _spawn_enemy() -> void:
	var e := ENEMY_SCENE.instantiate()
	e.destroyed.connect(_on_enemy_destroyed)
	get_parent().add_child(e)
	var vp := get_viewport_rect()
	var spawn_pos: Vector2
	# Spawn hors de la zone joueur (min 200px de distance)
	while true:
		spawn_pos = Vector2(randf_range(80, vp.size.x - 80), randf_range(80, vp.size.y - 80))
		if spawn_pos.distance_to(global_position) >= 200.0:
			break
	e.global_position = spawn_pos

func _on_enemy_destroyed(on_beat: bool) -> void:
	if on_beat:
		_thunk_hit()
	# Respawn après un court délai
	await get_tree().create_timer(1.0).timeout
	_spawn_enemy()

func _update_tap_bpm() -> void:
	var now := Time.get_ticks_msec() / 1000.0
	if not _tap_times.is_empty() and now - _tap_times.back() > 2.0:
		_tap_times.clear()
	_tap_times.append(now)
	if _tap_times.size() > 8:
		_tap_times = _tap_times.slice(_tap_times.size() - 8)
	if _tap_times.size() < 2:
		return
	var total := 0.0
	for i in range(1, _tap_times.size()):
		total += _tap_times[i] - _tap_times[i - 1]
	var avg_interval := total / (_tap_times.size() - 1)
	tap_bpm_updated.emit(60.0 / avg_interval)

func _compensated_pos() -> float:
	return maxf(MusicManager.get_playback_position() - song_offset, 0.0)

func _thunk() -> void:
	# Feedback visuel au tir on-beat
	player_rect.color = THUNK_COLOR
	await get_tree().create_timer(0.05).timeout
	player_rect.color = BASE_COLOR

func _thunk_hit() -> void:
	# Le vrai THUNK : freeze du jeu + flash
	combo += 1
	player_rect.color = THUNK_COLOR
	Engine.time_scale = 0.0
	await get_tree().create_timer(0.07, true, false, true).timeout
	Engine.time_scale = 1.0
	player_rect.color = BASE_COLOR

func _miss() -> void:
	combo = 0
	player_rect.color = MISS_COLOR
	await get_tree().create_timer(0.1).timeout
	player_rect.color = BASE_COLOR
