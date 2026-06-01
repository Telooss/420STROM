extends Node2D

@export var hit_window_ms: float = 150.0

@onready var player_rect: ColorRect = $ColorRect

var beat_interval: float = 0.5
var combo: int = 0
var song_offset: float = 0.0

const BASE_COLOR    := Color(0.2, 0.6, 1.0, 1)
const BEAT_COLOR    := Color(0.4, 0.8, 1.0, 1)
const THUNK_COLOR   := Color(1.0, 1.0, 1.0, 1)
const MISS_COLOR    := Color(0.8, 0.1, 0.1, 1)

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
	# Pulse visuel : le carré grossit légèrement sur le beat pour que tu vois où il tombe
	var pos := _compensated_pos()
	var beat_phase := fmod(pos, beat_interval)
	var phase_norm := beat_phase / beat_interval  # 0.0 → 1.0
	var pulse := 1.0 + 0.08 * (1.0 - phase_norm)  # plus grand en début de beat
	player_rect.scale = Vector2(pulse, pulse)

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_SPACE:
			_on_player_shoot()

func _on_player_shoot() -> void:
	if not MusicManager.is_playing():
		return
	var pos := _compensated_pos()
	var beat_phase := fmod(pos, beat_interval)
	var half_window := (hit_window_ms / 1000.0) / 2.0
	var on_beat := beat_phase < half_window or beat_phase > (beat_interval - half_window)

	if on_beat:
		_thunk()
	else:
		_miss()

func _compensated_pos() -> float:
	return maxf(MusicManager.get_playback_position() - song_offset, 0.0)

func _thunk() -> void:
	combo += 1
	print("THUNK!  combo x%d" % combo)
	player_rect.color = THUNK_COLOR
	await get_tree().create_timer(0.06).timeout
	player_rect.color = BASE_COLOR

func _miss() -> void:
	combo = 0
	print("miss — combo reset")
	player_rect.color = MISS_COLOR
	await get_tree().create_timer(0.1).timeout
	player_rect.color = BASE_COLOR
