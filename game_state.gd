extends Node
# AUTOLOAD "GameState". Holds data that survives scene changes, loads country data,
# and runs the game clock.
# Other systems (economy, AI, armies) should listen to  day_passed  to do daily work.

signal date_changed
signal speed_changed
signal resources_changed
signal day_passed

const PHASE_SELECT := 0     # player is choosing a country
const PHASE_PLAYING := 1    # game running

const COUNTRIES_FILE := "res://data/countries.json"
# Resources shown in the top bar. Every country in countries.json can give a value for each.
const RESOURCE_KEYS := ["money", "manpower"]

# 10 speed levels: 1-5 are SLOW, 6 is normal, 7-10 are fast.
const MIN_SPEED := 1
const MAX_SPEED := 10
const DEFAULT_SPEED := 6
# real seconds per in-game day, for each level (index = level - 1)
const SECONDS_PER_DAY := [5.0, 4.0, 3.0, 2.0, 1.5, 1.0, 0.5, 0.25, 0.1, 0.04]
# text shown in the top bar for each level
const SPEED_LABELS := ["x0.2", "x0.25", "x0.33", "x0.5", "x0.67", "x1", "x2", "x4", "x10", "x25"]

const MONTH_NAMES := ["Jan", "Feb", "Mar", "Apr", "May", "Jun",
		"Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]

var phase := PHASE_SELECT
var player_country := ""
var countries := {}         # loaded from countries.json: name -> data

# clock
var in_game := false        # true only while the game scene is open
var paused := true
var speed := DEFAULT_SPEED
var day := 1
var month := 1
var year := 2026
var _acc := 0.0

var resources := {}
var daily_change := {}


func _ready() -> void:
	_load_countries()
	reset()


# ---------------------------------------------------------------- data
func _load_countries() -> void:
	var text := FileAccess.get_file_as_string(COUNTRIES_FILE)
	if text.is_empty():
		push_error("Could not read " + COUNTRIES_FILE)
		return
	var json := JSON.new()
	var err := json.parse(text)
	if err != OK:
		push_error("%s: JSON error on line %d: %s" % [COUNTRIES_FILE, json.get_error_line(), json.get_error_message()])
		return
	if json.data is Dictionary:
		countries = json.data
		print("Loaded data for ", countries.size(), " countries")


func get_country(country: String) -> Dictionary:
	var d = countries.get(country, {})
	return d if d is Dictionary else {}


# ---------------------------------------------------------------- game flow
func reset() -> void:
	phase = PHASE_SELECT
	player_country = ""
	in_game = false
	paused = true
	speed = DEFAULT_SPEED
	day = 1
	month = 1
	year = 2026
	_acc = 0.0
	resources = {}
	daily_change = {}
	for key in RESOURCE_KEYS:
		resources[key] = 0.0
		daily_change[key] = 0.0


# Called when the player confirms their country
func start_as(country: String) -> void:
	player_country = country
	phase = PHASE_PLAYING
	var data := get_country(country)
	var res: Dictionary = data.get("resources", {})
	var chg: Dictionary = data.get("daily_change", {})
	for key in RESOURCE_KEYS:
		resources[key] = float(res.get(key, 0.0))
		daily_change[key] = float(chg.get(key, 0.0))
	paused = true
	speed_changed.emit()
	resources_changed.emit()
	date_changed.emit()


# ---------------------------------------------------------------- clock
func _process(delta: float) -> void:
	if not in_game or phase != PHASE_PLAYING or paused:
		return
	_acc += delta
	var step: float = SECONDS_PER_DAY[speed - 1]
	var days := 0
	while _acc >= step and days < 10:      # cap avoids a spiral if the game lags
		_acc -= step
		_advance_day()
		days += 1
	if days == 10:
		_acc = 0.0


func _advance_day() -> void:
	day += 1
	if day > days_in_month(month, year):
		day = 1
		month += 1
		if month > 12:
			month = 1
			year += 1
	for key in daily_change:
		resources[key] = resources.get(key, 0.0) + daily_change[key]
	day_passed.emit()
	date_changed.emit()
	resources_changed.emit()


func days_in_month(m: int, y: int) -> int:
	match m:
		2:
			return 29 if (y % 4 == 0 and (y % 100 != 0 or y % 400 == 0)) else 28
		4, 6, 9, 11:
			return 30
		_:
			return 31


func date_string() -> String:
	return "%d %s %d" % [day, MONTH_NAMES[month - 1], year]


func speed_text() -> String:
	return SPEED_LABELS[speed - 1]


func toggle_pause() -> void:
	paused = not paused
	speed_changed.emit()


func set_paused(value: bool) -> void:
	paused = value
	speed_changed.emit()


func change_speed(amount: int) -> void:
	speed = clampi(speed + amount, MIN_SPEED, MAX_SPEED)
	speed_changed.emit()
