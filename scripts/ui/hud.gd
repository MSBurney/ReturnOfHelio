class_name HUD
extends Control

## In-game heads-up display showing hearts, keys, coins, lives, and score.

# Display state (cached for redraw)
var hearts: int = 3
var max_hearts: int = 3
var key_count: int = 0
var coin_count: int = 0
var life_count: int = 5
var score_value: int = 0
var pickup_count: int = 0
var pickup_total: int = 0

func _ready() -> void:
	# Connect to GameState signals
	GameState.lives_changed.connect(_on_lives_changed)
	GameState.coins_changed.connect(_on_coins_changed)
	GameState.score_changed.connect(_on_score_changed)
	GameState.keys_changed.connect(_on_keys_changed)

	# Initialize from current GameState
	life_count = GameState.lives
	coin_count = GameState.coins
	score_value = GameState.score
	key_count = GameState.keys
	queue_redraw()

func _on_lives_changed(new_lives: int) -> void:
	life_count = new_lives
	queue_redraw()

func _on_coins_changed(new_coins: int) -> void:
	coin_count = new_coins
	queue_redraw()

func _on_score_changed(new_score: int) -> void:
	score_value = new_score
	queue_redraw()

func _on_keys_changed(new_keys: int) -> void:
	key_count = new_keys
	queue_redraw()

func update_hearts(current: int, maximum: int) -> void:
	hearts = current
	max_hearts = maximum
	queue_redraw()

func update_pickups(collected: int, total: int) -> void:
	pickup_count = collected
	pickup_total = total
	queue_redraw()

func _draw() -> void:
	_draw_hearts()
	_draw_keys()
	_draw_coins()
	_draw_lives()
	_draw_score()
	_draw_pickups()

func _draw_hearts() -> void:
	var x_start := 4.0
	var y_pos := 4.0
	var heart_size := 8.0
	var spacing := 10.0

	for i in range(max_hearts):
		var x := x_start + i * spacing
		if i < hearts:
			# Filled heart (red)
			_draw_heart_shape(Vector2(x + heart_size * 0.5, y_pos + heart_size * 0.5), heart_size * 0.5, Color(0.9, 0.15, 0.15))
		else:
			# Empty heart (dark)
			_draw_heart_shape(Vector2(x + heart_size * 0.5, y_pos + heart_size * 0.5), heart_size * 0.5, Color(0.3, 0.1, 0.1))

func _draw_heart_shape(center: Vector2, radius: float, color: Color) -> void:
	# Simple heart approximation: two circles + triangle
	var r := radius * 0.5
	draw_circle(center + Vector2(-r * 0.5, -r * 0.3), r, color)
	draw_circle(center + Vector2(r * 0.5, -r * 0.3), r, color)
	var tri := PackedVector2Array([
		center + Vector2(-radius * 0.7, -r * 0.1),
		center + Vector2(radius * 0.7, -r * 0.1),
		center + Vector2(0, radius * 0.8)
	])
	draw_colored_polygon(tri, color)

func _draw_keys() -> void:
	var x_pos := 4.0
	var y_pos := 16.0
	# Key icon: small yellow rectangle
	draw_rect(Rect2(x_pos, y_pos, 3, 5), Color(0.9, 0.8, 0.2))
	draw_rect(Rect2(x_pos + 3, y_pos + 1, 3, 2), Color(0.9, 0.8, 0.2))
	# Count text
	draw_string(ThemeDB.fallback_font, Vector2(x_pos + 10, y_pos + 6), "x%d" % key_count, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(1, 1, 1))

func _draw_coins() -> void:
	var x_pos := 4.0
	var y_pos := 26.0
	# Coin icon: small yellow circle
	draw_circle(Vector2(x_pos + 3, y_pos + 3), 3.0, Color(1.0, 0.85, 0.2))
	# Count text
	draw_string(ThemeDB.fallback_font, Vector2(x_pos + 10, y_pos + 6), "%04d" % coin_count, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(1, 1, 1))

func _draw_lives() -> void:
	# Bottom-left
	var x_pos := 4.0
	var y_pos := size.y - 14.0
	# Small player icon (blue circle)
	draw_circle(Vector2(x_pos + 3, y_pos + 3), 3.0, Color(0.2, 0.4, 0.9))
	# Count
	draw_string(ThemeDB.fallback_font, Vector2(x_pos + 10, y_pos + 6), "x%d" % life_count, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(1, 1, 1))

func _draw_score() -> void:
	# Top-right
	var score_text := "%d" % score_value
	draw_string(ThemeDB.fallback_font, Vector2(size.x - 6, 12), score_text, HORIZONTAL_ALIGNMENT_RIGHT, -1, 8, Color(1, 1, 1))

func _draw_pickups() -> void:
	if pickup_total <= 0:
		return
	# Below score, top-right area
	var text := "%d/%d" % [pickup_count, pickup_total]
	# Small pickup icon (golden circle)
	var x_pos := size.x - 50.0
	var y_pos := 16.0
	draw_circle(Vector2(x_pos, y_pos + 3), 2.5, Color(1.0, 0.85, 0.2))
	draw_string(ThemeDB.fallback_font, Vector2(x_pos + 6, y_pos + 6), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(1, 1, 1))
