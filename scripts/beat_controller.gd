extends Node2D

## Fenêtre de timing en ms (±moitié de chaque côté du beat).
## Valeur de test : 234ms ≈ 25% du beat à 128 BPM.
## À ajuster par niveau de difficulté (étape 5) : 250ms easy → 80ms expert.
## ⚠ Doit rester identique à hit_window_ms dans hud.gd
@export var hit_window_ms: float = 234.0
@export var speed: float = 300.0
@export var max_hp: int = 3

@onready var player_rect: ColorRect = $ColorRect

const PROJECTILE_SCENE := preload("res://scenes/projectile.tscn")
const ENEMY_SCENE      := preload("res://scenes/enemy.tscn")
const SETTINGS_PATH    := "user://settings.json"
const CALIB_TAPS       := 8

signal tap_bpm_updated(bpm: float)
signal calibration_status(text: String)
signal combo_changed(count: int)
signal hp_changed(current: int, maximum: int)
signal jauge_changed(current: float, maximum: float)

var beat_interval: float = 0.5
var combo: int = 0
var hp: int = 3
var jauge: float = 100.0
var jauge_max: float = 100.0
var song_offset: float = 0.0
var _last_press_time: float = -999.0
var _tap_times: Array[float] = []
var _calibrating: bool = false
var _calib_phases: Array[float] = []
var _last_phase: float = 0.0
var _click_player: AudioStreamPlayer
var _hit_cooldown: bool = false
var _dead: bool = false
var _world: Node2D  # Conteneur pour ennemis + projectiles — nettoyé au reload
var _aim_angle: float = 0.0

const BASE_COLOR  := Color(0.2, 0.6, 1.0, 1)
const THUNK_COLOR := Color(1.0, 1.0, 1.0, 1)
const MISS_COLOR  := Color(0.8, 0.1, 0.1, 1)

func _ready() -> void:
	add_to_group("player")
	hp = max_hp
	player_rect.color = BASE_COLOR

	# World est un frère du joueur dans la scène — pas un enfant
	# Donc les ennemis/projectiles ne suivent pas le déplacement du joueur
	_world = get_parent().get_node("World")

	_click_player = AudioStreamPlayer.new()
	_click_player.stream = _make_click_stream()
	_click_player.volume_db = 3.0
	add_child(_click_player)

	_load_settings()
	MusicManager.song_changed.connect(_on_song_changed)
	var songs := MusicManager.scan_songs()
	if songs.is_empty():
		push_error("BeatController: aucune chanson trouvée dans audio/songs/")
		return
	MusicManager.load_song(songs[0])
	_spawn_enemy.call_deferred()

func _on_song_changed(song_data: Dictionary) -> void:
	song_offset = song_data.get("offset", 0.0)
	beat_interval = 60.0 / MusicManager.current_bpm

func _process(delta: float) -> void:
	if _dead:
		return
	_handle_movement(delta)
	# On tourne uniquement le rect visuel, pas le Node2D racine
	# (évite que _world et ses enfants héritent de la rotation)
	_aim_angle = (get_global_mouse_position() - global_position).angle()
	player_rect.rotation = _aim_angle
	if not MusicManager.is_playing():
		return
	var phase_norm := fmod(_compensated_pos(), beat_interval) / beat_interval
	var pulse := 1.0 + 0.12 * (cos(TAU * phase_norm) * 0.5 + 0.5)
	player_rect.scale = Vector2(pulse, pulse)
	if _calibrating and phase_norm < 0.05 and _last_phase > 0.95:
		_click_player.play()
	_last_phase = phase_norm

func _handle_movement(delta: float) -> void:
	var direction := Vector2.ZERO
	if Input.is_key_pressed(KEY_Z): direction.y -= 1
	if Input.is_key_pressed(KEY_S): direction.y += 1
	if Input.is_key_pressed(KEY_Q): direction.x -= 1
	if Input.is_key_pressed(KEY_D): direction.x += 1
	position += direction.normalized() * speed * delta

func _input(event: InputEvent) -> void:
	# Restart uniquement quand mort
	if _dead:
		if event is InputEventKey and event.pressed and event.keycode == KEY_R:
			get_tree().reload_current_scene()
		return

	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_C:
			_start_calibration()
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if _calibrating:
				_record_calib_tap()
			else:
				_on_player_shoot()

# ── Calibration ───────────────────────────────────────────────────────────────

func _start_calibration() -> void:
	_calibrating = true
	_calib_phases.clear()
	calibration_status.emit("CALIBRATION — clique %d fois dans le rythme" % CALIB_TAPS)

func _record_calib_tap() -> void:
	if not MusicManager.is_playing():
		return
	var phase := fmod(_compensated_pos(), beat_interval) / beat_interval
	_calib_phases.append(phase)
	var remaining := CALIB_TAPS - _calib_phases.size()
	calibration_status.emit("CALIBRATION — encore %d taps..." % remaining if remaining > 0 else "")
	if _calib_phases.size() >= CALIB_TAPS:
		_finish_calibration()

func _finish_calibration() -> void:
	_calibrating = false
	var sum_sin := 0.0
	var sum_cos := 0.0
	for p in _calib_phases:
		sum_sin += sin(p * TAU)
		sum_cos += cos(p * TAU)
	var avg_phase := fmod(atan2(sum_sin, sum_cos) / TAU + 1.0, 1.0)
	var offset_ms := -avg_phase * beat_interval * 1000.0
	MusicManager.latency_offset_ms = offset_ms
	_save_settings(offset_ms)
	calibration_status.emit("Calibration OK — offset %.0fms" % offset_ms)

func _save_settings(offset_ms: float) -> void:
	var file := FileAccess.open(SETTINGS_PATH, FileAccess.WRITE)
	file.store_string(JSON.stringify({"latency_offset_ms": offset_ms}))
	file.close()

func _load_settings() -> void:
	if not FileAccess.file_exists(SETTINGS_PATH):
		return
	var file := FileAccess.open(SETTINGS_PATH, FileAccess.READ)
	var data = JSON.parse_string(file.get_as_text())
	file.close()
	if data is Dictionary:
		MusicManager.latency_offset_ms = float(data.get("latency_offset_ms", 0.0))

# ── Gameplay ──────────────────────────────────────────────────────────────────

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
		_thunk_shot_miss()

func _spawn_projectile(on_beat: bool) -> void:
	var p := PROJECTILE_SCENE.instantiate()
	p.on_beat = on_beat
	p.direction = Vector2.RIGHT.rotated(_aim_angle)
	_world.add_child(p)
	p.global_position = global_position
	var rect := p.get_node("ColorRect") as ColorRect
	rect.color = Color(1.0, 1.0, 1.0, 1) if on_beat else Color(0.5, 0.5, 0.5, 0.6)

func _spawn_enemy() -> void:
	if _dead:
		return
	var e := ENEMY_SCENE.instantiate()
	e.destroyed.connect(_on_enemy_destroyed)
	_world.add_child(e)
	var vp := get_viewport_rect()
	var spawn_pos: Vector2
	while true:
		spawn_pos = Vector2(randf_range(80, vp.size.x - 80), randf_range(80, vp.size.y - 80))
		if spawn_pos.distance_to(global_position) >= 200.0:
			break
	e.global_position = spawn_pos

func _on_enemy_destroyed(on_beat: bool) -> void:
	if on_beat:
		_thunk_hit()
	else:
		_miss()
	if _dead:
		return
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
	tap_bpm_updated.emit(60.0 / (total / (_tap_times.size() - 1)))

func _compensated_pos() -> float:
	return maxf(MusicManager.get_playback_position() - song_offset, 0.0)

func _thunk() -> void:
	player_rect.color = THUNK_COLOR
	_flash_reset(BASE_COLOR, 0.05)

func _thunk_shot_miss() -> void:
	player_rect.color = Color(0.5, 0.5, 0.5, 1)
	_flash_reset(BASE_COLOR, 0.05)

func _drain_jauge(pct: float) -> void:
	jauge = maxf(jauge - jauge_max * pct, 0.0)
	jauge_changed.emit(jauge, jauge_max)
	if jauge <= 0.0:
		_break_combo()

func _gain_jauge(pct: float) -> void:
	jauge = minf(jauge + jauge_max * pct, jauge_max)
	jauge_changed.emit(jauge, jauge_max)

func _break_combo() -> void:
	# Diminue progressivement : perd la moitié du combo, pas tout
	combo = max(0, combo / 2)
	jauge_max = 100.0 + combo * 5.0
	jauge = jauge_max
	combo_changed.emit(combo)
	jauge_changed.emit(jauge, jauge_max)
	player_rect.color = Color(1.0, 0.0, 0.0, 1)
	_flash_reset(BASE_COLOR, 0.18)

func _flash_reset(to_color: Color, delay: float) -> void:
	var t := create_tween()
	t.tween_interval(delay)
	t.tween_callback(func(): player_rect.color = to_color)

func _thunk_hit() -> void:
	combo += 1
	jauge_max = 100.0 + combo * 5.0
	_gain_jauge(0.15)
	combo_changed.emit(combo)
	player_rect.color = THUNK_COLOR
	Engine.time_scale = 0.0
	await get_tree().create_timer(0.07, true, false, true).timeout
	Engine.time_scale = 1.0
	player_rect.color = BASE_COLOR

func _miss() -> void:
	_drain_jauge(0.25)
	player_rect.color = MISS_COLOR
	_flash_reset(BASE_COLOR, 0.1)

func on_enemy_contact() -> void:
	if _hit_cooldown or _dead:
		return
	_hit_cooldown = true
	combo = 0
	combo_changed.emit(0)
	hp -= 1
	hp_changed.emit(hp, max_hp)
	if hp <= 0:
		_game_over()
		return
	_drain_jauge(0.40)
	player_rect.color = Color(1.0, 0.4, 0.0, 1)
	var t := create_tween()
	t.tween_interval(0.5)
	t.tween_callback(func():
		player_rect.color = BASE_COLOR
		_hit_cooldown = false)

func _game_over() -> void:
	_dead = true
	MusicManager.stop()
	# Nettoie tous les ennemis et projectiles
	for child in _world.get_children():
		child.queue_free()
	Engine.time_scale = 0.0
	await get_tree().create_timer(0.3, true, false, true).timeout
	Engine.time_scale = 1.0
	get_parent().get_node("HUD").show_game_over(combo)

func _make_click_stream() -> AudioStreamWAV:
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = 44100
	wav.stereo = false
	var samples := int(44100 * 0.06)
	var data := PackedByteArray()
	data.resize(samples * 2)
	for i in samples:
		var t := float(i) / 44100.0
		var envelope := 1.0 - (t / 0.06)
		var sample := int(envelope * 28000.0 * sin(TAU * 880.0 * t))
		data[i * 2]     = sample & 0xFF
		data[i * 2 + 1] = (sample >> 8) & 0xFF
	wav.data = data
	return wav
