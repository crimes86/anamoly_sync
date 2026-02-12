extends Control
## The drawn panel for the map overlay. Handles all the _draw() logic.

const CELL_SIZE: Vector2 = Vector2(60, 50)
const PADDING: Vector2 = Vector2(20, 20)


func _ready() -> void:
	GameState.relic_acquired.connect(_on_state_changed)
	GameState.fuel_changed.connect(_on_fuel_changed)


func _on_state_changed(_data: Variant) -> void:
	if visible:
		queue_redraw()


func _on_fuel_changed(_current: float, _max_fuel: float) -> void:
	if visible:
		queue_redraw()


func _get_cell_center(x: int, y: int) -> Vector2:
	return PADDING + Vector2(x, y) * CELL_SIZE + (CELL_SIZE - Vector2(4, 4)) * 0.5


func _draw() -> void:
	if not visible:
		return

	var sectors: Dictionary = GameState.sectors
	var connections: Dictionary = GameState.connections
	var player_sector: String = GameState.current_sector_id

	# Semi-transparent background
	var bg_width: float = PADDING.x * 2 + GameState.GALAXY_WIDTH * CELL_SIZE.x
	var bg_height: float = PADDING.y * 2 + GameState.GALAXY_HEIGHT * CELL_SIZE.y + 40
	draw_rect(Rect2(Vector2.ZERO, Vector2(bg_width, bg_height)), Color(0.0, 0.0, 0.05, 0.85))
	draw_rect(Rect2(Vector2.ZERO, Vector2(bg_width, bg_height)), Color(0.3, 0.4, 0.6, 0.5), false, 2.0)

	# Title
	draw_string(ThemeDB.fallback_font, Vector2(PADDING.x, PADDING.y - 4), "GALAXY MAP [M]", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.7, 0.8, 1.0))

	# Draw connections
	var drawn_pairs: Dictionary = {}
	for sector_id in connections:
		for neighbor_id in connections[sector_id]:
			var pair_key: String = sector_id + "|" + neighbor_id if sector_id < neighbor_id else neighbor_id + "|" + sector_id
			if drawn_pairs.has(pair_key):
				continue
			drawn_pairs[pair_key] = true
			var a_data: Dictionary = sectors[sector_id]
			var b_data: Dictionary = sectors[neighbor_id]
			var a_center := _get_cell_center(a_data["x"], a_data["y"])
			var b_center := _get_cell_center(b_data["x"], b_data["y"])
			var line_color: Color
			if sector_id == player_sector or neighbor_id == player_sector:
				line_color = Color(0.3, 0.6, 1.0, 0.6)
			else:
				line_color = Color(0.2, 0.25, 0.35, 0.3)
			draw_line(a_center, b_center, line_color, 1.0)

	# Draw sector cells
	for sector_id in sectors:
		var data: Dictionary = sectors[sector_id]
		if data.get("is_void", false):
			continue

		var pos := PADDING + Vector2(data["x"], data["y"]) * CELL_SIZE
		var rect := Rect2(pos, CELL_SIZE - Vector2(4, 4))
		var center := pos + (CELL_SIZE - Vector2(4, 4)) * 0.5

		# Background
		var bg_color: Color
		if sector_id == player_sector:
			bg_color = Color(0.15, 0.4, 0.2, 0.9)
		elif data["explored"]:
			bg_color = Color(0.1, 0.1, 0.15, 0.8)
		else:
			bg_color = Color(0.04, 0.04, 0.07, 0.8)

		draw_rect(rect, bg_color)

		# Border
		if sector_id == GameState.home_sector_id:
			draw_rect(rect, Color(0.9, 0.7, 0.2, 0.6), false, 1.5)
		elif GameState.are_connected(player_sector, sector_id) and sector_id != player_sector:
			draw_rect(rect, Color(0.3, 0.7, 1.0, 0.5), false, 1.5)
		else:
			draw_rect(rect, Color(0.2, 0.25, 0.35, 0.4), false, 1.0)

		# Anomaly indicator
		if data["anomaly_family"] != "" and data["signal_strength"] > 0.0:
			if data["depleted"]:
				# Red — exhausted
				draw_circle(center, 3.0, Color(0.6, 0.1, 0.1, 0.7))
			elif data.get("player_synced", false):
				# Blue — acquired
				draw_circle(center, 4.0, Color(0.2, 0.4, 0.9, 0.6))
			else:
				# Green — available
				var alpha: float = data["signal_strength"]
				if not data["explored"]:
					alpha *= 0.3
				draw_circle(center, 5.0 * data["signal_strength"], Color(0.2, 0.9, 0.5, alpha))

		# Player marker
		if sector_id == player_sector:
			draw_circle(center + Vector2(0, -10), 3.0, Color(1.0, 1.0, 1.0, 0.9))

	# Fuel bar at bottom
	var fuel_y: float = PADDING.y + GameState.GALAXY_HEIGHT * CELL_SIZE.y + 10
	var fuel_pct: float = GameState.fuel / GameState.max_fuel
	var fuel_bar := Rect2(PADDING.x, fuel_y, 150, 10)
	draw_rect(fuel_bar, Color(0.1, 0.1, 0.15, 0.9))
	draw_rect(Rect2(fuel_bar.position, Vector2(fuel_bar.size.x * fuel_pct, fuel_bar.size.y)), Color(0.9, 0.6, 0.1, 0.9))
	draw_string(ThemeDB.fallback_font, Vector2(PADDING.x + 155, fuel_y + 10), "FUEL %.0f%%" % (fuel_pct * 100), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.8, 0.6, 0.2))
