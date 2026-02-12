extends Node2D
## Anomaly node placed in a sector.
## Manages orbit zone visuals and delegates sync logic to Attunement system.
## Reads/writes persistent state from GameState.sectors.

signal anomaly_synced(family: String)

@export var anomaly_family: String = "FRACTAL"
@export var signal_strength: float = 1.0
@export var stability: float = 1.0
@export var sync_pool: int = 10

var attunement: Node = null
var syncs_remaining: int = 10
var is_depleted: bool = false
var player_already_synced: bool = false  # Prevents re-syncing on revisit
var sector_id: String = ""


func _ready() -> void:
	_load_persisted_state()
	_setup_attunement()
	_apply_family_color()


func _load_persisted_state() -> void:
	sector_id = GameState.pending_sector_id
	if GameState.sectors.has(sector_id):
		var data: Dictionary = GameState.sectors[sector_id]
		anomaly_family = data.get("anomaly_family", anomaly_family)
		signal_strength = data.get("signal_strength", signal_strength)
		stability = data.get("stability", stability)
		sync_pool = data.get("sync_pool", sync_pool)
		syncs_remaining = data.get("syncs_remaining", sync_pool)
		is_depleted = data.get("depleted", false)
		player_already_synced = data.get("player_synced", false)
	else:
		syncs_remaining = sync_pool

	# If player already synced or anomaly is depleted, mark attunement as complete
	if player_already_synced or is_depleted:
		# We'll set sync_complete on attunement after it's created
		pass


func _setup_attunement() -> void:
	var attune_script := preload("res://systems/attunement.gd")
	attunement = Node.new()
	attunement.set_script(attune_script)
	attunement.anomaly_family = anomaly_family
	attunement.stability = stability
	attunement.sync_completed.connect(_on_sync_completed)
	add_child(attunement)

	# If already synced, lock the attunement so it can't be re-synced
	if player_already_synced or is_depleted:
		attunement.sync_complete = true
		attunement.sync_progress = 1.0


func _apply_family_color() -> void:
	var col: Color = GameState.get_family_color(anomaly_family)
	var core_visual := get_node_or_null("CoreVisual") as Polygon2D
	if core_visual:
		core_visual.color = Color(col.r, col.g, col.b, 0.9)
	var mid_ring := get_node_or_null("MidRing") as Polygon2D
	if mid_ring:
		mid_ring.color = Color(col.r, col.g, col.b, 0.15)
	var outer_ring := get_node_or_null("OuterRing") as Polygon2D
	if outer_ring:
		outer_ring.color = Color(col.r, col.g, col.b, 0.06)


# Orbital pull settings per tier
const ORBIT_SPEEDS: Dictionary = {
	"core": 120.0,
	"mid": 80.0,
	"outer": 50.0,
}
const PULL_STRENGTH: Dictionary = {
	"core": 25.0,
	"mid": 12.0,
	"outer": 5.0,
}
# Minimum orbit distance — ship can't get closer than this
const MIN_ORBIT_RADIUS: float = 60.0


func _physics_process(_delta: float) -> void:
	var ship := _get_player_ship()
	if ship == null:
		return

	var distance: float = global_position.distance_to(ship.global_position)

	# Push ship out if it gets too close to the center
	if distance < MIN_ORBIT_RADIUS and distance > 0.1:
		var push_dir: Vector2 = (ship.global_position - global_position).normalized()
		ship.global_position = global_position + push_dir * MIN_ORBIT_RADIUS
		distance = MIN_ORBIT_RADIUS

	var tier: String = attunement.get_orbit_tier(distance)

	# Apply orbital force if within any orbit tier
	if tier != "none":
		_apply_orbit(ship, distance, tier)

	# Update sync (handles both syncing and de-sync)
	# Shooting pauses sync — progress only advances when not in combat
	if not is_depleted and not player_already_synced:
		if ship.get("is_in_combat"):
			return
		var ship_mod: float = GameState.ship_upgrades.get("sync_rate", 1.0)
		attunement.update_sync(get_physics_process_delta_time(), distance, ship_mod)


func _apply_orbit(ship: CharacterBody2D, distance: float, tier: String) -> void:
	if not ship.has_method("apply_orbital_force"):
		return

	var to_anomaly: Vector2 = (global_position - ship.global_position).normalized()
	# Tangential direction (perpendicular, clockwise orbit)
	var tangent: Vector2 = Vector2(-to_anomaly.y, to_anomaly.x)

	var orbit_speed: float = ORBIT_SPEEDS.get(tier, 0.0)
	var pull: float = PULL_STRENGTH.get(tier, 0.0)

	# Scale orbit speed by distance — prevents spinning at tight radii
	# At MIN_ORBIT_RADIUS the speed is capped, at outer edge it's full
	var max_radius: float = attunement.ORBIT_OUTER_RADIUS
	var radius_factor: float = clampf(distance / max_radius, 0.3, 1.0)
	orbit_speed *= radius_factor

	# No inward pull at minimum radius — only tangential orbit
	if distance <= MIN_ORBIT_RADIUS + 5.0:
		pull = 0.0

	var orbital_velocity: Vector2 = tangent * orbit_speed + to_anomaly * pull

	ship.apply_orbital_force(orbital_velocity)


func _get_player_ship() -> CharacterBody2D:
	var ships := get_tree().get_nodes_in_group("player_ship")
	if ships.is_empty():
		return null
	return ships[0] as CharacterBody2D


func _on_sync_completed(family: String) -> void:
	player_already_synced = true

	# Persist to GameState
	GameState.record_sync(sector_id)
	syncs_remaining = GameState.sectors[sector_id]["syncs_remaining"]
	is_depleted = GameState.sectors[sector_id]["depleted"]

	# Roll a relic from this anomaly's family
	var relic := RelicDB.roll_relic(family)
	if not relic.is_empty():
		var added := RelicDB.add_to_vault(relic)
		if added:
			var value := DemandManager.get_effective_value(relic)
			CreditLedger.earn(
				int(value),
				CreditLedger.Source.SYNC_COMPLETION,
				{"relic_id": relic.get("relic_id", ""), "family": family}
			)
			GameState.relic_acquired.emit(relic)

	anomaly_synced.emit(family)


func get_sync_progress() -> float:
	if attunement == null:
		return 0.0
	return attunement.sync_progress


func get_orbit_tier_for_player() -> String:
	var ship := _get_player_ship()
	if ship == null:
		return "none"
	var distance: float = global_position.distance_to(ship.global_position)
	return attunement.get_orbit_tier(distance)
