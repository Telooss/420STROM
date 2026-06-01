extends Node2D

@export var hit_window_ms: float = 150.0

@onready var player_rect: ColorRect = $ColorRect

var beat_interval: float = 0.5
var combo: int = 0
var song_offset: float = 0.0
var _last_press_time: float = -999.0

const BASE_COLOR  := Color(0.2, 0.6, 1.0, 1)
const THUNK_COLOR := Color(1.0, 1.0, 1.0, 1)
const MISS_COLOR  := Color(0.8, 0.1, 0.1, 1)

func _ready() -> void:
	player_rect.color = BASE_COLOR
	MusicManager.song_changed.connect(_on_song_changed)
	var songs := MusicManager.scan_songs()
	if songs.is_empty():
		push_error("BeatController: aucune chanson trouvée dans audio/songs/")
		return
	MusicManager.load_song(songs[0])

func _on_song_changed(song_data: Dictionary) -> void:
	beat_interval = 60.0 / song_data["bpm"]
	song_offset = song_data.get("offset", 0.0)

func _process(_delta: float) -> void:
	if not MusicManager.is_playing():
		return
	var phase_norm := fmod(_compensated_pos(), beat_interval) / beat_interval
	# Pulse symétrique : gros AUX DEUX extrémités (= là où le beat tombe)
	var pulse := 1.0 + 0.12 * (cos(TAU * phase_norm) * 0.5 + 0.5)
	player_rect.scale = Vector2(pulse, pulse)

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_SPACE:
			_on_player_shoot()

func _on_player_shoot() -> void:
	if not MusicManager.is_playing():
		return

	# Cooldown : impossible de valider deux fois sur le même beat
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

	if on_beat:
		_thunk()
	else:
		_miss()

func _compensated_pos() -> float:
	return maxf(MusicManager.get_playback_position() - song_offset, 0.0)

func _thunk() -> void:
	combo += 1
	player_rect.color = THUNK_COLOR
	await get_tree().create_timer(0.06).timeout
	player_rect.color = BASE_COLOR

func _miss() -> void:
	combo = 0
	player_rect.color = MISS_COLOR
	await get_tree().create_timer(0.1).timeout
	player_rect.color = BASE_COLOR
