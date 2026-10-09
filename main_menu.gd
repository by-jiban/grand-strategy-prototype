extends Control
# Root node of main_menu.tscn (a plain Control). Builds the whole menu in code.

const GAME_SCENE := "res://game.tscn"


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_build_ui()


func _build_ui() -> void:
	# Background: soft vertical gradient (dark top -> blue-ish bottom)
	var grad := Gradient.new()
	grad.set_color(0, Color(0.04, 0.07, 0.12))
	grad.set_color(1, Color(0.13, 0.24, 0.36))
	var grad_tex := GradientTexture2D.new()
	grad_tex.gradient = grad
	grad_tex.fill_from = Vector2(0.5, 0.0)
	grad_tex.fill_to = Vector2(0.5, 1.0)
	var bg := TextureRect.new()
	bg.texture = grad_tex
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_SCALE
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 22)
	center.add_child(box)

	var title := Label.new()
	title.text = "GRAND STRATEGY"            # placeholder: put your game name here
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 64)
	box.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "Asia-Pacific  -  prototype"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.modulate = Color(1, 1, 1, 0.6)
	subtitle.add_theme_font_size_override("font_size", 26)
	box.add_child(subtitle)

	box.add_child(Control.new())               # small spacer

	box.add_child(_make_button("New Game", _on_new_game))
	var settings := _make_button("Settings (soon)", func(): pass)
	settings.disabled = true
	box.add_child(settings)
	box.add_child(_make_button("Quit", _on_quit))

	var version := Label.new()
	version.text = "v0.0.1"
	version.modulate = Color(1, 1, 1, 0.4)
	version.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT, Control.PRESET_MODE_MINSIZE, 16)
	add_child(version)


# Big buttons: easy to hit with a finger (~90 px tall at base resolution)
func _make_button(text: String, callback: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(520, 90)
	b.add_theme_font_size_override("font_size", 36)
	b.pressed.connect(callback)
	return b


func _on_new_game() -> void:
	GameState.reset()
	SceneManager.change_scene(GAME_SCENE)


func _on_quit() -> void:
	get_tree().quit()
