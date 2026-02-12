extends Node2D
## Galaxy map — 2D grid of connected sectors. Player navigates sector-by-sector.

const CELL_SIZE: Vector2 = Vector2(120, 100)
const GRID_OFFSET: Vector2 = Vector2(100, 80)

var selected_sector: String = ""


func _ready() -> void:
	queue_redraw()


func _get_cell_center(x: int, y: int) -> Vector2:
	return GRID_OFFSET + Vector2(x, y) * CELL_SIZE + (CELL_SIZE - Vector2(4, 4)) * 0.5


func _draw() -> void:
	var sectors: Dictionary = GameState.sectors
	var connections: Dictionary = GameState.connections
	var player_sector: String = GameState.current_sector_id

	# Draw connection lines first (behind cells)
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
			# Brighter lines for connections from player's current sector
			var line_color: Color
			if sector_id == player_sector or neighbor_id == player_sector:
				line_color = Color(0.3, 0.6, 1.0, 0.7)
			else:
				line_color = Color(0.2, 0.25, 0.4, 0.4)
			draw_line(a_center, b_center, line_color, 2.0)

	# Draw sector cells
	for sector_id in sectors:
		var data: Dictionary = sectors[sector_id]
		var pos := GRID_OFFSET + Vector2(data["x"], data["y"]) * CELL_SIZE
		var rect := Rect2(pos, CELL_SIZE - Vector2(4, 4))
		var center := pos + (CELL_SIZE - Vector2(4, 4)) * 0.5

		# Void sectors — empty space, no cell drawn
		if data.get("is_void", false):
			continue

		# Background color
		var bg_color: Color
		if sector_id == player_sector:
			bg_color = Color(0.15, 0.4, 0.2, 0.9)  # Green — you are here
		elif sector_id == selected_sector:
			bg_color = Color(0.2, 0.35, 0.7, 0.9)
		elif data["explored"]:
			bg_color = Color(0.12, 0.12, 0.18, 0.9)
		else:
			bg_color = Color(0.06, 0.06, 0.1, 0.9)

		draw_rect(rect, bg_color)

		# Home base border
		if sector_id == GameState.home_sector_id:
			draw_rect(rect, Color(0.9, 0.7, 0.2, 0.7), false, 2.0)
		# Border — highlight connected sectors as jumpable
		elif GameState.are_connected(player_sector, sector_id) and sector_id != player_sector:
			draw_rect(rect, Color(0.3, 0.7, 1.0, 0.6), false, 2.0)
		else:
			draw_rect(rect, Color(0.25, 0.3, 0.45, 0.5), false, 1.0)

		# Anomaly indicator
		if data["anomaly_family"] != "" and data["signal_strength"] > 0.0:
			var signal_alpha: float = data["signal_strength"]
			if not data["explored"]:
				signal_alpha *= 0.35
			var family_col: Color = GameState.get_family_color(data["anomaly_family"])
			if data["depleted"]:
				# Dimmed family color — exhausted, no syncs left
				draw_circle(center, 6.0, Color(family_col.r * 0.4, family_col.g * 0.4, family_col.b * 0.4, 0.6))
				draw_circle(center, 3.0, Color(0.3, 0.05, 0.05, 0.6))
			elif data.get("player_synced", false):
				# Desaturated family color — acquired, you've synced this one
				var synced_col := family_col.lerp(Color(0.5, 0.5, 0.6), 0.5)
				draw_circle(center, 7.0, Color(synced_col.r, synced_col.g, synced_col.b, 0.6))
				draw_circle(center, 3.5, Color(synced_col.r, synced_col.g, synced_col.b, 0.4))
			else:
				# Family color — available, not yet synced
				var signal_color := Color(family_col.r, family_col.g, family_col.b, signal_alpha)
				draw_circle(center, 10.0 * data["signal_strength"], signal_color)

		# Player marker
		if sector_id == player_sector:
			draw_circle(center + Vector2(0, -18), 5.0, Color(1.0, 1.0, 1.0, 0.9))

	# Draw selected sector detail panel
	if selected_sector != "":
		_draw_sector_detail(sectors, player_sector)

	# Draw info bar at bottom
	var info_y: float = GRID_OFFSET.y + GALAXY_HEIGHT_PX + 16
	var fuel_pct: float = GameState.fuel / GameState.max_fuel
	var fuel_bar_rect := Rect2(GRID_OFFSET.x, info_y, 200, 16)
	draw_rect(fuel_bar_rect, Color(0.1, 0.1, 0.15, 0.9))
	draw_rect(Rect2(fuel_bar_rect.position, Vector2(fuel_bar_rect.size.x * fuel_pct, fuel_bar_rect.size.y)), Color(0.9, 0.6, 0.1, 0.9))
	draw_rect(fuel_bar_rect, Color(0.4, 0.4, 0.5, 0.6), false, 1.0)
	draw_string(ThemeDB.fallback_font, Vector2(GRID_OFFSET.x + 210, info_y + 13), "FUEL %.0f/%.0f" % [GameState.fuel, GameState.max_fuel], HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.8, 0.6, 0.2))

	# Status line
	draw_string(ThemeDB.fallback_font, Vector2(GRID_OFFSET.x, info_y + 36), "HOME BASE  |  WARP [Q] to return  |  %d CR" % GameState.player_credits, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.6, 0.6, 0.7))


# Precomputed for fuel bar positioning
var GALAXY_HEIGHT_PX: float:
	get:
		return GameState.GALAXY_HEIGHT * CELL_SIZE.y


func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var click_pos: Vector2 = event.position - GRID_OFFSET
		var grid_x := int(click_pos.x / CELL_SIZE.x)
		var grid_y := int(click_pos.y / CELL_SIZE.y)
		if grid_x < 0 or grid_x >= GameState.GALAXY_WIDTH or grid_y < 0 or grid_y >= GameState.GALAXY_HEIGHT:
			return
		var sector_id := "S_%d_%d" % [grid_x, grid_y]
		if GameState.sectors.has(sector_id) and not GameState.sectors[sector_id].get("is_void", false):
			selected_sector = sector_id
			queue_redraw()

	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT and event.double_click:
		if selected_sector != "" and selected_sector != GameState.current_sector_id:
			_try_jump_to_sector(selected_sector)


func _draw_sector_detail(sectors: Dictionary, player_sector: String) -> void:
	if not sectors.has(selected_sector):
		return
	var data: Dictionary = sectors[selected_sector]

	# Draw highlight border on selected cell
	var sel_pos := GRID_OFFSET + Vector2(data["x"], data["y"]) * CELL_SIZE
	var sel_rect := Rect2(sel_pos, CELL_SIZE - Vector2(4, 4))
	draw_rect(sel_rect, Color(1.0, 1.0, 1.0, 0.7), false, 2.0)

	# Panel position — right side of the grid
	var panel_x: float = GRID_OFFSET.x + GameState.GALAXY_WIDTH * CELL_SIZE.x + 20
	var panel_y: float = GRID_OFFSET.y
	var line_h: float = 18.0
	var label_color := Color(0.5, 0.55, 0.65)
	var value_color := Color(0.85, 0.85, 0.9)
	var y_off: float = 0.0

	# Sector name
	draw_string(ThemeDB.fallback_font, Vector2(panel_x, panel_y + y_off + 13), selected_sector, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(1.0, 1.0, 1.0, 0.9))
	y_off += line_h + 4

	# Status line
	var is_home: bool = selected_sector == GameState.home_sector_id
	var is_current: bool = selected_sector == player_sector
	var can_jump: bool = GameState.are_connected(player_sector, selected_sector) and selected_sector != player_sector
	if is_home:
		draw_string(ThemeDB.fallback_font, Vector2(panel_x, panel_y + y_off + 13), "HOME BASE", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.9, 0.7, 0.2))
		y_off += line_h
	if is_current:
		draw_string(ThemeDB.fallback_font, Vector2(panel_x, panel_y + y_off + 13), "YOU ARE HERE", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.3, 0.9, 0.4))
		y_off += line_h
	elif can_jump:
		draw_string(ThemeDB.fallback_font, Vector2(panel_x, panel_y + y_off + 13), "IN JUMP RANGE", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.3, 0.7, 1.0))
		y_off += line_h
	else:
		draw_string(ThemeDB.fallback_font, Vector2(panel_x, panel_y + y_off + 13), "OUT OF RANGE", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.5, 0.5, 0.55))
		y_off += line_h

	y_off += 6

	# Anomaly info
	var family: String = data.get("anomaly_family", "")
	if family != "":
		var family_col: Color = GameState.get_family_color(family)
		draw_string(ThemeDB.fallback_font, Vector2(panel_x, panel_y + y_off + 13), "Anomaly:", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, label_color)
		draw_string(ThemeDB.fallback_font, Vector2(panel_x + 70, panel_y + y_off + 13), family, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, family_col)
		y_off += line_h

		# Sync status
		draw_string(ThemeDB.fallback_font, Vector2(panel_x, panel_y + y_off + 13), "Status:", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, label_color)
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
		draw_string(ThemeDB.fallback_font, Vector2(panel_x + 70, panel_y + y_off + 13), status_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, status_color)
		y_off += line_h

		# Signal strength
		draw_string(ThemeDB.fallback_font, Vector2(panel_x, panel_y + y_off + 13), "Signal:", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, label_color)
		draw_string(ThemeDB.fallback_font, Vector2(panel_x + 70, panel_y + y_off + 13), "%.0f%%" % (data["signal_strength"] * 100), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, value_color)
		y_off += line_h

		# Stability
		draw_string(ThemeDB.fallback_font, Vector2(panel_x, panel_y + y_off + 13), "Stability:", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, label_color)
		draw_string(ThemeDB.fallback_font, Vector2(panel_x + 70, panel_y + y_off + 13), "%.0f%%" % (data["stability"] * 100), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, value_color)
		y_off += line_h

		# Syncs remaining (only if explored)
		if data["explored"]:
			draw_string(ThemeDB.fallback_font, Vector2(panel_x, panel_y + y_off + 13), "Syncs:", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, label_color)
			draw_string(ThemeDB.fallback_font, Vector2(panel_x + 70, panel_y + y_off + 13), "%d / %d" % [data["syncs_remaining"], data["sync_pool"]], HORIZONTAL_ALIGNMENT_LEFT, -1, 12, value_color)
			y_off += line_h
	else:
		draw_string(ThemeDB.fallback_font, Vector2(panel_x, panel_y + y_off + 13), "No anomaly", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.4, 0.4, 0.45))
		y_off += line_h

	if not data["explored"]:
		y_off += 6
		draw_string(ThemeDB.fallback_font, Vector2(panel_x, panel_y + y_off + 13), "UNEXPLORED", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.45, 0.45, 0.5))


func _try_jump_to_sector(sector_id: String) -> void:
	# Can only jump to directly connected sectors
	if not GameState.are_connected(GameState.current_sector_id, sector_id):
		return

	# Check fuel
	if not GameState.consume_fuel_for_jump():
		return

	GameState.enter_sector(sector_id)
	GameState.pending_sector_data = GameState.sectors[sector_id]
	GameState.pending_sector_id = sector_id
	GameState.pending_entry_direction = ""
	get_tree().change_scene_to_file("res://scenes/sector.tscn")
