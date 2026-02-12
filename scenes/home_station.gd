extends Node2D
## Visual for the home base station. Drawn with _draw() — no sprites needed.
## Sits at center of the home sector.

const FUEL_REGEN_RATE: float = 1.67  # fuel per second (~1 minute for full tank)
const HEALTH_REGEN_RATE: float = 20.0  # HP per second
const REGEN_RADIUS: float = 250.0  # must be within this range to regen

var pulse_time: float = 0.0


func _process(delta: float) -> void:
	pulse_time += delta
	queue_redraw()

	# Regen fuel and health for nearby player
	var ship := _get_player_ship()
	if ship == null:
		return
	var dist: float = global_position.distance_to(ship.global_position)
	if dist <= REGEN_RADIUS:
		_regen_fuel(delta)
		_regen_health(delta, ship)


func _regen_fuel(delta: float) -> void:
	if GameState.fuel < GameState.max_fuel:
		GameState.fuel = minf(GameState.max_fuel, GameState.fuel + FUEL_REGEN_RATE * delta)
		GameState.fuel_changed.emit(GameState.fuel, GameState.max_fuel)


func _regen_health(delta: float, ship: CharacterBody2D) -> void:
	if ship.health < ship.max_health:
		ship.health = mini(ship.max_health, ship.health + int(HEALTH_REGEN_RATE * delta))
		ship.health_changed.emit(ship.health, ship.max_health)


func _get_player_ship() -> CharacterBody2D:
	var ships := get_tree().get_nodes_in_group("player_ship")
	if ships.is_empty():
		return null
	return ships[0] as CharacterBody2D


func _draw() -> void:
	var pulse: float = (sin(pulse_time * 1.5) + 1.0) * 0.5  # 0.0 to 1.0

	# Regen radius ring
	var ring_alpha: float = 0.06 + pulse * 0.04
	draw_arc(Vector2.ZERO, REGEN_RADIUS, 0, TAU, 64, Color(0.2, 0.8, 0.4, ring_alpha), 1.5)

	# Outer hull — octagon
	var outer_pts: PackedVector2Array = _make_polygon(8, 40.0)
	draw_colored_polygon(outer_pts, Color(0.15, 0.18, 0.25, 0.9))
	draw_polyline(outer_pts, Color(0.5, 0.6, 0.7, 0.7), 2.0)

	# Inner structure — square rotated 45 degrees
	var inner_pts: PackedVector2Array = _make_polygon(4, 22.0, PI / 4.0)
	draw_colored_polygon(inner_pts, Color(0.1, 0.12, 0.2, 0.9))
	draw_polyline(inner_pts, Color(0.4, 0.5, 0.65, 0.6), 1.5)

	# Center beacon — pulsing
	var beacon_color := Color(0.9, 0.7, 0.2, 0.5 + pulse * 0.4)
	draw_circle(Vector2.ZERO, 6.0 + pulse * 2.0, beacon_color)
	draw_circle(Vector2.ZERO, 3.0, Color(1.0, 0.9, 0.5, 0.9))

	# Docking arms — 4 lines extending outward
	for i in range(4):
		var angle: float = i * PI / 2.0 + PI / 4.0
		var arm_start := Vector2.RIGHT.rotated(angle) * 42.0
		var arm_end := Vector2.RIGHT.rotated(angle) * 65.0
		draw_line(arm_start, arm_end, Color(0.4, 0.5, 0.6, 0.6), 2.0)
		# Arm tips
		draw_circle(arm_end, 3.0, Color(0.3, 0.6, 0.4, 0.5 + pulse * 0.3))

	# "HOME BASE" label
	draw_string(ThemeDB.fallback_font, Vector2(-38, 58), "HOME BASE", HORIZONTAL_ALIGNMENT_CENTER, 80, 12, Color(0.7, 0.7, 0.8, 0.6))

	# Status labels when player is nearby
	var ship := _get_player_ship()
	if ship and global_position.distance_to(ship.global_position) <= REGEN_RADIUS:
		if GameState.fuel < GameState.max_fuel:
			var regen_color := Color(0.3, 0.9, 0.4, 0.4 + pulse * 0.3)
			draw_string(ThemeDB.fallback_font, Vector2(-30, 74), "REFUELING", HORIZONTAL_ALIGNMENT_CENTER, 64, 11, regen_color)
		var market_color := Color(0.85, 0.75, 1.0, 0.5 + pulse * 0.3)
		draw_string(ThemeDB.fallback_font, Vector2(-34, 90), "MARKET [E]", HORIZONTAL_ALIGNMENT_CENTER, 72, 11, market_color)


func _make_polygon(sides: int, radius: float, offset_angle: float = 0.0) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in range(sides + 1):  # +1 to close the shape for polyline
		var angle: float = offset_angle + i * TAU / sides
		pts.append(Vector2(cos(angle), sin(angle)) * radius)
	return pts
