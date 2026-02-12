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
			if data["depleted"]:
				# Red — exhausted, no syncs left
				draw_circle(center, 6.0, Color(0.6, 0.1, 0.1, 0.8))
				draw_circle(center, 3.0, Color(0.3, 0.05, 0.05, 0.6))
			elif data.get("player_synced", false):
				# Blue — acquired, you've synced this one
				draw_circle(center, 7.0, Color(0.2, 0.4, 0.9, 0.7))
				draw_circle(center, 3.5, Color(0.3, 0.5, 1.0, 0.5))
			else:
				# Bright green — available, not yet synced
				var signal_color := Color(0.2, 0.9, 0.5, signal_alpha)
				draw_circle(center, 10.0 * data["signal_strength"], signal_color)

		# Player marker
		if sector_id == player_sector:
			draw_circle(center + Vector2(0, -18), 5.0, Color(1.0, 1.0, 1.0, 0.9))

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
