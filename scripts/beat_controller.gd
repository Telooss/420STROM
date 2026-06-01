extends Node2D

@export var hit_window_ms: float = 150.0

@onready var player_rect: ColorRect = $ColorRect

var beat_interval: float = 0.5
var combo: int = 0
var original_color: Color

func _ready() -> void:
	original_color = player_rect.color
	MusicManager.song_changed.connect(_on_song_changed)

	var songs := MusicManager.scan_songs()
	if songs.is_empty():
		push_error("BeatController: aucune chanson trouvée dans audio/songs/")
		return
	MusicManager.load_song(songs[0])

func _on_song_changed(song_data: Dictionary) -> void:
	beat_interval = 60.0 / song_data["bpm"]

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_SPACE:
			_on_player_shoot()

func _on_player_shoot() -> void:
	if not MusicManager.is_playing():
		return

	var pos: float = MusicManager.get_playback_position()
	var beat_phase: float = fmod(pos, beat_interval)
	var half_window: float = (hit_window_ms / 1000.0) / 2.0
	var on_beat: bool = beat_phase < half_window or beat_phase > (beat_interval - half_window)

	if on_beat:
		_thunk()
	else:
		_miss()

func _thunk() -> void:
	combo += 1
	print("THUNK!  combo x%d" % combo)
	player_rect.color = Color.WHITE
	await get_tree().create_timer(0.06).timeout
	player_rect.color = original_color

func _miss() -> void:
	combo = 0
	print("miss — combo reset")
	player_rect.color = Color(0.8, 0.1, 0.1)
	await get_tree().create_timer(0.1).timeout
	player_rect.color = original_color
