extends Node

signal song_changed(song_data: Dictionary)

const SONGS_DIR := "res://audio/songs/"

var base_bpm: float = 120.0
var current_bpm: float = 120.0
var current_song: Dictionary = {}
var latency_offset_ms: float = 0.0

@onready var _player: AudioStreamPlayer = AudioStreamPlayer.new()

func _ready() -> void:
	add_child(_player)

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
	current_bpm = bpm
	current_song = {"title": title, "bpm": bpm, "offset": offset, "path": ogg_path}

	_player.stream = load(ogg_path)
	_player.pitch_scale = 1.0
	_player.play(offset)
	song_changed.emit(current_song)
	print("MusicManager: %s — %s BPM" % [title, bpm])

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

func get_playback_position() -> float:
	return _player.get_playback_position() + (latency_offset_ms / 1000.0)

func is_playing() -> bool:
	return _player.playing

func stop() -> void:
	_player.stop()
