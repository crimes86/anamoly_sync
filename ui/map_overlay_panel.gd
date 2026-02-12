extends Control
## The drawn panel for the map overlay. Handles all the _draw() logic.

const CELL_SIZE: Vector2 = Vector2(60, 50)
const PADDING: Vector2 = Vector2(16, 28)

var selected_sector: String = ""


func _ready() -> void:
	GameState.relic_acquired.connect(_on_state_changed)
	GameState.fuel_changed.connect(_on_fuel_changed)
	mouse_filter = Control.MOUSE_FILTER_STOP


func _on_state_changed(_data: Variant) -> void:
	if visible:
		queue_redraw()


func _on_fuel_changed(_current: float, _max_fuel: float) -> void:
	if visible:
		queue_redraw()


func _get_cell_center(x: int, y: int) -> Vector2:
	return PADDING + Vector2(x, y) * CELL_SIZE + (CELL_SIZE - Vector2(4, 4)) * 0.5


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var click_pos: Vector2 = event.position - PADDING
		var grid_x := int(click_pos.x / CELL_SIZE.x)
		var grid_y := int(click_pos.y / CELL_SIZE.y)
		if grid_x < 0 or grid_x >= GameState.GALAXY_WIDTH or grid_y < 0 or grid_y >= GameState.GALAXY_HEIGHT:
			selected_sector = ""
			queue_redraw()
			return
		var sector_id := "S_%d_%d" % [grid_x, grid_y]
		if GameState.sectors.has(sector_id) and not GameState.sectors[sector_id].get("is_void", false):
			selected_sector = sector_id
		else:
			selected_sector = ""
		queue_redraw()


func _draw() -> void:
	if not visible:
		return

	var sectors: Dictionary = GameState.sectors
	var connections: Dictionary = GameState.connections
	var player_sector: String = GameState.current_sector_id

	# Semi-transparent background — full panel width
	var grid_width: float = GameState.GALAXY_WIDTH * CELL_SIZE.x
	var grid_height: float = GameState.GALAXY_HEIGHT * CELL_SIZE.y
	var bg_width: float = size.x
	var bg_height: float = size.y
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
		elif sector_id == selected_sector:
			bg_color = Color(0.2, 0.25, 0.35, 0.9)
		elif data["explored"]:
			bg_color = Color(0.1, 0.1, 0.15, 0.8)
		else:
			bg_color = Color(0.04, 0.04, 0.07, 0.8)

		draw_rect(rect, bg_color)

		# Border
		if sector_id == selected_sector:
			draw_rect(rect, Color(1.0, 1.0, 1.0, 0.7), false, 1.5)
		elif sector_id == GameState.home_sector_id:
			draw_rect(rect, Color(0.9, 0.7, 0.2, 0.6), false, 1.5)
		elif GameState.are_connected(player_sector, sector_id) and sector_id != player_sector:
			draw_rect(rect, Color(0.3, 0.7, 1.0, 0.5), false, 1.5)
		else:
			draw_rect(rect, Color(0.2, 0.25, 0.35, 0.4), false, 1.0)

		# Anomaly indicator
		if data["anomaly_family"] != "" and data["signal_strength"] > 0.0:
			var family_col: Color = GameState.get_family_color(data["anomaly_family"])
			if data["depleted"]:
				draw_circle(center, 3.0, Color(family_col.r * 0.4, family_col.g * 0.4, family_col.b * 0.4, 0.5))
			elif data.get("player_synced", false):
				var synced_col := family_col.lerp(Color(0.5, 0.5, 0.6), 0.5)
				draw_circle(center, 4.0, Color(synced_col.r, synced_col.g, synced_col.b, 0.5))
			else:
				var alpha: float = data["signal_strength"]
				if not data["explored"]:
					alpha *= 0.3
				draw_circle(center, 5.0 * data["signal_strength"], Color(family_col.r, family_col.g, family_col.b, alpha))

		# Player marker
		if sector_id == player_sector:
			draw_circle(center + Vector2(0, -10), 3.0, Color(1.0, 1.0, 1.0, 0.9))

	# Fuel bar at bottom of grid area
	var fuel_y: float = PADDING.y + grid_height + 10
	var fuel_pct: float = GameState.fuel / GameState.max_fuel
	var fuel_bar := Rect2(PADDING.x, fuel_y, 150, 10)
	draw_rect(fuel_bar, Color(0.1, 0.1, 0.15, 0.9))
	draw_rect(Rect2(fuel_bar.position, Vector2(fuel_bar.size.x * fuel_pct, fuel_bar.size.y)), Color(0.9, 0.6, 0.1, 0.9))
	draw_string(ThemeDB.fallback_font, Vector2(PADDING.x + 155, fuel_y + 10), "FUEL %.0f%%" % (fuel_pct * 100), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.8, 0.6, 0.2))

	# Selected sector detail panel
	if selected_sector != "" and sectors.has(selected_sector):
		_draw_sector_detail(sectors)


func _draw_sector_detail(sectors: Dictionary) -> void:
	var data: Dictionary = sectors[selected_sector]
	var player_sector: String = GameState.current_sector_id

	var panel_x: float = PADDING.x + GameState.GALAXY_WIDTH * CELL_SIZE.x + 16
	var panel_y: float = PADDING.y + 10
	var line_h: float = 16.0
	var label_color := Color(0.5, 0.55, 0.65)
	var value_color := Color(0.85, 0.85, 0.9)
	var y_off: float = 0.0

	# Sector name
	draw_string(ThemeDB.fallback_font, Vector2(panel_x, panel_y + y_off + 12), selected_sector, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(1.0, 1.0, 1.0, 0.9))
	y_off += line_h + 2

	# Location status
	var is_home: bool = selected_sector == GameState.home_sector_id
	var is_current: bool = selected_sector == player_sector
	var can_jump: bool = GameState.are_connected(player_sector, selected_sector) and selected_sector != player_sector
	if is_home:
		draw_string(ThemeDB.fallback_font, Vector2(panel_x, panel_y + y_off + 12), "HOME BASE", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.9, 0.7, 0.2))
		y_off += line_h
	if is_current:
		draw_string(ThemeDB.fallback_font, Vector2(panel_x, panel_y + y_off + 12), "YOU ARE HERE", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.3, 0.9, 0.4))
		y_off += line_h
	elif can_jump:
		draw_string(ThemeDB.fallback_font, Vector2(panel_x, panel_y + y_off + 12), "IN JUMP RANGE", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.3, 0.7, 1.0))
		y_off += line_h
	else:
		draw_string(ThemeDB.fallback_font, Vector2(panel_x, panel_y + y_off + 12), "OUT OF RANGE", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.5, 0.5, 0.55))
		y_off += line_h

	y_off += 4

	# Anomaly info
	var family: String = data.get("anomaly_family", "")
	if family != "":
		var family_col: Color = GameState.get_family_color(family)
		draw_string(ThemeDB.fallback_font, Vector2(panel_x, panel_y + y_off + 12), "Anomaly:", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, label_color)
		draw_string(ThemeDB.fallback_font, Vector2(panel_x + 60, panel_y + y_off + 12), family, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, family_col)
		y_off += line_h

		draw_string(ThemeDB.fallback_font, Vector2(panel_x, panel_y + y_off + 12), "Status:", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, label_color)
		var status_text: String
		var status_color: Color
		if data.get("depleted", false):
			status_text = "DEPLETED"
			status_color = Color(0.7, 0.2, 0.2)
		elif data.get("player_synced", false):
			status_text = "SYNCED"
			status_color = Color(0.3, 0.5, 1.0)
		else:
			status_text = "AVAILABLE"
			status_color = Color(0.3, 0.9, 0.5)
		draw_string(ThemeDB.fallback_font, Vector2(panel_x + 60, panel_y + y_off + 12), status_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, status_color)
		y_off += line_h

		draw_string(ThemeDB.fallback_font, Vector2(panel_x, panel_y + y_off + 12), "Signal:", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, label_color)
		draw_string(ThemeDB.fallback_font, Vector2(panel_x + 60, panel_y + y_off + 12), "%.0f%%" % (data["signal_strength"] * 100), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, value_color)
		y_off += line_h

		draw_string(ThemeDB.fallback_font, Vector2(panel_x, panel_y + y_off + 12), "Stability:", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, label_color)
		draw_string(ThemeDB.fallback_font, Vector2(panel_x + 60, panel_y + y_off + 12), "%.0f%%" % (data["stability"] * 100), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, value_color)
		y_off += line_h

		if data["explored"]:
			draw_string(ThemeDB.fallback_font, Vector2(panel_x, panel_y + y_off + 12), "Syncs:", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, label_color)
			draw_string(ThemeDB.fallback_font, Vector2(panel_x + 60, panel_y + y_off + 12), "%d / %d" % [data["syncs_remaining"], data["sync_pool"]], HORIZONTAL_ALIGNMENT_LEFT, -1, 11, value_color)
			y_off += line_h
	else:
		draw_string(ThemeDB.fallback_font, Vector2(panel_x, panel_y + y_off + 12), "No anomaly", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.4, 0.4, 0.45))
		y_off += line_h

	if not data["explored"]:
		y_off += 4
		draw_string(ThemeDB.fallback_font, Vector2(panel_x, panel_y + y_off + 12), "UNEXPLORED", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(0.45, 0.45, 0.5))
