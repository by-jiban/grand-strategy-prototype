extends Node
# Game scene script (root of game.tscn).
# Phase 1: player picks a country. Phase 2: playing (clock runs from GameState).

const DRAG_THRESHOLD := 12.0       # px a finger/mouse may wobble and still be a "tap"
const ZOOM_MAX := 6.0
const SEA_COLOR := Color(0.14, 0.27, 0.40)
const MENU_SCENE := "res://main_menu.tscn"
const BAR_HEIGHT := 80.0
const BAR_FONT := 26

# Draws white pixels as sea, and pulses the selected country's color lighter.
const MAP_SHADER := """
shader_type canvas_item;
uniform vec4 sea_color;
uniform vec4 sel_color;
uniform float sel_on = 0.0;
void fragment() {
	vec4 c = texture(TEXTURE, UV);
	if (c.r > 0.98 && c.g > 0.98 && c.b > 0.98) {
		c.rgb = sea_color.rgb;
	} else if (sel_on > 0.5 && distance(c.rgb, sel_color.rgb) < 0.003) {
		float pulse = 0.30 + 0.15 * sin(TIME * 5.0);
		c.rgb = mix(c.rgb, vec3(1.0), pulse);
	}
	COLOR = c;
}
"""

@onready var map_sprite: Sprite2D = $MapSprite
@onready var camera: Camera2D = $Camera2D
@onready var info_label: Label = $CanvasLayer/InfoLabel

var map_image: Image
var hex_to_name := {}          # "df223b" -> "China"
var name_to_hex := {}          # "China" -> "df223b"

var selected := ""
var hovered := ""

# UI (all built in code)
var top_bar: PanelContainer
var country_label: Label
var res_box: HBoxContainer
var res_labels := {}           # resource key -> Label
var clock_box: HBoxContainer
var date_label: Label
var pause_btn: Button
var speed_label: Label
var panel: PanelContainer      # bottom selection panel
var panel_label: Label
var panel_stats: Label
var play_btn: Button

# input state
var touches := {}              # finger index -> screen position
var press_pos := Vector2.ZERO
var moved := false
var mouse_down := false
var pinch_last_dist := 0.0
var pinch_last_mid := Vector2.ZERO


func _ready() -> void:
	GameState.in_game = true
	map_image = map_sprite.texture.get_image()
	_load_colors()
	_setup_look()
	_build_ui()
	camera.position = Vector2(map_image.get_size()) / 2.0
	camera.zoom = Vector2.ONE * _min_zoom()
	get_viewport().size_changed.connect(_on_resized)
	GameState.date_changed.connect(_refresh_bar_values)
	GameState.speed_changed.connect(_refresh_bar_values)
	GameState.resources_changed.connect(_refresh_bar_values)
	_refresh_ui()


func _exit_tree() -> void:
	GameState.in_game = false      # stop the clock when we leave this scene


# ---------------------------------------------------------------- setup
func _load_colors() -> void:
	var f := FileAccess.open("res://data/color_code.txt", FileAccess.READ)
	if f == null:
		push_error("Could not open res://data/color_code.txt")
		return
	while not f.eof_reached():
		var line := f.get_line().strip_edges()
		if line.is_empty() or not ":" in line:
			continue
		var idx := line.rfind(":")
		var country := line.substr(0, idx).strip_edges()
		var hex := line.substr(idx + 1).strip_edges().trim_prefix("#").to_lower()
		hex_to_name[hex] = country
		name_to_hex[country] = hex
	print("Loaded ", hex_to_name.size(), " countries")


func _setup_look() -> void:
	RenderingServer.set_default_clear_color(SEA_COLOR)    # area outside the map
	var shader := Shader.new()
	shader.code = MAP_SHADER
	var mat := ShaderMaterial.new()
	mat.shader = shader
	mat.set_shader_parameter("sea_color", SEA_COLOR)
	mat.set_shader_parameter("sel_on", 0.0)
	map_sprite.material = mat


# ---------------------------------------------------------------- UI building
func _bar_button(text: String, min_size: Vector2, callback: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = min_size
	b.focus_mode = Control.FOCUS_NONE        # so Space doesn't "click" the last button
	b.add_theme_font_size_override("font_size", BAR_FONT)
	b.pressed.connect(callback)
	return b


func _bar_label(min_width: float = 0.0) -> Label:
	var l := Label.new()
	l.custom_minimum_size = Vector2(min_width, 0)
	l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	l.add_theme_font_size_override("font_size", BAR_FONT)
	return l


func _build_ui() -> void:
	var layer := $CanvasLayer

	# ---- top bar: [Menu] [country] [resources...] ......... [date] [pause] [-] [speed] [+]
	top_bar = PanelContainer.new()
	top_bar.mouse_filter = Control.MOUSE_FILTER_STOP
	layer.add_child(top_bar)
	top_bar.anchor_left = 0.0
	top_bar.anchor_right = 1.0
	top_bar.anchor_top = 0.0
	top_bar.anchor_bottom = 0.0
	top_bar.offset_left = 0.0
	top_bar.offset_right = 0.0
	top_bar.offset_top = 0.0
	top_bar.offset_bottom = BAR_HEIGHT

	var pad := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		pad.add_theme_constant_override("margin_" + side, 8)
	top_bar.add_child(pad)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	pad.add_child(row)

	row.add_child(_bar_button("Menu", Vector2(110, 60), _go_menu))

	country_label = _bar_label()
	country_label.add_theme_font_size_override("font_size", 30)
	row.add_child(country_label)

	res_box = HBoxContainer.new()
	res_box.add_theme_constant_override("separation", 20)
	for key in GameState.resources:
		var l := _bar_label()
		res_labels[key] = l
		res_box.add_child(l)
	row.add_child(res_box)

	var spacer := Control.new()                 # pushes the clock to the right side
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spacer)

	clock_box = HBoxContainer.new()
	clock_box.add_theme_constant_override("separation", 10)
	date_label = _bar_label(190)
	date_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	clock_box.add_child(date_label)
	pause_btn = _bar_button("", Vector2(64, 60), GameState.toggle_pause)
	clock_box.add_child(pause_btn)
	clock_box.add_child(_bar_button("-", Vector2(56, 60), func(): GameState.change_speed(-1)))
	speed_label = _bar_label(90)
	speed_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	clock_box.add_child(speed_label)
	clock_box.add_child(_bar_button("+", Vector2(56, 60), func(): GameState.change_speed(1)))
	row.add_child(clock_box)

	# ---- small text under the bar (hover name on desktop)
	info_label.position = Vector2(16, BAR_HEIGHT + 10)
	info_label.add_theme_font_size_override("font_size", 28)
	info_label.add_theme_color_override("font_outline_color", Color.BLACK)
	info_label.add_theme_constant_override("outline_size", 6)

	# ---- bottom selection panel
	panel = PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	layer.add_child(panel)
	panel.anchor_left = 0.0
	panel.anchor_right = 1.0
	panel.anchor_top = 1.0
	panel.anchor_bottom = 1.0
	panel.offset_left = 16.0
	panel.offset_right = -16.0
	panel.offset_top = -136.0
	panel.offset_bottom = -16.0
	panel.grow_vertical = Control.GROW_DIRECTION_BEGIN

	var prow := HBoxContainer.new()
	prow.add_theme_constant_override("separation", 20)
	panel.add_child(prow)

	var text_box := VBoxContainer.new()
	text_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_box.alignment = BoxContainer.ALIGNMENT_CENTER
	prow.add_child(text_box)

	panel_label = Label.new()
	panel_label.add_theme_font_size_override("font_size", 36)
	text_box.add_child(panel_label)

	panel_stats = Label.new()
	panel_stats.add_theme_font_size_override("font_size", 24)
	panel_stats.modulate.a = 0.75
	text_box.add_child(panel_stats)

	play_btn = Button.new()
	play_btn.custom_minimum_size = Vector2(300, 80)
	play_btn.add_theme_font_size_override("font_size", 32)
	play_btn.pressed.connect(_on_play_pressed)
	prow.add_child(play_btn)

	panel.visible = false


func _go_menu() -> void:
	SceneManager.change_scene(MENU_SCENE)


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:      # Android back button
		_go_menu()


# ---------------------------------------------------------------- selection + UI refresh
func _set_selected(country: String) -> void:
	selected = country
	var mat := map_sprite.material as ShaderMaterial
	if selected == "":
		mat.set_shader_parameter("sel_on", 0.0)
	else:
		mat.set_shader_parameter("sel_color", Color.html(name_to_hex[selected]))
		mat.set_shader_parameter("sel_on", 1.0)
	_refresh_ui()


func _on_play_pressed() -> void:
	if selected == "":
		return
	GameState.start_as(selected)          # loads that country's data, starts paused
	_refresh_ui()


func _refresh_ui() -> void:
	var selecting := GameState.phase == GameState.PHASE_SELECT
	country_label.text = "Choose your country" if selecting else GameState.player_country
	res_box.visible = not selecting
	clock_box.visible = not selecting
	info_label.text = hovered

	panel.visible = selected != ""
	panel_label.text = selected
	panel_stats.text = _country_stats_text(selected)
	play_btn.visible = selecting
	play_btn.text = "Play as %s" % selected
	_refresh_bar_values()


func _country_stats_text(country: String) -> String:
	var d := GameState.get_country(country)
	if d.is_empty():
		return "No data yet (add it to data/countries.json)"
	return "Population: %s     GDP: $%s B" % [_fmt(d.get("population", 0)), _fmt(d.get("gdp", 0))]


func _fmt(n: float) -> String:        # 1234567 -> "1,234,567"
	var s := str(int(n))
	var out := ""
	var count := 0
	for i in range(s.length() - 1, -1, -1):
		out = s[i] + out
		count += 1
		if count % 3 == 0 and i > 0:
			out = "," + out
	return out


func _refresh_bar_values() -> void:
	for key in res_labels:
		res_labels[key].text = "%s: %s" % [key.capitalize(), _fmt(GameState.resources[key])]
	date_label.text = GameState.date_string()
	date_label.modulate.a = 0.55 if GameState.paused else 1.0
	pause_btn.text = ">" if GameState.paused else "||"      # shows what pressing will do
	speed_label.text = GameState.speed_text()


# ---------------------------------------------------------------- camera math
func _viewport_size() -> Vector2:
	return get_viewport().get_visible_rect().size


# Zoom level at which the whole map just fits on screen
func _min_zoom() -> float:
	var vp := _viewport_size()
	var m := Vector2(map_image.get_size())
	return minf(vp.x / m.x, vp.y / m.y)


func _to_world(screen_pos: Vector2) -> Vector2:
	return camera.position + (screen_pos - _viewport_size() / 2.0) / camera.zoom


# Keep the camera from scrolling off the map
func _clamp_camera() -> void:
	var m := Vector2(map_image.get_size())
	var half := _viewport_size() / (2.0 * camera.zoom.x)
	var p := camera.position
	if half.x * 2.0 >= m.x:
		p.x = m.x / 2.0
	else:
		p.x = clampf(p.x, half.x, m.x - half.x)
	if half.y * 2.0 >= m.y:
		p.y = m.y / 2.0
	else:
		p.y = clampf(p.y, half.y, m.y - half.y)
	camera.position = p


func _pan_by_screen(delta: Vector2) -> void:
	camera.position -= delta / camera.zoom
	_clamp_camera()


# Zoom while keeping the point under the cursor/fingers in place
func _zoom_at(screen_pos: Vector2, factor: float) -> void:
	var before := _to_world(screen_pos)
	camera.zoom = Vector2.ONE * clampf(camera.zoom.x * factor, _min_zoom(), ZOOM_MAX)
	camera.position += before - _to_world(screen_pos)
	_clamp_camera()


func _on_resized() -> void:
	camera.zoom = Vector2.ONE * clampf(camera.zoom.x, _min_zoom(), ZOOM_MAX)
	_clamp_camera()


# ---------------------------------------------------------------- picking
func country_at(screen_pos: Vector2) -> String:
	var px := Vector2i(_to_world(screen_pos).floor())
	if px.x < 0 or px.y < 0 or px.x >= map_image.get_width() or px.y >= map_image.get_height():
		return ""
	var hex := map_image.get_pixelv(px).to_html(false)
	return hex_to_name.get(hex, "")


# True if a screen position is on top of one of our UI controls
func _over_ui(pos: Vector2) -> bool:
	for c: Control in [top_bar, panel]:
		if c.visible and c.get_global_rect().has_point(pos):
			return true
	return false


# ---------------------------------------------------------------- input
func _pinch_points() -> Array:
	var pts := touches.values()
	return [pts[0], pts[1]]


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):          # Esc
		_go_menu()
		return

	# Keyboard shortcuts for the clock (desktop)
	if event is InputEventKey and event.pressed and not event.echo \
			and GameState.phase == GameState.PHASE_PLAYING:
		match event.keycode:
			KEY_SPACE:
				GameState.toggle_pause()
			KEY_EQUAL, KEY_KP_ADD:
				GameState.change_speed(1)
			KEY_MINUS, KEY_KP_SUBTRACT:
				GameState.change_speed(-1)
		return

	# On Android, touches also create "fake" mouse events. Ignore those here,
	# we already handle the real touch events below.
	if event is InputEventMouseButton or event is InputEventMouseMotion:
		if event.device == InputEvent.DEVICE_ID_EMULATION:
			return

	# ---------- TOUCH (Android) ----------
	if event is InputEventScreenTouch:
		if event.pressed:
			if _over_ui(event.position):
				return
			touches[event.index] = event.position
			if touches.size() == 1:
				press_pos = event.position
				moved = false
			elif touches.size() == 2:
				moved = true                          # two fingers = never a tap
				var p := _pinch_points()
				pinch_last_dist = p[0].distance_to(p[1])
				pinch_last_mid = (p[0] + p[1]) / 2.0
		else:
			if not touches.has(event.index):
				return
			if touches.size() == 1 and not moved:
				_set_selected(country_at(event.position))   # quick tap = select
			touches.erase(event.index)

	elif event is InputEventScreenDrag:
		if not touches.has(event.index):
			return
		touches[event.index] = event.position
		if touches.size() == 1:
			if not moved and event.position.distance_to(press_pos) > DRAG_THRESHOLD:
				moved = true
			if moved:
				_pan_by_screen(event.relative)
		elif touches.size() == 2:
			var p := _pinch_points()
			var dist: float = p[0].distance_to(p[1])
			var mid: Vector2 = (p[0] + p[1]) / 2.0
			if pinch_last_dist > 0.0:
				_zoom_at(mid, dist / pinch_last_dist)      # pinch = zoom at fingers
			_pan_by_screen(mid - pinch_last_mid)            # two-finger drag = pan
			pinch_last_dist = dist
			pinch_last_mid = mid

	# ---------- MOUSE (Linux / Windows) ----------
	elif event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				if _over_ui(event.position):
					return
				mouse_down = true
				press_pos = event.position
				moved = false
			else:
				if mouse_down and not moved:
					_set_selected(country_at(event.position))
				mouse_down = false
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_zoom_at(event.position, 1.1)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_zoom_at(event.position, 1.0 / 1.1)

	elif event is InputEventMouseMotion:
		if mouse_down:
			if not moved and event.position.distance_to(press_pos) > DRAG_THRESHOLD:
				moved = true
			if moved:
				_pan_by_screen(event.relative)
		else:
			var h := country_at(event.position)
			if h != hovered:
				hovered = h
				_refresh_ui()
