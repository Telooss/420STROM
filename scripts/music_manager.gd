extends Node

signal song_changed(song_data: Dictionary)
signal bpm_updated(bpm: float)

const SONGS_DIR := "res://audio/songs/"

## BPM de départ en dessous du BPM cible (ex: 50 → démarre à bpm_cible - 50)
@export var bpm_start_offset: float = 50.0
## Vitesse de montée en BPM par seconde
@export var bpm_ramp_per_sec: float = 2.0

var base_bpm: float = 120.0
var current_bpm: float = 120.0
var current_song: Dictionary = {}
var _ramping: bool = false

@onready var _player: AudioStreamPlayer = AudioStreamPlayer.new()

func _ready() -> void:
	add_child(_player)

func _process(delta: float) -> void:
	if not _ramping:
		return
	current_bpm = minf(current_bpm + bpm_ramp_per_sec * delta, base_bpm)
	_player.pitch_scale = current_bpm / base_bpm
	bpm_updated.emit(current_bpm)
	if current_bpm >= base_bpm:
		_ramping = false

func load_song(ogg_path: String) -> void:
	var json_path := ogg_path.replace(".ogg", ".json")
	var bpm := 120.0
	var offset := 0.0
	var title := ogg_path.get_file().get_basename()

	if FileAccess.file_exists(json_path):
		var file := FileAccess.open(json_path, FileAccess.READ)
		var parsed = JSON.parse_string(file.get_as_text())
		file.close()
		if parsed is Dictionary:
			bpm = float(parsed.get("bpm", 120.0))
			offset = float(parsed.get("offset", 0.0))
			title = str(parsed.get("title", title))

	base_bpm = bpm
	current_bpm = maxf(base_bpm - bpm_start_offset, 60.0)
	_ramping = current_bpm < base_bpm
	current_song = {"title": title, "bpm": bpm, "offset": offset, "path": ogg_path}

	_player.stream = load(ogg_path)
	_player.pitch_scale = current_bpm / base_bpm
	_player.play(offset)

	song_changed.emit(current_song)
	bpm_updated.emit(current_bpm)
	print("MusicManager: %s — start %.0f BPM → %.0f BPM cible" % [title, current_bpm, base_bpm])

func scan_songs() -> Array[String]:
	var songs: Array[String] = []
	var dir := DirAccess.open(SONGS_DIR)
	if not dir:
		push_error("MusicManager: dossier introuvable — " + SONGS_DIR)
		return songs
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if file_name.ends_with(".ogg"):
			songs.append(SONGS_DIR + file_name)
		file_name = dir.get_next()
	dir.list_dir_end()
	return songs

## Décalage manuel en ms si la détection de beat semble en avance ou en retard.
## Positif = avance la grille, négatif = recule la grille.
@export var latency_offset_ms: float = 0.0

func get_playback_position() -> float:
	return _player.get_playback_position() + (latency_offset_ms / 1000.0)

func is_playing() -> bool:
	return _player.playing

func stop() -> void:
	_player.stop()
