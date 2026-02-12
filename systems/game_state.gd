extends Node
## Global game state singleton.
## Tracks player progress, current sector, navigation graph, and session data.

signal sector_entered(sector_id: String)
signal sector_exited()
signal relic_acquired(relic: Dictionary)
signal credits_changed(new_total: int)
signal fuel_changed(current: float, max_fuel: float)

# Player persistent data
var player_credits: int = 0
var vault_capacity: int = 10
var ship_upgrades: Dictionary = {}

# Fuel system
var fuel: float = 100.0
var max_fuel: float = 100.0
const FUEL_COST_PER_JUMP: float = 8.0

# Home base
var home_sector_id: String = "S_0_0"
const HOME_POSITION: Vector2i = Vector2i(0, 0)

# Session state
var current_sector_id: String = ""
var player_map_position: Vector2i = Vector2i(0, 0)
var galaxy_seed: int = 0
var explored_sectors: Array[String] = []

# Scene transition data (used to pass data between scenes)
var pending_sector_data: Dictionary = {}
var pending_sector_id: String = ""
var pending_entry_direction: String = ""  # "north", "south", "east", "west" — where player enters from
var spawn_health_percent: float = 1.0  # 0.0-1.0, reset after use

# Sector grid and connections
const GALAXY_WIDTH: int = 8
const GALAXY_HEIGHT: int = 6

# Sector data: sector_id -> {x, y, signal_strength, stability, threat_index, anomaly_family, explored, depleted, sync_pool}
var sectors: Dictionary = {}

# Connection graph: sector_id -> array of connected sector_ids
var connections: Dictionary = {}

# Anomaly families
const FAMILIES: Array[String] = ["FRACTAL", "VOID", "PULSE", "DRIFT", "ECHO"]

# Family color palette
const FAMILY_COLORS: Dictionary = {
	"FRACTAL": Color(0.2, 0.9, 0.6),   # Teal-green
	"VOID": Color(0.6, 0.15, 0.8),      # Deep purple
	"PULSE": Color(1.0, 0.45, 0.15),    # Orange
	"DRIFT": Color(0.3, 0.6, 1.0),      # Sky blue
	"ECHO": Color(0.95, 0.85, 0.2),     # Gold-yellow
}

static func get_family_color(family: String) -> Color:
	return FAMILY_COLORS.get(family, Color(0.5, 0.5, 0.5))

# Jump cooldown
var jump_cooldown: float = 0.0
const JUMP_COOLDOWN_DURATION: float = 2.0  # seconds after arriving before you can edge-jump again

# UI state persisted across scene changes
var map_overlay_open: bool = false
var codex_open: bool = false
var relay_market_open: bool = false


func _ready() -> void:
	galaxy_seed = randi()
	_generate_galaxy()
	# Set up initial scene data so sector.tscn can load home base on launch
	pending_sector_data = sectors[home_sector_id]
	pending_sector_id = home_sector_id
	pending_entry_direction = ""


func _process(delta: float) -> void:
	if jump_cooldown > 0.0:
		jump_cooldown -= delta


func _generate_galaxy() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = galaxy_seed

	# First pass: decide which sectors are void (impassable empty space)
	# ~20% of sectors become void, but never the starting sector or its neighbors
	var void_sectors: Dictionary = {}
	for y in range(GALAXY_HEIGHT):
		for x in range(GALAXY_WIDTH):
			var sector_id := "S_%d_%d" % [x, y]
			# Never void the starting position or its immediate neighbors
			var dist_from_start := absi(x - player_map_position.x) + absi(y - player_map_position.y)
			if dist_from_start <= 1:
				void_sectors[sector_id] = false
			else:
				void_sectors[sector_id] = rng.randf() < 0.2

	# Generate sectors
	for y in range(GALAXY_HEIGHT):
		for x in range(GALAXY_WIDTH):
			var sector_id := "S_%d_%d" % [x, y]
			var is_void: bool = void_sectors[sector_id]
			var is_home: bool = (x == HOME_POSITION.x and y == HOME_POSITION.y)
			var has_anomaly: bool = (not is_void) and (not is_home) and rng.randf() < 0.4
			var pool: int = rng.randi_range(5, 20) if has_anomaly else 0
			sectors[sector_id] = {
				"x": x,
				"y": y,
				"is_void": is_void,
				"signal_strength": rng.randf_range(0.2, 1.0) if has_anomaly else 0.0,
				"stability": rng.randf_range(0.5, 1.0),
				"threat_index": -1.0,
				"anomaly_family": FAMILIES[rng.randi() % FAMILIES.size()] if has_anomaly else "",
				"explored": false,
				"depleted": false,
				"sync_pool": pool,
				"syncs_remaining": pool,
				"player_synced": false,
			}
			connections[sector_id] = []

	# Connect cardinal neighbors — skip connections to/from void sectors
	for y in range(GALAXY_HEIGHT):
		for x in range(GALAXY_WIDTH):
			var sector_id := "S_%d_%d" % [x, y]
			if sectors[sector_id]["is_void"]:
				continue
			if x < GALAXY_WIDTH - 1:
				var east_id := "S_%d_%d" % [x + 1, y]
				if not sectors[east_id]["is_void"]:
					_add_connection(sector_id, east_id)
			if y < GALAXY_HEIGHT - 1:
				var south_id := "S_%d_%d" % [x, y + 1]
				if not sectors[south_id]["is_void"]:
					_add_connection(sector_id, south_id)

	# Mark starting sector as explored
	var start_id := "S_%d_%d" % [player_map_position.x, player_map_position.y]
	sectors[start_id]["explored"] = true
	explored_sectors.append(start_id)
	current_sector_id = start_id


func _add_connection(a: String, b: String) -> void:
	if b not in connections[a]:
		connections[a].append(b)
	if a not in connections[b]:
		connections[b].append(a)


func _get_cardinal_neighbors(x: int, y: int) -> Array[String]:
	var result: Array[String] = []
	if x > 0:
		result.append("S_%d_%d" % [x - 1, y])
	if x < GALAXY_WIDTH - 1:
		result.append("S_%d_%d" % [x + 1, y])
	if y > 0:
		result.append("S_%d_%d" % [x, y - 1])
	if y < GALAXY_HEIGHT - 1:
		result.append("S_%d_%d" % [x, y + 1])
	return result


func get_connected_sectors(sector_id: String) -> Array:
	return connections.get(sector_id, [])


func are_connected(a: String, b: String) -> bool:
	return b in connections.get(a, [])


func get_neighbor_in_direction(sector_id: String, direction: String) -> String:
	## Returns the connected sector in the given direction, or "" if none.
	var data: Dictionary = sectors.get(sector_id, {})
	if data.is_empty():
		return ""
	var x: int = data["x"]
	var y: int = data["y"]
	var target_id: String = ""
	match direction:
		"east":
			target_id = "S_%d_%d" % [x + 1, y]
		"west":
			target_id = "S_%d_%d" % [x - 1, y]
		"north":
			target_id = "S_%d_%d" % [x, y - 1]
		"south":
			target_id = "S_%d_%d" % [x, y + 1]
	if target_id != "" and are_connected(sector_id, target_id):
		return target_id
	return ""


func record_sync(sector_id: String) -> void:
	## Called when the player completes a sync in a sector.
	if not sectors.has(sector_id):
		return
	sectors[sector_id]["player_synced"] = true
	sectors[sector_id]["syncs_remaining"] = maxi(0, sectors[sector_id]["syncs_remaining"] - 1)
	if sectors[sector_id]["syncs_remaining"] <= 0:
		sectors[sector_id]["depleted"] = true


func is_sector_syncable(sector_id: String) -> bool:
	## Returns true if this sector has an anomaly the player hasn't synced yet.
	if not sectors.has(sector_id):
		return false
	var data: Dictionary = sectors[sector_id]
	return data["anomaly_family"] != "" and not data["player_synced"] and not data["depleted"]


func warp_home() -> void:
	## Warp back to home base. Resets position — fuel regens at the station over time.
	current_sector_id = home_sector_id
	player_map_position = HOME_POSITION
	sector_exited.emit()


func can_jump() -> bool:
	return jump_cooldown <= 0.0 and fuel >= FUEL_COST_PER_JUMP


func consume_fuel_for_jump() -> bool:
	if fuel < FUEL_COST_PER_JUMP:
		return false
	fuel -= FUEL_COST_PER_JUMP
	fuel_changed.emit(fuel, max_fuel)
	return true


func enter_sector(sector_id: String) -> void:
	current_sector_id = sector_id
	if sectors.has(sector_id):
		player_map_position = Vector2i(sectors[sector_id]["x"], sectors[sector_id]["y"])
	if sector_id not in explored_sectors:
		explored_sectors.append(sector_id)
		sectors[sector_id]["explored"] = true
	jump_cooldown = JUMP_COOLDOWN_DURATION
	sector_entered.emit(sector_id)


func exit_sector() -> void:
	sector_exited.emit()


func add_credits(amount: int) -> void:
	player_credits += amount
	credits_changed.emit(player_credits)


func spend_credits(amount: int) -> bool:
	if player_credits >= amount:
		player_credits -= amount
		credits_changed.emit(player_credits)
		return true
	return false


func save_game() -> Dictionary:
	return {
		"player_credits": player_credits,
		"vault_capacity": vault_capacity,
		"ship_upgrades": ship_upgrades,
		"explored_sectors": explored_sectors,
		"galaxy_seed": galaxy_seed,
		"fuel": fuel,
		"player_map_position": {"x": player_map_position.x, "y": player_map_position.y},
		"vault": RelicDB.get_vault_data(),
		"crafted_recipes": DemandManager.crafted_recipes,
	}


func load_game(data: Dictionary) -> void:
	player_credits = data.get("player_credits", 0)
	vault_capacity = data.get("vault_capacity", 10)
	ship_upgrades = data.get("ship_upgrades", {})
	explored_sectors = data.get("explored_sectors", [])
	galaxy_seed = data.get("galaxy_seed", randi())
	fuel = data.get("fuel", 100.0)
	var pos: Dictionary = data.get("player_map_position", {"x": 0, "y": 0})
	player_map_position = Vector2i(pos["x"], pos["y"])
	if data.has("vault"):
		RelicDB.load_vault_data(data["vault"])
	if data.has("crafted_recipes"):
		DemandManager.crafted_recipes.assign(data["crafted_recipes"])
