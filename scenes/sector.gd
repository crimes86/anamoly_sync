extends Node2D
## Instanced sector scene containing anomaly, player ship, and threats.

signal sector_complete()

var sector_id: String = ""
var sector_data: Dictionary = {}
var has_anomaly: bool = false
var is_home_sector: bool = false

@onready var ship: CharacterBody2D = $Ship
@onready var anomaly_node: Node2D = $Anomaly
@onready var hud: CanvasLayer = $HUD

# Entry spawn positions — "north" means "I came from the north" → spawn at top
const SPAWN_POSITIONS: Dictionary = {
	"north": Vector2(640, 40),    # Came from north → appear at top
	"south": Vector2(640, 680),   # Came from south → appear at bottom
	"east": Vector2(1240, 360),   # Came from east → appear at right
	"west": Vector2(40, 360),     # Came from west → appear at left
	"": Vector2(640, 360),        # Default center (from galaxy map)
}


func _ready() -> void:
	# Read transition data from GameState
	sector_data = GameState.pending_sector_data
	sector_id = GameState.pending_sector_id

	has_anomaly = sector_data.get("anomaly_family", "") != ""
	is_home_sector = sector_id == GameState.home_sector_id

	_setup_anomaly()
	_setup_home_station()
	_position_ship()
	_connect_signals()

	if hud and hud.has_method("set_sector_info"):
		if is_home_sector:
			hud.set_sector_info(sector_id, "HOME BASE")
		else:
			var family: String = sector_data.get("anomaly_family", "EMPTY")
			if sector_data.get("player_synced", false):
				family += " [SYNCED]"
			elif sector_data.get("depleted", false):
				family += " [DEPLETED]"
			hud.set_sector_info(sector_id, family)


func _setup_anomaly() -> void:
	if not has_anomaly:
		# No anomaly in this sector — remove the node
		if anomaly_node:
			anomaly_node.queue_free()
			anomaly_node = null
		return

	if anomaly_node:
		anomaly_node.anomaly_family = sector_data["anomaly_family"]
		anomaly_node.signal_strength = sector_data.get("signal_strength", 1.0)
		anomaly_node.stability = sector_data.get("stability", 1.0)
		anomaly_node.sync_pool = sector_data.get("sync_pool", 10)


func _setup_home_station() -> void:
	if not is_home_sector:
		return
	# Spawn the home station visual at center
	var station_script := preload("res://scenes/home_station.gd")
	var station := Node2D.new()
	station.set_script(station_script)
	station.global_position = Vector2(640, 360)
	add_child(station)
	# Tint the background slightly different for home
	var bg := $Background as ColorRect
	if bg:
		bg.color = Color(0.03, 0.03, 0.06, 1)


func _position_ship() -> void:
	if ship == null:
		return
	var entry_dir: String = GameState.pending_entry_direction
	ship.global_position = SPAWN_POSITIONS.get(entry_dir, SPAWN_POSITIONS[""])


func _connect_signals() -> void:
	if ship:
		ship.warp_completed.connect(_on_warp_completed)
		ship.ship_destroyed.connect(_on_ship_destroyed)
		ship.health_changed.connect(_on_ship_health_changed)
		ship.warp_charge_changed.connect(_on_warp_charge_changed)
		ship.edge_jump_completed.connect(_on_edge_jump_completed)
		ship.edge_jump_progress_changed.connect(_on_edge_jump_progress_changed)
		ship.edge_jump_started.connect(_on_edge_jump_started)
		ship.edge_jump_cancelled.connect(_on_edge_jump_cancelled)
		# Set initial health display
		_on_ship_health_changed(ship.health, ship.max_health)

	if anomaly_node:
		anomaly_node.anomaly_synced.connect(_on_anomaly_synced)


func _physics_process(_delta: float) -> void:
	_update_hud()


func _update_hud() -> void:
	if hud == null:
		return
	if is_home_sector:
		if hud.has_method("update_sync_bar"):
			hud.update_sync_bar(0.0)
		if hud.has_method("update_orbit_tier"):
			hud.update_orbit_tier("home")
		return
	if anomaly_node and hud.has_method("update_sync_bar"):
		hud.update_sync_bar(anomaly_node.get_sync_progress())
	elif not has_anomaly and hud.has_method("update_sync_bar"):
		hud.update_sync_bar(0.0)
	if anomaly_node and hud.has_method("update_orbit_tier"):
		hud.update_orbit_tier(anomaly_node.get_orbit_tier_for_player())
	elif not has_anomaly and hud.has_method("update_orbit_tier"):
		hud.update_orbit_tier("none")


func _on_warp_completed() -> void:
	GameState.warp_home()
	GameState.pending_sector_data = GameState.sectors[GameState.home_sector_id]
	GameState.pending_sector_id = GameState.home_sector_id
	GameState.pending_entry_direction = ""
	get_tree().change_scene_to_file("res://scenes/sector.tscn")


func _on_ship_destroyed() -> void:
	GameState.exit_sector()
	get_tree().change_scene_to_file("res://scenes/galaxy_map.tscn")


func _on_edge_jump_completed(direction: String) -> void:
	# Get the neighbor sector in this direction
	var neighbor_id := GameState.get_neighbor_in_direction(sector_id, direction)
	if neighbor_id == "" or not GameState.consume_fuel_for_jump():
		return

	# Determine entry direction for the next sector (opposite of exit direction)
	var entry_dir: String = ""
	match direction:
		"north":
			entry_dir = "south"
		"south":
			entry_dir = "north"
		"east":
			entry_dir = "west"
		"west":
			entry_dir = "east"

	GameState.enter_sector(neighbor_id)
	GameState.pending_sector_data = GameState.sectors[neighbor_id]
	GameState.pending_sector_id = neighbor_id
	GameState.pending_entry_direction = entry_dir
	get_tree().change_scene_to_file("res://scenes/sector.tscn")


func _on_edge_jump_progress_changed(progress: float) -> void:
	if hud and hud.has_method("update_edge_jump_bar"):
		hud.update_edge_jump_bar(progress)


func _on_edge_jump_started(direction: String) -> void:
	if hud and hud.has_method("show_edge_jump_indicator"):
		hud.show_edge_jump_indicator(direction)


func _on_edge_jump_cancelled() -> void:
	if hud and hud.has_method("hide_edge_jump_indicator"):
		hud.hide_edge_jump_indicator()


func _on_ship_health_changed(current: int, max_hp: int) -> void:
	if hud and hud.has_method("update_health"):
		hud.update_health(current, max_hp)


func _on_warp_charge_changed(progress: float) -> void:
	if hud and hud.has_method("update_warp_bar"):
		hud.update_warp_bar(progress)


func _on_anomaly_synced(family: String) -> void:
	if hud and hud.has_method("show_relic_acquired"):
		hud.show_relic_acquired(family)
