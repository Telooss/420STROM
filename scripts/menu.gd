extends Node

var _options_open: bool = false
var _options_panel: ColorRect

func _ready() -> void:
	var vp := get_viewport().get_visible_rect().size

	# Fond
	var bg := ColorRect.new()
	bg.color = Color(0.04, 0.04, 0.08)
	bg.size = vp
	add_child(bg)

	# Titre
	var title := Label.new()
	title.text = "420STORM"
	title.add_theme_font_size_override("font_size", 80)
	title.modulate = Color(0.2, 0.85, 1.0)
	title.position = Vector2(vp.x / 2.0 - 210, vp.y * 0.22)
	add_child(title)

	var sub := Label.new()
	sub.text = "RYTHM  ROGUELIKE  ARCADE"
	sub.add_theme_font_size_override("font_size", 16)
	sub.modulate = Color(0.4, 0.6, 0.8)
	sub.position = Vector2(vp.x / 2.0 - 148, vp.y * 0.22 + 88)
	add_child(sub)

	# Boutons
	_make_button("JOUER",   Vector2(vp.x / 2.0 - 90, vp.y * 0.55),       _on_play)
	_make_button("OPTIONS", Vector2(vp.x / 2.0 - 90, vp.y * 0.55 + 70),  _on_options)

	# Panel options (caché par défaut)
	_build_options_panel(vp)

func _on_play() -> void:
	get_tree().change_scene_to_file("res://node_2d.tscn")

func _on_options() -> void:
	_options_open = !_options_open
	_options_panel.visible = _options_open

func _build_options_panel(vp: Vector2) -> void:
	_options_panel = ColorRect.new()
	_options_panel.color = Color(0.06, 0.06, 0.14, 0.97)
	_options_panel.size = Vector2(420, 240)
	_options_panel.position = Vector2(vp.x / 2.0 - 210, vp.y / 2.0 - 120)
	_options_panel.visible = false
	add_child(_options_panel)

	var title := Label.new()
	title.text = "OPTIONS"
	title.add_theme_font_size_override("font_size", 28)
	title.modulate = Color(0.2, 0.85, 1.0)
	title.position = Vector2(140, 20)
	_options_panel.add_child(title)

	var calib_info := Label.new()
	calib_info.text = "Calibration latence\nLancer une partie puis appuyer sur C\npour calibrer le timing automatiquement."
	calib_info.add_theme_font_size_override("font_size", 14)
	calib_info.modulate = Color(0.8, 0.8, 0.8)
	calib_info.position = Vector2(20, 80)
	calib_info.autowrap_mode = TextServer.AUTOWRAP_WORD
	calib_info.size = Vector2(380, 100)
	_options_panel.add_child(calib_info)

	var back := _make_button("FERMER", Vector2(140, 175), _on_options, _options_panel)
	back.size = Vector2(140, 42)

func _make_button(txt: String, pos: Vector2, callback: Callable, parent: Node = self) -> Button:
	var btn := Button.new()
	btn.text = txt
	btn.position = pos
	btn.size = Vector2(180, 50)
	btn.add_theme_font_size_override("font_size", 26)
	btn.add_theme_color_override("font_color",       Color(1, 1, 1))
	btn.add_theme_color_override("font_hover_color", Color(0.2, 1.0, 0.8))
	btn.add_theme_stylebox_override("normal",  _stylebox(Color(0.1, 0.1, 0.22)))
	btn.add_theme_stylebox_override("hover",   _stylebox(Color(0.15, 0.25, 0.45)))
	btn.add_theme_stylebox_override("pressed", _stylebox(Color(0.2, 0.6, 1.0, 0.5)))
	btn.pressed.connect(callback)
	parent.add_child(btn)
	return btn

func _stylebox(color: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = color
	sb.border_color = Color(0.25, 0.55, 1.0, 0.6)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(4)
	return sb
