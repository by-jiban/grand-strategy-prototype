extends CanvasLayer
# AUTOLOAD (name it "SceneManager"). Draws a loading screen above everything
# and switches scenes without freezing.
# Usage from anywhere:  SceneManager.change_scene("res://game.tscn")

const MIN_SHOW_TIME := 0.6     # seconds, so the screen doesn't just flash
const FADE_TIME := 0.25

var overlay: ColorRect
var title_label: Label
var tip_label: Label
var bar: ProgressBar
var busy := false


func _ready() -> void:
	layer = 100                          # draw on top of everything
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_ui()
	overlay.visible = false


func _build_ui() -> void:
	overlay = ColorRect.new()
	overlay.color = Color(0.06, 0.08, 0.11)
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP    # blocks clicks while loading
	add_child(overlay)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(center)

	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(600, 0)
	box.add_theme_constant_override("separation", 24)
	center.add_child(box)

	title_label = Label.new()
	title_label.text = "Loading..."
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 44)
	box.add_child(title_label)

	bar = ProgressBar.new()
	bar.custom_minimum_size = Vector2(0, 28)
	bar.show_percentage = false
	bar.max_value = 100
	box.add_child(bar)

	tip_label = Label.new()
	tip_label.text = "Tip: pinch or scroll to zoom the map"
	tip_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tip_label.modulate = Color(1, 1, 1, 0.6)
	tip_label.add_theme_font_size_override("font_size", 24)
	box.add_child(tip_label)


func change_scene(path: String) -> void:
	if busy:
		return
	busy = true

	# 1) fade the loading screen in
	bar.value = 0
	overlay.modulate.a = 0.0
	overlay.visible = true
	var fade_in := create_tween()
	fade_in.tween_property(overlay, "modulate:a", 1.0, FADE_TIME)
	await fade_in.finished

	# 2) load the next scene in the background, updating the bar
	var start := Time.get_ticks_msec()
	ResourceLoader.load_threaded_request(path)
	var progress: Array = []
	while true:
		var status := ResourceLoader.load_threaded_get_status(path, progress)
		if progress.size() > 0:
			bar.value = progress[0] * 100.0
		if status == ResourceLoader.THREAD_LOAD_LOADED:
			break
		if status == ResourceLoader.THREAD_LOAD_FAILED \
				or status == ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
			push_error("SceneManager: failed to load " + path)
			overlay.visible = false
			busy = false
			return
		await get_tree().process_frame

	# 3) keep the screen up for a minimum time
	var elapsed := (Time.get_ticks_msec() - start) / 1000.0
	if elapsed < MIN_SHOW_TIME:
		await get_tree().create_timer(MIN_SHOW_TIME - elapsed).timeout
	bar.value = 100

	# 4) switch scene (its _ready() runs now, hidden behind the overlay)
	var packed := ResourceLoader.load_threaded_get(path) as PackedScene
	get_tree().change_scene_to_packed(packed)
	await get_tree().process_frame
	await get_tree().process_frame

	# 5) fade out
	var fade_out := create_tween()
	fade_out.tween_property(overlay, "modulate:a", 0.0, FADE_TIME)
	await fade_out.finished
	overlay.visible = false
	busy = false
